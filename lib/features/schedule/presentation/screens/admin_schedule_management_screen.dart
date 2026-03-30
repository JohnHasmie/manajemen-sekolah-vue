// Admin teaching schedule management screen - full CRUD for class schedules.
//
// Like `pages/admin/schedules.vue` - manages the school timetable with create,
// edit, delete, search, multi-filter (teacher, class, day, semester, lesson hour),
// infinite scroll pagination, Excel import/export, and a timetable grid view.
//
// In Laravel terms, this consumes ScheduleController endpoints.
// Also handles conflict detection (double-booked teachers/rooms).
// Supports two view modes: card list and Syncfusion data grid (timetable).
//
// All data/logic methods live in AdminScheduleController — this file only owns
// state variables, setState calls, lifecycle hooks, dialog/navigation, and
// widget build methods.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/gradient_page_header.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/dashboard/presentation/providers/academic_year_provider.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/admin_schedule_controller.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/admin_schedule_card.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_detail_dialog.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_filter_sheet.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_form_dialog.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_table_view.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/timetable_data_source.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Admin teaching schedule management with full CRUD, timetable grid, and conflict detection.
///
/// This is a [StatefulWidget] - like a Vue page with extensive local state for
/// schedule list, reference data (teachers, subjects, classes, days), pagination,
/// filters, and two view modes (card list vs timetable grid).
class TeachingScheduleManagementScreen extends ConsumerStatefulWidget {
  const TeachingScheduleManagementScreen({super.key});

  @override
  TeachingScheduleManagementScreenState createState() =>
      TeachingScheduleManagementScreenState();
}

/// Mutable state for [TeachingScheduleManagementScreen].
///
/// Key state (like Vue `data()`):
/// - [_scheduleList] - paginated schedule entries from API
/// - [_teacherList] / [_subjectList] / [_classList] / [_dayList] / [_lessonHourList] - reference data
/// - [_showTableView] - toggles between card list and timetable grid (Syncfusion DataGrid)
/// - [_gridData] / [_timetableDataSource] - data source for the timetable grid view
/// - Filter states: [_selectedTeacherId], [_selectedClassId], [_selectedDayId], etc.
/// - Pagination: [_currentPage], [_hasMoreData], [_isLoadingMore] for infinite scroll
///
/// Listens to AcademicYearProvider for year changes and FCM for real-time sync.
/// setState() triggers re-render like Vue's reactivity system.
class TeachingScheduleManagementScreenState
    extends ConsumerState<TeachingScheduleManagementScreen> {
  // Controller holds all data/logic methods. Accessed via Riverpod provider so
  // it shares the same instance as any other widget reading the same provider.
  // Like injecting a Laravel controller into a view — the screen doesn't own the
  // logic, it just calls the controller and rebuilds via setState.
  late AdminScheduleController _controller;

  List<dynamic> _scheduleList = [];
  List<dynamic> _subjectList = [];
  List<dynamic> _classList = [];
  List<dynamic> _dayList = [];
  List<dynamic> _semesterList = [];
  List<dynamic> _lessonHourList = [];

  bool _isLoading = true;
  String _selectedSemester = '1'; // Will be set by _setDefaultAcademicPeriod()
  String _selectedAcademicYear =
      '2024/2025'; // Will be set by _setDefaultAcademicPeriod()
  final TextEditingController _searchController = TextEditingController();

  // Scroll Controller for Infinite Scroll
  final ScrollController _scrollController = ScrollController();

  // Pagination States (Infinite Scroll)
  int _currentPage = 1;
  final int _perPage = 10; // Fixed 10 items per load
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  // Filter state (Backend filtering)
  String? _selectedTeacherId; // Filter by teacher
  String? _selectedClassId; // Filter by class
  String? _selectedDayId; // Filter by day
  String? _selectedFilterSemester;
  String? _selectedJamPelajaran; // Filter by Lesson Hour
  bool _hasActiveFilter = false;

  // Filter Options (from backend)
  List<dynamic> _availableTeachers = [];
  List<dynamic> _availableClasses = [];
  List<dynamic> _availableDays = [];
  List<dynamic> _availableSemesters = [];
  List<dynamic> _availableAcademicYears = [];

  // Search debounce
  Timer? _searchDebounce;

  // Tour Keys
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _viewToggleKey = GlobalKey();
  bool _isTourShowing = false;

  // Additional state for table view
  bool _showTableView = false;
  List<ScheduleGridData> _gridData = [];
  TimetableDataSource? _timetableDataSource;
  AcademicYearProvider? _academicYearProvider;

  // Persisted cache key values
  String? _lastCachedAcademicYear;
  String? _lastCachedSemester;

  /// Like Vue's `mounted()` - sets up scroll listener, academic year provider,
  /// FCM sync listener, and loads all reference data + schedule list.
  @override
  void initState() {
    super.initState();

    // Resolve the controller via Riverpod. Must be done in initState (not the
    // constructor) because `ref` is only available after the widget is wired in.
    _controller = ref.read(adminScheduleControllerProvider);

    // Listen to scroll for infinite scroll
    _scrollController.addListener(_onScroll);

    // Set default academic year from provider
    _academicYearProvider = ref.read(academicYearRiverpod);
    if (_academicYearProvider?.selectedAcademicYear != null) {
      _selectedAcademicYear = _academicYearProvider!.selectedAcademicYear!['id']
          .toString();
    } else {
      _setDefaultAcademicPeriod();
    }

    // Listen to academic year changes
    _academicYearProvider?.addListener(_onAcademicYearProviderChanged);

    // Load cached data first for instant display, then fetch fresh
    _loadCachedScheduleData();
    _loadFilterOptions();
    _loadData();

    // Listen to real-time sync trigger
    FCMService().syncTrigger.addListener(_onSyncTriggered);
  }

  /// Load cached schedule data for instant display before any API calls.
  /// Delegates to the controller; applies result with setState here.
  Future<void> _loadCachedScheduleData() async {
    final result = await _controller.loadCachedScheduleData();
    if (result == null || !mounted) return;
    setState(() {
      _scheduleList = result.scheduleList;
      _subjectList = result.subjectList;
      _classList = result.classList;
      _dayList = result.dayList;
      _semesterList = result.semesterList;
      _lessonHourList = result.lessonHourList;
      _hasMoreData = result.hasMoreData;
      _isLoading = result.isLoading;
      _lastCachedAcademicYear = _selectedAcademicYear;
      _lastCachedSemester = _selectedSemester;
    });
    _updateGridData();
  }

  void _onSyncTriggered() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger != null && trigger['type'] == 'refresh_schedules') {
      if (mounted) {
        AppLogger.debug('schedule', 'Sync triggered: refresh_schedules');
        _loadData(resetPage: true, useCache: false);
      }
    }
  }

  /// Set default academic period based on current date.
  /// Delegates pure calculation to the controller.
  void _setDefaultAcademicPeriod() {
    _selectedAcademicYear = _controller.setDefaultAcademicPeriod(
      availableAcademicYears: _availableAcademicYears,
    );
  }

  /// Update semester selection after semester list is loaded.
  /// Delegates to the controller; applies result with setState here.
  Future<void> _updateCurrentSemester() async {
    final newSemesterId = await _controller.updateCurrentSemester(
      semesterList: _semesterList,
      currentSemesterId: _selectedSemester,
    );
    if (newSemesterId != null && mounted) {
      setState(() => _selectedSemester = newSemesterId);
      _loadData(resetPage: true);
    }
  }

  /// Generate list of academic years

  @override
  void dispose() {
    FCMService().syncTrigger.removeListener(_onSyncTriggered);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _academicYearProvider?.removeListener(_onAcademicYearProviderChanged);
    super.dispose();
  }

  void _onAcademicYearProviderChanged() {
    if (mounted && _academicYearProvider?.selectedAcademicYear != null) {
      setState(() {
        _selectedAcademicYear = _academicYearProvider!
            .selectedAcademicYear!['id']
            .toString();
        // Usually changing year resets semester or keeps it if ID matches.
      });
      _loadFilterOptions(); // Reload classes based on new academic year
      _loadData(resetPage: true);
    }
  }

  void _onScroll() {
    // Detect when user scrolls near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && !_isLoading) {
        _loadMoreData();
      }
    }
  }

  /// Fetches filter options and applies them with setState.
  Future<void> _loadFilterOptions() async {
    final result = await _controller.loadFilterOptions(
      selectedAcademicYear: _selectedAcademicYear,
    );
    if (result == null || !mounted) return;
    setState(() {
      _availableTeachers = result.teachers;
      _availableClasses = result.classes;
      _availableDays = result.days;
      _availableSemesters = result.semesters;
      _availableAcademicYears = result.academicYears;
    });
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    SnackBarUtils.showInfo(context, message);
  }

  /// Builds the cache key for the current state, delegates to controller, and
  /// also syncs [_lastCachedAcademicYear] / [_lastCachedSemester] so that
  /// subsequent early-cache loads resolve the right key.
  String? _buildScheduleCacheKey() {
    final key = _controller.buildScheduleCacheKey(
      currentPage: _currentPage,
      showTableView: _showTableView,
      selectedAcademicYear: _selectedAcademicYear,
      selectedSemester: _selectedSemester,
      selectedTeacherId: _selectedTeacherId,
      selectedClassId: _selectedClassId,
      selectedDayId: _selectedDayId,
      selectedJamPelajaran: _selectedJamPelajaran,
      selectedFilterSemester: _selectedFilterSemester,
      searchText: _searchController.text,
      lastCachedAcademicYear: _lastCachedAcademicYear,
      lastCachedSemester: _lastCachedSemester,
    );
    if (key != null) {
      _lastCachedAcademicYear = _selectedAcademicYear;
      _lastCachedSemester = _selectedSemester;
    }
    return key;
  }

  /// Unpacks a [ScheduleLoadResult] into local state fields.
  /// Must be called inside setState — no setState call here.
  void _applyLoadResult(ScheduleLoadResult result) {
    _scheduleList = result.scheduleList;
    _subjectList = result.subjectList;
    _classList = result.classList;
    _dayList = result.dayList.isEmpty && _availableDays.isNotEmpty
        ? _availableDays
        : result.dayList;
    _semesterList = result.semesterList;
    _lessonHourList = result.lessonHourList;
    _hasMoreData = result.hasMoreData;
    _isLoading = result.isLoading;
  }

  /// Loads all schedule + reference data, with cache-first strategy.
  /// Delegates API/cache work to the controller; this method only owns state
  /// updates (setState) and UI side-effects (tour, snackbar).
  Future<void> _loadData({bool resetPage = true, bool useCache = true}) async {
    if (resetPage) {
      _currentPage = 1;
      _hasMoreData = true;
    }

    try {
      final result = await _controller.loadData(
        showTableView: _showTableView,
        selectedSemester: _selectedSemester,
        selectedFilterSemester: _selectedFilterSemester,
        selectedAcademicYear: _selectedAcademicYear,
        selectedTeacherId: _selectedTeacherId,
        selectedClassId: _selectedClassId,
        selectedDayId: _selectedDayId,
        selectedJamPelajaran: _selectedJamPelajaran,
        searchText: _searchController.text,
        perPage: _perPage,
        availableDays: _availableDays,
        lastCachedAcademicYear: _lastCachedAcademicYear,
        lastCachedSemester: _lastCachedSemester,
        useCache: useCache,
      );

      if (!mounted) return;

      if (result == null) {
        // Error path — show snackbar only when there's nothing cached to show
        if (_scheduleList.isEmpty) {
          _showErrorSnackBar(
            ref.read(languageRiverpod).getTranslatedText({
              'en': 'Failed to load schedules',
              'id': 'Gagal memuat jadwal',
            }),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      setState(() => _applyLoadResult(result));
      _updateGridData();

      // Cache the result for next cold start
      _controller.saveScheduleToCache(
        cacheKey: _buildScheduleCacheKey(),
        scheduleResponse: {'data': result.scheduleList},
        teacher: result.teacherList,
        subject: result.subjectList,
        classData: result.classList,
        days: result.dayList,
        semester: result.semesterList,
        lessonHours: result.lessonHourList,
      );

      if (_semesterList.isNotEmpty) {
        _updateCurrentSemester();
      }
    } catch (e) {
      AppLogger.error('schedule', e);
      if (!mounted) return;
      if (_scheduleList.isEmpty) {
        _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
      }
      setState(() => _isLoading = false);
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkAndShowTour();
      });
    }
  }

  /// Force refresh: clears caches then reloads from the API.
  Future<void> _forceRefresh() async {
    await _controller.forceRefresh(
      cacheKey: _buildScheduleCacheKey(),
      selectedAcademicYear: _selectedAcademicYear,
    );
    await _loadData(resetPage: true, useCache: false);
  }

  /// Loads the next page of schedules for infinite scroll.
  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() => _isLoadingMore = true);

    _currentPage++;
    final result = await _controller.loadMoreData(
      nextPage: _currentPage,
      perPage: _perPage,
      selectedSemester: _selectedSemester,
      selectedFilterSemester: _selectedFilterSemester,
      selectedAcademicYear: _selectedAcademicYear,
      selectedTeacherId: _selectedTeacherId,
      selectedClassId: _selectedClassId,
      selectedDayId: _selectedDayId,
      selectedJamPelajaran: _selectedJamPelajaran,
      searchText: _searchController.text,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isLoadingMore = false;
        _currentPage--;
      });
      return;
    }

    setState(() {
      _scheduleList.addAll(result.newItems);
      _hasMoreData = result.hasMoreData;
      _isLoadingMore = false;
    });
    _updateGridData();
    AppLogger.info(
      'schedule',
      'Loaded more schedules: Page $_currentPage, Total: ${_scheduleList.length}',
    );
  }

  /// Opens file picker and imports schedules from Excel.
  Future<void> _importFromExcel() async {
    final languageProvider = ref.read(languageRiverpod);
    try {
      setState(() => _isLoading = true);
      final imported = await _controller.importFromExcel();
      if (!mounted) return;
      if (imported) {
        _loadData(resetPage: true, useCache: false);
        _showInfoSnackBar(
          languageProvider.getTranslatedText({
            'en': 'Import successful',
            'id': 'Import berhasil',
          }),
        );
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger.error('schedule', e);
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorSnackBar(
        '${languageProvider.getTranslatedText({'en': 'Failed to import file: ', 'id': 'Gagal mengimpor file: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  /// Exports current schedule list to Excel.
  Future<void> _exportToExcel() async {
    try {
      await _controller.exportToExcel(
        context: context,
        scheduleList: _scheduleList,
        dayList: _dayList,
        availableAcademicYears: _availableAcademicYears,
      );
    } catch (e) {
      AppLogger.error('schedule', e);
      _showErrorSnackBar(
        '${ref.read(languageRiverpod).getTranslatedText({'en': 'Export failed: ', 'id': 'Export gagal: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  /// Downloads the Excel import template.
  Future<void> _downloadTemplate() async {
    try {
      await _controller.downloadTemplate(context);
    } catch (e) {
      AppLogger.error('schedule', e);
      _showErrorSnackBar(
        '${ref.read(languageRiverpod).getTranslatedText({'en': 'Download template failed: ', 'id': 'Gagal download template: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  /// Rebuilds the timetable data source from current state.
  /// Delegates all logic to the controller; assigns results to local fields.
  void _updateGridData() {
    final result = _controller.updateGridData(
      scheduleList: _getFilteredSchedules(),
      dayList: _dayList,
      classList: _classList,
      lessonHourList: _lessonHourList,
      availableDays: _availableDays,
      selectedDayId: _selectedDayId,
      selectedClassId: _selectedClassId,
      selectedJamPelajaran: _selectedJamPelajaran,
      onScheduleTap: _showScheduleDetail,
    );
    _gridData = result.gridData;
    _timetableDataSource = result.timetableDataSource;
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      SnackBarUtils.showError(context, message);
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      SnackBarUtils.showSuccess(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': message,
          'id': message.replaceAll('successfully', 'berhasil'),
        }),
      );
    }
  }

  Future<void> _addSchedule() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduleFormDialog(
        teacherList: _availableTeachers,
        subjectList: _subjectList,
        classList: _availableClasses,
        dayList: _availableDays,
        semesterList: _availableSemesters,
        lessonHourList: _lessonHourList,
        semester: _selectedSemester,
        academicYear: _selectedAcademicYear,
        academicYearList: _availableAcademicYears,
        apiService: _controller.apiService,
        apiTeacherService: _controller.apiTeacherService,
      ),
    );

    if (result != null) {
      await _checkAndResolveConflicts(result);
    }
  }

  Future<void> _editSchedule(dynamic schedule) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduleFormDialog(
        teacherList: _availableTeachers,
        subjectList: _subjectList,
        classList: _availableClasses,
        dayList: _availableDays,
        semesterList: _availableSemesters,
        lessonHourList: _lessonHourList,
        semester: _selectedSemester,
        academicYear: _selectedAcademicYear,
        academicYearList: _availableAcademicYears,
        schedule: schedule,
        apiService: _controller.apiService,
        apiTeacherService: _controller.apiTeacherService,
      ),
    );

    if (result != null) {
      await _checkAndResolveConflicts(
        result,
        editingScheduleId: schedule['id'],
      );
    }
  }

  Future<void> _deleteSchedule(String id) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) {
        final languageProvider = ref.watch(languageRiverpod);
        return ConfirmationDialog(
          title: languageProvider.getTranslatedText({
            'en': 'Delete Schedule',
            'id': 'Hapus Jadwal',
          }),
          content: languageProvider.getTranslatedText({
            'en': 'Are you sure you want to delete this schedule?',
            'id': 'Apakah Anda yakin ingin menghapus jadwal ini?',
          }),
          confirmText: languageProvider.getTranslatedText({
            'en': 'Delete',
            'id': 'Hapus',
          }),
          confirmColor: Colors.red,
        );
      },
    );

    if (confirmed == true) {
      final ok = await _controller.deleteSchedule(id);
      if (ok) {
        _showSuccessSnackBar('Schedule successfully deleted');
        _loadData(resetPage: true, useCache: false);
      } else {
        _showErrorSnackBar(
          ref.read(languageRiverpod).getTranslatedText({
            'en': 'Failed to delete schedule',
            'id': 'Gagal menghapus jadwal',
          }),
        );
      }
    }
  }

  /// Shows the conflict-resolution dialog if needed, then saves the schedule
  /// and reloads data. Dialog/navigation stays here; API work in controller.
  Future<void> _checkAndResolveConflicts(
    Map<String, dynamic> newScheduleData, {
    String? editingScheduleId,
  }) async {
    try {
      final saved = await _controller.checkAndResolveConflicts(
        context,
        newScheduleData,
        editingScheduleId: editingScheduleId,
      );
      if (saved) {
        _showSuccessSnackBar('Schedule successfully saved');
        _loadData(resetPage: true, useCache: false);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save schedule: $e');
      _loadData(resetPage: true, useCache: false);
    }
  }

  Color _getPrimaryColor() => _controller.getPrimaryColor();

  void _clearAllFilters() {
    setState(() {
      _selectedTeacherId = null;
      _selectedClassId = null;
      _selectedDayId = null;
      _selectedFilterSemester = null;
      _selectedJamPelajaran = null;
      _searchController.clear();
      _hasActiveFilter = false;
    });
    _loadData();
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    final List<Map<String, dynamic>> filterChips = [];

    // Add Day Filter Chip
    if (_selectedDayId != null) {
      final day = _availableDays.firstWhere(
        (d) => d['id'].toString() == _selectedDayId,
        orElse: () => {},
      );
      final String dayNameRaw = day.isNotEmpty
          ? (day['name'] ?? day['nama'] ?? '')
          : 'Day';

      // Localization helper for days
      final dayMap = {
        'senin': {'en': 'Monday', 'id': 'Senin'},
        'selasa': {'en': 'Tuesday', 'id': 'Selasa'},
        'rabu': {'en': 'Wednesday', 'id': 'Rabu'},
        'kamis': {'en': 'Thursday', 'id': 'Kamis'},
        'jumat': {'en': 'Friday', 'id': 'Jumat'},
        'jum\'at': {'en': 'Friday', 'id': 'Jumat'},
        'sabtu': {'en': 'Saturday', 'id': 'Sabtu'},
        'minggu': {'en': 'Sunday', 'id': 'Minggu'},
        'monday': {'en': 'Monday', 'id': 'Senin'},
        'tuesday': {'en': 'Tuesday', 'id': 'Selasa'},
        'wednesday': {'en': 'Wednesday', 'id': 'Rabu'},
        'thursday': {'en': 'Thursday', 'id': 'Kamis'},
        'friday': {'en': 'Friday', 'id': 'Jumat'},
        'saturday': {'en': 'Saturday', 'id': 'Sabtu'},
        'sunday': {'en': 'Sunday', 'id': 'Minggu'},
      };

      final normalizedKey = dayNameRaw.toLowerCase();
      final label = dayMap[normalizedKey] != null
          ? languageProvider.getTranslatedText(dayMap[normalizedKey]!)
          : dayNameRaw;

      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Day', 'id': 'Hari'})}: $label',
        'onRemove': () {
          setState(() {
            _selectedDayId = null;
            _hasActiveFilter = _controller.checkActiveFilter(
              selectedDayId: null,
              selectedClassId: _selectedClassId,
              selectedJamPelajaran: _selectedJamPelajaran,
              selectedFilterSemester: _selectedFilterSemester,
              selectedSemester: _selectedSemester,
            );
          });
          _loadData();
        },
      });
    }

    // Add Class Filter Chip
    if (_selectedClassId != null) {
      final cls = _availableClasses.firstWhere(
        (c) => c['id'].toString() == _selectedClassId,
        orElse: () => {},
      );
      final label = cls.isNotEmpty ? (cls['name'] ?? cls['nama']) : 'Class';
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'})}: $label',
        'onRemove': () {
          setState(() {
            _selectedClassId = null;
            _hasActiveFilter = _controller.checkActiveFilter(
              selectedDayId: _selectedDayId,
              selectedClassId: null,
              selectedJamPelajaran: _selectedJamPelajaran,
              selectedFilterSemester: _selectedFilterSemester,
              selectedSemester: _selectedSemester,
            );
          });
          _loadData();
        },
      });
    }

    // Add Semester Filter Chip
    if (_selectedFilterSemester != null &&
        _selectedFilterSemester != _selectedSemester) {
      final semester = _semesterList.firstWhere(
        (s) => s['id'].toString() == _selectedFilterSemester,
        orElse: () => {},
      );
      String semesterNameRaw = semester.isNotEmpty
          ? (semester['name'] ??
                semester['nama'] ??
                'Semester $_selectedFilterSemester')
          : 'Semester $_selectedFilterSemester';

      if (semester.isNotEmpty &&
          semester['academic_year'] != null &&
          semester['academic_year']['year'] != null) {
        semesterNameRaw += ' (${semester['academic_year']['year']})';
      }
      final label = semesterNameRaw;

      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Semester', 'id': 'Semester'})}: $label',
        'onRemove': () {
          setState(() {
            _selectedFilterSemester = null;
            _hasActiveFilter = _controller.checkActiveFilter(
              selectedDayId: _selectedDayId,
              selectedClassId: _selectedClassId,
              selectedJamPelajaran: _selectedJamPelajaran,
              selectedFilterSemester: null,
              selectedSemester: _selectedSemester,
            );
          });
          _loadData();
        },
      });
    }

    return filterChips;
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleFilterSheet(
        availableDays: _availableDays,
        availableClasses: _availableClasses,
        semesterList: _semesterList,
        lessonHourList: _lessonHourList,
        currentSemester: _selectedSemester,
        selectedDayId: _selectedDayId,
        selectedClassId: _selectedClassId,
        selectedFilterSemester: _selectedFilterSemester,
        selectedJamPelajaran: _selectedJamPelajaran,
        onApply: ({
          required String? dayId,
          required String? classId,
          required String? semester,
          required String? jamPelajaran,
        }) {
          setState(() {
            _selectedDayId = dayId;
            _selectedClassId = classId;
            _selectedFilterSemester = semester;
            _selectedJamPelajaran = jamPelajaran;
            _hasActiveFilter = _controller.checkActiveFilter(
              selectedDayId: dayId,
              selectedClassId: classId,
              selectedJamPelajaran: jamPelajaran,
              selectedFilterSemester: semester,
              selectedSemester: _selectedSemester,
            );
          });
          _loadData();
        },
      ),
    );
  }

  /// Delegates client-side filtering to the controller.
  List<dynamic> _getFilteredSchedules() {
    return _controller.getFilteredSchedules(
      scheduleList: _scheduleList,
      dayList: _dayList,
      searchText: _searchController.text,
      selectedTeacherId: _selectedTeacherId,
      selectedClassId: _selectedClassId,
      selectedDayId: _selectedDayId,
      selectedJamPelajaran: _selectedJamPelajaran,
    );
  }

  Widget _buildTableView() {
    if (_timetableDataSource == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ScheduleTableView(
      timetableDataSource: _timetableDataSource!,
      dayList: _dayList,
      classList: _classList,
      selectedClassId: _selectedClassId,
      gridData: _gridData,
      primaryColor: _getPrimaryColor(),
      languageProvider: ref.read(languageRiverpod),
      onExport: _exportToExcel,
      translateDay: _controller.translateDay,
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final filteredSchedules = _getFilteredSchedules();

    return Scaffold(
      backgroundColor: ColorUtils.lightGray,
      body: Column(
        children: [
          // Header
          GradientPageHeader(
            title: languageProvider.getTranslatedText({
              'en': 'Teaching Schedule',
              'id': 'Jadwal Mengajar',
            }),
            subtitle: languageProvider.getTranslatedText({
              'en': 'Manage teaching schedules',
              'id': 'Kelola jadwal mengajar',
            }),
            primaryColor: _getPrimaryColor(),
            onBackPressed: () => AppNavigator.pop(context),
            actionMenu: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showTableView = !_showTableView;
                      if (_showTableView) {
                        _loadData();
                      } else {
                        _loadData();
                      }
                    });
                  },
                  child: Container(
                    key: _viewToggleKey,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _showTableView ? Icons.view_list : Icons.table_chart,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                PopupMenuButton<String>(
                  key: _menuKey,
                  onSelected: (value) {
                    switch (value) {
                      case 'refresh':
                        _forceRefresh();
                        break;
                      case 'export':
                        _exportToExcel();
                        break;
                      case 'import':
                        _importFromExcel();
                        break;
                      case 'template':
                        _downloadTemplate();
                        break;
                    }
                  },
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.more_vert, color: Colors.white, size: 20),
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
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Refresh Data',
                              'id': 'Perbarui Data',
                            }),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(Icons.download, size: 20),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Export to Excel',
                              'id': 'Export ke Excel',
                            }),
                          ),
                        ],
                      ),
                    ),
                    if (!ref.read(academicYearRiverpod).isReadOnly)
                      PopupMenuItem<String>(
                        value: 'import',
                        child: Row(
                          children: [
                            Icon(Icons.upload, size: 20),
                            SizedBox(width: AppSpacing.sm),
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Import from Excel',
                                'id': 'Import dari Excel',
                              }),
                            ),
                          ],
                        ),
                      ),
                    PopupMenuItem<String>(
                      value: 'template',
                      child: Row(
                        children: [
                          Icon(Icons.file_download, size: 20),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Download Template',
                              'id': 'Download Template',
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            searchBar: Row(
              children: [
                Expanded(
                  child: Container(
                    key: _searchKey,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              hintText: languageProvider.getTranslatedText({
                                'en': 'Search schedules...',
                                'id': 'Cari jadwal...',
                              }),
                              hintStyle: TextStyle(color: Colors.grey),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.grey,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) {
                              if (_showTableView) {
                                setState(_updateGridData);
                              } else {
                                _loadData();
                              }
                            },
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.only(right: 4),
                          child: IconButton(
                            icon: Icon(Icons.search, color: _getPrimaryColor()),
                            onPressed: () {
                              if (_showTableView) {
                                setState(_updateGridData);
                              } else {
                                _loadData();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                // Filter Button
                Container(
                  key: _filterKey,
                  decoration: BoxDecoration(
                    color: _hasActiveFilter
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
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
                            padding: EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: Colors.red,
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
            filterChips: _hasActiveFilter
                ? SizedBox(
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
                                  margin: EdgeInsets.only(right: 6),
                                  child: Chip(
                                    label: Text(
                                      filter['label'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _getPrimaryColor(),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    deleteIcon: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: _getPrimaryColor(),
                                    ),
                                    onDeleted: filter['onRemove'],
                                    backgroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white,
                                      width: 0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    labelPadding: EdgeInsets.only(left: 4),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        InkWell(
                          onTap: _clearAllFilters,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Clear All',
                                'id': 'Hapus Semua',
                              }),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          Expanded(
            child: _isLoading
                ? SkeletonListLoading(
                    padding: EdgeInsets.only(top: 8, bottom: 80),
                  )
                : _showTableView
                ? _buildTableView()
                : filteredSchedules.isEmpty
                ? EmptyState(
                    title: languageProvider.getTranslatedText({
                      'en': 'No Schedules Found',
                      'id': 'Jadwal Tidak Ditemukan',
                    }),
                    subtitle: languageProvider.getTranslatedText({
                      'en': 'Try adjusting your filters',
                      'id': 'Coba sesuaikan filter Anda',
                    }),
                    icon: Icons.event_busy,
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await _loadData(resetPage: true, useCache: false);
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.only(top: 8, bottom: 80),
                      itemCount:
                          filteredSchedules.length + (_hasMoreData ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == filteredSchedules.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _getPrimaryColor(),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final schedule = filteredSchedules[index];
                        return _buildScheduleCard(schedule, index);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: ref.read(academicYearRiverpod).isReadOnly
          ? null
          : FloatingActionButton(
              key: _fabKey,
              onPressed: _addSchedule,
              backgroundColor: _getPrimaryColor(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.add, color: Colors.white, size: 20),
            ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule, int index) {
    final language = ref.read(languageRiverpod).currentLanguage;
    return AdminScheduleCard(
      schedule: schedule,
      index: index,
      isReadOnly: ref.read(academicYearRiverpod).isReadOnly,
      primaryColor: _getPrimaryColor(),
      dayLabel: _controller.formatScheduleDays(schedule, _dayList, language),
      timeLabel: _controller.formatTime(schedule),
      onTap: () => _showScheduleDetail(schedule),
      onEdit: () => _editSchedule(schedule),
      onDelete: () => _deleteSchedule(schedule['id']),
    );
  }

  void _showScheduleDetail(Map<String, dynamic> schedule) {
    showDialog(
      context: context,
      builder: (context) => ScheduleDetailDialog(
        schedule: schedule,
        primaryColor: _getPrimaryColor(),
        languageProvider: ref.read(languageRiverpod),
        isReadOnly: ref.read(academicYearRiverpod).isReadOnly,
        formatTime: _controller.formatTime,
        formatScheduleDays: (s, [p]) => _controller.formatScheduleDays(
          s,
          _dayList,
          (p ?? ref.read(languageRiverpod))!.currentLanguage,
        ),
        getGradeLevel: (id) => _controller.getGradeLevel(id, _classList),
        onEdit: _editSchedule,
      ),
    );
  }

  Future<void> _checkAndShowTour() async {
    if (_isTourShowing) return;
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'schedule_management',
        'admin',
      );

      // Only use cache (pre-fetched by dashboard), no API call
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isTourShowing) _showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('schedule', e);
    }
  }

  /// Marks the tour as completed in the backend and local cache, then hides it.
  void _completeTour() {
    setState(() => _isTourShowing = false);
    getIt<ApiTourService>().completeTour(
      name: 'teaching_schedule_management_tour',
      role: 'admin',
      platform: 'mobile',
    );
    LocalCacheService.save(
      CacheKeyBuilder.tourStatus('schedule_management', 'admin'),
      {'should_show': false},
    );
  }

  void _showTour() {
    final List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    setState(() => _isTourShowing = true);

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: ref.read(languageRiverpod).getTranslatedText({
        'en': 'SKIP',
        'id': 'LEWATI',
      }),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: _completeTour,
      onSkip: () {
        _completeTour();
        return true;
      },
      onClickOverlay: (_) {},
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    final List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    targets.add(
      TargetFocus(
        identify: "ScheduleViewToggle",
        keyTarget: _viewToggleKey,
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
                      'en': 'Switch View Mode',
                      'id': 'Ganti Mode Tampilan',
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
                            'Toggle between a list view or a comprehensive timetable grid view.',
                        'id':
                            'Beralih antara tampilan daftar atau tampilan grid jadwal yang komprehensif.',
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
        identify: "ScheduleMenu",
        keyTarget: _menuKey,
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
                      'en': 'Schedule Tools',
                      'id': 'Alat Jadwal',
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
                            'Export, import, or download schedule templates from this menu.',
                        'id':
                            'Ekspor, impor, atau unduh template jadwal dari menu ini.',
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
        identify: "ScheduleSearch",
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
                      'en': 'Search Schedule',
                      'id': 'Cari Jadwal',
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
                            'Find a specific teaching schedule by typing keywords here.',
                        'id':
                            'Temukan jadwal mengajar tertentu dengan mengetikkan kata kunci di sini.',
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
        identify: "ScheduleFilter",
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
                      'en': 'Apply Filters',
                      'id': 'Terapkan Filter',
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
                            'Filter schedules by teacher, class, day, or academic period.',
                        'id':
                            'Saring jadwal berdasarkan guru, kelas, hari, atau periode akademik.',
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
        identify: "AddSchedule",
        keyTarget: _fabKey,
        alignSkip: Alignment.topLeft,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Add New Schedule',
                      'id': 'Tambah Jadwal Baru',
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
                            'Click here to manually create a new schedule entry.',
                        'id':
                            'Klik di sini untuk membuat entri jadwal baru secara manual.',
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
