// Admin presence/attendance report screen.
//
// Like `pages/admin/attendance-report.vue` - displays attendance summaries
// across classes, subjects, and dates. Supports both list view and table view,
// with filters by date range, subject, class, day, and lesson hour.
// Can export reports to Excel.
//
// In Laravel terms, this consumes AttendanceController with complex query
// filters, similar to
// `Attendance::with(['student','subject'])->filter(...)->paginate()`.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/admin_attendance_report_controller.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_grid_data.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/admin_attendance_summary_card.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_class_list_view.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_table_view.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/teacher_selection_sheet.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/admin_report_header.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/admin_report_tour_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/admin_report_data_loading_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/admin_report_filter_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/admin_report_actions_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/admin_report_helper_mixin.dart';

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
      AdminAttendanceReportScreenState();
}

/// Mutable state for [AdminAttendanceReportScreen].
/// Manages data, pagination, filtering, and dual view modes.
class AdminAttendanceReportScreenState
    extends ConsumerState<AdminAttendanceReportScreen>
    with
        AdminReportTourMixin,
        AdminReportDataLoadingMixin,
        AdminReportFilterMixin,
        AdminReportActionsMixin,
        AdminReportHelperMixin {
  late AdminAttendanceReportController _controller;

  List<AttendanceSummary> _attendanceSummaryList = [];
  bool _isLoadingSummary = false;
  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  bool _showTableView = false;
  final List<dynamic> _studentList = [];
  final Map<String, dynamic> _attendanceMap = {};
  AttendanceDataSource? _attendanceDataSource;
  final List<String> _uniqueDates = [];
  final List<String> _uniqueSubjectIds = [];
  final Map<String, String> _dateLabels = {};
  bool _isTableLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDateFilter;
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

  @override
  GlobalKey get searchKey => _searchKey;
  @override
  GlobalKey get filterKey => _filterKey;
  @override
  GlobalKey get moreKey => _moreKey;
  @override
  GlobalKey get infoKey => _infoKey;
  @override
  bool get isTourShowing => _isTourShowing;
  @override
  set isTourShowing(bool value) => _isTourShowing = value;

  List<dynamic> _subjectList = [];
  List<dynamic> _classList = [];
  List<dynamic> _lessonHours = [];
  Map<String, dynamic>? _selectedClassData;
  bool _isLoadingClasses = true;
  List<dynamic> _fullTeacherList = [];

  @override
  AdminAttendanceReportController get controller => _controller;
  @override
  List<AttendanceSummary> get attendanceSummaryList => _attendanceSummaryList;
  @override
  set attendanceSummaryList(List<AttendanceSummary> v) =>
      _attendanceSummaryList = v;
  @override
  bool get isLoadingSummary => _isLoadingSummary;
  @override
  set isLoadingSummary(bool v) => _isLoadingSummary = v;
  @override
  int get currentPage => _currentPage;
  @override
  set currentPage(int v) => _currentPage = v;
  @override
  int get perPage => _perPage;
  @override
  bool get hasMoreData => _hasMoreData;
  @override
  set hasMoreData(bool v) => _hasMoreData = v;
  @override
  bool get isLoadingMore => _isLoadingMore;
  @override
  set isLoadingMore(bool v) => _isLoadingMore = v;
  @override
  ScrollController get scrollController => _scrollController;
  @override
  bool get showTableView => _showTableView;
  @override
  set showTableView(bool v) => _showTableView = v;
  @override
  bool get hasActiveFilter => _hasActiveFilter;
  @override
  set hasActiveFilter(bool v) => _hasActiveFilter = v;
  @override
  String? get selectedDateFilter => _selectedDateFilter;
  @override
  set selectedDateFilter(String? v) => _selectedDateFilter = v;
  @override
  List<String> get selectedSubjectIds => _selectedSubjectIds;
  @override
  List<String> get selectedClassIds => _selectedClassIds;
  @override
  List<String> get selectedDayIds => _selectedDayIds;
  @override
  List<String> get selectedLessonHourIds => _selectedLessonHourIds;
  @override
  TextEditingController get searchController => _searchController;
  @override
  List<dynamic> get subjectList => _subjectList;
  @override
  set subjectList(List<dynamic> v) => _subjectList = v;
  @override
  List<dynamic> get classList => _classList;
  @override
  set classList(List<dynamic> v) => _classList = v;
  @override
  List<dynamic> get lessonHours => _lessonHours;
  @override
  set lessonHours(List<dynamic> v) => _lessonHours = v;
  @override
  bool get isLoadingClasses => _isLoadingClasses;
  @override
  set isLoadingClasses(bool v) => _isLoadingClasses = v;
  @override
  List<dynamic> get fullTeacherList => _fullTeacherList;
  @override
  set fullTeacherList(List<dynamic> v) => _fullTeacherList = v;
  @override
  bool get isTableLoading => _isTableLoading;
  @override
  set isTableLoading(bool v) => _isTableLoading = v;
  @override
  List<dynamic> get studentList => _studentList;
  @override
  Map<String, dynamic> get attendanceMap => _attendanceMap;
  @override
  List<String> get uniqueDates => _uniqueDates;
  @override
  List<String> get uniqueSubjectIds => _uniqueSubjectIds;
  @override
  Map<String, String> get dateLabels => _dateLabels;
  @override
  set dateLabels(Map<String, String> v) => _dateLabels
    ..clear()
    ..addAll(v);
  @override
  AttendanceDataSource? get attendanceDataSource => _attendanceDataSource;
  @override
  set attendanceDataSource(AttendanceDataSource? v) =>
      _attendanceDataSource = v;
  @override
  Map<String, dynamic>? get selectedClassData => _selectedClassData;
  @override
  Color get primaryColor => controller.getPrimaryColor();
  @override
  Future<void> forceRefresh() => forceRefreshImpl();

  @override
  void initState() {
    super.initState();
    _controller = AdminAttendanceReportController(ref);
    _scrollController.addListener(onScroll);
    loadFilterData();
  }

  @override
  void loadMoreScrolling() {
    if (!isLoadingMore && hasMoreData) {
      loadMoreData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!mounted) return;
      loadMoreScrolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final filteredSummaries = getFilteredSummaries();

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      floatingActionButton: FloatingActionButton(
        onPressed: () => TeacherSelectionSheet.show(
          context: context,
          teacherList: fullTeacherList,
          primaryColor: primaryColor,
          onSelected: (teacher) {
            AppNavigator.push(
              context,
              AttendancePage(teacher: teacher),
            ).then((_) => loadData(useCache: false));
          },
        ),
        backgroundColor: primaryColor,
        tooltip: languageProvider.getTranslatedText({
          'en': 'Add Attendance',
          'id': 'Tambah Absensi',
        }),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          AdminReportHeader(
            primaryColor: primaryColor,
            gradient: controller.getCardGradient(),
            languageProvider: languageProvider,
            hasClassSelected: selectedClassData != null,
            showTableView: showTableView,
            hasActiveFilter: _hasActiveFilter,
            infoKey: infoKey,
            searchKey: searchKey,
            filterKey: filterKey,
            moreKey: moreKey,
            searchController: searchController,
            filterChips: buildFilterChips(languageProvider),
            onBack: () => AppNavigator.pop(context),
            onBackToClassList: () {
              setState(() {
                _selectedClassData = null;
                selectedClassIds.clear();
                attendanceSummaryList = [];
              });
            },
            onToggleView: () {
              setState(() {
                _showTableView = !showTableView;
                if (showTableView) loadTableData();
              });
            },
            onRefresh: forceRefresh,
            onExport: showExportDialog,
            onShowFilter: showFilterSheet,
            onClearAllFilters: clearAllFilters,
            onSearch: () => setState(() {}),
          ),
          Expanded(
            child: selectedClassData == null
                ? AttendanceClassListView(
                    isLoading: isLoadingClasses,
                    classList: classList,
                    searchTerm: searchController.text.toLowerCase(),
                    primaryColor: primaryColor,
                    languageProvider: languageProvider,
                    onRefresh: forceRefresh,
                    onClassSelected: (classItem) {
                      setState(() {
                        _selectedClassData = classItem;
                        selectedClassIds.clear();
                        selectedClassIds.add(classItem['id'].toString());
                        loadData();
                      });
                    },
                  )
                : showTableView
                ? AttendanceTableView(
                    isLoading: isTableLoading,
                    selectedClassIds: selectedClassIds,
                    attendanceDataSource: attendanceDataSource,
                    studentList: studentList,
                    uniqueDates: uniqueDates,
                    uniqueSubjectIds: uniqueSubjectIds,
                    primaryColor: primaryColor,
                    languageProvider: languageProvider,
                  )
                : isLoadingSummary
                ? const SkeletonListLoading(
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
                    subtitle: searchController.text.isEmpty && !_hasActiveFilter
                        ? languageProvider.getTranslatedText({
                            'en': 'No attendance data available',
                            'id':
                                'Tidak ada data absensi '
                                'tersedia',
                          })
                        : languageProvider.getTranslatedText({
                            'en': 'No search results found',
                            'id':
                                'Tidak ditemukan hasil '
                                'pencarian',
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
                        primaryColor: primaryColor,
                        languageProvider: languageProvider,
                        onTap: () => navigateToAttendanceDetail(summary),
                        onDelete: () =>
                            deleteAttendance(summary, languageProvider),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
