import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/announcements/data/announcement_service.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart';

/// Mixin for admin announcement data loading and caching.
///
/// Handles loading announcements with pagination, caching,
/// filtering, and search support.
mixin AdminDataLoadingMixin on ConsumerState<AdminAnnouncementScreen> {
  List<dynamic> announcements = [];
  bool isLoading = true;
  String? errorMessage;
  Set<String> processedIds = {};

  String? selectedPriorityFilter;
  String? selectedTargetFilter;
  String? selectedStatusFilter;

  TextEditingController get searchController;

  // PaginationMixin properties
  int get currentPage;
  set currentPage(int value);
  int get perPage;
  bool get isLoadingMore;
  set isLoadingMore(bool value);
  bool get hasMoreData;
  set hasMoreData(bool value);
  ScrollController get paginationScrollController;

  String? mapPriorityFilter(String? value);

  String? mapTargetFilter(String? value);

  String? mapStatusFilter(String? value);

  Future<void> checkAndShowTour();

  void updatePaginationFromMeta(Map<String, dynamic>? meta);

  String? buildAnnouncementCacheKey() {
    if (currentPage != 1) return null;
    if (selectedPriorityFilter != null ||
        selectedTargetFilter != null ||
        selectedStatusFilter != null ||
        searchController.text.trim().isNotEmpty) {
      return null;
    }
    return 'announcement_list_admin';
  }

  Future<void> forceRefresh() async {
    final cacheKey = buildAnnouncementCacheKey();
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await LocalCacheService.clearStartingWith('tour_announcement_');
    await LocalCacheService.invalidate(
      CacheKeyBuilder.custom('announcement', 'filter_options'),
    );
    loadData(resetPage: true, useCache: false);
  }

  void handleSearch() {
    setState(() {
      currentPage = 1;
    });
    loadData();
  }

  Future<void> loadFilterOptions() async {
    try {
      final cacheKey = CacheKeyBuilder.custom('announcement', 'filter_options');
      try {
        final cached = await LocalCacheService.load(
          cacheKey,
          ttl: const Duration(hours: 6),
        );
        if (cached != null && mounted) {
          AppLogger.info(
            'announcement',
            'Announcement filter options loaded from cache',
          );
          return;
        }
      } catch (e) {
        AppLogger.error(
          'announcement',
          'Announcement filter cache load failed: $e',
        );
      }

      final response = await getIt<ApiAnnouncementService>()
          .getAnnouncementFilterOptions();

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        LocalCacheService.save(cacheKey, {
          'prioritas_options': response['data']['prioritas_options'] ?? [],
          'target_options': response['data']['target_options'] ?? [],
          'status_options': response['data']['status_options'] ?? [],
        });
        AppLogger.info('announcement', 'Announcement filter options loaded');
      }
    } catch (e) {
      AppLogger.error(
        'announcement',
        'Error loading announcement filter options: $e',
      );
    }
  }

  Future<void> loadData({bool resetPage = true, bool useCache = true}) async {
    try {
      if (resetPage) {
        currentPage = 1;
        hasMoreData = true;
        errorMessage = null;
        processedIds.clear();
      }

      if (useCache && resetPage) {
        final cacheKey = buildAnnouncementCacheKey();
        if (cacheKey != null) {
          final cached = await LocalCacheService.load(cacheKey);
          if (cached != null &&
              cached is Map &&
              cached['data'] != null &&
              mounted) {
            final cachedList = cached['data'] as List<dynamic>;
            if (cachedList.isNotEmpty) {
              setState(() {
                announcements = cachedList;
                hasMoreData = cached['pagination']?['has_next_page'] ?? false;
                isLoading = false;
              });
              AppLogger.info('announcement', 'Announcements loaded from cache');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) checkAndShowTour();
              });
              return;
            }
          }
        }
      }

      if (announcements.isEmpty && mounted) {
        setState(() {
          isLoading = true;
        });
      }

      final mappedPrioritas = mapPriorityFilter(selectedPriorityFilter);
      final mappedRoleTarget = mapTargetFilter(selectedTargetFilter);
      final mappedStatus = mapStatusFilter(selectedStatusFilter);

      final response = await getIt<ApiAnnouncementService>()
          .getAnnouncementsPaginated(
            page: currentPage,
            limit: perPage,
            prioritas: mappedPrioritas,
            roleTarget: mappedRoleTarget,
            status: mappedStatus,
            search: searchController.text.trim().isEmpty
                ? null
                : searchController.text.trim(),
          );

      if (!mounted) return;

      if (response.containsKey('data') && response.containsKey('pagination')) {
        final fetchedList = response['data'] ?? [];

        setState(() {
          announcements = fetchedList;
          hasMoreData = response['pagination']?['has_next_page'] ?? false;
          isLoading = false;
          errorMessage = null;
        });

        final cacheKey = buildAnnouncementCacheKey();
        if (cacheKey != null) {
          LocalCacheService.save(cacheKey, {
            'data': fetchedList,
            'pagination': response['pagination'],
          });
        }
      } else {
        AppLogger.error('announcement', 'Unexpected response structure');
        setState(() {
          isLoading = false;
          errorMessage = 'Unexpected response structure';
        });
      }
    } catch (e) {
      if (!mounted) return;

      if (announcements.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = ErrorUtils.getFriendlyMessage(e);
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }

      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        'Gagal memuat data pengumuman: '
        '${ErrorUtils.getFriendlyMessage(e)}',
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          checkAndShowTour();
        }
      });
    }
  }

  Future<void> loadPage(int page) async {
    try {
      final mappedPrioritas = mapPriorityFilter(selectedPriorityFilter);
      final mappedRoleTarget = mapTargetFilter(selectedTargetFilter);
      final mappedStatus = mapStatusFilter(selectedStatusFilter);

      final response = await getIt<ApiAnnouncementService>()
          .getAnnouncementsPaginated(
            page: page,
            limit: perPage,
            prioritas: mappedPrioritas,
            roleTarget: mappedRoleTarget,
            status: mappedStatus,
            search: searchController.text.trim().isEmpty
                ? null
                : searchController.text.trim(),
          );

      if (!mounted) return;

      if (response.containsKey('data') && response.containsKey('pagination')) {
        final newItems = response['data'] ?? [];

        setState(() {
          if (newItems is List) {
            announcements.addAll(newItems);
          }
          updatePaginationFromMeta(response['pagination']);
        });
      } else {
        AppLogger.error(
          'announcement',
          'Unexpected response structure for loadPage',
        );
        setState(() {
          currentPage--;
        });
      }

      AppLogger.info(
        'announcement',
        'Loaded more announcements: Page $page, Total: '
            '${announcements.length}',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        currentPage--;
      });

      AppLogger.error('announcement', 'Error loading more announcements: $e');
    }
  }
}
