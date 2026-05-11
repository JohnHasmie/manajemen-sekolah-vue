import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/admin_attendance_report_controller.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_report_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_grid_data.dart';

/// Mixin for data loading operations in admin report screen.
/// Handles pagination, caching, API calls for summaries & filters.
mixin AdminReportDataLoadingMixin
    on ConsumerState<AdminAttendanceReportScreen> {
  // Access state variables from main state class
  AdminAttendanceReportController get controller;
  List<AttendanceSummary> get attendanceSummaryList;
  set attendanceSummaryList(List<AttendanceSummary> value);
  bool get isLoadingSummary;
  set isLoadingSummary(bool value);
  int get currentPage;
  set currentPage(int value);
  int get perPage;
  bool get hasMoreData;
  set hasMoreData(bool value);
  bool get isLoadingMore;
  set isLoadingMore(bool value);
  ScrollController get scrollController;
  bool get showTableView;
  set showTableView(bool value);
  String? get selectedDateFilter;
  List<String> get selectedSubjectIds;
  List<String> get selectedClassIds;
  List<String> get selectedDayIds;
  List<String> get selectedLessonHourIds;
  TextEditingController get searchController;
  List<dynamic> get subjectList;
  set subjectList(List<dynamic> value);
  List<dynamic> get classList;
  set classList(List<dynamic> value);
  List<dynamic> get lessonHours;
  set lessonHours(List<dynamic> value);
  bool get isLoadingClasses;
  set isLoadingClasses(bool value);
  List<dynamic> get fullTeacherList;
  set fullTeacherList(List<dynamic> value);
  bool get isTableLoading;
  set isTableLoading(bool value);
  List<dynamic> get studentList;
  Map<String, dynamic> get attendanceMap;
  List<String> get uniqueDates;
  List<String> get uniqueSubjectIds;
  Map<String, String> get dateLabels;
  set dateLabels(Map<String, String> value);
  AttendanceDataSource? get attendanceDataSource;
  set attendanceDataSource(AttendanceDataSource? value);
  Map<String, dynamic>? get selectedClassData;

  Future<void> _loadFilterDataFromCacheIfAvailable() async {
    final cached = await controller.loadFilterDataFromCache();
    if (cached != null && mounted) {
      setState(() {
        subjectList = cached.subjects;
        classList = cached.classes;
        fullTeacherList = cached.teachers;
        lessonHours = cached.lessonHours;
        isLoadingClasses = false;
      });
      AppLogger.info('attendance', 'Filter data loaded from cache');
    }
  }

  Future<void> _loadFilterDataFromApi() async {
    if (classList.isEmpty && mounted) {
      setState(() => isLoadingClasses = true);
    }
    try {
      final result = await controller.loadFilterDataFromApi();
      if (mounted) {
        setState(() {
          subjectList = result.subjects;
          classList = result.classes;
          fullTeacherList = result.teachers;
          lessonHours = result.lessonHours;
        });
      }
    } catch (e) {
      AppLogger.error('attendance', 'Error loading filter data (critical): $e');
      if (mounted && classList.isEmpty) {
        SnackBarUtils.showError(
          context,
          'Gagal memuat data filter: '
          '${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoadingClasses = false);
      }
    }
  }

  Future<void> loadFilterData({bool useCache = true}) async {
    if (useCache) {
      await _loadFilterDataFromCacheIfAvailable();
      if (classList.isNotEmpty) return;
    }
    await _loadFilterDataFromApi();
  }

  Future<void> _loadSummaryFromCacheIfAvailable(bool useCache) async {
    if (!useCache) return;
    final cached = await controller.loadSummaryFromCache(
      selectedDateFilter: selectedDateFilter,
      selectedSubjectIds: selectedSubjectIds,
      selectedClassIds: selectedClassIds,
      selectedDayIds: selectedDayIds,
      selectedLessonHourIds: selectedLessonHourIds,
      searchText: searchController.text,
      showTableView: showTableView,
    );
    if (cached != null && mounted) {
      setState(() {
        attendanceSummaryList = cached.items;
        hasMoreData = cached.hasMoreData;
        isLoadingSummary = false;
      });
      AppLogger.info('attendance', 'Summary data loaded from cache');
    }
  }

  void _saveSummaryToCache() {
    if (!mounted) return;
    controller.saveSummaryToCache(
      items: attendanceSummaryList,
      hasMoreData: hasMoreData,
      selectedDateFilter: selectedDateFilter,
      selectedSubjectIds: selectedSubjectIds,
      selectedClassIds: selectedClassIds,
      selectedDayIds: selectedDayIds,
      selectedLessonHourIds: selectedLessonHourIds,
      searchText: searchController.text,
      showTableView: showTableView,
    );
  }

  Future<void> loadData({bool useCache = true}) async {
    if (!mounted) return;
    currentPage = 1;
    hasMoreData = true;
    await _loadSummaryFromCacheIfAvailable(useCache);
    if (attendanceSummaryList.isNotEmpty) return;
    if (attendanceSummaryList.isEmpty && mounted) {
      setState(() => isLoadingSummary = true);
    }
    await fetchData();
    _saveSummaryToCache();
  }

  Future<void> loadMoreData() async {
    if (!mounted || isLoadingMore || !hasMoreData) return;
    setState(() => isLoadingMore = true);
    await fetchData();
  }

  void _updateSummaryFromResult(dynamic result) {
    if (!mounted) return;
    setState(() {
      if (currentPage == 1) {
        attendanceSummaryList = result.items;
      } else {
        attendanceSummaryList.addAll(result.items);
      }
      hasMoreData = result.hasMoreData;
      currentPage = result.nextPage;
      isLoadingSummary = false;
      isLoadingMore = false;
    });
  }

  void _handleFetchError(Object e) {
    AppLogger.error('attendance', 'Error loading absensi summary: $e');
    if (mounted) {
      setState(() {
        isLoadingSummary = false;
        isLoadingMore = false;
      });
      SnackBarUtils.showError(
        context,
        'Gagal memuat data laporan: '
        '${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  Future<void> fetchData() async {
    try {
      final result = await controller.fetchData(
        currentPage: currentPage,
        perPage: perPage,
        selectedDateFilter: selectedDateFilter,
        selectedSubjectIds: selectedSubjectIds,
        selectedClassIds: selectedClassIds,
        selectedDayIds: selectedDayIds,
        selectedLessonHourIds: selectedLessonHourIds,
        lessonHours: lessonHours,
      );
      _updateSummaryFromResult(result);
    } catch (e) {
      _handleFetchError(e);
    }
  }

  void _validateAndPrepareTableLoad() {
    if (selectedClassIds.isEmpty) {
      SnackBarUtils.showError(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Please select a class first',
          'id': 'Mohon pilih kelas terlebih dahulu',
        }),
      );
      setState(() => showTableView = false);
    }
    setState(() {
      isTableLoading = true;
      attendanceMap.clear();
      studentList.clear();
      uniqueDates.clear();
      uniqueSubjectIds.clear();
    });
  }

  void _updateTableState(dynamic result) {
    if (!mounted) return;
    setState(() {
      studentList
        ..clear()
        ..addAll(result.studentList);
      uniqueDates
        ..clear()
        ..addAll(result.uniqueDates);
      uniqueSubjectIds
        ..clear()
        ..addAll(result.uniqueSubjectIds);
      dateLabels
        ..clear()
        ..addAll(result.dateLabels);
      attendanceDataSource = result.dataSource;
      isTableLoading = false;
    });
  }

  Future<void> loadTableData() async {
    if (!mounted || selectedClassIds.isEmpty) {
      _validateAndPrepareTableLoad();
      return;
    }
    _validateAndPrepareTableLoad();
    try {
      final result = await controller.loadTableData(
        classId: selectedClassIds.first,
        selectedDateFilter: selectedDateFilter,
        subjectList: subjectList,
      );
      _updateTableState(result);
    } catch (e) {
      AppLogger.error('attendance', 'Error loading table: $e');
      if (mounted) {
        setState(() => isTableLoading = false);
        SnackBarUtils.showInfo(context, 'Failed to load table data: $e');
      }
    }
  }
}
