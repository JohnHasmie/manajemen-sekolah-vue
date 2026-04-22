// Cache helper methods for TeacherScheduleController.
// Handles schedule caching logic with TTL management.

import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Cached schedule snapshot returned by load cached methods.
/// If [found] is false the screen should not update state.
class CachedScheduleResult {
  final bool found;
  final List<dynamic> schedules;
  final List<Map<String, String>> availableClasses;

  const CachedScheduleResult({
    required this.found,
    this.schedules = const [],
    this.availableClasses = const [],
  });
}

/// Helper class for schedule cache operations.
class TeacherScheduleCacheHelper {
  /// Builds the local-cache key for the schedule given filter state.
  /// Returns `null` when caching should be skipped (active filters).
  ///
  /// Like `Cache::tags(['schedule'])->key(...)` in Laravel.
  static String? buildScheduleCacheKey({
    required String teacherId,
    required List<String> selectedDayIds,
    required String? selectedClassId,
    required String searchText,
    required String? selectedFilterSemester,
    required String selectedSemester,
    required String selectedAcademicYear,
    required bool isHomeroomView,
    required Map<String, dynamic>? selectedHomeroomClass,
  }) {
    // Don't cache when filters or search are active
    if (selectedDayIds.isNotEmpty ||
        selectedClassId != null ||
        searchText.isNotEmpty ||
        (selectedFilterSemester != null &&
            selectedFilterSemester != selectedSemester)) {
      return null;
    }
    if (teacherId.isEmpty) return null;

    final semesterToUse = selectedFilterSemester ?? selectedSemester;
    if (isHomeroomView && selectedHomeroomClass != null) {
      final classId = selectedHomeroomClass['id'].toString();
      return 'schedule_homeroom_${classId}_${semesterToUse}_'
          '$selectedAcademicYear';
    }
    return 'schedule_teacher_${teacherId}_${semesterToUse}_'
        '$selectedAcademicYear';
  }

  /// Tries to load a schedule snapshot from local cache.
  /// Returns [CachedScheduleResult.found] == false if nothing cached.
  ///
  /// Like `Cache::get('schedule_teacher_...')` in Laravel.
  static Future<CachedScheduleResult> loadCachedSchedule(
    String cacheKey,
  ) async {
    try {
      final cached = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(hours: 3),
      );
      if (cached != null) {
        final cachedData = Map<String, dynamic>.from(cached);
        return CachedScheduleResult(
          found: true,
          schedules: List<dynamic>.from(cachedData['schedules'] ?? []),
          availableClasses:
              (cachedData['availableClasses'] as List<dynamic>?)
                  ?.map((e) => Map<String, String>.from(e))
                  .toList() ??
              [],
        );
      }
    } catch (e) {
      AppLogger.error('schedule', 'Schedule cache load failed: $e');
    }
    return const CachedScheduleResult(found: false);
  }

  /// Invalidates the cached schedule and related cache entries.
  /// Called by the screen's "force refresh" menu item.
  ///
  /// Like `Cache::tags(['schedule'])->flush()` in Laravel.
  static Future<void> invalidateScheduleCache(String? cacheKey) async {
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await LocalCacheService.clearStartingWith('schedule_');
  }

  /// Saves a freshly-fetched schedule to the local cache.
  /// Also persists the cache key to SharedPreferences for early loading
  /// on the next app launch.
  static void saveScheduleToCache({
    required String cacheKey,
    required List<dynamic> schedules,
    required List<Map<String, String>> availableClasses,
    required String prefKeyLastCacheKey,
  }) {
    LocalCacheService.save(cacheKey, {
      'schedules': schedules,
      'availableClasses': availableClasses,
    });
    PreferencesService().setString(prefKeyLastCacheKey, cacheKey);
  }
}
