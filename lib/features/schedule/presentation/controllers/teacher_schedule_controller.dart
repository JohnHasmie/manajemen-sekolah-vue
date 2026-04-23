// Controller for TeachingScheduleScreen.
// Delegates to helper classes for cache, filtering, data loading, API calls.
//
// Usage in screen:
//   final ctrl = ref.read(teacherScheduleControllerProvider);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/'
    'teacher_schedule_api_helper.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/'
    'teacher_schedule_cache_helper.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/'
    'teacher_schedule_color_helper.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/'
    'teacher_schedule_data_loader.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/'
    'teacher_schedule_filter_helper.dart';

// Re-export result types for public API compatibility
export 'package:manajemensekolah/features/schedule/presentation/controllers/'
    'teacher_schedule_api_helper.dart'
    show LoadScheduleResult;
export 'package:manajemensekolah/features/schedule/presentation/controllers/'
    'teacher_schedule_cache_helper.dart'
    show CachedScheduleResult;
export 'package:manajemensekolah/features/schedule/presentation/controllers/'
    'teacher_schedule_data_loader.dart'
    show LoadAcademicYearDataResult, LoadDayDataResult, LoadSemesterDataResult;

/// Riverpod provider for [TeacherScheduleController].
/// Use `ref.read(teacherScheduleControllerProvider)` from the screen.
final teacherScheduleControllerProvider = Provider<TeacherScheduleController>((
  ref,
) {
  return TeacherScheduleController(ref);
});

/// Plain Dart class that delegates all schedule-related operations
/// to helper classes. Receives `ref` (like Laravel's DI container)
/// and passes it to loaders that need Riverpod access.
class TeacherScheduleController {
  final Ref _ref;

  TeacherScheduleController(this._ref);

  /// Returns the current academic year based on the current date.
  String getCurrentAcademicYear() =>
      TeacherScheduleDataLoader.getCurrentAcademicYear();

  /// Builds the local-cache key for the schedule.
  String? buildScheduleCacheKey({
    required String teacherId,
    required List<String> selectedDayIds,
    required String? selectedClassId,
    required String searchText,
    required String? selectedFilterSemester,
    required String selectedSemester,
    required String selectedAcademicYear,
    required bool isHomeroomView,
    required Map<String, dynamic>? selectedHomeroomClass,
  }) => TeacherScheduleCacheHelper.buildScheduleCacheKey(
    teacherId: teacherId,
    selectedDayIds: selectedDayIds,
    selectedClassId: selectedClassId,
    searchText: searchText,
    selectedFilterSemester: selectedFilterSemester,
    selectedSemester: selectedSemester,
    selectedAcademicYear: selectedAcademicYear,
    isHomeroomView: isHomeroomView,
    selectedHomeroomClass: selectedHomeroomClass,
  );

  /// Loads the school day list (cache-first, 24h TTL).
  Future<LoadDayDataResult?> loadDayData() =>
      TeacherScheduleDataLoader(_ref).loadDayData();

  /// Loads the semester list and resolves the default semester.
  Future<LoadSemesterDataResult> loadTermData() =>
      TeacherScheduleDataLoader(_ref).loadTermData();

  /// Loads the academic year list and resolves the default year.
  Future<LoadAcademicYearDataResult> loadAcademicYearData() =>
      TeacherScheduleDataLoader(_ref).loadAcademicYearData();

  /// Tries to load a schedule snapshot from local cache.
  Future<CachedScheduleResult> loadCachedSchedule(String cacheKey) =>
      TeacherScheduleCacheHelper.loadCachedSchedule(cacheKey);

  /// Fetches the teacher's schedule from the API.
  Future<LoadScheduleResult> fetchScheduleFromApi({
    required String teacherId,
    required String semesterToUse,
    required String academicYearToUse,
    required bool isHomeroomView,
    required Map<String, dynamic>? selectedHomeroomClass,
  }) => TeacherScheduleApiHelper.fetchScheduleFromApi(
    teacherId: teacherId,
    semesterToUse: semesterToUse,
    academicYearToUse: academicYearToUse,
    isHomeroomView: isHomeroomView,
    selectedHomeroomClass: selectedHomeroomClass,
  );

  /// Invalidates the cached schedule and related cache entries.
  Future<void> invalidateScheduleCache(String? cacheKey) =>
      TeacherScheduleCacheHelper.invalidateScheduleCache(cacheKey);

  /// Saves a freshly-fetched schedule to the local cache.
  void saveScheduleToCache({
    required String cacheKey,
    required List<dynamic> schedules,
    required List<Map<String, String>> availableClasses,
    required String prefKeyLastCacheKey,
  }) => TeacherScheduleCacheHelper.saveScheduleToCache(
    cacheKey: cacheKey,
    schedules: schedules,
    availableClasses: availableClasses,
    prefKeyLastCacheKey: prefKeyLastCacheKey,
  );

  /// Normalises a day name to its canonical Indonesian form.
  String normalizeDayName(String name) =>
      TeacherScheduleFilterHelper.normalizeDayName(name);

  /// Extracts the list of day-ID strings from a schedule item.
  List<String> extractDayIds(dynamic schedule) =>
      TeacherScheduleFilterHelper.extractDayIds(schedule);

  /// Filters and sorts the raw schedule list according to filters.
  List<dynamic> getFilteredSchedules({
    required List<dynamic> scheduleList,
    required String searchText,
    required List<String> selectedDayIds,
    required String? selectedClassId,
    required Map<String, String> dayIdMap,
  }) => TeacherScheduleFilterHelper.getFilteredSchedules(
    scheduleList: scheduleList,
    searchText: searchText,
    selectedDayIds: selectedDayIds,
    selectedClassId: selectedClassId,
    dayIdMap: dayIdMap,
  );

  /// Returns the primary theme color for the teacher role.
  /// Delegates to TeacherScheduleColorHelper.getPrimaryColor().
  /// (Note: return type is Color, import from flutter/material.dart)
  /// This preserves the original public API.
  dynamic getPrimaryColor() => TeacherScheduleColorHelper.getPrimaryColor();

  /// Returns the gradient used on the screen header card.
  /// Delegates to TeacherScheduleColorHelper.getCardGradient().
  /// (Note: return type is LinearGradient)
  /// This preserves the original public API.
  dynamic getCardGradient() => TeacherScheduleColorHelper.getCardGradient();
}
