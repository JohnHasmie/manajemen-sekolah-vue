// Admin presence/attendance report screen.
//
// Like `pages/admin/attendance-report.vue` - displays attendance summaries
// across classes, subjects, and dates. Supports both list view and table view,
// with filters by date range, subject, class, day, and lesson hour.
// Can export reports to Excel.
//
// In Laravel terms, this consumes AttendanceController with complex query filters,
// similar to `Attendance::with(['student','subject'])->filter(...)->paginate()`.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/attendance/exports/attendance_export_service.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/admin_attendance_report_controller.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_detail.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_report_filter_sheet.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_grid_data.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/admin_attendance_summary_card.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_class_list_view.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_table_view.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/teacher_selection_sheet.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_export_dialog.dart';

/// Data model for a single attendance summary record.
/// Like a Laravel Eloquent model or a TypeScript interface in Vue.
/// Represents aggregated attendance data for one subject/class/date combination.
class AttendanceSummary {
  final String subjectId;
  final String subjectName;
  final DateTime date;
  final int totalStudents;
  final int present;
  final int absent;
  final String classId;
  final String className;
  final String? lessonHourId;
  final String? lessonHourName;
  final String? academicYearId;

  AttendanceSummary({
    required this.subjectId,
    required this.subjectName,
    required this.date,
    required this.totalStudents,
    required this.present,
    required this.absent,
    required this.classId,
    required this.className,
    this.lessonHourId,
    this.lessonHourName,
    this.academicYearId,
  });

  String get key =>
      '$subjectId-$classId-${DateFormat('yyyy-MM-dd').format(date)}-$lessonHourId';
}

/// Admin attendance report screen with list and table views, multi-filter support.
///
/// This is a [StatefulWidget] - like a Vue page with extensive local state
/// for filters, pagination, and two view modes (list vs table/grid).
class AdminAttendanceReportScreen extends ConsumerStatefulWidget {
  const AdminAttendanceReportScreen({super.key});

  @override
  ConsumerState<AdminAttendanceReportScreen> createState() =>
      _AdminAttendanceReportScreenState();
}

/// Mutable state for [AdminAttendanceReportScreen].
///
/// Key state (like Vue `data()`):
/// - [_attendanceSummaryList] - attendance summary records from API
/// - [_showTableView] - toggles between card list and Syncfusion data grid
/// - [_selectedSubjectIds] / [_selectedClassIds] / [_selectedDayIds] - multi-select filters
/// - [_selectedDateFilter] - date range filter ('today', 'week', 'month')
/// - [_studentList] / [_attendanceMap] - raw student attendance data for table view
///
/// setState() is like Vue's reactivity - triggers a re-render when data changes.
class _AdminAttendanceReportScreenState
    extends ConsumerState<AdminAttendanceReportScreen> {
  // Controller: owns all API calls and pure helpers.
  // Like injecting a Laravel Controller into a View — instantiated once.
  late final AdminAttendanceReportController _controller;

  // Data for View Results mode
  List<AttendanceSummary> _attendanceSummaryList = [];
  bool _isLoadingSummary = false;

  // Pagination State
  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  // Table View State
  bool _showTableView = false;
  final List<dynamic> _studentList = [];
  final Map<String, dynamic> _attendanceMap =
      {}; // Key: studentId-date -> [subjects]
  AttendanceDataSource? _attendanceDataSource;
  final List<String> _uniqueDates = [];
  final List<String> _uniqueSubjectIds = [];
  final Map<String, String> _dateLabels = {}; // date -> label (1, 2, 3...)
  bool _isTableLoading = false;

  // Search dan Filter
  final TextEditingController _searchController = TextEditingController();

  // Filter States
  String? _selectedDateFilter; // 'today', 'week', 'month', or null for all
  final List<String> _selectedSubjectIds = [];
  final List<String> _selectedClassIds = [];
  final List<String> _selectedDayIds = [];
  final List<String> _selectedLessonHourIds = [];
  bool _hasActiveFilter = false;
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _moreKey = GlobalKey();
  final GlobalKey _infoKey = GlobalKey();
  bool _isTourShowing = false;

  // Data for filters
  List<dynamic> _subjectList = [];
  List<dynamic> _classList = [];
  List<dynamic> _lessonHours = [];
  Map<String, dynamic>? _selectedClassData;
  bool _isLoadingClasses = true;
  List<dynamic> _fullTeacherList = [];

  /// Like Vue's `mounted()` - sets up scroll listener and loads filter data.
  @override
  void initState() {
    super.initState();
    _controller = AdminAttendanceReportController(ref);
    _scrollController.addListener(_onScroll);
    _loadFilterData();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreData();
    }
  }

  Future<void> _forceRefresh() async {
    await _controller.invalidateCaches(
      selectedDateFilter: _selectedDateFilter,
      selectedSubjectIds: _selectedSubjectIds,
      selectedClassIds: _selectedClassIds,
      selectedDayIds: _selectedDayIds,
      selectedLessonHourIds: _selectedLessonHourIds,
      searchText: _searchController.text,
      showTableView: _showTableView,
    );
    if (_selectedClassData == null) {
      _loadFilterData(useCache: false);
    } else {
      _loadData(useCache: false);
    }
  }

  Future<void> _loadFilterData({bool useCache = true}) async {
    // Step 1: Try cache for instant display
    if (useCache) {
      final cached = await _controller.loadFilterDataFromCache();
      if (cached != null && mounted) {
        setState(() {
          _subjectList = cached.subjects;
          _classList = cached.classes;
          _fullTeacherList = cached.teachers;
          _lessonHours = cached.lessonHours;
          _isLoadingClasses = false;
        });
        AppLogger.info('attendance', 'Filter data loaded from cache');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkAndShowTour();
        });
        return;
      }
    }

    // Show loading only if data is empty
    if (_classList.isEmpty && mounted) {
      setState(() => _isLoadingClasses = true);
    }

    // Step 2: Fetch fresh from API via controller
    try {
      final result = await _controller.loadFilterDataFromApi();
      if (mounted) {
        setState(() {
          _subjectList = result.subjects;
          _classList = result.classes;
          _fullTeacherList = result.teachers;
          _lessonHours = result.lessonHours;
        });
      }
    } catch (e) {
      AppLogger.error('attendance', 'Error loading filter data (critical): $e');
      if (mounted && _classList.isEmpty) {
        SnackBarUtils.showError(
          context,
          'Gagal memuat data filter: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingClasses = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkAndShowTour();
        });
      }
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter = _controller.checkActiveFilter(
        selectedDateFilter: _selectedDateFilter,
        selectedSubjectIds: _selectedSubjectIds,
        selectedClassIds: _selectedClassIds,
        selectedDayIds: _selectedDayIds,
        selectedLessonHourIds: _selectedLessonHourIds,
      );
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedDateFilter = null;
      _selectedSubjectIds.clear();
      _selectedClassIds.clear();
      _selectedDayIds.clear();
      _selectedLessonHourIds.clear();
      _hasActiveFilter = false;
    });
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    return _controller.buildFilterChips(
      languageProvider: languageProvider,
      selectedDateFilter: _selectedDateFilter,
      selectedSubjectIds: _selectedSubjectIds,
      selectedClassIds: _selectedClassIds,
      selectedDayIds: _selectedDayIds,
      selectedLessonHourIds: _selectedLessonHourIds,
      subjectList: _subjectList,
      classList: _classList,
      // Each chip's onRemove mutates screen state then reloads data
      onRemoveSideEffect: (mutation) {
        setState(mutation);
        _checkActiveFilter();
        _loadData();
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool useCache = true}) async {
    if (!mounted) return;

    _currentPage = 1;
    _hasMoreData = true;

    // Step 1: Try cache for instant display
    if (useCache) {
      final cached = await _controller.loadSummaryFromCache(
        selectedDateFilter: _selectedDateFilter,
        selectedSubjectIds: _selectedSubjectIds,
        selectedClassIds: _selectedClassIds,
        selectedDayIds: _selectedDayIds,
        selectedLessonHourIds: _selectedLessonHourIds,
        searchText: _searchController.text,
        showTableView: _showTableView,
      );
      if (cached != null && mounted) {
        setState(() {
          _attendanceSummaryList = cached.items;
          _hasMoreData = cached.hasMoreData;
          _isLoadingSummary = false;
        });
        AppLogger.info('attendance', 'Summary data loaded from cache');
        return;
      }
    }

    // Show skeleton only if list is empty
    if (_attendanceSummaryList.isEmpty && mounted) {
      setState(() => _isLoadingSummary = true);
    }

    // Step 2: Fetch fresh from API
    await _fetchData();

    // Step 3: Save to cache (non-blocking, only for default unfiltered page 1)
    if (mounted) {
      _controller.saveSummaryToCache(
        items: _attendanceSummaryList,
        hasMoreData: _hasMoreData,
        selectedDateFilter: _selectedDateFilter,
        selectedSubjectIds: _selectedSubjectIds,
        selectedClassIds: _selectedClassIds,
        selectedDayIds: _selectedDayIds,
        selectedLessonHourIds: _selectedLessonHourIds,
        searchText: _searchController.text,
        showTableView: _showTableView,
      );
    }
  }

  Future<void> _loadMoreData() async {
    if (!mounted || _isLoadingMore || !_hasMoreData) return;
    setState(() => _isLoadingMore = true);
    await _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final result = await _controller.fetchData(
        currentPage: _currentPage,
        perPage: _perPage,
        selectedDateFilter: _selectedDateFilter,
        selectedSubjectIds: _selectedSubjectIds,
        selectedClassIds: _selectedClassIds,
        selectedDayIds: _selectedDayIds,
        selectedLessonHourIds: _selectedLessonHourIds,
        lessonHours: _lessonHours,
      );

      if (!mounted) return;

      setState(() {
        if (_currentPage == 1) {
          _attendanceSummaryList = result.items;
        } else {
          _attendanceSummaryList.addAll(result.items);
        }
        _hasMoreData = result.hasMoreData;
        _currentPage = result.nextPage;
        _isLoadingSummary = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      AppLogger.error('attendance', 'Error loading absensi summary: $e');
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
          _isLoadingMore = false;
        });
        SnackBarUtils.showError(
          context,
          'Gagal memuat data laporan: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  Color _getPrimaryColor() => _controller.getPrimaryColor();

  LinearGradient _getCardGradient() => _controller.getCardGradient();

  void _showFilterSheet() {
    showAttendanceReportFilterSheet(
      context: context,
      ref: ref,
      primaryColor: _getPrimaryColor(),
      initialDate: _selectedDateFilter,
      initialSubjectIds: _selectedSubjectIds,
      initialClassIds: _selectedClassIds,
      initialDayIds: _selectedDayIds,
      initialLessonHourIds: _selectedLessonHourIds,
      subjectList: _subjectList,
      classList: _classList,
      lessonHours: _lessonHours,
      onApply: (result) {
        setState(() {
          _selectedDateFilter = result.selectedDate;
          _selectedSubjectIds
            ..clear()
            ..addAll(result.selectedSubjectIds);
          _selectedClassIds
            ..clear()
            ..addAll(result.selectedClassIds);
          _selectedDayIds
            ..clear()
            ..addAll(result.selectedDayIds);
          _selectedLessonHourIds
            ..clear()
            ..addAll(result.selectedLessonHourIds);
          _checkActiveFilter();
        });
        _loadData(); // Reload data with new filters
      },
    );
  }

  Future<void> _loadTableData() async {
    if (!mounted) return;
    if (_selectedClassIds.isEmpty) {
      SnackBarUtils.showError(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Please select a class first',
          'id': 'Mohon pilih kelas terlebih dahulu',
        }),
      );
      setState(() => _showTableView = false);
      return;
    }

    setState(() {
      _isTableLoading = true;
      _attendanceMap.clear();
      _studentList.clear();
      _uniqueDates.clear();
      _uniqueSubjectIds.clear();
    });

    try {
      final result = await _controller.loadTableData(
        classId: _selectedClassIds.first,
        selectedDateFilter: _selectedDateFilter,
        subjectList: _subjectList,
      );

      if (!mounted) return;

      setState(() {
        _studentList
          ..clear()
          ..addAll(result.studentList);
        _uniqueDates
          ..clear()
          ..addAll(result.uniqueDates);
        _uniqueSubjectIds
          ..clear()
          ..addAll(result.uniqueSubjectIds);
        _dateLabels
          ..clear()
          ..addAll(result.dateLabels);
        _attendanceDataSource = result.dataSource;
        _isTableLoading = false;
      });
    } catch (e) {
      AppLogger.error('attendance', 'Error loading table data: $e');
      if (mounted) {
        setState(() => _isTableLoading = false);
        SnackBarUtils.showInfo(context, 'Failed to load table data: $e');
      }
    }
  }

  Future<void> _processExport(List<DateTime> months) async {
    final languageProvider = ref.read(languageRiverpod);
    months.sort();
    int successCount = 0;

    // Show loading spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (var month in months) {
        // Build rows without touching context (no async gap issue)
        final exportRows = await _controller.buildExportRows(
          month: month,
          selectedClassData: _selectedClassData!,
          subjectList: _subjectList,
        );

        if (exportRows.isNotEmpty && mounted) {
          // Pass context only after confirming mounted — safe sync-adjacent call
          await ExcelPresenceService.exportPresenceToExcel(
            presenceData: exportRows,
            context: context,
            filters: {},
          );
          successCount++;
        }

        await Future.delayed(const Duration(seconds: 1));
      }

      if (mounted) {
        AppNavigator.pop(context); // Close loading
        SnackBarUtils.showSuccess(
          context,
          languageProvider.getTranslatedText({
            'en': 'Exported $successCount files successfully',
            'id': 'Berhasil mengexport $successCount file',
          }),
        );
      }
    } catch (e) {
      if (mounted) {
        AppNavigator.pop(context);
        SnackBarUtils.showError(context, 'Export failed: $e');
      }
    }
  }

  /// Delegates filtering to the controller — keeps the screen free of
  /// duplicate business logic (like Vue calling a Vuex getter).
  List<AttendanceSummary> _getFilteredSummaries() {
    return _controller.getFilteredSummaries(
      summaryList: _attendanceSummaryList,
      searchText: _searchController.text,
      selectedDateFilter: _selectedDateFilter,
      selectedSubjectIds: _selectedSubjectIds,
      selectedClassIds: _selectedClassIds,
      selectedDayIds: _selectedDayIds,
      selectedLessonHourIds: _selectedLessonHourIds,
    );
  }

  Future<void> _deleteAttendance(
    AttendanceSummary summary,
    LanguageProvider languageProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient danger header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ColorUtils.error600,
                    ColorUtils.error600.withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Delete Attendance',
                      'id': 'Hapus Absensi',
                    }),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Text(
                    languageProvider.getTranslatedText({
                      'en':
                          'Are you sure you want to delete this attendance record?',
                      'id':
                          'Apakah Anda yakin ingin menghapus data absensi ini?',
                    }),
                    style: TextStyle(fontSize: 14, color: ColorUtils.slate700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => AppNavigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: ColorUtils.slate300),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10)),
                            ),
                          ),
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Cancel',
                              'id': 'Batal',
                            }),
                            style: TextStyle(color: ColorUtils.slate700),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => AppNavigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: ColorUtils.error600,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10)),
                            ),
                          ),
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Delete',
                              'id': 'Hapus',
                            }),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        setState(() {
          _isLoadingSummary = true;
        });

        await _controller.deleteAttendance(summary);

        if (!mounted) return;
        SnackBarUtils.showSuccess(
          context,
          languageProvider.getTranslatedText({
            'en': 'Attendance deleted successfully',
            'id': 'Absensi berhasil dihapus',
          }),
        );

        _loadData(useCache: false);
      } catch (e) {
        setState(() {
          _isLoadingSummary = false;
        });
        if (!mounted) return;
        SnackBarUtils.showError(
          context,
          'Gagal menghapus absensi: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  void _navigateToAttendanceDetail(AttendanceSummary summary) {
    AppNavigator.push(
      context,
      AdminAttendanceDetailPage(
        subjectId: summary.subjectId,
        subjectName: summary.subjectName,
        date: summary.date,
        classId: summary.classId,
        className: summary.className,
        lessonHourId: summary.lessonHourId,
        lessonHourName: summary.lessonHourName,
        academicYearId: summary.academicYearId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final filteredSummaries = _getFilteredSummaries();

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      floatingActionButton: FloatingActionButton(
        onPressed: () => TeacherSelectionSheet.show(
          context: context,
          teacherList: _fullTeacherList,
          primaryColor: _getPrimaryColor(),
          onSelected: (teacher) {
            AppNavigator.push(
              context,
              AttendancePage(teacher: teacher),
            ).then((_) => _loadData(useCache: false));
          },
        ),
        backgroundColor: _getPrimaryColor(),
        tooltip: languageProvider.getTranslatedText({
          'en': 'Add Attendance',
          'id': 'Tambah Absensi',
        }),
        child: Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              gradient: _getCardGradient(),
              boxShadow: [
                BoxShadow(
                  color: _getPrimaryColor().withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_selectedClassData != null) {
                          setState(() {
                            _selectedClassData = null;
                            _selectedClassIds.clear();
                            _attendanceSummaryList.clear();
                          });
                        } else {
                          AppNavigator.pop(context);
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: const BorderRadius.all(Radius.circular(10)),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        key: _infoKey,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Attendance Report',
                              'id': 'Laporan Absensi',
                            }),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'View attendance reports',
                              'id': 'Lihat laporan absensi',
                            }),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedClassData != null) ...[
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showTableView = !_showTableView;
                            if (_showTableView) {
                              _loadTableData();
                            }
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: const BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Icon(
                            _showTableView
                                ? Icons.view_list
                                : Icons.table_chart,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'refresh':
                            _forceRefresh();
                            break;
                          case 'export':
                            if (_selectedClassData != null) {
                              AttendanceExportDialog.show(
                                context: context,
                                ref: ref,
                                onExport: _processExport,
                              );
                            } else {
                              SnackBarUtils.showInfo(
                                context,
                                languageProvider.getTranslatedText({
                                  'en': 'Please select a class first',
                                  'id': 'Mohon pilih kelas terlebih dahulu',
                                }),
                              );
                            }
                            break;
                        }
                      },
                      icon: Container(
                        width: 40,
                        height: 40,
                        key: _moreKey,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: const BorderRadius.all(Radius.circular(10)),
                        ),
                        child: Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem<String>(
                          value: 'refresh',
                          child: Row(
                            children: [
                              Icon(
                                Icons.refresh,
                                size: 20,
                                color: ColorUtils.info600,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(AppLocalizations.updateData.tr),
                            ],
                          ),
                        ),
                        if (_selectedClassData != null)
                          PopupMenuItem<String>(
                            value: 'export',
                            child: Row(
                              children: [
                                Icon(Icons.file_download, size: 20),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Export Excel',
                                    'id': 'Export Excel',
                                  }),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Search Bar with Filter Button
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        key: _searchKey,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onSubmitted: (_) => setState(() {}),
                                style: TextStyle(color: ColorUtils.slate800),
                                decoration: InputDecoration(
                                  hintText: languageProvider.getTranslatedText({
                                    'en': 'Search attendance...',
                                    'id': 'Cari absensi...',
                                  }),
                                  hintStyle: TextStyle(
                                    color: ColorUtils.slate400,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: ColorUtils.slate400,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              child: IconButton(
                                icon: Icon(
                                  Icons.search,
                                  color: _getPrimaryColor(),
                                ),
                                onPressed: () => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Filter Button
                    Container(
                      decoration: BoxDecoration(
                        color: _hasActiveFilter
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      key: _filterKey,
                      child: Stack(
                        children: [
                          IconButton(
                            onPressed: _showFilterSheet,
                            icon: Icon(
                              Icons.tune,
                              color: _hasActiveFilter
                                  ? _getPrimaryColor()
                                  : Colors.white,
                            ),
                            tooltip: languageProvider.getTranslatedText({
                              'en': 'Filter',
                              'id': 'Filter',
                            }),
                          ),
                          if (_hasActiveFilter)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: ColorUtils.error600,
                                  shape: BoxShape.circle,
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 8,
                                  minHeight: 8,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Filter Chips
                if (_hasActiveFilter) ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 32,
                    child: Row(
                      children: [
                        Expanded(
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ..._buildFilterChips(languageProvider).map((
                                filter,
                              ) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  child: Chip(
                                    label: Text(
                                      filter['label'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    deleteIcon: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                    onDeleted: filter['onRemove'],
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.2,
                                    ),
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                      width: 1,
                                    ),
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(8)),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    labelPadding: const EdgeInsets.only(left: 4),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        InkWell(
                          onTap: _clearAllFilters,
                          borderRadius: const BorderRadius.all(Radius.circular(8)),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: ColorUtils.error600,
                              borderRadius: const BorderRadius.all(Radius.circular(8)),
                            ),
                            child: Icon(
                              Icons.clear_all,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _selectedClassData == null
                ? AttendanceClassListView(
                    isLoading: _isLoadingClasses,
                    classList: _classList,
                    searchTerm: _searchController.text.toLowerCase(),
                    primaryColor: _getPrimaryColor(),
                    languageProvider: languageProvider,
                    onRefresh: _forceRefresh,
                    onClassSelected: (classItem) {
                      setState(() {
                        _selectedClassData = classItem;
                        _selectedClassIds.clear();
                        _selectedClassIds.add(classItem['id'].toString());
                        _loadData();
                      });
                    },
                  )
                : _showTableView
                ? AttendanceTableView(
                    isLoading: _isTableLoading,
                    selectedClassIds: _selectedClassIds,
                    attendanceDataSource: _attendanceDataSource,
                    studentList: _studentList,
                    uniqueDates: _uniqueDates,
                    uniqueSubjectIds: _uniqueSubjectIds,
                    primaryColor: _getPrimaryColor(),
                    languageProvider: languageProvider,
                  )
                : _isLoadingSummary
                ? SkeletonListLoading(
                    itemCount: 8,
                    infoTagCount: 2,
                    showActions: false,
                  )
                : filteredSummaries.isEmpty
                ? EmptyState(
                    title: languageProvider.getTranslatedText({
                      'en': 'No attendance records',
                      'id': 'Belum ada data absensi',
                    }),
                    subtitle:
                        _searchController.text.isEmpty && !_hasActiveFilter
                        ? languageProvider.getTranslatedText({
                            'en': 'No attendance data available',
                            'id': 'Tidak ada data absensi tersedia',
                          })
                        : languageProvider.getTranslatedText({
                            'en': 'No search results found',
                            'id': 'Tidak ditemukan hasil pencarian',
                          }),
                    icon: Icons.list_alt,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: filteredSummaries.length,
                    itemBuilder: (context, index) {
                      final summary = filteredSummaries[index];
                      return AdminAttendanceSummaryCard(
                        summary: summary,
                        primaryColor: _getPrimaryColor(),
                        languageProvider: languageProvider,
                        onTap: () => _navigateToAttendanceDetail(summary),
                        onDelete: () =>
                            _deleteAttendance(summary, languageProvider),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAndShowTour() async {
    if (_isTourShowing) return;
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'presence_report',
        'admin',
      );
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
          if (mounted && !_isTourShowing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isTourShowing) _showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('attendance', 'Error checking tour status: $e');
    }
  }

  void _showTour() {
    final List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = ref.read(languageRiverpod);

    setState(() {
      _isTourShowing = true;
    });

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: languageProvider.getTranslatedText({
        'en': 'SKIP',
        'id': 'LEWATI',
      }),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        setState(() {
          _isTourShowing = false;
        });
        getIt<ApiTourService>().completeTour(
          name: 'admin_presence_report_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('presence_report', 'admin'),
          {'should_show': false},
        );
      },
      onSkip: () {
        setState(() {
          _isTourShowing = false;
        });
        getIt<ApiTourService>().completeTour(
          name: 'admin_presence_report_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('presence_report', 'admin'),
          {'should_show': false},
        );
        return true;
      },
      onClickOverlay: (target) {
        // Optional handle
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    final List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    targets.add(
      TargetFocus(
        identify: "PresenceReportInfo",
        keyTarget: _infoKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Attendance Reports',
                      'id': 'Laporan Absensi',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en':
                            'View and manage student attendance reports across all classes.',
                        'id':
                            'Lihat dan kelola laporan absensi siswa di semua kelas.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "PresenceReportSearch",
        keyTarget: _searchKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Search Attendance',
                      'id': 'Cari Absensi',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Search for specific classes or subjects.',
                        'id': 'Cari kelas atau mata pelajaran tertentu.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "PresenceReportFilter",
        keyTarget: _filterKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Filter Options',
                      'id': 'Opsi Filter',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Narrow down results by date, subject, or class.',
                        'id':
                            'Persempit hasil berdasarkan tanggal, mata pelajaran, atau kelas.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "PresenceReportMore",
        keyTarget: _moreKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'More Options',
                      'id': 'Opsi Lanjutan',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Refresh data or export reports to Excel.',
                        'id': 'Segarkan data atau export laporan ke Excel.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    return targets;
  }
}

// AttendanceGridData and AttendanceDataSource have been extracted to
// attendance_grid_data.dart in the widgets directory.
