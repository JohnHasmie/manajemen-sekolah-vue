/// Controller for AdminAttendanceReportScreen.
///
/// Like a Laravel Controller class extracted from a fat Route closure —
/// it holds all data-fetching and business logic, while the Screen (View)
/// stays focused on rendering and calling setState().
///
/// Pattern: plain Dart class (not a Riverpod Notifier) so methods can freely
/// return values/results that the screen uses inside its own setState().
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/helpers/attendance_cache_helper.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/helpers/attendance_export_helper.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/helpers/attendance_filter_helper.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/helpers/attendance_result_models.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/helpers/attendance_summary_helper.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/helpers/attendance_table_helper.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_report_screen.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';

/// Controller class that owns all API calls, cache management, and
/// pure helper logic for [AdminAttendanceReportScreen].
///
/// Think of this like a Laravel Controller that the Screen (View) calls.
/// The Screen keeps setState(), build(), dialogs, and navigation.
class AdminAttendanceReportController {
  final WidgetRef ref;
  late final AttendanceCacheHelper _cacheHelper;
  late final AttendanceExportHelper _exportHelper;
  late final AttendanceFilterHelper _filterHelper;
  late final AttendanceSummaryHelper _summaryHelper;
  late final AttendanceTableHelper _tableHelper;

  AdminAttendanceReportController(this.ref) {
    _cacheHelper = AttendanceCacheHelper(ref);
    _exportHelper = AttendanceExportHelper(ref);
    _filterHelper = AttendanceFilterHelper();
    _summaryHelper = AttendanceSummaryHelper(ref);
    _tableHelper = AttendanceTableHelper(ref);
  }

  // ---------------------------------------------------------------------------
  // API: Filter data (subjects, classes, teachers, lesson hours)
  // ---------------------------------------------------------------------------

  /// Loads filter dropdown data.
  ///
  /// 1. Tries cache first (instant display).
  /// 2. Falls back to parallel API calls.
  /// 3. Saves fresh data to cache.
  ///
  /// Returns [FilterDataResult] on success (from cache or API).
  Future<FilterDataResult> loadFilterDataFromApi() async {
    final results = await Future.wait<List<dynamic>>([
      getIt<ApiSubjectService>()
          .getSubject()
          .then((value) {
            AppLogger.info('attendance', 'Subjects loaded: ${value.length}');
            return value;
          })
          .catchError((e) {
            AppLogger.error('attendance', 'Error loading subjects: $e');
            return <dynamic>[];
          }),
      getIt<ApiClassService>()
          .getClass(
            academicYearId: ref
                .read(academicYearRiverpod)
                .selectedAcademicYear?['id']
                ?.toString(),
          )
          .then((value) {
            AppLogger.info('attendance', 'Classes loaded: ${value.length}');
            return value;
          })
          .catchError((e) {
            AppLogger.error('attendance', 'Error loading classes: $e');
            return <dynamic>[];
          }),
      getIt<ApiTeacherService>().getTeacher().catchError((e) {
        AppLogger.error('attendance', 'Error loading teachers: $e');
        return <dynamic>[];
      }),
      getIt<ApiScheduleService>().getJamPelajaran().catchError((e) {
        AppLogger.error('attendance', 'Error loading lesson hours: $e');
        return <dynamic>[];
      }),
    ]);

    final result = FilterDataResult(
      subjects: results[0],
      classes: results[1],
      teachers: results[2],
      lessonHours: results[3],
    );

    _cacheHelper.saveFilterDataToCache(result);
    return result;
  }

  /// Attempts to load filter data from cache.
  /// Returns [FilterDataResult] if valid cache exists, otherwise null.
  Future<FilterDataResult?> loadFilterDataFromCache() async {
    return _cacheHelper.loadFilterDataFromCache();
  }

  // ---------------------------------------------------------------------------
  // API: Attendance summary (list view)
  // ---------------------------------------------------------------------------

  /// Fetches one page of attendance summaries from the API.
  ///
  /// Like `Attendance::paginate()` in Laravel — handles all filter params,
  /// maps raw JSON to [AttendanceSummary] objects, and returns the result.
  Future<FetchDataResult> fetchData({
    required int currentPage,
    required int perPage,
    required String? selectedDateFilter,
    required List<String> selectedSubjectIds,
    required List<String> selectedClassIds,
    required List<String> selectedDayIds,
    required List<String> selectedLessonHourIds,
    required List<dynamic> lessonHours,
  }) {
    return _summaryHelper.fetchData(
      currentPage: currentPage,
      perPage: perPage,
      selectedDateFilter: selectedDateFilter,
      selectedSubjectIds: selectedSubjectIds,
      selectedClassIds: selectedClassIds,
      selectedDayIds: selectedDayIds,
      selectedLessonHourIds: selectedLessonHourIds,
      lessonHours: lessonHours,
    );
  }

  /// Attempts to load summary list from cache (page 1, no filters).
  /// Returns list + hasMoreData on cache hit, otherwise null.
  Future<({List<AttendanceSummary> items, bool hasMoreData})?>
  loadSummaryFromCache({
    required String? selectedDateFilter,
    required List<String> selectedSubjectIds,
    required List<String> selectedClassIds,
    required List<String> selectedDayIds,
    required List<String> selectedLessonHourIds,
    required String searchText,
    required bool showTableView,
  }) {
    return _cacheHelper.loadSummaryFromCache(
      selectedDateFilter: selectedDateFilter,
      selectedSubjectIds: selectedSubjectIds,
      selectedClassIds: selectedClassIds,
      selectedDayIds: selectedDayIds,
      selectedLessonHourIds: selectedLessonHourIds,
      searchText: searchText,
      showTableView: showTableView,
    );
  }

  /// Persists summary list to cache (only on page 1 with no active filters).
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
    _cacheHelper.saveSummaryToCache(
      items: items,
      hasMoreData: hasMoreData,
      selectedDateFilter: selectedDateFilter,
      selectedSubjectIds: selectedSubjectIds,
      selectedClassIds: selectedClassIds,
      selectedDayIds: selectedDayIds,
      selectedLessonHourIds: selectedLessonHourIds,
      searchText: searchText,
      showTableView: showTableView,
    );
  }

  // ---------------------------------------------------------------------------
  // API: Force refresh (invalidate all caches)
  // ---------------------------------------------------------------------------

  /// Invalidates all caches for this screen so next load hits the API.
  Future<void> invalidateCaches({
    required String? selectedDateFilter,
    required List<String> selectedSubjectIds,
    required List<String> selectedClassIds,
    required List<String> selectedDayIds,
    required List<String> selectedLessonHourIds,
    required String searchText,
    required bool showTableView,
  }) {
    return _cacheHelper.invalidateCaches(
      selectedDateFilter: selectedDateFilter,
      selectedSubjectIds: selectedSubjectIds,
      selectedClassIds: selectedClassIds,
      selectedDayIds: selectedDayIds,
      selectedLessonHourIds: selectedLessonHourIds,
      searchText: searchText,
      showTableView: showTableView,
    );
  }

  // ---------------------------------------------------------------------------
  // API: Table view data
  // ---------------------------------------------------------------------------

  /// Fetches all data needed for the Syncfusion DataGrid table view.
  ///
  /// Returns a [TableDataResult] with processed students, dates, and a
  /// ready-to-use [AttendanceDataSource].
  Future<TableDataResult> loadTableData({
    required String classId,
    required String? selectedDateFilter,
    required List<dynamic> subjectList,
  }) {
    return _tableHelper.loadTableData(
      classId: classId,
      selectedDateFilter: selectedDateFilter,
      subjectList: subjectList,
    );
  }

  // ---------------------------------------------------------------------------
  // API: Delete attendance
  // ---------------------------------------------------------------------------

  /// Calls the API to delete a specific attendance record.
  /// Returns normally on success; throws on error.
  Future<void> deleteAttendance(AttendanceSummary summary) async {
    await AttendanceService.deleteAttendance(
      subjectId: summary.subjectId,
      classId: summary.classId,
      date: DateFormat('yyyy-MM-dd').format(summary.date),
      lessonHourId: summary.lessonHourId,
    );
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Builds export row list for a single month without UI calls.
  /// Returns empty list when nothing to export.
  Future<List<Map<String, dynamic>>> buildExportRows({
    required DateTime month,
    required Map<String, dynamic> selectedClassData,
    required List<dynamic> subjectList,
  }) {
    return _exportHelper.buildExportRows(
      month: month,
      selectedClassData: selectedClassData,
      subjectList: subjectList,
    );
  }

  // ---------------------------------------------------------------------------
  // Delegated filter helper methods
  // ---------------------------------------------------------------------------

  /// Returns true when any filter parameter is non-default.
  bool checkActiveFilter({
    required String? selectedDateFilter,
    required List<String> selectedSubjectIds,
    required List<String> selectedClassIds,
    required List<String> selectedDayIds,
    required List<String> selectedLessonHourIds,
  }) {
    return _filterHelper.checkActiveFilter(
      selectedDateFilter: selectedDateFilter,
      selectedSubjectIds: selectedSubjectIds,
      selectedClassIds: selectedClassIds,
      selectedDayIds: selectedDayIds,
      selectedLessonHourIds: selectedLessonHourIds,
    );
  }

  /// Builds list of active filter chip descriptors.
  List<ActiveFilter> buildFilterChips({
    required LanguageProvider languageProvider,
    required String? selectedDateFilter,
    required List<String> selectedSubjectIds,
    required List<String> selectedClassIds,
    required List<String> selectedDayIds,
    required List<String> selectedLessonHourIds,
    required List<dynamic> subjectList,
    required List<dynamic> classList,
    required void Function(void Function()) onRemoveSideEffect,
  }) {
    return _filterHelper.buildFilterChips(
      languageProvider: languageProvider,
      selectedDateFilter: selectedDateFilter,
      selectedSubjectIds: selectedSubjectIds,
      selectedClassIds: selectedClassIds,
      selectedDayIds: selectedDayIds,
      selectedLessonHourIds: selectedLessonHourIds,
      subjectList: subjectList,
      classList: classList,
      onRemoveSideEffect: onRemoveSideEffect,
    );
  }

  /// Filters in-memory summary list by search and active filters.
  List<AttendanceSummary> getFilteredSummaries({
    required List<AttendanceSummary> summaryList,
    required String searchText,
    required String? selectedDateFilter,
    required List<String> selectedSubjectIds,
    required List<String> selectedClassIds,
    required List<String> selectedDayIds,
    required List<String> selectedLessonHourIds,
  }) {
    return _filterHelper.getFilteredSummaries(
      summaryList: summaryList,
      searchText: searchText,
      selectedDateFilter: selectedDateFilter,
      selectedSubjectIds: selectedSubjectIds,
      selectedClassIds: selectedClassIds,
      selectedDayIds: selectedDayIds,
      selectedLessonHourIds: selectedLessonHourIds,
    );
  }

  // ---------------------------------------------------------------------------
  // Utility methods
  // ---------------------------------------------------------------------------

  /// Returns the primary color for the admin role.
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  /// Returns the card gradient for the admin role header.
  LinearGradient getCardGradient() {
    final primary = getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primary, primary.withValues(alpha: 0.85)],
    );
  }
}

/// Riverpod provider for [AdminAttendanceReportController].
///
/// Usage in screen: `final controller =
/// ref.read(adminAttendanceReportControllerProvider);`
///
/// Uses `.autoDispose` so it is cleaned up when the screen is removed
/// from the widget tree.
final adminAttendanceReportControllerProvider =
    Provider<AdminAttendanceReportController>((ref) {
      throw UnimplementedError(
        'Use AdminAttendanceReportController(ref) directly in the screen '
        'or call adminAttendanceReportControllerProvider via the screen ref.',
      );
    });

/// Factory helper: creates a controller bound to the screen's [WidgetRef].
/// Call this once in initState or at the top of the state class.
AdminAttendanceReportController createAdminAttendanceReportController(
  WidgetRef ref,
) {
  return AdminAttendanceReportController(ref);
}
