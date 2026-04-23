import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/settings/data/settings_service.dart';

/// Mixin for profile loading and role management.
mixin SettingsScreenProfileMixin {
  static const String _profileCacheKey = 'settings_profile';

  // Abstract properties - must be implemented by state class
  Map<String, dynamic> get profileData;
  set profileData(Map<String, dynamic> value);
  bool get isLoading;
  set isLoading(bool value);
  String get role;
  set role(String value);
  void setState(VoidCallback fn);
  BuildContext get context;
  WidgetRef get ref;

  /// Loads user role from SharedPreferences.
  Future<void> loadRole() async {
    try {
      final prefs = PreferencesService();
      final userJson = prefs.getString('user');
      if (userJson != null) {
        final user = jsonDecode(userJson);
        final rawRole = user['role']?.toString() ?? 'admin';
        String normalizedRole = rawRole;
        if (rawRole == 'teacher') normalizedRole = 'guru';
        if (rawRole == 'parent') normalizedRole = 'wali';
        setState(() => role = normalizedRole);
      }
    } catch (e) {
      AppLogger.error('settings', e);
    }
  }

  /// Invalidates profile cache and reloads from API.
  Future<void> forceRefresh() async {
    await LocalCacheService.invalidate(_profileCacheKey);
    await loadProfile(useCache: false);
  }

  /// Loads user profile with cache-first pattern.
  /// Step 1: Try cache for instant display.
  /// Step 2: Show loading only if no data.
  /// Step 3: Fetch fresh from API.
  Future<void> loadProfile({bool useCache = true}) async {
    await _tryLoadFromCache(useCache);

    if (profileData.isEmpty) {
      setState(() => isLoading = true);
    }

    await _fetchAndCacheProfile();
  }

  /// Attempts to load profile from cache.
  Future<void> _tryLoadFromCache(bool useCache) async {
    if (!useCache) return;
    final cached = await LocalCacheService.load(_profileCacheKey);
    if (cached != null && cached is Map<String, dynamic>) {
      setState(() {
        profileData = cached;
        isLoading = false;
      });
    }
  }

  /// Fetches profile from API and caches it.
  Future<void> _fetchAndCacheProfile() async {
    try {
      final data = await getIt<ApiSettingsService>().getProfile();

      await LocalCacheService.save(_profileCacheKey, data);

      setState(() {
        profileData = data;
        isLoading = false;
      });
    } catch (e) {
      AppLogger.error('settings', e);
      if (profileData.isEmpty) {
        setState(() => isLoading = false);
        _showProfileLoadError(e);
      }
    }
  }

  /// Shows error message for profile load.
  void _showProfileLoadError(dynamic error) {
    final msg = ref.read(languageRiverpod).getTranslatedText({
      'en': 'Failed to load profile',
      'id': 'Gagal memuat profil',
    });
    SnackBarUtils.showError(
      context,
      '$msg: ${ErrorUtils.getFriendlyMessage(error)}',
    );
  }
}
