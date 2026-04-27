// Admin teaching-schedule management screen — full CRUD for Jadwal Mengajar.
//
// Refactored from the 7-mixin state-smuggling pattern
// (Tour + StateBridge + Data + Filter + Dialogs + Events + Actions) into a
// single flat [ConsumerState] that delegates data/Excel/CRUD work to
// [AdminScheduleController]. The bespoke gradient header, per-feature list
// builder, and coach-mark tour are retired in favor of the shared
// [AdminCrudScaffold] + [AdminDataMenu] + [PaginatedListView] stack.
//
// What lives here: UI flags (loading / error / filters / pagination cursor),
// the reference data lists (teachers, classes, days, semesters, academic
// years, lesson hours), and dispatch glue that hands state down to the
// controller + sheets. Everything else has moved out.
//
// Dual-view: a list (card) view and a matrix (timetable) view share one
// filter state. Toggle lives in the gradient-header trailing slot via the
// shared [ViewToggleButton]; matrix rendering delegates to
// [AdminScheduleMatrixView] which wraps [FrozenColumnTable].
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/action_confirm_sheet.dart';
import 'package:manajemensekolah/core/widgets/admin_crud_scaffold.dart';
import 'package:manajemensekolah/core/widgets/admin_data_menu.dart';
import 'package:manajemensekolah/core/widgets/paginated_list_view.dart';
import 'package:manajemensekolah/core/widgets/view_toggle_button.dart';
import 'package:manajemensekolah/features/dashboard/presentation/providers/academic_year_provider.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/admin_schedule_controller.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/admin_schedule_card.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/admin_schedule_matrix_view.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_detail_dialog.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_filter_sheet.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_form_dialog.dart';

/// Admin teaching-schedule management screen with full CRUD, search, filters,
/// and Excel import/export.
///
/// Name preserved — referenced from `cards_mixin.dart` and
/// `admin_menu_items_mixin.dart`.
class TeachingScheduleManagementScreen extends ConsumerStatefulWidget {
  const TeachingScheduleManagementScreen({super.key});

  @override
  TeachingScheduleManagementScreenState createState() =>
      TeachingScheduleManagementScreenState();
}

/// Mutable state for [TeachingScheduleManagementScreen].
///
/// Holds pagination cursor, filter selections, loaded data, and the
/// teacher + class + day + semester + academic-year + lesson-hour lookup
/// lists that populate the add/edit sheet and filter sheet.
class TeachingScheduleManagementScreenState
    extends ConsumerState<TeachingScheduleManagementScreen> {
  // Search — shared with [AdminCrudScaffold] via [searchController].
  final TextEditingController _searchController = TextEditingController();

  // Loaded schedule data (server-paginated).
  List<dynamic> _scheduleList = [];

  // Reference lists returned alongside schedules — used by the detail
  // dialog, form, and filter sheet.
  List<dynamic> _subjectList = [];
  List<dynamic> _classList = [];
  List<dynamic> _dayList = [];
  List<dynamic> _termList = [];
  List<dynamic> _lessonHourList = [];

  // Filter-option lists (sourced from FilterOptionsService; populate the
  // chip pickers in [ScheduleFilterSheet]).
  List<dynamic> _availableTeachers = [];
  List<dynamic> _availableClasses = [];
  List<dynamic> _availableDays = [];
  List<dynamic> _availableSemesters = [];
  List<dynamic> _availableAcademicYears = [];

  // UI flags.
  bool _isLoading = true;
  String? _errorMessage;

  // View mode — `false` renders the paginated card list, `true` renders the
  // [AdminScheduleMatrixView] timetable grid. Toggled from the header
  // trailing slot via [ViewToggleButton].
  bool _showMatrixView = false;

  // Pagination cursor.
  int _currentPage = 1;
  static const int _perPage = 10;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  // Academic-period selection. [_selectedTerm] tracks the current semester
  // (auto-resolved on first load); [_selectedAcademicYear] tracks the active
  // year and is kept in sync with [AcademicYearProvider].
  String _selectedTerm = '1';
  String _selectedAcademicYear = '2024/2025';

  // Filter selections (applied to the API query + client overlay).
  String? _selectedClassId;
  String? _selectedDayId;
  String? _selectedFilterTerm;
  String? _selectedLessonHour;
  bool _hasActiveFilter = false;

  // Cache bookkeeping — used by [buildScheduleCacheKey] to only persist
  // unfiltered first-page results.
  String? _lastCachedAcademicYear;
  String? _lastCachedTerm;

  // Search debounce — avoids spamming the API on every keystroke.
  Timer? _searchDebounce;

  // Provider listener — reacts to academic-year changes in the app-level
  // picker.
  AcademicYearProvider? _academicYearProvider;

  @override
  void initState() {
    super.initState();
    FCMService().syncTrigger.addListener(_onSyncTriggered);
    _academicYearProvider = ref.read(academicYearRiverpod);
    _academicYearProvider?.addListener(_onAcademicYearChanged);
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    FCMService().syncTrigger.removeListener(_onSyncTriggered);
    _academicYearProvider?.removeListener(_onAcademicYearChanged);
    super.dispose();
  }

  // ── Initialization ──────────────────────────────────────────────────

  Future<void> _initialize() async {
    // Seed the academic year from the global picker when available; fall back
    // to the API's "current" flag otherwise.
    final providerYear = _academicYearProvider?.selectedAcademicYear;
    if (providerYear != null) {
      _selectedAcademicYear = providerYear['id'].toString();
    }

    // Show stale cache immediately for instant paint, then hit the API.
    await _loadCachedScheduleData();
    await _loadFilterOptions();

    if (providerYear == null) {
      _setDefaultAcademicPeriod();
    }

    await _loadSchedules();
  }

  // ── Cache & filter-option warm-up ───────────────────────────────────

  Future<void> _loadCachedScheduleData() async {
    final ctrl = ref.read(adminScheduleControllerProvider);
    final result = await ctrl.loadCachedScheduleData();
    if (result == null || !mounted) return;
    setState(() {
      _scheduleList = result.scheduleList;
      _subjectList = result.subjectList;
      _classList = result.classList;
      _dayList = result.dayList;
      _termList = result.semesterList;
      _lessonHourList = result.lessonHourList;
      _hasMoreData = result.hasMoreData;
      _isLoading = result.isLoading;
      _lastCachedAcademicYear = _selectedAcademicYear;
      _lastCachedTerm = _selectedTerm;
    });
  }

  Future<void> _loadFilterOptions() async {
    final ctrl = ref.read(adminScheduleControllerProvider);
    final result = await ctrl.loadFilterOptions(
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

  void _setDefaultAcademicPeriod() {
    final ctrl = ref.read(adminScheduleControllerProvider);
    final year = ctrl.setDefaultAcademicPeriod(
      availableAcademicYears: _availableAcademicYears,
    );
    _selectedAcademicYear = year;
  }

  Future<void> _updateCurrentTerm() async {
    final ctrl = ref.read(adminScheduleControllerProvider);
    final newSemesterId = await ctrl.updateCurrentSemester(
      semesterList: _termList,
      currentSemesterId: _selectedTerm,
    );
    if (newSemesterId != null && mounted) {
      setState(() => _selectedTerm = newSemesterId);
      await _loadSchedules();
    }
  }

  // ── Data loading ────────────────────────────────────────────────────

  String? _buildCacheKey() {
    final ctrl = ref.read(adminScheduleControllerProvider);
    final key = ctrl.buildScheduleCacheKey(
      currentPage: _currentPage,
      showTableView: false,
      selectedAcademicYear: _selectedAcademicYear,
      selectedSemester: _selectedTerm,
      selectedTeacherId: null,
      selectedClassId: _selectedClassId,
      selectedDayId: _selectedDayId,
      selectedJamPelajaran: _selectedLessonHour,
      selectedFilterSemester: _selectedFilterTerm,
      searchText: _searchController.text,
      lastCachedAcademicYear: _lastCachedAcademicYear,
      lastCachedSemester: _lastCachedTerm,
    );
    if (key != null) {
      _lastCachedAcademicYear = _selectedAcademicYear;
      _lastCachedTerm = _selectedTerm;
    }
    return key;
  }

  Future<void> _loadSchedules({
    bool resetPage = true,
    bool useCache = true,
  }) async {
    if (resetPage) {
      _currentPage = 1;
      _hasMoreData = true;
      if (_scheduleList.isEmpty && mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
    }

    final ctrl = ref.read(adminScheduleControllerProvider);

    try {
      final result = await ctrl.loadData(
        showTableView: false,
        selectedSemester: _selectedTerm,
        selectedFilterSemester: _selectedFilterTerm,
        selectedAcademicYear: _selectedAcademicYear,
        selectedTeacherId: null,
        selectedClassId: _selectedClassId,
        selectedDayId: _selectedDayId,
        selectedJamPelajaran: _selectedLessonHour,
        searchText: _searchController.text,
        perPage: _perPage,
        availableDays: _availableDays,
        lastCachedAcademicYear: _lastCachedAcademicYear,
        lastCachedSemester: _lastCachedTerm,
        useCache: useCache,
      );

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _isLoading = false;
          if (_scheduleList.isEmpty) {
            _errorMessage = ref.read(languageRiverpod).getTranslatedText(const {
              'en': 'Failed to load schedules',
              'id': 'Gagal memuat jadwal',
            });
          }
        });
        return;
      }

      setState(() {
        _scheduleList = result.scheduleList;
        _subjectList = result.subjectList;
        _classList = result.classList;
        _dayList = result.dayList.isEmpty && _availableDays.isNotEmpty
            ? _availableDays
            : result.dayList;
        _termList = result.semesterList;
        _lessonHourList = result.lessonHourList;
        _hasMoreData = result.hasMoreData;
        _isLoading = false;
        _errorMessage = null;
      });

      ctrl.saveScheduleToCache(
        cacheKey: _buildCacheKey(),
        scheduleResponse: {'data': result.scheduleList},
        teacher: result.teacherList,
        subject: result.subjectList,
        classData: result.classList,
        days: result.dayList,
        semester: result.semesterList,
        lessonHours: result.lessonHourList,
      );

      if (_termList.isNotEmpty) {
        await _updateCurrentTerm();
      }
    } catch (e) {
      AppLogger.error('schedule', e);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_scheduleList.isEmpty) {
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
        }
      });
    }
  }

  Future<void> _loadMoreSchedules() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    final ctrl = ref.read(adminScheduleControllerProvider);
    final result = await ctrl.loadMoreData(
      nextPage: nextPage,
      perPage: _perPage,
      selectedSemester: _selectedTerm,
      selectedFilterSemester: _selectedFilterTerm,
      selectedAcademicYear: _selectedAcademicYear,
      selectedTeacherId: null,
      selectedClassId: _selectedClassId,
      selectedDayId: _selectedDayId,
      selectedJamPelajaran: _selectedLessonHour,
      searchText: _searchController.text,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() => _isLoadingMore = false);
      return;
    }

    setState(() {
      _currentPage = nextPage;
      _scheduleList = List<dynamic>.from(_scheduleList)
        ..addAll(result.newItems);
      _hasMoreData = result.hasMoreData;
      _isLoadingMore = false;
    });
  }

  Future<void> _onRefresh() => _loadSchedules(resetPage: true, useCache: false);

  Future<void> _forceRefresh() async {
    final ctrl = ref.read(adminScheduleControllerProvider);
    await ctrl.forceRefresh(
      cacheKey: _buildCacheKey(),
      selectedAcademicYear: _selectedAcademicYear,
    );
    if (!mounted) return;
    await _loadSchedules(resetPage: true, useCache: false);
  }

  void _onSyncTriggered() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger == null || !mounted) return;
    if (trigger['type'] == 'refresh_schedules') {
      AppLogger.debug(
        'schedule',
        'Real-time sync triggered (refresh_schedules): Reloading',
      );
      _loadSchedules(resetPage: true, useCache: false);
    }
  }

  void _onAcademicYearChanged() {
    if (!mounted) return;
    final providerYear = _academicYearProvider?.selectedAcademicYear;
    if (providerYear == null) return;
    setState(() => _selectedAcademicYear = providerYear['id'].toString());
    _loadFilterOptions();
    _loadSchedules(resetPage: true, useCache: true);
  }

  // ── Search ──────────────────────────────────────────────────────────

  void _onSearchChanged(String _) {
    _refreshHasActiveFilter();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _loadSchedules();
    });
  }

  // ── Filter state ────────────────────────────────────────────────────

  void _refreshHasActiveFilter() {
    setState(() {
      _hasActiveFilter = ref
          .read(adminScheduleControllerProvider)
          .checkActiveFilter(
            selectedDayId: _selectedDayId,
            selectedClassId: _selectedClassId,
            selectedJamPelajaran: _selectedLessonHour,
            selectedFilterSemester: _selectedFilterTerm,
            selectedSemester: _selectedTerm,
          );
    });
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleFilterSheet(
        availableDays: _availableDays,
        availableClasses: _availableClasses,
        semesterList: _termList,
        lessonHourList: _lessonHourList,
        currentSemester: _selectedTerm,
        selectedDayId: _selectedDayId,
        selectedClassId: _selectedClassId,
        selectedFilterSemester: _selectedFilterTerm,
        selectedJamPelajaran: _selectedLessonHour,
        onApply:
            ({
              required String? dayId,
              required String? classId,
              required String? semester,
              required String? lessonHour,
            }) {
              setState(() {
                _selectedDayId = dayId;
                _selectedClassId = classId;
                _selectedFilterTerm = semester;
                _selectedLessonHour = lessonHour;
              });
              _refreshHasActiveFilter();
              _loadSchedules();
            },
      ),
    );
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _selectedDayId = null;
      _selectedClassId = null;
      _selectedFilterTerm = null;
      _selectedLessonHour = null;
      _hasActiveFilter = false;
      _currentPage = 1;
    });
    _loadSchedules();
  }

  // Per-chip removal callbacks — each chip's × only removes that filter.
  void _removeDayFilter() {
    setState(() => _selectedDayId = null);
    _refreshHasActiveFilter();
    _loadSchedules();
  }

  void _removeClassFilter() {
    setState(() => _selectedClassId = null);
    _refreshHasActiveFilter();
    _loadSchedules();
  }

  void _removeSemesterFilter() {
    setState(() => _selectedFilterTerm = null);
    _refreshHasActiveFilter();
    _loadSchedules();
  }

  void _removeLessonHourFilter() {
    setState(() => _selectedLessonHour = null);
    _refreshHasActiveFilter();
    _loadSchedules();
  }

  // ── Row-level actions ───────────────────────────────────────────────

  void _showScheduleDetail(Map<String, dynamic> schedule) {
    final ctrl = ref.read(adminScheduleControllerProvider);
    showDialog(
      context: context,
      builder: (_) => ScheduleDetailDialog(
        schedule: schedule,
        primaryColor: ctrl.getPrimaryColor(),
        languageProvider: ref.read(languageRiverpod),
        isReadOnly: ref.read(academicYearRiverpod).isReadOnly,
        formatTime: ctrl.formatTime,
        formatScheduleDays: (s, [p]) {
          final LanguageProvider lp = p ?? ref.read(languageRiverpod);
          return ctrl.formatScheduleDays(s, _dayList, lp.currentLanguage);
        },
        getGradeLevel: (id) => ctrl.getGradeLevel(id, _classList),
        onEdit: (s) {
          Navigator.of(context).pop();
          _openAddEditSheet(schedule: s);
        },
      ),
    );
  }

  void _openAddEditSheet({dynamic schedule}) async {
    final ctrl = ref.read(adminScheduleControllerProvider);
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleFormDialog(
        teacherList: _availableTeachers,
        subjectList: _subjectList,
        classList: _availableClasses,
        dayList: _availableDays,
        semesterList: _availableSemesters,
        lessonHourList: _lessonHourList,
        semester: _selectedTerm,
        academicYear: _selectedAcademicYear,
        academicYearList: _availableAcademicYears,
        schedule: schedule,
        apiService: ctrl.apiService,
        apiTeacherService: ctrl.apiTeacherService,
      ),
    );
    if (result != null && mounted) {
      await _checkAndResolveConflicts(
        result,
        editingScheduleId: schedule?['id']?.toString(),
      );
    }
  }

  Future<void> _checkAndResolveConflicts(
    Map<String, dynamic> newScheduleData, {
    String? editingScheduleId,
  }) async {
    final ctrl = ref.read(adminScheduleControllerProvider);
    final lp = ref.read(languageRiverpod);
    try {
      final saved = await ctrl.checkAndResolveConflicts(
        context,
        newScheduleData,
        editingScheduleId: editingScheduleId,
      );
      if (!mounted) return;
      if (saved) {
        SnackBarUtils.showSuccess(
          context,
          lp.getTranslatedText(const {
            'en': 'Schedule successfully saved',
            'id': 'Jadwal berhasil disimpan',
          }),
        );
        await _loadSchedules(resetPage: true, useCache: false);
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        '${lp.getTranslatedText(const {'en': 'Failed to save schedule: ', 'id': 'Gagal menyimpan jadwal: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
      await _loadSchedules(resetPage: true, useCache: false);
    }
  }

  Future<void> _deleteSchedule(Map<String, dynamic> schedule) async {
    final ctrl = ref.read(adminScheduleControllerProvider);
    final lp = ref.read(languageRiverpod);

    final confirmed = await ActionConfirmSheet.show(
      context: context,
      title: lp.getTranslatedText(const {
        'en': 'Delete Schedule',
        'id': 'Hapus Jadwal',
      }),
      message: lp.getTranslatedText(const {
        'en': 'Are you sure you want to delete this schedule?',
        'id': 'Apakah Anda yakin ingin menghapus jadwal ini?',
      }),
      confirmText: lp.getTranslatedText(const {'en': 'Delete', 'id': 'Hapus'}),
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    final id = schedule['id']?.toString();
    if (id == null) return;
    final ok = await ctrl.deleteSchedule(id);

    if (!mounted) return;

    if (ok) {
      SnackBarUtils.showSuccess(
        context,
        lp.getTranslatedText(const {
          'en': 'Schedule successfully deleted',
          'id': 'Jadwal berhasil dihapus',
        }),
      );
      await _loadSchedules(resetPage: true, useCache: false);
    } else {
      SnackBarUtils.showError(
        context,
        lp.getTranslatedText(const {
          'en': 'Failed to delete schedule',
          'id': 'Gagal menghapus jadwal',
        }),
      );
    }
  }

  // ── Excel flows ─────────────────────────────────────────────────────

  Future<void> _exportToExcel() async {
    final ctrl = ref.read(adminScheduleControllerProvider);
    final lp = ref.read(languageRiverpod);
    try {
      await ctrl.exportToExcel(
        context: context,
        scheduleList: _scheduleList,
        dayList: _dayList,
        availableAcademicYears: _availableAcademicYears,
      );
    } catch (e) {
      AppLogger.error('schedule', e);
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        '${lp.getTranslatedText(const {'en': 'Export failed: ', 'id': 'Export gagal: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  Future<void> _importFromExcel() async {
    final ctrl = ref.read(adminScheduleControllerProvider);
    final lp = ref.read(languageRiverpod);
    try {
      setState(() => _isLoading = true);
      final imported = await ctrl.importFromExcel();
      if (!mounted) return;
      if (imported) {
        await _loadSchedules(resetPage: true, useCache: false);
        if (mounted) {
          SnackBarUtils.showInfo(
            context,
            lp.getTranslatedText(const {
              'en': 'Import successful',
              'id': 'Import berhasil',
            }),
          );
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger.error('schedule', e);
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackBarUtils.showError(
        context,
        '${lp.getTranslatedText(const {'en': 'Failed to import file: ', 'id': 'Gagal mengimpor berkas: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  Future<void> _downloadTemplate() async {
    final ctrl = ref.read(adminScheduleControllerProvider);
    final lp = ref.read(languageRiverpod);
    try {
      await ctrl.downloadTemplate(context);
    } catch (e) {
      AppLogger.error('schedule', e);
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        '${lp.getTranslatedText(const {'en': 'Download template failed: ', 'id': 'Gagal download template: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    final academicYear = ref.watch(academicYearRiverpod);
    final ctrl = ref.read(adminScheduleControllerProvider);
    final primaryColor = ctrl.getPrimaryColor();

    // Client-side overlay: the server slice already respects the filter
    // chips, so we only apply search here. Kept to mirror the prior
    // behaviour (the controller's filter helper also tolerates class/day/
    // lesson-hour filters client-side for cached-data edge cases).
    final filteredSchedules = ctrl.getFilteredSchedules(
      scheduleList: _scheduleList,
      dayList: _dayList,
      searchText: _searchController.text,
      selectedTeacherId: null,
      selectedClassId: _selectedClassId,
      selectedDayId: _selectedDayId,
      selectedJamPelajaran: _selectedLessonHour,
    );

    final activeFilters = ctrl.buildActiveFilterChips(
      selectedDayId: _selectedDayId,
      selectedClassId: _selectedClassId,
      selectedFilterTerm: _selectedFilterTerm,
      selectedLessonHour: _selectedLessonHour,
      selectedTerm: _selectedTerm,
      availableDays: _availableDays,
      availableClasses: _availableClasses,
      termList: _termList,
      languageProvider: lang,
      onClearDay: _removeDayFilter,
      onClearClass: _removeClassFilter,
      onClearSemester: _removeSemesterFilter,
      onClearLessonHour: _removeLessonHourFilter,
    );

    return AdminCrudScaffold(
      title: lang.getTranslatedText(const {
        'en': 'Teaching Schedule',
        'id': 'Jadwal Mengajar',
      }),
      subtitle: lang.getTranslatedText(const {
        'en': 'Manage teaching schedules',
        'id': 'Kelola jadwal mengajar',
      }),
      primaryColor: primaryColor,
      searchController: _searchController,
      searchHint: lang.getTranslatedText(const {
        'en': 'Search schedules...',
        'id': 'Cari jadwal...',
      }),
      onSearchChanged: _onSearchChanged,
      onSearchSubmitted: (_) => _loadSchedules(),
      onFilterTap: _openFilterSheet,
      hasActiveFilter: _hasActiveFilter,
      activeFilters: activeFilters,
      onClearAllFilters: _clearAllFilters,
      actionMenu: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ViewToggleButton(
            currentMode: _showMatrixView ? ViewMode.table : ViewMode.card,
            availableModes: const [ViewMode.card, ViewMode.table],
            onChanged: (mode) =>
                setState(() => _showMatrixView = mode == ViewMode.table),
          ),
          const SizedBox(width: 8),
          AdminDataMenu(
            languageProvider: lang,
            onRefresh: _forceRefresh,
            onExport: _exportToExcel,
            onImport: academicYear.isReadOnly ? null : _importFromExcel,
            onDownloadTemplate: _downloadTemplate,
          ),
        ],
      ),
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      // Matrix mode always renders (even with 0 schedules) so the time-slot
      // grid stays visible and the toggle isn't swallowed by an empty state.
      // Card mode keeps the existing empty-state behaviour.
      isEmpty: !_showMatrixView && filteredSchedules.isEmpty,
      onRefresh: _onRefresh,
      emptyTitle: lang.getTranslatedText(const {
        'en': 'No schedules',
        'id': 'Tidak ada jadwal',
      }),
      emptySubtitle: _searchController.text.isEmpty && !_hasActiveFilter
          ? lang.getTranslatedText(const {
              'en': 'Tap + to add a schedule',
              'id': 'Tap + untuk menambah jadwal',
            })
          : lang.getTranslatedText(const {
              'en': 'No search results found',
              'id': 'Tidak ditemukan hasil pencarian',
            }),
      emptyIcon: Icons.calendar_today_outlined,
      childBuilder: () => _showMatrixView
          ? AdminScheduleMatrixView(
              scheduleList: filteredSchedules,
              dayList: _dayList.isNotEmpty ? _dayList : _availableDays,
              lessonHourList: _lessonHourList,
              selectedDayId: _selectedDayId,
              selectedLessonHour: _selectedLessonHour,
              primaryColor: primaryColor,
              languageProvider: lang,
              onScheduleTap: _showScheduleDetail,
            )
          : PaginatedListView<dynamic>(
              items: filteredSchedules,
              itemBuilder: (context, schedule, index) {
                final scheduleMap = Map<String, dynamic>.from(schedule as Map);
                return AdminScheduleCard(
                  schedule: scheduleMap,
                  index: index,
                  isReadOnly: academicYear.isReadOnly,
                  primaryColor: primaryColor,
                  dayLabel: ctrl.formatScheduleDays(
                    scheduleMap,
                    _dayList,
                    lang.currentLanguage,
                  ),
                  timeLabel: ctrl.formatTime(scheduleMap),
                  onTap: () => _showScheduleDetail(scheduleMap),
                  onEdit: () => _openAddEditSheet(schedule: scheduleMap),
                  onDelete: () => _deleteSchedule(scheduleMap),
                );
              },
              onLoadMore: _loadMoreSchedules,
              hasMore: _hasMoreData,
              isLoadingMore: _isLoadingMore,
              padding: const EdgeInsets.only(top: 8, bottom: 16),
            ),
      onFabTap: () => _openAddEditSheet(),
      fabIcon: Icons.add,
      hideFab: academicYear.isReadOnly,
    );
  }
}

/// Backwards-compat alias — legacy code and tests may still reference the
/// long-form screen-state name. The mutable state class name was preserved
/// during the refactor so no callers need to change.
///
/// (No alias needed: [TeachingScheduleManagementScreenState] is already the
/// public state type.)
