// Controller for AdminAttendanceReportScreen.
//
// Like a Laravel Controller class extracted from a fat Route closure —
// it holds all data-fetching and business logic, while the Screen (View)
// stays focused on rendering and calling setState().
//
// Pattern: plain Dart class (not a Riverpod Notifier) so methods can freely
// return values/results that the screen uses inside its own setState().
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_report_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_grid_data.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';

/// Result returned by [AdminAttendanceReportController.loadFilterData].
/// Like a Laravel ResourceCollection: a typed wrapper around raw API data.
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

/// Result returned by [AdminAttendanceReportController.fetchData].
/// Contains the new attendance summary items and updated pagination state.
class FetchDataResult {
  final List<AttendanceSummary> items;
  final bool hasMoreData;
  final int nextPage;

  const FetchDataResult({
    required this.items,
    required this.hasMoreData,
    required this.nextPage,
  });
}

/// Result returned by [AdminAttendanceReportController.loadTableData].
class TableDataResult {
  final List<dynamic> studentList;
  final List<String> uniqueDates;
  final List<String> uniqueSubjectIds;
  final Map<String, String> dateLabels;
  final AttendanceDataSource dataSource;

  const TableDataResult({
    required this.studentList,
    required this.uniqueDates,
    required this.uniqueSubjectIds,
    required this.dateLabels,
    required this.dataSource,
  });
}

/// Controller class that owns all API calls, cache management, and
/// pure helper logic for [AdminAttendanceReportScreen].
///
/// Think of this like a Laravel Controller that the Screen (View) calls.
/// The Screen keeps setState(), build(), dialogs, and navigation.
class AdminAttendanceReportController {
  // Like dependency injection: ref gives access to Riverpod providers
  // (academicYear, language) without the controller needing a BuildContext.
  final WidgetRef ref;

  AdminAttendanceReportController(this.ref);

  // ---------------------------------------------------------------------------
  // Cache key helpers
  // ---------------------------------------------------------------------------

  /// Builds the cache key for filter dropdown data (subjects, classes, etc.).
  /// Returns null only when the academic year provider has no selection yet.
  String buildFilterDataCacheKey() {
    final yearId =
        ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString() ??
        'default';
    return 'presence_filter_data_$yearId';
  }

  /// Builds the cache key for the summary list.
  /// Returns null when any filter is active (filtered views are not cached).
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
        ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString() ??
        'default';
    return 'presence_summary_$yearId';
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
  /// Returns null only when cached data is found — caller should check for
  /// the cached fast-path first via [loadFilterDataFromCache].
  Future<FilterDataResult> loadFilterDataFromApi() async {
    final results = await Future.wait([
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

    // Save to cache (non-blocking)
    final cacheKey = buildFilterDataCacheKey();
    LocalCacheService.save(cacheKey, {
      'subjects': result.subjects,
      'classes': result.classes,
      'teachers': result.teachers,
      'lessonHours': result.lessonHours,
    });

    return result;
  }

  /// Attempts to load filter data from cache.
  /// Returns [FilterDataResult] if valid cache exists, otherwise null.
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
  }) async {
    // Resolve date filter params
    String? filterDate;
    String? filterDateStart;
    String? filterDateEnd;

    if (selectedDateFilter == 'today') {
      filterDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    } else if (selectedDateFilter == 'week') {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(Duration(days: 6));
      filterDateStart = DateFormat('yyyy-MM-dd').format(startOfWeek);
      filterDateEnd = DateFormat('yyyy-MM-dd').format(endOfWeek);
    } else if (selectedDateFilter == 'month') {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      filterDateStart = DateFormat('yyyy-MM-dd').format(startOfMonth);
      filterDateEnd = DateFormat('yyyy-MM-dd').format(endOfMonth);
    }

    final academicYearId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();

    final result = await AttendanceService.getAttendanceSummaryPaginated(
      page: currentPage,
      limit: perPage,
      subjectId: selectedSubjectIds.isNotEmpty ? selectedSubjectIds.first : null,
      classId: selectedClassIds.isNotEmpty ? selectedClassIds.first : null,
      date: filterDate,
      dateStart: filterDateStart,
      dateEnd: filterDateEnd,
      academicYearId: academicYearId,
      dayIds: selectedDayIds,
      lessonHourIds: selectedLessonHourIds,
    );

    final List<dynamic> data = result['data'] ?? [];
    final Map<String, dynamic> pagination = result['pagination'] ?? {};

    final List<AttendanceSummary> newItems = data.map((item) {
      final lessonHourId = item['lesson_hour_id']?.toString();
      String? lessonHourName;
      if (lessonHourId != null && lessonHourId.isNotEmpty) {
        final lh = lessonHours.firstWhere(
          (h) => h['id']?.toString() == lessonHourId,
          orElse: () => null,
        );
        if (lh != null) {
          lessonHourName = lh['name'];
        }
      }

      return AttendanceSummary(
        subjectId: item['subject_id']?.toString() ?? '',
        subjectName: item['subject_name'] ?? 'Unknown',
        date: AppDateUtils.parseApiDate(item['date']) ?? DateTime.now(),
        totalStudents:
            int.tryParse(item['total_students']?.toString() ?? '0') ?? 0,
        present: int.tryParse(item['present']?.toString() ?? '0') ?? 0,
        absent: int.tryParse(item['absent']?.toString() ?? '0') ?? 0,
        classId: item['class_id']?.toString() ?? '',
        className: item['class_name'] ?? 'Unknown',
        lessonHourId: lessonHourId,
        lessonHourName: lessonHourName,
        academicYearId: academicYearId,
      );
    }).toList();

    final hasMoreData = pagination['has_next_page'] ?? false;
    final nextPage = hasMoreData ? currentPage + 1 : currentPage;

    return FetchDataResult(
      items: newItems,
      hasMoreData: hasMoreData,
      nextPage: nextPage,
    );
  }

  /// Attempts to load summary list from cache (page 1, no filters).
  /// Returns list + hasMoreData on cache hit, otherwise null.
  Future<({List<AttendanceSummary> items, bool hasMoreData})?> loadSummaryFromCache({
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

  /// Persists summary list to cache (only when on page 1 with no active filters).
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

    final serialized = items.map((item) => {
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
    }).toList();

    LocalCacheService.save(cacheKey, {
      'data': serialized,
      'hasMoreData': hasMoreData,
    });
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

  // ---------------------------------------------------------------------------
  // API: Table view data
  // ---------------------------------------------------------------------------

  /// Fetches all data needed for the Syncfusion DataGrid table view.
  ///
  /// Returns a [TableDataResult] with processed students, dates, and a
  /// ready-to-use [AttendanceDataSource]. Analogous to a Laravel resource
  /// that joins students with their daily attendance records.
  Future<TableDataResult> loadTableData({
    required String classId,
    required String? selectedDateFilter,
    required List<dynamic> subjectList,
  }) async {
    final academicYearId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();

    // Resolve date range
    String? startDate;
    String? endDate;
    final now = DateTime.now();

    if (selectedDateFilter == 'today') {
      startDate = DateFormat('yyyy-MM-dd').format(now);
      endDate = startDate;
    } else if (selectedDateFilter == 'week') {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(Duration(days: 6));
      startDate = DateFormat('yyyy-MM-dd').format(startOfWeek);
      endDate = DateFormat('yyyy-MM-dd').format(endOfWeek);
    } else {
      // Default to current month for 'month' or null filter
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      startDate = DateFormat('yyyy-MM-dd').format(startOfMonth);
      endDate = DateFormat('yyyy-MM-dd').format(endOfMonth);
    }

    // Parallel fetch: students + attendance records
    final students = await getIt<ApiClassService>().getStudentsByClassId(classId);

    final attendanceResult = await AttendanceService.getAttendancePaginated(
      page: 1,
      limit: 1000,
      classId: classId,
      dateStart: startDate,
      dateEnd: endDate,
      academicYearId: academicYearId,
    );

    final List<dynamic> attendanceData = attendanceResult['data'] ?? [];

    // Process attendance records into a flat map: "$studentId-$date-$subjectId" → status
    final Set<String> dateSet = {};
    final Set<String> subjectIdSet = {};
    final Map<String, dynamic> attMap = {};

    for (var record in attendanceData) {
      final String? date = record['date'];
      final String? sId = record['student_id']?.toString();
      final String? subjId = record['subject_id']?.toString();
      final String? status = record['status'];

      if (date != null && sId != null && subjId != null) {
        dateSet.add(date);
        subjectIdSet.add(subjId);
        attMap['$sId-$date-$subjId'] = status;
      }
    }

    // Build subject name lookup map
    final Map<String, dynamic> subjectMap = {};
    for (var s in subjectList) {
      subjectMap[s['id'].toString()] = s['name'];
    }

    // Map students to AttendanceGridData (the DataSource's row model)
    final List<AttendanceGridData> gridData = [];
    for (var student in students) {
      final sData = student is Map ? student : <dynamic, dynamic>{};
      var id = sData['id']?.toString() ?? sData['student_id']?.toString() ?? '';
      var nis = sData['nis'] ?? sData['student_number'] ?? '-';
      var name = sData['name'] ?? sData['nama'] ?? 'Unknown';

      // Normalize: sometimes student data is nested under 'student' key
      if (sData.containsKey('student')) {
        final inner = sData['student'];
        if (id.isEmpty) id = inner['id']?.toString() ?? '';
        nis = inner['nis'] ?? inner['student_number'] ?? nis;
        name = inner['name'] ?? inner['nama'] ?? name;
      }

      gridData.add(
        AttendanceGridData(
          studentId: id,
          nis: nis.toString(),
          name: name.toString(),
          attendance: attMap,
        ),
      );
    }

    final sortedDates = dateSet.toList()..sort();

    // Build date → day-of-month label map
    final Map<String, String> dateLabels = {};
    for (var d in sortedDates) {
      final DateTime? dt = AppDateUtils.parseApiDate(d);
      dateLabels[d] = dt != null ? dt.day.toString() : d;
    }

    return TableDataResult(
      studentList: students,
      uniqueDates: sortedDates,
      uniqueSubjectIds: subjectIdSet.toList(),
      dateLabels: dateLabels,
      dataSource: AttendanceDataSource(
        students: gridData,
        dates: sortedDates,
        subjectIds: subjectIdSet.toList(),
        subjectMap: subjectMap,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // API: Delete attendance
  // ---------------------------------------------------------------------------

  /// Calls the API to delete a specific attendance record.
  /// Returns normally on success; throws on error (caller handles UI).
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

  /// Builds the export row list for a single month without calling any UI.
  ///
  /// Like a Laravel Export class that prepares data rows — the actual
  /// file download (which needs a BuildContext for snackbars) is done by
  /// the screen after confirming it is still mounted.
  ///
  /// Returns an empty list when there is nothing to export for this month.
  Future<List<Map<String, dynamic>>> buildExportRows({
    required DateTime month,
    required Map<String, dynamic> selectedClassData,
    required List<dynamic> subjectList,
  }) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    final startDate = DateFormat('yyyy-MM-dd').format(startOfMonth);
    final endDate = DateFormat('yyyy-MM-dd').format(endOfMonth);

    final classId = selectedClassData['id'];
    final className = selectedClassData['name'];

    final academicYearProvider = ref.read(academicYearRiverpod);
    final academicYearId =
        academicYearProvider.selectedAcademicYear?['id']?.toString();
    final academicYearName =
        academicYearProvider.selectedAcademicYear?['year']?.toString() ?? '-';

    final students =
        await getIt<ApiClassService>().getStudentsByClassId(classId);

    final attendanceResult = await AttendanceService.getAttendancePaginated(
      page: 1,
      limit: 2000,
      classId: classId,
      dateStart: startDate,
      dateEnd: endDate,
      academicYearId: academicYearId,
    );

    final List<dynamic> attendanceData = attendanceResult['data'] ?? [];
    if (attendanceData.isEmpty) return [];

    // Build subject name lookup
    final Map<String, String> subjectMap = {};
    for (var s in subjectList) {
      subjectMap[s['id'].toString()] = s['name'];
    }

    final List<Map<String, dynamic>> exportList = [];

    for (var record in attendanceData) {
      final sId = record['student_id'].toString();

      var studentMap = students.firstWhere((s) {
        final id = s['id']?.toString();
        if (id != null && id == sId) return true;
        if (s['student'] != null && s['student']['id']?.toString() == sId) {
          return true;
        }
        return false;
      }, orElse: () => null);

      if (studentMap == null) continue;

      // Normalize nested student structure
      if (studentMap['student'] != null) studentMap = studentMap['student'];

      final nis = studentMap['nis'] ?? studentMap['student_number'] ?? '';
      final name = studentMap['name'] ?? studentMap['nama'] ?? 'Unknown';
      final subjId = record['subject_id'].toString();
      final subjectName =
          subjectMap[subjId] ?? record['subject_name'] ?? 'Unknown';

      exportList.add({
        'nis': nis,
        'student_name': name,
        'class_name': className,
        'academic_year': academicYearName,
        'date': record['date'],
        'subject_name': subjectName,
        'status': record['status'],
      });
    }

    return exportList;
  }

  // ---------------------------------------------------------------------------
  // Pure helper / utility methods
  // ---------------------------------------------------------------------------

  /// Returns true when any filter parameter is non-default.
  /// Like a computed property in Vue: `hasActiveFilter`.
  bool checkActiveFilter({
    required String? selectedDateFilter,
    required List<String> selectedSubjectIds,
    required List<String> selectedClassIds,
    required List<String> selectedDayIds,
    required List<String> selectedLessonHourIds,
  }) {
    return selectedDateFilter != null ||
        selectedSubjectIds.isNotEmpty ||
        selectedClassIds.isNotEmpty ||
        selectedDayIds.isNotEmpty ||
        selectedLessonHourIds.isNotEmpty;
  }

  /// Builds the list of active filter chip descriptors.
  ///
  /// Each chip has a `label` (String) and `onRemove` (VoidCallback).
  /// The [onRemoveSideEffect] closure is called by each chip's onRemove
  /// so the screen can do setState() + loadData() after a chip is dismissed —
  /// keeping UI logic out of this controller.
  List<Map<String, dynamic>> buildFilterChips({
    required LanguageProvider languageProvider,
    required String? selectedDateFilter,
    required List<String> selectedSubjectIds,
    required List<String> selectedClassIds,
    required List<String> selectedDayIds,
    required List<String> selectedLessonHourIds,
    required List<dynamic> subjectList,
    required List<dynamic> classList,
    // Callbacks so the screen does setState() after each chip removal
    required void Function(void Function()) onRemoveSideEffect,
  }) {
    final List<Map<String, dynamic>> filterChips = [];

    if (selectedDateFilter != null) {
      final label = selectedDateFilter == 'today'
          ? languageProvider.getTranslatedText({'en': 'Today', 'id': 'Hari Ini'})
          : selectedDateFilter == 'week'
          ? languageProvider.getTranslatedText({
              'en': 'This Week',
              'id': 'Minggu Ini',
            })
          : languageProvider.getTranslatedText({
              'en': 'This Month',
              'id': 'Bulan Ini',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Date', 'id': 'Tanggal'})}: $label',
        'onRemove': () => onRemoveSideEffect(() => selectedDateFilter = null),
      });
    }

    for (var subjectId in selectedSubjectIds) {
      final subject = subjectList.firstWhere(
        (s) => s['id'].toString() == subjectId,
        orElse: () => {'name': 'Subject #$subjectId'},
      );
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Subject', 'id': 'Mapel'})}: ${subject['name']}',
        'onRemove': () =>
            onRemoveSideEffect(() => selectedSubjectIds.remove(subjectId)),
      });
    }

    for (var classId in selectedClassIds) {
      final classItem = classList.firstWhere(
        (k) => k['id'].toString() == classId,
        orElse: () => {'name': 'Class #$classId'},
      );
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'})}: ${classItem['name'] ?? classItem['nama']}',
        'onRemove': () =>
            onRemoveSideEffect(() => selectedClassIds.remove(classId)),
      });
    }

    if (selectedDayIds.isNotEmpty) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Day', 'id': 'Hari'})}: ${selectedDayIds.length}',
        'onRemove': () => onRemoveSideEffect(() => selectedDayIds.clear()),
      });
    }

    if (selectedLessonHourIds.isNotEmpty) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Hour', 'id': 'Jam'})}: ${selectedLessonHourIds.length}',
        'onRemove': () =>
            onRemoveSideEffect(() => selectedLessonHourIds.clear()),
      });
    }

    return filterChips;
  }

  /// Filters the in-memory summary list by search term and all active filters.
  /// Pure function — no side effects, no API calls.
  List<AttendanceSummary> getFilteredSummaries({
    required List<AttendanceSummary> summaryList,
    required String searchText,
    required String? selectedDateFilter,
    required List<String> selectedSubjectIds,
    required List<String> selectedClassIds,
    required List<String> selectedDayIds,
    required List<String> selectedLessonHourIds,
  }) {
    final searchTerm = searchText.toLowerCase();
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 6));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    return summaryList.where((summary) {
      final matchesSearch =
          searchTerm.isEmpty ||
          summary.subjectName.toLowerCase().contains(searchTerm) ||
          summary.className.toLowerCase().contains(searchTerm);

      bool matchesDateFilter = true;
      if (selectedDateFilter != null) {
        if (selectedDateFilter == 'today') {
          matchesDateFilter = isSameDay(summary.date, now);
        } else if (selectedDateFilter == 'week') {
          matchesDateFilter =
              summary.date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
              summary.date.isBefore(endOfWeek.add(const Duration(days: 1)));
        } else if (selectedDateFilter == 'month') {
          matchesDateFilter =
              summary.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
              summary.date.isBefore(endOfMonth.add(const Duration(days: 1)));
        }
      }

      final matchesSubject =
          selectedSubjectIds.isEmpty ||
          selectedSubjectIds.contains(summary.subjectId);

      final matchesClass =
          selectedClassIds.isEmpty || selectedClassIds.contains(summary.classId);

      final matchesDay =
          selectedDayIds.isEmpty ||
          selectedDayIds.contains(summary.date.weekday.toString());

      final matchesLessonHour =
          selectedLessonHourIds.isEmpty ||
          selectedLessonHourIds.contains(summary.lessonHourId);

      return matchesSearch &&
          matchesDateFilter &&
          matchesSubject &&
          matchesClass &&
          matchesDay &&
          matchesLessonHour;
    }).toList();
  }

  /// Checks if two [DateTime] values fall on the same calendar day.
  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

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
/// Usage in screen: `final controller = ref.read(adminAttendanceReportControllerProvider);`
///
/// Uses `.autoDispose` so it is cleaned up when the screen is removed from
/// the widget tree — like a Vue component being destroyed.
final adminAttendanceReportControllerProvider =
    Provider<AdminAttendanceReportController>((ref) {
  // The controller holds a WidgetRef — valid because we use autoDispose and
  // the provider lifetime matches the screen's ConsumerStatefulWidget lifetime.
  // Note: ref here is a ProviderRef, not WidgetRef. The controller receives
  // ref at construction time from the screen via the factory below.
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
