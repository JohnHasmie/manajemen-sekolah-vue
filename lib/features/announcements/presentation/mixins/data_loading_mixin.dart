import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';

/// Mixin for loading and managing announcement data.
mixin DataLoadingMixin on ConsumerState<ParentAnnouncementScreen> {
  final ApiService apiService = ApiService();

  List<dynamic> announcementList = [];
  bool isLoading = true;
  String? errorMessage;
  String userRole = 'wali';

  String get announcementCacheKey => 'announcement_list_$userRole';

  Future<void> loadData({bool useCache = true}) async {
    resolveUserRole();

    if (useCache) {
      final cached = await LocalCacheService.load(announcementCacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            announcementList = List<dynamic>.from(cached);
            isLoading = false;
            errorMessage = null;
          });
          checkAndShowTour();
        }
        AppLogger.debug(
          'announcement',
          'AnnouncementScreen: Data from cache (${cached.length})',
        );
        // Don't return — continue fetching fresh data from API
      }
    }

    // Show skeleton only if list is still empty (no cache hit)
    if (announcementList.isEmpty && mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }
    await fetchFromApi();
  }

  void resolveUserRole() {
    final prefs = PreferencesService();
    final userData = prefs.getString('user');
    if (userData != null) {
      final user = json.decode(userData);
      if (mounted) {
        setState(() {
          userRole = user['role'] ?? 'wali';
        });
      }
    }
  }

  Future<void> fetchFromApi() async {
    resolveUserRole();
    try {
      final response = await apiService.get('/announcement/user/current');

      List<dynamic> announcementListData = [];
      if (response is Map<String, dynamic> && response['data'] != null) {
        announcementListData = response['data'] is List ? response['data'] : [];
      } else if (response is List) {
        announcementListData = response;
      }

      if (mounted) {
        setState(() {
          announcementList = announcementListData;
          isLoading = false;
          errorMessage = null;
        });
      }

      await LocalCacheService.save(announcementCacheKey, announcementListData);
    } catch (e) {
      AppLogger.error('announcement', e);
      if (mounted && announcementList.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = ErrorUtils.getFriendlyMessage(e);
        });
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          checkAndShowTour();
        }
      });
    }
  }

  Future<void> forceRefresh() async {
    await LocalCacheService.clearStartingWith('announcement_');
    await fetchFromApi();
  }

  Future<void> checkAndShowTour() async {}
}
