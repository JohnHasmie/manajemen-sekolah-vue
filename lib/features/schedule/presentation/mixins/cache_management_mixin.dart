import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';

/// Mixin providing cache key generation and schedule cache
/// management for the admin schedule controller.
mixin CacheManagementMixin {
  /// Generates the cache key for the schedule list.
  /// Returns null when filters or search are active.
  ///
  /// [currentPage], [showTableView], filters and search are
  /// passed in because they live as state fields on the screen.
  String? buildScheduleCacheKey({
    required int currentPage,
    required bool showTableView,
    required String selectedAcademicYear,
    required String selectedSemester,
    required String? selectedTeacherId,
    required String? selectedClassId,
    required String? selectedDayId,
    required String? selectedJamPelajaran,
    required String? selectedFilterSemester,
    required String searchText,
    required String? lastCachedAcademicYear,
    required String? lastCachedSemester,
  }) {
    if (currentPage != 1) return null;
    if (showTableView) return null;
    if (selectedTeacherId != null ||
        selectedClassId != null ||
        selectedDayId != null ||
        selectedJamPelajaran != null ||
        selectedFilterSemester != null ||
        searchText.trim().isNotEmpty) {
      return null;
    }

    final key = 'schedule_list_${selectedAcademicYear}_$selectedSemester';

    if (selectedAcademicYear != lastCachedAcademicYear ||
        selectedSemester != lastCachedSemester) {
      final prefs = PreferencesService();
      prefs.setString('schedule_last_year_id', selectedAcademicYear);
      prefs.setString('schedule_last_semester_id', selectedSemester);
    }

    return key;
  }

  /// Saves the loaded schedule data into the local cache.
  /// Only saves for default, unfiltered first-page views.
  void saveScheduleToCache({
    required String? cacheKey,
    required Map<String, dynamic> scheduleResponse,
    required List<dynamic> teacher,
    required List<dynamic> subject,
    required List<dynamic> classData,
    required List<dynamic> days,
    required List<dynamic> semester,
    required List<dynamic> lessonHours,
  }) {
    if (cacheKey == null) return;
    LocalCacheService.save(cacheKey, {
      'schedules': scheduleResponse['data'] ?? [],
      'pagination': scheduleResponse['pagination'],
      'teachers': teacher,
      'subjects': subject,
      'classes': classData,
      'hari': days,
      'semester': semester,
      'lessonHour': lessonHours,
    });
  }

  /// Invalidates caches and triggers a clean API reload.
  Future<void> forceRefresh({
    required String? cacheKey,
    required String selectedAcademicYear,
  }) async {
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await LocalCacheService.invalidate(
      CacheKeyBuilder.custom('schedule_filter_options', selectedAcademicYear),
    );
  }
}
