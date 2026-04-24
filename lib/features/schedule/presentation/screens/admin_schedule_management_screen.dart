// Admin schedule management: tour/data/filter logic extracted to mixins; UI to widgets.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/admin_schedule_controller.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/admin_schedule_tour_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/admin_schedule_data_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/admin_schedule_filter_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/admin_schedule_state_bridge_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/admin_schedule_dialogs_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/admin_schedule_events_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/admin_schedule_actions_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/admin_schedule_header.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/admin_schedule_list_builder.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/timetable_data_source.dart';

class TeachingScheduleManagementScreen extends ConsumerStatefulWidget {
  const TeachingScheduleManagementScreen({super.key});
  @override
  TeachingScheduleManagementScreenState createState() =>
      TeachingScheduleManagementScreenState();
}

class TeachingScheduleManagementScreenState
    extends ConsumerState<TeachingScheduleManagementScreen>
    with
        AdminScheduleTourMixin,
        AdminScheduleStateBridgeMixin,
        AdminScheduleDataMixin,
        AdminScheduleFilterMixin,
        AdminScheduleDialogsMixin,
        AdminScheduleEventsMixin,
        AdminScheduleActionsMixin {
  late AdminScheduleController _controller;
  List<dynamic> _scheduleList = [],
      _subjectList = [],
      _classList = [],
      _dayList = [],
      _termList = [],
      _lessonHourList = [];
  bool _isLoading = true,
      _hasMoreData = true,
      _isLoadingMore = false,
      _hasActiveFilter = false,
      _showTableView = false,
      _isTourShowing = false;
  int _currentPage = 1;
  final int _perPage = 10;
  String _selectedTerm = '1', _selectedAcademicYear = '2024/2025';
  String? _selectedTeacherId,
      _selectedClassId,
      _selectedDayId,
      _selectedFilterTerm,
      _selectedLessonHour;
  String? _lastCachedAcademicYear, _lastCachedTerm;
  List<dynamic> _availableTeachers = [],
      _availableClasses = [],
      _availableDays = [],
      _availableSemesters = [],
      _availableAcademicYears = [];
  final TextEditingController _searchController = TextEditingController();
  List<ScheduleGridData> _gridData = [];
  dynamic _timetableDataSource;
  final GlobalKey _menuKey = GlobalKey(),
      _searchKey = GlobalKey(),
      _filterKey = GlobalKey(),
      _fabKey = GlobalKey(),
      _viewToggleKey = GlobalKey();
  @override
  AdminScheduleController get controller => _controller;
  @override
  List<dynamic> get scheduleList => _scheduleList;
  @override
  List<dynamic> get subjectList => _subjectList;
  @override
  List<dynamic> get classList => _classList;
  @override
  List<dynamic> get dayList => _dayList;
  @override
  List<dynamic> get termList => _termList;
  @override
  List<dynamic> get lessonHourList => _lessonHourList;
  @override
  bool get isLoading => _isLoading;
  @override
  String get selectedTerm => _selectedTerm;
  @override
  String get selectedAcademicYear => _selectedAcademicYear;
  @override
  int get currentPage => _currentPage;
  @override
  int get perPage => _perPage;
  @override
  bool get hasMoreData => _hasMoreData;
  @override
  bool get isLoadingMore => _isLoadingMore;
  @override
  String? get lastCachedAcademicYear => _lastCachedAcademicYear;
  @override
  String? get lastCachedTerm => _lastCachedTerm;
  @override
  List<dynamic> get availableTeachers => _availableTeachers;
  @override
  List<dynamic> get availableClasses => _availableClasses;
  @override
  List<dynamic> get availableDays => _availableDays;
  @override
  List<dynamic> get availableSemesters => _availableSemesters;
  @override
  List<dynamic> get availableAcademicYears => _availableAcademicYears;
  @override
  String? get selectedTeacherId => _selectedTeacherId;
  @override
  String? get selectedClassId => _selectedClassId;
  @override
  String? get selectedDayId => _selectedDayId;
  @override
  String? get selectedFilterTerm => _selectedFilterTerm;
  @override
  String? get selectedLessonHour => _selectedLessonHour;
  @override
  bool get hasActiveFilter => _hasActiveFilter;
  @override
  GlobalKey get menuKey => _menuKey;
  @override
  GlobalKey get searchKey => _searchKey;
  @override
  GlobalKey get filterKey => _filterKey;
  @override
  GlobalKey get fabKey => _fabKey;
  @override
  GlobalKey get viewToggleKey => _viewToggleKey;
  @override
  bool get isTourShowing => _isTourShowing;
  @override
  set isTourShowing(bool v) => _isTourShowing = v;
  @override
  void updateScheduleList(List<dynamic> v) => _scheduleList = v;
  @override
  void updateSubjectList(List<dynamic> v) => _subjectList = v;
  @override
  void updateClassList(List<dynamic> v) => _classList = v;
  @override
  void updateDayList(List<dynamic> v) => _dayList = v;
  @override
  void updateTermList(List<dynamic> v) => _termList = v;
  @override
  void updateLessonHourList(List<dynamic> v) => _lessonHourList = v;
  @override
  void updateIsLoading(bool v) => _isLoading = v;
  @override
  void updateCurrentPage(int v) => _currentPage = v;
  @override
  void updateHasMoreData(bool v) => _hasMoreData = v;
  @override
  void updateIsLoadingMore(bool v) => _isLoadingMore = v;
  @override
  void updateLastCachedAcademicYear(String? v) => _lastCachedAcademicYear = v;
  @override
  void updateLastCachedTerm(String? v) => _lastCachedTerm = v;
  @override
  void updateAvailableTeachers(List<dynamic> v) => _availableTeachers = v;
  @override
  void updateAvailableClasses(List<dynamic> v) => _availableClasses = v;
  @override
  void updateAvailableDays(List<dynamic> v) => _availableDays = v;
  @override
  void updateAvailableSemesters(List<dynamic> v) => _availableSemesters = v;
  @override
  void updateAvailableAcademicYears(List<dynamic> v) =>
      _availableAcademicYears = v;
  @override
  void updateSelectedAcademicYear(String v) => _selectedAcademicYear = v;
  @override
  void updateSelectedTerm(String v) => _selectedTerm = v;
  @override
  void updateSelectedTeacherId(String? v) => _selectedTeacherId = v;
  @override
  void updateSelectedClassId(String? v) => _selectedClassId = v;
  @override
  void updateSelectedDayId(String? v) => _selectedDayId = v;
  @override
  void updateSelectedFilterTerm(String? v) => _selectedFilterTerm = v;
  @override
  void updateSelectedLessonHour(String? v) => _selectedLessonHour = v;
  @override
  void updateHasActiveFilter(bool v) => _hasActiveFilter = v;
  @override
  bool get showTableView => _showTableView;
  @override
  TextEditingController get searchController => _searchController;
  @override
  void initState() {
    // Assign the late controller BEFORE super.initState() so that mixins'
    // initState (notably AdminScheduleEventsMixin, which kicks off
    // loadCachedScheduleData/loadFilterOptions/loadData synchronously) can
    // safely reach the `controller` getter. Riverpod's `ref` is available
    // on ConsumerState from construction, so reading the provider here is
    // fine.
    _controller = ref.read(adminScheduleControllerProvider);
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void updateGridData() {
    final r = _controller.updateGridData(
      scheduleList: getFilteredSchedules(
        _scheduleList,
        _dayList,
        _searchController.text,
      ),
      dayList: _dayList,
      classList: _classList,
      lessonHourList: _lessonHourList,
      availableDays: _availableDays,
      selectedDayId: _selectedDayId,
      selectedClassId: _selectedClassId,
      selectedJamPelajaran: _selectedLessonHour,
      onScheduleTap: showScheduleDetail,
    );
    _gridData = r.gridData;
    _timetableDataSource = r.timetableDataSource;
  }

  @override
  void setIsLoading(bool v) => setState(() => _isLoading = v);
  Widget _buildHeader(LanguageProvider lp) => AdminScheduleHeader(
    title: lp.getTranslatedText({
      'en': 'Teaching Schedule',
      'id': 'Jadwal Mengajar',
    }),
    subtitle: lp.getTranslatedText({
      'en': 'Manage teaching schedules',
      'id': 'Kelola jadwal mengajar',
    }),
    primaryColor: _controller.getPrimaryColor(),
    searchController: _searchController,
    showTableView: _showTableView,
    hasActiveFilter: _hasActiveFilter,
    menuKey: _menuKey,
    searchKey: _searchKey,
    filterKey: _filterKey,
    viewToggleKey: _viewToggleKey,
    filterChips: buildFilterChips(lp),
    clearAllLabel: 'Clear All',
    onBack: () => AppNavigator.pop(context),
    onViewToggle: () {
      setState(() => _showTableView = !_showTableView);
      loadData(
        resetPage: true,
        useCache: true,
        searchText: _searchController.text,
        showTableView: _showTableView,
      );
    },
    onShowFilter: showFilterSheet,
    onClearAllFilters: clearAllFilters,
    onSearch: triggerSearch,
    onRefresh: () => forceRefresh().then(
      (_) => loadData(
        resetPage: true,
        useCache: false,
        searchText: _searchController.text,
        showTableView: _showTableView,
      ),
    ),
    onExport: exportToExcel,
    onImport: importFromExcel,
    onDownloadTemplate: downloadTemplate,
    canImport: !ref.read(academicYearRiverpod).isReadOnly,
  );
  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(languageRiverpod);
    final filtered = getFilteredSchedules(
      _scheduleList,
      _dayList,
      _searchController.text,
    );
    final isRO = ref.read(academicYearRiverpod).isReadOnly;
    return Scaffold(
      backgroundColor: ColorUtils.lightGray,
      body: Column(
        children: [
          _buildHeader(lp),
          Expanded(
            child: AdminScheduleListBuilder(
              isLoading: _isLoading,
              showTableView: _showTableView,
              filteredSchedules: filtered,
              gridData: _gridData,
              timetableDataSource: _timetableDataSource,
              dayList: _dayList,
              classList: _classList,
              hasMoreData: _hasMoreData,
              isLoadingMore: _isLoadingMore,
              selectedClassId: _selectedClassId,
              primaryColor: _controller.getPrimaryColor(),
              controller: _controller,
              scrollController: scrollController,
              isReadOnly: isRO,
              currentLanguage: lp.currentLanguage,
              onRefresh: () => loadData(
                resetPage: true,
                useCache: false,
                searchText: _searchController.text,
                showTableView: _showTableView,
              ),
              onScheduleTap: showScheduleDetail,
              onScheduleEdit: editSchedule,
              onScheduleDelete: deleteSchedule,
            ),
          ),
        ],
      ),
      floatingActionButton: isRO
          ? null
          : FloatingActionButton(
              key: _fabKey,
              onPressed: addSchedule,
              backgroundColor: _controller.getPrimaryColor(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
    );
  }
}
