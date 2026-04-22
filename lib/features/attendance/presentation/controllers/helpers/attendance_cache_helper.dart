/// Cache management helper for admin attendance report.
///
/// Encapsulates cache key generation and cache operations.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_report_screen.dart';

class AttendanceCacheHelper {
  final WidgetRef ref;

  AttendanceCacheHelper(this.ref);

  /// Builds cache key for filter dropdown data.
  /// Returns a consistent key based on academic year.
  String buildFilterDataCacheKey() {
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return 'presence_filter_data_$yearId';
  }

  /// Builds cache key for summary list.
  /// Returns null when any filter is active or on pages > 1.
  String? buildSummaryCacheKey({
    required int currentPage,
    required String? selectedDateFilter,
    required List<String> selectedSubjectIds,
    required List<String> selectedClassIds,
    required List<String> selectedDayIds,
    required List<String> selectedLessonHourIds,
    required String searchText,
    required bool showTableView,
  }) {
    if (currentPage != 1) return null;
    if (selectedDateFilter != null ||
        selectedSubjectIds.isNotEmpty ||
        selectedClassIds.isNotEmpty ||
        selectedDayIds.isNotEmpty ||
        selectedLessonHourIds.isNotEmpty ||
        searchText.trim().isNotEmpty ||
        showTableView) {
      return null;
    }
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return 'presence_summary_$yearId';
  }

  /// Loads filter data from cache.
  /// Returns FilterDataResult if valid cache exists, otherwise null.
  Future<FilterDataResult?> loadFilterDataFromCache() async {
    final cacheKey = buildFilterDataCacheKey();
    final cached = await LocalCacheService.load(cacheKey);
    if (cached == null) return null;

    final subjects = cached['subjects'] as List<dynamic>? ?? [];
    final classes = cached['classes'] as List<dynamic>? ?? [];
    if (subjects.isEmpty && classes.isEmpty) return null;

    return FilterDataResult(
      subjects: subjects,
      classes: classes,
      teachers: cached['teachers'] as List<dynamic>? ?? [],
      lessonHours: cached['lessonHours'] as List<dynamic>? ?? [],
    );
  }

  /// Saves filter data to cache.
  void saveFilterDataToCache(FilterDataResult result) {
    final cacheKey = buildFilterDataCacheKey();
    LocalCacheService.save(cacheKey, {
      'subjects': result.subjects,
      'classes': result.classes,
      'teachers': result.teachers,
      'lessonHours': result.lessonHours,
    });
  }

  /// Loads summary list from cache (page 1, no filters).
  /// Returns items + hasMoreData on cache hit, otherwise null.
  Future<({List<AttendanceSummary> items, bool hasMoreData})?>
  loadSummaryFromCache({
    required String? selectedDateFilter,
    required List<String> selectedSubjectIds,
    required List<String> selectedClassIds,
    required List<String> selectedDayIds,
    required List<String> selectedLessonHourIds,
    required String searchText,
    required bool showTableView,
  }) async {
    final cacheKey = buildSummaryCacheKey(
      currentPage: 1,
      selectedDateFilter: selectedDateFilter,
      selectedSubjectIds: selectedSubjectIds,
      selectedClassIds: selectedClassIds,
      selectedDayIds: selectedDayIds,
      selectedLessonHourIds: selectedLessonHourIds,
      searchText: searchText,
      showTableView: showTableView,
    );
    if (cacheKey == null) return null;

    final cached = await LocalCacheService.load(cacheKey);
    if (cached == null || cached['data'] == null) return null;

    final cachedList = cached['data'] as List<dynamic>;
    if (cachedList.isEmpty) return null;

    final items = cachedList.map((item) {
      return AttendanceSummary(
        subjectId: item['subjectId']?.toString() ?? '',
        subjectName: item['subjectName'] ?? 'Unknown',
        date: DateTime.tryParse(item['date'] ?? '') ?? DateTime.now(),
        totalStudents: item['totalStudents'] ?? 0,
        present: item['present'] ?? 0,
        absent: item['absent'] ?? 0,
        classId: item['classId']?.toString() ?? '',
        className: item['className'] ?? 'Unknown',
        lessonHourId: item['lessonHourId'],
        lessonHourName: item['lessonHourName'],
        academicYearId: item['academicYearId'],
      );
    }).toList();

    return (items: items, hasMoreData: cached['hasMoreData'] as bool? ?? false);
  }

  /// Saves summary list to cache (only on page 1 with no filters).
  void saveSummaryToCache({
    required List<AttendanceSummary> items,
    required bool hasMoreData,
    required String? selectedDateFilter,
    required List<String> selectedSubjectIds,
    required List<String> selectedClassIds,
    required List<String> selectedDayIds,
    required List<String> selectedLessonHourIds,
    required String searchText,
    required bool showTableView,
  }) {
    final cacheKey = buildSummaryCacheKey(
      currentPage: 1,
      selectedDateFilter: selectedDateFilter,
      selectedSubjectIds: selectedSubjectIds,
      selectedClassIds: selectedClassIds,
      selectedDayIds: selectedDayIds,
      selectedLessonHourIds: selectedLessonHourIds,
      searchText: searchText,
      showTableView: showTableView,
    );
    if (cacheKey == null || items.isEmpty) return;

    final serialized = items
        .map(
          (item) => {
            'subjectId': item.subjectId,
            'subjectName': item.subjectName,
            'date': item.date.toIso8601String(),
            'totalStudents': item.totalStudents,
            'present': item.present,
            'absent': item.absent,
            'classId': item.classId,
            'className': item.className,
            'lessonHourId': item.lessonHourId,
            'lessonHourName': item.lessonHourName,
            'academicYearId': item.academicYearId,
          },
        )
        .toList();

    LocalCacheService.save(cacheKey, {
      'data': serialized,
      'hasMoreData': hasMoreData,
    });
  }

  /// Invalidates all caches for this screen.
  Future<void> invalidateCaches({
    required String? selectedDateFilter,
    required List<String> selectedSubjectIds,
    required List<String> selectedClassIds,
    required List<String> selectedDayIds,
    required List<String> selectedLessonHourIds,
    required String searchText,
    required bool showTableView,
  }) async {
    final filterKey = buildFilterDataCacheKey();
    await LocalCacheService.invalidate(filterKey);

    final summaryKey = buildSummaryCacheKey(
      currentPage: 1,
      selectedDateFilter: selectedDateFilter,
      selectedSubjectIds: selectedSubjectIds,
      selectedClassIds: selectedClassIds,
      selectedDayIds: selectedDayIds,
      selectedLessonHourIds: selectedLessonHourIds,
      searchText: searchText,
      showTableView: showTableView,
    );
    if (summaryKey != null) await LocalCacheService.invalidate(summaryKey);

    await LocalCacheService.clearStartingWith('tour_presence_report_');
  }
}

/// Result returned by filter data API calls.
class FilterDataResult {
  final List<dynamic> subjects;
  final List<dynamic> classes;
  final List<dynamic> teachers;
  final List<dynamic> lessonHours;

  const FilterDataResult({
    required this.subjects,
    required this.classes,
    required this.teachers,
    required this.lessonHours,
  });
}
