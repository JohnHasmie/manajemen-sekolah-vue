// Admin teaching-schedule management screen — full CRUD for Jadwal Mengajar.
//
// Refactored from the 7-mixin state-smuggling pattern
// (Tour + StateBridge + Data + Filter + Dialogs + Events + Actions) into a
// single flat [ConsumerState] that delegates data/Excel/CRUD work to
// [AdminScheduleController]. The bespoke gradient header, per-feature list
// builder, and coach-mark tour are retired.
//
// TR.A.1 — migrated from [AdminCrudScaffold] to the shared
// [BrandPageLayout] + [BrandPageHeader] + [BrandKpiStrip] chrome with a
// 3-tab view toggle (Grid · List · Matrix). The KPI strip overlaps the
// header gradient and tracks `total / today / conflicts` from the
// `/teaching-schedule/stats` endpoint. Grid mode is a placeholder until
// the week-calendar widget lands in TR.A.2.
//
// What lives here: UI flags (loading / error / filters / pagination cursor),
// the reference data lists (teachers, classes, days, semesters, academic
// years, lesson hours), the [ScheduleKpiSummary] snapshot for the KPI
// strip, and dispatch glue that hands state down to the controller +
// sheets. Everything else has moved out.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/mixins/admin_academic_year_reload_mixin.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/action_confirm_sheet.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_kpi_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/core/widgets/bulk_action_bar.dart';
import 'package:manajemensekolah/core/widgets/bulk_delete_confirm_dialog.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule_kpi_summary.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/admin_schedule_controller.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/admin_schedule_detail_sheet.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/bulk_action_pickers.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/admin_schedule_matrix_view.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/admin_schedule_row_card.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/admin_schedule_skeleton.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/slot_cluster_sheet.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/admin_schedule_week_grid_view.dart';
import 'package:manajemensekolah/features/schedule/exports/schedule_print_pdf_service.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_filter_sheet.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_reschedule_banner.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_form_dialog.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_print_scope_sheet.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/single_reschedule_sheet.dart';

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
    extends ConsumerState<TeachingScheduleManagementScreen>
    with AdminAcademicYearReloadMixin<TeachingScheduleManagementScreen> {
  // Search controller — kept as an always-empty backing field so the
  // existing cache-key + load helpers continue to work after TR.E
  // removed the visible search bar from the hub. Filtering is now
  // performed entirely via the brand filter chips + filter sheet.
  final TextEditingController _searchController = TextEditingController();

  // Loaded schedule data (server-paginated).
  List<dynamic> _scheduleList = [];

  // Reference lists returned alongside schedules — used by the detail
  // dialog, form, and filter sheet.
  List<dynamic> _subjectList = [];
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

  // Drag-and-drop reschedule banner state (TR.E creative loading).
  // Set inside [_doReschedule] before the PATCH races the network so
  // the admin sees a shimmering "Memindahkan…" pill while the request
  // is in flight, then flips to success/error before auto-dismissing.
  // Null when no reschedule is currently visible.
  ScheduleRescheduleSnapshot? _rescheduleBanner;
  Timer? _rescheduleBannerTimer;

  // View mode — drives which body widget renders.
  //   * grid   → week calendar grid (TR.A.2 — placeholder for now)
  //   * list   → paginated card list
  //   * matrix → AdminScheduleMatrixView timetable grid
  // Toggled from the 3-tab strip inside the body.
  ScheduleViewMode _viewMode = ScheduleViewMode.list;

  // Backend-driven KPI snapshot (Total / Today / Conflicts). Populated by
  // _loadKpiSummary() which hits /teaching-schedule/stats. Defaults to
  // an empty snapshot so the strip renders zeros before the first fetch
  // completes instead of flickering.
  ScheduleKpiSummary _kpi = const ScheduleKpiSummary.empty();

  // Client-side day filter for the List view's day-tab pill row.
  // `null` = show all days (default). Independent from [_selectedDayId]
  // which lives in the filter sheet and drives the server-side query.
  String? _activeDayTab;

  // Grid view's "zoom-in" focused day_id. `null` = show full 6-day
  // week view. When set, the grid renders a single full-width day
  // column with a pill-tab strip for navigation + horizontal swipe
  // between days. Defaults to today's day_id on first load so the
  // admin lands on a readable single-day view; the zoom-out chevron
  // in the strip clears it back to the week view.
  String? _focusedDayId;
  bool _focusedDaySeeded = false;

  // Pagination is removed — the admin Jadwal hub loads every row in one
  // request so the Grid view can render a complete week-calendar and
  // the bulk-select handlers can operate over the full set. [_perPage]
  // is intentionally large; 2000 covers the typical school (21 classes
  // × 9 subjects × 6 days × ~8 hours). Larger schools that outgrow this
  // can switch the loader to ApiScheduleService.getAllSchedules.
  static const int _perPage = 2000;

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
  // Teacher filter hits the server (backend already supports
  // ?teacher_id=…). Subject filter is overlaid client-side because the
  // teaching-schedule index endpoint doesn't accept subject_id today;
  // since admin Jadwal pulls every row in one batch (perPage=2000) the
  // overlay is cheap and avoids a backend round-trip just to surface
  // the chip.
  String? _selectedTeacherId;
  String? _selectedSubjectId;
  bool _hasActiveFilter = false;

  // Bulk-select state.
  final Set<String> _selectedIds = <String>{};
  bool get _bulkMode => _selectedIds.isNotEmpty;

  // Cache bookkeeping — used by [buildScheduleCacheKey] to only persist
  // unfiltered first-page results.
  String? _lastCachedAcademicYear;
  String? _lastCachedTerm;

  @override
  void initState() {
    super.initState();
    FCMService().syncTrigger.addListener(_onSyncTriggered);
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _rescheduleBannerTimer?.cancel();
    FCMService().syncTrigger.removeListener(_onSyncTriggered);
    super.dispose();
  }

  // ── Initialization ──────────────────────────────────────────────────

  Future<void> _initialize() async {
    // Seed the academic year from the global picker when available; fall back
    // to the API's "current" flag otherwise.
    final providerYear = ref.read(academicYearRiverpod).selectedAcademicYear;
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
    // KPI summary is independent of the paginated list — fire it after
    // the first list-load so the strip's "Total / Hari Ini / Bentrok"
    // values surface as the data settles. Errors are swallowed inside
    // the service (returns the empty snapshot), so failures don't block
    // the rest of the UI.
    unawaited(_loadKpiSummary());
  }

  /// Pulls the KPI snapshot (Total · Hari Ini · Bentrok) from
  /// `GET /teaching-schedule/stats`. Scoped by the currently-selected
  /// semester + academic year so the numbers match the visible filter
  /// state. Called from [_initialize] on first load and from
  /// [_onRefresh] / [_forceRefresh] so the KPI tracks the list.
  Future<void> _loadKpiSummary() async {
    final summary = await getIt<ApiScheduleService>().fetchKpiSummary(
      semesterId: _selectedTerm,
      academicYearId: _selectedAcademicYear,
    );
    if (!mounted) return;
    setState(() => _kpi = summary);
  }

  // ── Cache & filter-option warm-up ───────────────────────────────────

  Future<void> _loadCachedScheduleData() async {
    final ctrl = ref.read(adminScheduleControllerProvider);
    final result = await ctrl.loadCachedScheduleData();
    if (result == null || !mounted) return;
    _normalizeScheduleRows(result.scheduleList);
    setState(() {
      _scheduleList = result.scheduleList;
      _subjectList = result.subjectList;
      _dayList = result.dayList;
      _termList = result.semesterList;
      _lessonHourList = result.lessonHourList;
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
      currentPage: 1,
      showTableView: false,
      selectedAcademicYear: _selectedAcademicYear,
      selectedSemester: _selectedTerm,
      selectedTeacherId: _selectedTeacherId,
      selectedSubjectId: _selectedSubjectId,
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
    // [resetPage] is retained for call-site compat — pagination is
    // removed, so we always show the skeleton on a fresh load when the
    // list is empty.
    if (resetPage && _scheduleList.isEmpty && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final ctrl = ref.read(adminScheduleControllerProvider);

    try {
      final result = await ctrl.loadData(
        showTableView: false,
        selectedSemester: _selectedTerm,
        selectedFilterSemester: _selectedFilterTerm,
        selectedAcademicYear: _selectedAcademicYear,
        selectedTeacherId: _selectedTeacherId,
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

      _normalizeScheduleRows(result.scheduleList);

      setState(() {
        _scheduleList = result.scheduleList;
        _subjectList = result.subjectList;
        _dayList = result.dayList.isEmpty && _availableDays.isNotEmpty
            ? _availableDays
            : result.dayList;
        _termList = result.semesterList;
        _lessonHourList = result.lessonHourList;
        _isLoading = false;
        _errorMessage = null;
        // First time we have day data: open the Grid view zoomed in
        // on today (subsequent reloads keep the admin's current pick).
        _maybeSeedFocusedDay();
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

  /// Flattens nested `lesson_hour` relations onto each schedule row so
  /// downstream widgets can read `start_time`, `end_time`, `day_id`,
  /// `day_name`, and `lesson_hour_days_id` directly without crawling the
  /// nested API shape.
  ///
  /// The backend eagerly loads `lesson_hour` as a Map of
  ///   `{ id, start_time, end_time, hour_number, day: {id, name, order_number} }`
  /// which means a naive `row['start_time']` returns null and a row card's
  /// time column renders as "-- --" (issue surfaced in TR.E.2 verify).
  ///
  /// Mutates rows in place. Safe to call on already-normalized rows —
  /// `??=` and the `is Map` guards skip writes when fields are present.
  /// After normalization, `row['lesson_hour']` holds the int hour number
  /// instead of the original Map; callers that needed the slot UUID
  /// should read `row['lesson_hour_days_id']`.
  void _normalizeScheduleRows(List<dynamic> rows) {
    for (final raw in rows) {
      if (raw is! Map) continue;
      final m = raw as Map<String, dynamic>;
      final lh = m['lesson_hour'];
      if (lh is Map) {
        m['start_time'] ??= lh['start_time'] ?? lh['jam_mulai'];
        m['end_time'] ??= lh['end_time'] ?? lh['jam_selesai'];
        m['lesson_hour_days_id'] ??= lh['id'];
        // Day was eagerly loaded under lesson_hour.day in the
        // teaching-schedule index response — surface it as the flat
        // day_id / day_name so day-tab + grouping reads work without
        // a second join lookup.
        final lhDay = lh['day'] ?? lh['hari'];
        if (lhDay is Map) {
          m['day_id'] ??= lhDay['id'];
          m['day_name'] ??= lhDay['name'] ?? lhDay['nama'];
        }
        // Replace the nested Map with the int hour number so the
        // detail sheet's "Jam Ke-" tile renders "1" instead of the
        // raw `{id: ..., start_time: ..., ...}` blob.
        m['lesson_hour'] = lh['hour_number'] ?? lh['jam_ke'];
      }
      m['start_time'] ??= m['jam_mulai'];
      m['end_time'] ??= m['jam_selesai'];
    }
  }

  Future<void> _onRefresh() async {
    await _loadSchedules(resetPage: true, useCache: false);
    unawaited(_loadKpiSummary());
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

  @override
  void onAcademicYearChanged() {
    if (!mounted) return;
    final providerYear = ref.read(academicYearRiverpod).selectedAcademicYear;
    if (providerYear == null) return;
    setState(() {
      _selectedAcademicYear = providerYear['id'].toString();
      // Clear any teacher / subject narrowing — the picked entities may not
      // exist (or may carry different IDs) under the new year. Other
      // dimensions (Hari, Jam Pelajaran) are AY-stable so they can stay.
      _selectedTeacherId = null;
      _selectedSubjectId = null;
      _selectedClassId = null;
    });
    _refreshHasActiveFilter();
    _loadFilterOptions();
    _loadSchedules(resetPage: true, useCache: true);
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
            selectedTeacherId: _selectedTeacherId,
            selectedSubjectId: _selectedSubjectId,
          );
    });
  }

  void _openFilterSheet() {
    // Resolve a human-readable label for the active academic year (e.g.
    // "2024/2025") so the filter sheet can show it in its header subtitle.
    // The year picker itself lives in the app shell — the sheet only
    // surfaces it as context, not as an editable field.
    final yearLabel =
        _availableAcademicYears
            .cast<Map<String, dynamic>>()
            .firstWhere(
              (y) => y['id']?.toString() == _selectedAcademicYear,
              orElse: () => const {'year': null, 'name': null},
            )['year']
            ?.toString() ??
        _availableAcademicYears
            .cast<Map<String, dynamic>>()
            .firstWhere(
              (y) => y['id']?.toString() == _selectedAcademicYear,
              orElse: () => const {'year': null, 'name': null},
            )['name']
            ?.toString() ??
        '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleFilterSheet(
        availableDays: _availableDays,
        availableClasses: _availableClasses,
        availableTeachers: _availableTeachers,
        availableSubjects: _subjectList,
        semesterList: _termList,
        lessonHourList: _lessonHourList,
        currentSemester: _selectedTerm,
        scheduleList: _scheduleList,
        selectedDayId: _selectedDayId,
        selectedClassId: _selectedClassId,
        selectedTeacherId: _selectedTeacherId,
        selectedSubjectId: _selectedSubjectId,
        selectedFilterSemester: _selectedFilterTerm,
        selectedJamPelajaran: _selectedLessonHour,
        activeAcademicYearLabel: yearLabel.isEmpty ? null : yearLabel,
        onApply:
            ({
              required String? dayId,
              required String? classId,
              required String? teacherId,
              required String? subjectId,
              required String? semester,
              required String? lessonHour,
            }) {
              setState(() {
                _selectedDayId = dayId;
                _selectedClassId = classId;
                _selectedTeacherId = teacherId;
                _selectedSubjectId = subjectId;
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
      _selectedTeacherId = null;
      _selectedSubjectId = null;
      _hasActiveFilter = false;
    });
    _loadSchedules();
  }

  // ── Row-level actions ───────────────────────────────────────────────

  void _showScheduleDetail(Map<String, dynamic> schedule) {
    showAdminScheduleDetailSheet(
      context: context,
      schedule: schedule,
      controller: ref.read(adminScheduleControllerProvider),
      lang: ref.read(languageRiverpod),
      dayList: _dayList,
      isReadOnly: ref.read(academicYearRiverpod).isReadOnly,
      onEdit: () => _openAddEditSheet(schedule: schedule),
      onDelete: () => _deleteSchedule(schedule),
      onDuplicate: () => _duplicateSchedule(schedule),
      onMoveSlot: () => _moveSlotForSchedule(schedule),
      onChangeTeacher: () => _changeTeacherForSchedule(schedule),
    );
  }

  /// Opens the add/edit sheet pre-filled with [schedule]'s teacher /
  /// subject / class / semester / academic_year, but without the `id`
  /// — saving creates a NEW row. The admin picks a fresh slot from
  /// the day + lesson_hour pickers inside the form.
  ///
  /// Triggered by the "Duplikat" action tile in the Frame C detail
  /// sheet. Used for quickly cloning a popular session across multiple
  /// classes / days without retyping all the fields.
  void _duplicateSchedule(Map<String, dynamic> schedule) {
    final clone = Map<String, dynamic>.from(schedule);
    // Strip identity + slot — admin re-picks the slot on save.
    clone.remove('id');
    clone.remove('lesson_hour_days_id');
    clone.remove('lesson_hour');
    clone.remove('start_time');
    clone.remove('end_time');
    clone.remove('day_id');
    clone.remove('day_name');
    _openAddEditSheet(schedule: clone);
  }

  /// "Pindah Slot" handler — opens the day picker and bulk-moves this
  /// single row to the equivalent lesson_hour on the target day.
  ///
  /// Reuses [showBulkDayPickerSheet] + [ApiScheduleService.bulkMoveSessions]
  /// with a one-element id list so the List view's per-row Pindah Slot
  /// single row to the target day AND hour.
  ///
  /// Reuses [_doReschedule] so it has the same UX as drag-and-drop
  /// (including the "Urungkan" action and "Paksa Simpan" conflict toast).
  Future<void> _moveSlotForSchedule(Map<String, dynamic> schedule) async {
    final id = schedule['id']?.toString();
    if (id == null || id.isEmpty) return;

    final visibleDays = _visibleListDays();
    final targetLessonHourDaysId = await showSingleRescheduleSheet(
      context: context,
      schedule: schedule,
      days: visibleDays,
      lessonHours: _lessonHourList,
      semesterId: _selectedTerm,
      academicYearId: _selectedAcademicYear,
      languageProvider: ref.read(languageRiverpod),
    );

    if (targetLessonHourDaysId == null || !mounted) return;

    // The sheet returns the specific lesson_hour_days_id. We need to
    // find the corresponding day name and start time for the success toast.
    final targetHourData = _lessonHourList.firstWhere(
      (h) => h['id']?.toString() == targetLessonHourDaysId,
      orElse: () => const <String, dynamic>{},
    );

    final targetDayId =
        targetHourData['day_id']?.toString() ??
        targetHourData['hari_id']?.toString();
    final dayName =
        visibleDays
            .firstWhere(
              (d) => d['id']?.toString() == targetDayId,
              orElse: () => const {'name': ''},
            )['name']
            ?.toString() ??
        '';

    final startTime =
        (targetHourData['start_time'] ?? targetHourData['jam_mulai'] ?? '')
            .toString();

    final previousLessonHourId =
        schedule['lesson_hour_days_id']?.toString() ?? '';
    final previousDayName =
        visibleDays
            .firstWhere(
              (d) => d['id']?.toString() == schedule['day_id']?.toString(),
              orElse: () => const {'name': ''},
            )['name']
            ?.toString() ??
        '';
    final previousStartTime = (schedule['start_time'] ?? '').toString();

    final subjectName =
        (schedule['subject_name'] ?? schedule['mata_pelajaran_nama'] ?? '—')
            .toString();

    await _doReschedule(
      scheduleId: id,
      targetLessonHourId: targetLessonHourDaysId,
      targetDayName: dayName,
      targetStartTime: startTime,
      subjectName: subjectName,
      previousLessonHourId: previousLessonHourId,
      previousDayName: previousDayName,
      previousStartTime: previousStartTime,
      force: false,
    );
  }

  /// "Ganti Guru" per-row handler — opens the teacher picker and
  /// reassigns this single row to the selected teacher. Mirrors the
  /// bulk flow with a single id.
  Future<void> _changeTeacherForSchedule(Map<String, dynamic> schedule) async {
    final id = schedule['id']?.toString();
    if (id == null || id.isEmpty) return;
    final teachers = _availableTeachers
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    final teacherId = await showBulkTeacherPickerSheet(
      context: context,
      teachers: teachers,
      selectedCount: 1,
    );
    if (teacherId == null || !mounted) return;
    final teacherName =
        teachers
            .firstWhere(
              (t) => t['id']?.toString() == teacherId,
              orElse: () => const {'name': ''},
            )['name']
            ?.toString() ??
        '';
    await _runBulkChangeTeacher(
      ids: [id],
      teacherId: teacherId,
      teacherName: teacherName,
      force: false,
    );
  }

  // ── Density mode (Frame I — 6+ sessions per slot) ───────────────────

  /// Opens the [SlotClusterSheet] for a tapped cluster card.
  ///
  /// The sheet lists every session at this slot with search + filter
  /// tabs (Semua / Bentrok / per-mapel). From any row the admin can
  /// jump into the per-row detail sheet (which carries Edit, Pindah,
  /// Ganti Guru, Duplikat, Hapus). The footer's "Tambah di slot ini"
  /// CTA seeds the add form with the slot's day + lesson_hour so the
  /// admin can extend the cluster without rebuilding the pickers.
  ///
  /// Reads the slot context from the first session in [sessions] —
  /// every session in a cluster shares `day_id`, `day_name`, and the
  /// `start_time` / `end_time` window by construction.
  Future<void> _openSlotClusterSheet(
    List<Map<String, dynamic>> sessions,
  ) async {
    if (sessions.isEmpty) return;
    final first = sessions.first;
    final dayName = (first['day_name'] ?? '').toString();
    final startTime = (first['start_time'] ?? '').toString();
    final endTime = (first['end_time'] ?? '').toString();

    final changed = await showSlotClusterSheet(
      context: context,
      sessions: sessions,
      dayName: dayName,
      startTime: startTime,
      endTime: endTime,
      onOpenDetail: _showScheduleDetail,
      onMoveSession: _moveSlotForSchedule,
      onAddInSlot: () {
        // Seed the add form with this slot's day_id + lesson_hour_days_id
        // so the admin doesn't have to pick them again.
        _openAddEditSheet(
          schedule: {
            'day_id': first['day_id'],
            'day_name': first['day_name'],
            'lesson_hour_days_id': first['lesson_hour_days_id'],
            'lesson_hour': first['lesson_hour'],
            'start_time': first['start_time'],
            'end_time': first['end_time'],
          },
        );
      },
    );
    if (changed == true && mounted) {
      // Sheet reported a mutation — refresh the list + KPI strip so the
      // grid re-paints with the new cluster size.
      await _loadSchedules(resetPage: true, useCache: false);
      unawaited(_loadKpiSummary());
    }
  }

  /// Long-press handler on a cluster card — seeds [_selectedIds] with
  /// every session in the cluster and flips the screen into bulk-mode.
  /// The existing BulkActionBar then exposes Pindah Hari / Ganti Guru /
  /// Hapus over the entire cluster in one shot ("move every 10:00 to
  /// Tuesday" in two taps).
  void _selectClusterForBulk(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return;
    setState(() {
      for (final s in sessions) {
        final id = s['id']?.toString();
        if (id != null && id.isNotEmpty) _selectedIds.add(id);
      }
    });
  }

  // ── Drag-and-drop reschedule (Frame E.1 + E.2) ──────────────────────

  /// Drag-and-drop reschedule entry point — wired into the grid view's
  /// [AdminScheduleWeekGridView.onReschedule] callback. Fires when an
  /// admin long-press-drags a session block onto a different day/slot
  /// in the week-grid view.
  ///
  /// Looks up the previous + new day names for nicer toast copy and
  /// delegates to [_doReschedule]. The schedule map is the original
  /// (pre-move) API row passed via the drag payload — used to capture
  /// the rollback slot for Urungkan (TR.E.2).
  Future<void> _handleReschedule({
    required Map<String, dynamic> schedule,
    required String newLessonHourDaysId,
    required String newDayId,
    required String newStartTime,
  }) async {
    final scheduleId = schedule['id']?.toString();
    if (scheduleId == null || scheduleId.isEmpty) return;

    String resolveDayName(String? id) {
      if (id == null || id.isEmpty) return '';
      return _availableDays
              .cast<Map<String, dynamic>>()
              .firstWhere(
                (d) => d['id']?.toString() == id,
                orElse: () => const {'name': ''},
              )['name']
              ?.toString() ??
          '';
    }

    final newDayName = resolveDayName(newDayId);
    final previousLessonHourId =
        schedule['lesson_hour_days_id']?.toString() ?? '';
    final previousDayName = resolveDayName(schedule['day_id']?.toString());
    final previousStartTime = (schedule['start_time'] ?? '').toString();
    final subjectName =
        (schedule['subject_name'] ?? schedule['mata_pelajaran_nama'] ?? '—')
            .toString();

    await _doReschedule(
      scheduleId: scheduleId,
      targetLessonHourId: newLessonHourDaysId,
      targetDayName: newDayName,
      targetStartTime: newStartTime,
      subjectName: subjectName,
      previousLessonHourId: previousLessonHourId,
      previousDayName: previousDayName,
      previousStartTime: previousStartTime,
      force: false,
    );
  }

  /// Internal reschedule worker — issues the PATCH and surfaces the
  /// appropriate toast for the outcome.
  ///
  /// Three terminal states:
  ///   * **Success** → green snack with the target slot and an
  ///     "URUNGKAN" action that calls back into this method with the
  ///     target / previous slot ids swapped (and `force: true`, so the
  ///     rollback can't be blocked by another row racing in).
  ///   * **409 conflict** → red snack with the server's `error` body
  ///     and a "PAKSA SIMPAN" action that retries the same drop with
  ///     `force: true`. Server-side force=true accepts the duplicate
  ///     and lets the admin clean up after.
  ///   * **Any other error** → plain red snack via [SnackBarUtils.showError].
  ///
  /// `previousLessonHourId` is allowed to be empty (and the Urungkan
  /// action is then suppressed) for callers that don't have access to
  /// a rollback slot — e.g. an admin who refreshes the list mid-undo.
  /// Pulls the most actionable error string out of a [DioException].
  ///
  /// Priority: 409 conflict's `conflicts[].message` (says which side
  /// is blocked) → top-level `error` → top-level `message` → null.
  /// Used by the banner to show a short reason without re-implementing
  /// the same extraction inside the catch block below.
  String? _extractServerMessage(DioException e) {
    final body = e.response?.data;
    if (body is! Map) return null;
    if (e.response?.statusCode == 409 && body['conflicts'] is List) {
      for (final c in body['conflicts'] as List) {
        if (c is Map && c['message'] is String) {
          return c['message'] as String;
        }
      }
    }
    if (body['error'] is String) return body['error'] as String;
    if (body['message'] is String) return body['message'] as String;
    return null;
  }

  /// Sets the floating reschedule banner state and (optionally)
  /// auto-dismisses it after [autoDismiss]. Used by [_doReschedule]
  /// to drive the loading → success / error animation lifecycle.
  void _setRescheduleBanner(
    ScheduleRescheduleSnapshot? snapshot, {
    Duration? autoDismiss,
  }) {
    _rescheduleBannerTimer?.cancel();
    if (!mounted) return;
    setState(() => _rescheduleBanner = snapshot);
    if (snapshot != null && autoDismiss != null) {
      _rescheduleBannerTimer = Timer(autoDismiss, () {
        if (!mounted) return;
        setState(() => _rescheduleBanner = null);
      });
    }
  }

  Future<void> _doReschedule({
    required String scheduleId,
    required String targetLessonHourId,
    required String targetDayName,
    required String targetStartTime,
    required String subjectName,
    required String previousLessonHourId,
    required String previousDayName,
    required String previousStartTime,
    required bool force,
  }) async {
    final lang = ref.read(languageRiverpod);

    // Compose the slot labels surfaced in the banner. Falls back to
    // an em-dash when either side is empty (e.g. an Urungkan that
    // doesn't carry the rollback day name).
    String fmtSlot(String day, String time) {
      final d = day.trim();
      final t = time.trim();
      if (d.isEmpty && t.isEmpty) return '—';
      if (d.isEmpty) return t;
      if (t.isEmpty) return d;
      return '$d · $t';
    }

    _setRescheduleBanner(
      ScheduleRescheduleSnapshot(
        subjectName: subjectName,
        fromSlotLabel: fmtSlot(previousDayName, previousStartTime),
        toSlotLabel: fmtSlot(targetDayName, targetStartTime),
        phase: ScheduleReschedulePhase.loading,
      ),
    );

    try {
      await getIt<ApiScheduleService>().rescheduleSession(
        scheduleId: scheduleId,
        lessonHourDaysId: targetLessonHourId,
        force: force,
      );
      if (!mounted) return;
      // Flip the banner to success the moment the server confirms —
      // before the list refresh — so the admin sees the green tick
      // even on slow networks where _loadSchedules adds a beat. The
      // banner auto-dismisses 1.4s later regardless of refresh state.
      _setRescheduleBanner(
        _rescheduleBanner?.copyWith(phase: ScheduleReschedulePhase.success),
        autoDismiss: const Duration(milliseconds: 1400),
      );
      await _loadSchedules(resetPage: true, useCache: false);
      unawaited(_loadKpiSummary());
      if (!mounted) return;

      // Only offer Urungkan when we know where to roll back to and
      // the rollback would actually move the row (rules out no-op
      // drops onto the source slot, which the grid filters anyway).
      final canUndo =
          previousLessonHourId.isNotEmpty &&
          previousLessonHourId != targetLessonHourId;

      SnackBarUtils.showWithActions(
        context,
        message: lang.getTranslatedText({
          'en': 'Moved "$subjectName" to $targetDayName $targetStartTime',
          'id':
              'Sesi "$subjectName" dipindah ke '
              '$targetDayName $targetStartTime',
        }),
        backgroundColor: ColorUtils.success600,
        duration: const Duration(seconds: 5),
        actions: [
          if (canUndo)
            SnackBarToastAction(
              label: lang.getTranslatedText(const {
                'en': 'UNDO',
                'id': 'URUNGKAN',
              }),
              onTap: () => _doReschedule(
                scheduleId: scheduleId,
                // Swap target ↔ previous so the call rolls back.
                targetLessonHourId: previousLessonHourId,
                targetDayName: previousDayName,
                targetStartTime: previousStartTime,
                subjectName: subjectName,
                previousLessonHourId: targetLessonHourId,
                previousDayName: targetDayName,
                previousStartTime: targetStartTime,
                // Force so a race-in row can't block the undo.
                force: true,
              ),
            ),
        ],
      );
    } on DioException catch (e) {
      AppLogger.error(
        'schedule',
        'reschedule failed: ${e.response?.statusCode} ${e.message} '
            'body=${e.response?.data}',
      );
      if (!mounted) return;
      // Flip the banner to error before extracting the message — gives
      // an instant red signal even before the snackbar fires. The
      // banner sticks around until the snackbar dismisses (longer
      // auto-dismiss tolerates the reader checking what went wrong).
      _setRescheduleBanner(
        _rescheduleBanner?.copyWith(
          phase: ScheduleReschedulePhase.error,
          errorMessage: _extractServerMessage(e),
        ),
        autoDismiss: const Duration(seconds: 5),
      );
      // Extract the server's structured `error` / `message` field
      // before falling back to ErrorUtils. Backend may surface a
      // 422 "lesson_hour_days_id invalid" / 500 "no slot at this
      // day" etc. — those messages are actionable, so we want them
      // verbatim instead of the generic "Terjadi kesalahan sistem".
      // For 409s, [_extractServerMessage] already prefers the first
      // conflict's `message` over the top-level `error` so the admin
      // sees "Guru sudah punya jadwal" instead of the generic
      // "Slot bentrok" — no extra conflict lookup needed here.
      final serverMsg = _extractServerMessage(e);

      // 409 = teacher / class collision. Falls back to a built-in
      // copy if the body shape is unexpected.
      if (e.response?.statusCode == 409) {
        SnackBarUtils.showWithActions(
          context,
          message:
              serverMsg ??
              lang.getTranslatedText({
                'en': 'Slot $targetDayName $targetStartTime is already taken.',
                'id': 'Slot $targetDayName $targetStartTime sudah terisi.',
              }),
          backgroundColor: ColorUtils.error600,
          duration: const Duration(seconds: 6),
          actions: [
            SnackBarToastAction(
              label: lang.getTranslatedText(const {
                'en': 'FORCE SAVE',
                'id': 'PAKSA SIMPAN',
              }),
              onTap: () => _doReschedule(
                scheduleId: scheduleId,
                targetLessonHourId: targetLessonHourId,
                targetDayName: targetDayName,
                targetStartTime: targetStartTime,
                subjectName: subjectName,
                previousLessonHourId: previousLessonHourId,
                previousDayName: previousDayName,
                previousStartTime: previousStartTime,
                force: true,
              ),
            ),
          ],
        );
        return;
      }
      // Non-409 — prefer the server's error message when present,
      // otherwise fall back to the generic friendly translator.
      SnackBarUtils.showError(
        context,
        '${lang.getTranslatedText(const {'en': 'Failed to reschedule: ', 'id': 'Gagal memindahkan: '})}${serverMsg ?? ErrorUtils.getFriendlyMessage(e)}',
      );
      // The backend has been observed to 500 *after* committing the
      // update (e.g. notify-step failure). Force a refresh so the UI
      // re-syncs with whatever actually landed in the DB instead of
      // showing stale data after a misleading error toast.
      await _loadSchedules(resetPage: true, useCache: false);
      if (mounted) unawaited(_loadKpiSummary());
    } catch (e) {
      AppLogger.error('schedule', e);
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        '${lang.getTranslatedText(const {'en': 'Failed to reschedule: ', 'id': 'Gagal memindahkan: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
      await _loadSchedules(resetPage: true, useCache: false);
      if (mounted) unawaited(_loadKpiSummary());
    }
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

  // ── Bulk-select actions ──

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    if (_selectedIds.isEmpty) return;
    setState(_selectedIds.clear);
  }

  /// Bulk-deletes every row in [_selectedIds] in a single server call.
  ///
  /// Uses the [ApiScheduleService.bulkDeleteSessions] endpoint (one
  /// transaction, one round-trip) instead of the legacy per-row
  /// `deleteSchedule` loop. After the call the list + KPI are refreshed
  /// and the selection is cleared. The success snack quotes the server's
  /// `deleted_count` so partial failures show up honestly.
  Future<void> _bulkDeleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final lang = ref.read(languageRiverpod);
    final selected = _scheduleList
        .cast<Map<String, dynamic>>()
        .where((s) => _selectedIds.contains(s['id']?.toString()))
        .toList();

    final ok = await showBulkDeleteConfirm(
      context,
      entityNoun: lang.getTranslatedText(const {
        'en': 'sessions',
        'id': 'sesi',
      }),
      items: selected
          .map(
            (s) => BulkDeleteItem(
              id: s['id'].toString(),
              title: (s['subject_name'] ?? '?').toString(),
              subtitle: [
                s['class_name'],
                s['teacher_name'],
              ].where((v) => v != null && v.toString().isNotEmpty).join(' · '),
            ),
          )
          .toList(),
    );
    if (ok != true || !mounted) return;

    final ids = selected
        .map((s) => s['id']?.toString())
        .whereType<String>()
        .toList(growable: false);
    final total = ids.length;
    setState(_selectedIds.clear);

    try {
      final deleted = await getIt<ApiScheduleService>().bulkDeleteSessions(ids);
      if (!mounted) return;
      await _loadSchedules(resetPage: true, useCache: false);
      unawaited(_loadKpiSummary());
      if (!mounted) return;
      SnackBarUtils.showSuccess(
        context,
        lang.getTranslatedText({
          'en': '$deleted of $total sessions deleted',
          'id': '$deleted dari $total sesi terhapus',
        }),
      );
    } catch (e) {
      AppLogger.error('schedule', 'bulk delete failed: $e');
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        '${lang.getTranslatedText(const {'en': 'Bulk delete failed: ', 'id': 'Hapus massal gagal: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  /// "Pindah Hari" bulk action — opens the day picker, then bulk-moves
  /// every selected session to the equivalent lesson_hour on the target
  /// day (server preserves hour_number).
  ///
  /// Skipped rows surface in a red toast with **PAKSA SIMPAN** that
  /// retries those ids with `force: true` — same UX as the single-row
  /// drag reschedule's 409 path so the flow feels consistent.
  Future<void> _bulkMoveSelected() async {
    if (_selectedIds.isEmpty) return;
    final visibleDays = _visibleListDays();
    final ids = _selectedIds.toList(growable: false);
    final total = ids.length;

    final targetDayId = await showBulkDayPickerSheet(
      context: context,
      days: visibleDays,
      selectedCount: total,
    );
    if (targetDayId == null || !mounted) return;

    final dayName =
        visibleDays
            .firstWhere(
              (d) => d['id']?.toString() == targetDayId,
              orElse: () => const {'name': ''},
            )['name']
            ?.toString() ??
        '';

    await _runBulkMove(
      ids: ids,
      targetDayId: targetDayId,
      targetDayName: dayName,
      force: false,
    );
    if (!mounted) return;
    setState(_selectedIds.clear);
  }

  /// Internal bulk-move worker. Separated so the **PAKSA SIMPAN** retry
  /// action can call back with `force: true` on the same payload without
  /// re-opening the picker.
  Future<void> _runBulkMove({
    required List<String> ids,
    required String targetDayId,
    required String targetDayName,
    required bool force,
  }) async {
    final lang = ref.read(languageRiverpod);
    try {
      final result = await getIt<ApiScheduleService>().bulkMoveSessions(
        ids: ids,
        targetDayId: targetDayId,
        force: force,
      );
      if (!mounted) return;
      await _loadSchedules(resetPage: true, useCache: false);
      unawaited(_loadKpiSummary());
      if (!mounted) return;

      final movedCount = (result['moved_count'] is num)
          ? (result['moved_count'] as num).toInt()
          : 0;
      final skipped = (result['skipped'] is List)
          ? List<dynamic>.from(result['skipped'] as List)
          : const <dynamic>[];

      if (skipped.isEmpty) {
        SnackBarUtils.showSuccess(
          context,
          lang.getTranslatedText({
            'en':
                '$movedCount of ${ids.length} sessions moved to '
                '$targetDayName',
            'id':
                '$movedCount dari ${ids.length} sesi dipindah ke '
                '$targetDayName',
          }),
        );
        return;
      }

      // Some rows hit conflicts. Offer Paksa simpan to force the
      // remaining ids through.
      final skippedIds = skipped
          .whereType<Map>()
          .map((s) => s['id']?.toString())
          .whereType<String>()
          .toList(growable: false);
      SnackBarUtils.showWithActions(
        context,
        message: lang.getTranslatedText({
          'en': '$movedCount moved, ${skipped.length} skipped (conflicts).',
          'id': '$movedCount dipindah, ${skipped.length} dilewati (bentrok).',
        }),
        backgroundColor: ColorUtils.error600,
        duration: const Duration(seconds: 7),
        actions: [
          if (skippedIds.isNotEmpty)
            SnackBarToastAction(
              label: lang.getTranslatedText(const {
                'en': 'FORCE SAVE',
                'id': 'PAKSA SIMPAN',
              }),
              onTap: () => _runBulkMove(
                ids: skippedIds,
                targetDayId: targetDayId,
                targetDayName: targetDayName,
                force: true,
              ),
            ),
        ],
      );
    } catch (e) {
      AppLogger.error('schedule', 'bulk move failed: $e');
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        '${lang.getTranslatedText(const {'en': 'Bulk move failed: ', 'id': 'Pindah massal gagal: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
      // The backend has been observed to 500 *after* committing the
      // update (e.g. notify-step failure). Force a refresh so the UI
      // re-syncs with whatever actually landed in the DB instead of
      // showing stale data after a misleading error toast.
      await _loadSchedules(resetPage: true, useCache: false);
      if (mounted) unawaited(_loadKpiSummary());
    }
  }

  /// "Ganti Guru" bulk action — opens the teacher picker, then bulk-
  /// reassigns every selected row to the chosen teacher_id.
  ///
  /// Skipped rows (teacher already has a colliding slot) surface in the
  /// same Paksa simpan toast pattern as bulk move.
  Future<void> _bulkChangeTeacherForSelected() async {
    if (_selectedIds.isEmpty) return;
    final teachers = _availableTeachers
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    final ids = _selectedIds.toList(growable: false);
    final total = ids.length;

    final teacherId = await showBulkTeacherPickerSheet(
      context: context,
      teachers: teachers,
      selectedCount: total,
    );
    if (teacherId == null || !mounted) return;

    final teacherName =
        teachers
            .firstWhere(
              (t) => t['id']?.toString() == teacherId,
              orElse: () => const {'name': ''},
            )['name']
            ?.toString() ??
        '';

    await _runBulkChangeTeacher(
      ids: ids,
      teacherId: teacherId,
      teacherName: teacherName,
      force: false,
    );
    if (!mounted) return;
    setState(_selectedIds.clear);
  }

  /// Internal bulk change-teacher worker — mirrors [_runBulkMove] so the
  /// PAKSA SIMPAN action can recurse on the skipped subset with
  /// `force: true`.
  Future<void> _runBulkChangeTeacher({
    required List<String> ids,
    required String teacherId,
    required String teacherName,
    required bool force,
  }) async {
    final lang = ref.read(languageRiverpod);
    try {
      final result = await getIt<ApiScheduleService>().bulkChangeTeacher(
        ids: ids,
        teacherId: teacherId,
        force: force,
      );
      if (!mounted) return;
      await _loadSchedules(resetPage: true, useCache: false);
      unawaited(_loadKpiSummary());
      if (!mounted) return;

      final movedCount = (result['moved_count'] is num)
          ? (result['moved_count'] as num).toInt()
          : 0;
      final skipped = (result['skipped'] is List)
          ? List<dynamic>.from(result['skipped'] as List)
          : const <dynamic>[];

      if (skipped.isEmpty) {
        SnackBarUtils.showSuccess(
          context,
          lang.getTranslatedText({
            'en':
                '$movedCount of ${ids.length} sessions assigned to '
                '$teacherName',
            'id':
                '$movedCount dari ${ids.length} sesi dialihkan ke '
                '$teacherName',
          }),
        );
        return;
      }

      final skippedIds = skipped
          .whereType<Map>()
          .map((s) => s['id']?.toString())
          .whereType<String>()
          .toList(growable: false);
      SnackBarUtils.showWithActions(
        context,
        message: lang.getTranslatedText({
          'en':
              '$movedCount reassigned, ${skipped.length} skipped (conflicts).',
          'id': '$movedCount dialihkan, ${skipped.length} dilewati (bentrok).',
        }),
        backgroundColor: ColorUtils.error600,
        duration: const Duration(seconds: 7),
        actions: [
          if (skippedIds.isNotEmpty)
            SnackBarToastAction(
              label: lang.getTranslatedText(const {
                'en': 'FORCE SAVE',
                'id': 'PAKSA SIMPAN',
              }),
              onTap: () => _runBulkChangeTeacher(
                ids: skippedIds,
                teacherId: teacherId,
                teacherName: teacherName,
                force: true,
              ),
            ),
        ],
      );
    } catch (e) {
      AppLogger.error('schedule', 'bulk change teacher failed: $e');
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        '${lang.getTranslatedText(const {'en': 'Bulk change teacher failed: ', 'id': 'Ganti guru massal gagal: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
      // Same "500-after-commit" refresh pattern as bulk move — see
      // _runBulkMove for the rationale.
      await _loadSchedules(resetPage: true, useCache: false);
      if (mounted) unawaited(_loadKpiSummary());
    }
  }

  // ── Excel flows ─────────────────────────────────────────────────────

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

  // ── Print PDF ───────────────────────────────────────────────────────

  /// Opens the Print PDF scope picker; once admin chooses a scope,
  /// calls the backend `/teaching-schedule/print-pdf` endpoint with the
  /// currently-applied filters and the chosen scope. Snackbar feedback
  /// is handled inside [SchedulePrintPdfService.printAndShow] so the
  /// screen stays thin.
  void _openPrintPdfSheet() {
    // Compose a one-line summary of active filters so admin sees the
    // PDF will mirror the visible list. The labels reuse the same
    // resolvers as the BrandFilterChip strip.
    final lang = ref.read(languageRiverpod);
    final parts = <String>[];
    String? teacherLabel;
    if (_selectedTeacherId != null) {
      final m = _availableTeachers.cast<Map<String, dynamic>>().firstWhere(
        (t) => t['id']?.toString() == _selectedTeacherId,
        orElse: () => const {'name': null},
      );
      teacherLabel = (m['name'] ?? m['nama'])?.toString();
      if (teacherLabel != null) parts.add('Guru $teacherLabel');
    }
    String? subjectLabel;
    if (_selectedSubjectId != null) {
      final m = _subjectList.cast<Map<String, dynamic>>().firstWhere(
        (s) => s['id']?.toString() == _selectedSubjectId,
        orElse: () => const {'name': null},
      );
      subjectLabel = (m['name'] ?? m['nama'])?.toString();
      if (subjectLabel != null) parts.add('Mapel $subjectLabel');
    }
    if (_selectedClassId != null) {
      final m = _availableClasses.cast<Map<String, dynamic>>().firstWhere(
        (c) => c['id']?.toString() == _selectedClassId,
        orElse: () => const {'name': null},
      );
      final classLabel = (m['name'] ?? m['nama'])?.toString();
      if (classLabel != null) parts.add('Kelas $classLabel');
    }
    if (_selectedDayId != null) {
      final m = _availableDays.cast<Map<String, dynamic>>().firstWhere(
        (d) => d['id']?.toString() == _selectedDayId,
        orElse: () => const {'name': null},
      );
      final dayLabel = (m['name'] ?? m['nama'])?.toString();
      if (dayLabel != null) parts.add('Hari $dayLabel');
    }
    if (_selectedLessonHour != null) {
      parts.add('Jam $_selectedLessonHour');
    }
    final summary = parts.isEmpty
        ? lang.getTranslatedText(const {
            'en': 'No filters active — full timetable.',
            'id': 'Tanpa filter — seluruh jadwal akan dicetak.',
          })
        : '${lang.getTranslatedText(const {'en': 'Active filter: ', 'id': 'Filter aktif: '})}${parts.join(' · ')}';

    SchedulePrintScopeSheet.show(
      context: context,
      filterSummary: summary,
      onConfirm: (scope) async {
        await SchedulePrintPdfService.printAndShow(
          context: context,
          scope: scope,
          teacherId: _selectedTeacherId,
          subjectId: _selectedSubjectId,
          classId: _selectedClassId,
          dayId: _selectedDayId,
          hourNumber: _selectedLessonHour,
          semesterId: _selectedFilterTerm ?? _selectedTerm,
          academicYearId: _selectedAcademicYear,
        );
      },
    );
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
      selectedTeacherId: _selectedTeacherId,
      selectedSubjectId: _selectedSubjectId,
      selectedClassId: _selectedClassId,
      selectedDayId: _selectedDayId,
      selectedJamPelajaran: _selectedLessonHour,
    );

    // v3 brand chips — sticky inside hero. Period chip leads, then Day,
    // Class, Lesson hour. Tapping any opens the full filter sheet.
    String? dayName(String? id) {
      if (id == null) return null;
      final m = _availableDays.cast<Map<String, dynamic>>().firstWhere(
        (d) => d['id']?.toString() == id,
        orElse: () => const {'name': null},
      );
      return m['name']?.toString();
    }

    String? className(String? id) {
      if (id == null) return null;
      final m = _availableClasses.cast<Map<String, dynamic>>().firstWhere(
        (c) => c['id']?.toString() == id,
        orElse: () => const {'name': null},
      );
      return m['name']?.toString();
    }

    String? teacherName(String? id) {
      if (id == null) return null;
      final m = _availableTeachers.cast<Map<String, dynamic>>().firstWhere(
        (t) => t['id']?.toString() == id,
        orElse: () => const {'name': null},
      );
      return m['name']?.toString() ?? m['nama']?.toString();
    }

    String? subjectName(String? id) {
      if (id == null) return null;
      final m = _subjectList.cast<Map<String, dynamic>>().firstWhere(
        (s) => s['id']?.toString() == id,
        orElse: () => const {'name': null},
      );
      return m['name']?.toString() ?? m['nama']?.toString();
    }

    // Periode chip retired — the academic year is owned by the global
    // dashboard picker (top-right chip), and the semester defaults to
    // the backend's "current" flag. Keeping it here would duplicate the
    // dashboard's source of truth and let admin pick two different
    // years in two different places. The Guru / Mapel / Hari / Kelas /
    // Jam chips remain so admin can still narrow the table along each
    // dimension. Guru + Mapel were added in Fix-1a so admin can print
    // per-teacher / per-subject schedule listings.
    final brandChips = <BrandFilterChip>[
      BrandFilterChip(
        label: lang.getTranslatedText(const {'en': 'Teacher', 'id': 'Guru'}),
        value: teacherName(_selectedTeacherId),
        onTap: _openFilterSheet,
      ),
      BrandFilterChip(
        label: lang.getTranslatedText(const {'en': 'Subject', 'id': 'Mapel'}),
        value: subjectName(_selectedSubjectId),
        onTap: _openFilterSheet,
      ),
      BrandFilterChip(
        label: lang.getTranslatedText(const {'en': 'Day', 'id': 'Hari'}),
        value: dayName(_selectedDayId),
        onTap: _openFilterSheet,
      ),
      BrandFilterChip(
        label: lang.getTranslatedText(const {'en': 'Class', 'id': 'Kelas'}),
        value: className(_selectedClassId),
        onTap: _openFilterSheet,
      ),
      BrandFilterChip(
        label: lang.getTranslatedText(const {'en': 'Hour', 'id': 'Jam'}),
        value: _selectedLessonHour,
        onTap: _openFilterSheet,
      ),
    ];

    // ── KPI overlap card ─────────────────────────────────────────────
    //
    // Mirrors the mockup's "Total Sesi · Hari Ini · Bentrok" strip. The
    // Bentrok cell flips red when conflicts > 0 so the admin sees the
    // problem the moment the page paints.
    final kpiCard = BrandKpiStrip(
      columns: [
        BrandKpiColumn(
          label: lang.getTranslatedText(const {
            'en': 'Total',
            'id': 'Total Sesi',
          }),
          value: '${_kpi.total}',
        ),
        BrandKpiColumn(
          label: lang.getTranslatedText(const {
            'en': 'Today',
            'id': 'Hari Ini',
          }),
          value: '${_kpi.today}',
        ),
        BrandKpiColumn(
          label: lang.getTranslatedText(const {
            'en': 'Conflicts',
            'id': 'Bentrok',
          }),
          value: '${_kpi.conflicts}',
          valueColor: _kpi.conflicts > 0 ? ColorUtils.error600 : null,
        ),
      ],
    );

    // ── Body content per view mode ───────────────────────────────────
    final bodyContent = _buildViewBody(
      mode: _viewMode,
      filteredSchedules: filteredSchedules,
      lang: lang,
      ctrl: ctrl,
      primaryColor: primaryColor,
      isReadOnly: academicYear.isReadOnly,
    );

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Stack(
        children: [
          // Pagination removed — every row loads on init via the bumped
          // [_perPage] limit, so the body no longer needs a scroll
          // listener.
          BrandPageLayout(
            role: 'admin',
            onRefresh: _onRefresh,
            header: BrandPageHeader(
              role: 'admin',
              subtitle: lang.getTranslatedText(const {
                'en': 'DATA MANAGEMENT',
                'id': 'MANAJEMEN DATA',
              }),
              title: lang.getTranslatedText(const {
                'en': 'Schedule',
                'id': 'Jadwal',
              }),
              isRealtimeFresh: !_isLoading && _errorMessage == null,
              kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
              actionIcons: [
                BrandHeaderIconButton(
                  icon: Icons.print_rounded,
                  onTap: _openPrintPdfSheet,
                ),
                BrandHeaderIconButton(
                  icon: Icons.tune_rounded,
                  onTap: _openFilterSheet,
                  badgeCount: _hasActiveFilter ? 1 : null,
                  badgeBorderColor: primaryColor,
                ),
              ],
              bottomSlot: BrandFilterChipStrip(chips: brandChips),
            ),
            kpiCard: kpiCard,
            bottomPadding:
                (_bulkMode ? 96 : 0) +
                AppSpacing.xl +
                MediaQuery.of(context).padding.bottom,
            bodyChildren: [
              // 3-tab view toggle: Grid · List · Matrix. Sits flush
              // under the KPI overlap so the list / grid surface gets
              // maximum vertical room. List is the default; Grid
              // renders the AdminScheduleWeekGridView, Matrix renders
              // the legacy timetable view.
              //
              // The search bar that used to sit above this toggle was
              // dropped — filtering happens entirely through the brand
              // filter chips + the filter sheet now, which keeps the
              // hub closer to the mockup density.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _ScheduleViewToggleStrip(
                  mode: _viewMode,
                  onChanged: (m) => setState(() => _viewMode = m),
                ),
              ),
              const SizedBox(height: 8),
              ...bodyContent,
            ],
          ),
          // Reschedule progress banner (TR.E creative loading) —
          // overlaid above the body while a drag-and-drop PATCH is
          // racing the network. Sits below the header at the very
          // top of the body area; uses SafeArea so it doesn't slip
          // under the status bar. IgnorePointer so it doesn't steal
          // taps from the grid while it animates.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(
                  // Push below the BrandPageHeader's compact rail so
                  // the banner reads as "the row that just landed"
                  // rather than fighting the header for attention.
                  top: MediaQuery.of(context).padding.top > 0 ? 64 : 84,
                ),
                child: IgnorePointer(
                  child: ScheduleRescheduleBanner(snapshot: _rescheduleBanner),
                ),
              ),
            ),
          ),
          // Bulk-select bottom bar — only when rows are selected.
          //
          // Three actions, ordered by destructiveness:
          //   1. Pindah Hari — bulk-move to another weekday.
          //   2. Ganti Guru — bulk-reassign teacher.
          //   3. Hapus      — bulk-delete (destructive, rendered red).
          if (_bulkMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BulkActionBar(
                selectedCount: _selectedIds.length,
                onClear: _clearSelection,
                itemNoun: lang.getTranslatedText(const {
                  'en': 'session',
                  'id': 'sesi',
                }),
                actions: [
                  BulkAction(
                    icon: Icons.swap_horiz_rounded,
                    label: lang.getTranslatedText(const {
                      'en': 'Move day',
                      'id': 'Pindah',
                    }),
                    onTap: _bulkMoveSelected,
                    enabled: !academicYear.isReadOnly,
                  ),
                  BulkAction(
                    icon: Icons.person_search_rounded,
                    label: lang.getTranslatedText(const {
                      'en': 'Teacher',
                      'id': 'Ganti Guru',
                    }),
                    onTap: _bulkChangeTeacherForSelected,
                    enabled: !academicYear.isReadOnly,
                  ),
                  BulkAction(
                    icon: Icons.delete_outline_rounded,
                    label: lang.getTranslatedText(const {
                      'en': 'Delete',
                      'id': 'Hapus',
                    }),
                    onTap: _bulkDeleteSelected,
                    isDestructive: true,
                    enabled: !academicYear.isReadOnly,
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: academicYear.isReadOnly || _bulkMode
          ? null
          : FloatingActionButton(
              backgroundColor: ColorUtils.brandCobalt,
              foregroundColor: Colors.white,
              elevation: 4,
              onPressed: _openAddEditSheet,
              child: const Icon(Icons.add_rounded, size: 28),
            ),
    );
  }

  // ── Body rendering per view mode ──────────────────────────────────
  //
  // Returns a flat list of widgets to splice into BrandPageLayout's
  // bodyChildren. Each mode renders its own structure:
  //   - grid:   "Coming soon" placeholder card (TR.A.2 fills in)
  //   - list:   Loading / error / empty / N cards + tap-to-load-more
  //   - matrix: AdminScheduleMatrixView wrapped at a fixed height
  List<Widget> _buildViewBody({
    required ScheduleViewMode mode,
    required List<dynamic> filteredSchedules,
    required LanguageProvider lang,
    required AdminScheduleController ctrl,
    required Color primaryColor,
    required bool isReadOnly,
  }) {
    if (_isLoading && _scheduleList.isEmpty) {
      // Skeleton picks the right shape for the active view mode so the
      // silhouette matches the data that's about to appear. Grid/Matrix
      // get the week-grid ghost; List gets the row-card ghost.
      return [
        if (mode == ScheduleViewMode.list)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: ScheduleListSkeleton(),
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: ScheduleGridSkeleton(),
          ),
      ];
    }
    if (_errorMessage != null) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: ColorUtils.error600,
                  size: 36,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ColorUtils.slate700, fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    switch (mode) {
      case ScheduleViewMode.grid:
        // Week-grid calendar. Renders schedules as color-coded blocks
        // on a Mon-Sab × time grid. Tap a block → detail sheet.
        // Long-press-and-drag (TR.E.1) lets the admin move a session
        // onto a different slot; the drop fires [_handleReschedule]
        // which PATCHes the row's lesson_hour_days_id server-side.
        //
        // Drag drops are disabled when the current academic year is
        // read-only — passing `null` to [onReschedule] makes the grid
        // skip the LongPressDraggable wrapping so blocks stay tappable
        // but un-draggable.
        return [
          AdminScheduleWeekGridView(
            scheduleList: filteredSchedules,
            dayList: _dayList.isNotEmpty ? _dayList : _availableDays,
            lessonHourList: _lessonHourList,
            highlightDayId: _selectedDayId,
            // In bulk mode the screen routes block taps through
            // _toggleSelection (parity with list rows). Outside bulk
            // mode taps open the detail sheet as before. The grid's
            // own block-render layer flips behaviour based on
            // [isBulkMode] / [selectedIds], so the screen just hands
            // it both callbacks.
            onScheduleTap: _showScheduleDetail,
            onScheduleLongPress: isReadOnly
                ? null
                : (s) {
                    final id = s['id']?.toString();
                    if (id != null && id.isNotEmpty) _toggleSelection(id);
                  },
            // Drag-drop is auto-suppressed inside the grid when
            // [isBulkMode] is true, so we don't need to gate the
            // reschedule callback here.
            onReschedule: isReadOnly ? null : _handleReschedule,
            selectedIds: _selectedIds,
            // Density-mode hooks — 6+ session clusters open the slot
            // expansion sheet on tap and seed bulk-select on long-press.
            onSlotClusterTap: _openSlotClusterSheet,
            onSlotClusterLongPress: isReadOnly ? null : _selectClusterForBulk,
            // Zoom-in day view — default to today on first load, allow
            // the admin to tap a day-header cell (week mode) or any
            // pill (focused mode) to switch days, swipe horizontally
            // to navigate, and tap the grid icon to zoom out.
            focusedDayId: _focusedDayId,
            onFocusedDayChanged: (id) => setState(() => _focusedDayId = id),
          ),
        ];

      case ScheduleViewMode.matrix:
        // Wrap matrix view at a fixed-ish height so it sits cleanly
        // inside BrandPageLayout's outer ListView. The matrix has its
        // own horizontal scroll inside the FrozenColumnTable.
        return [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.62,
            child: AdminScheduleMatrixView(
              scheduleList: filteredSchedules,
              dayList: _dayList.isNotEmpty ? _dayList : _availableDays,
              lessonHourList: _lessonHourList,
              selectedDayId: _selectedDayId,
              selectedLessonHour: _selectedLessonHour,
              primaryColor: primaryColor,
              languageProvider: lang,
              onScheduleTap: _showScheduleDetail,
            ),
          ),
        ];

      case ScheduleViewMode.list:
        return _buildListBody(
          filteredSchedules: filteredSchedules,
          lang: lang,
          ctrl: ctrl,
          primaryColor: primaryColor,
        );
    }
  }

  /// Renders the List view body — day-tab pill row + (per-day) Pagi /
  /// Siang sections of row cards. Tap a tab to client-filter to that
  /// day; tap the active tab again to clear back to "Semua".
  ///
  /// Day-tab filtering is purely client-side so it doesn't trigger a
  /// new API hit; the underlying `filteredSchedules` already respects
  /// the server-side filter chips (Periode / Hari / Kelas / Jam) +
  /// search.
  List<Widget> _buildListBody({
    required List<dynamic> filteredSchedules,
    required LanguageProvider lang,
    required AdminScheduleController ctrl,
    required Color primaryColor,
  }) {
    // ── 1. Compute visible weekdays (Senin → Sabtu) ────────────────
    final visibleDays = _visibleListDays();
    if (visibleDays.isEmpty) {
      // No day reference data loaded yet — render a plain list as a
      // fallback. Should be rare in practice; _loadFilterOptions fires
      // alongside _loadSchedules.
      return _buildFlatRowCards(
        items: filteredSchedules,
        lang: lang,
        ctrl: ctrl,
      );
    }

    // ── 2. Count schedules per day for tab badges ─────────────────
    final countsByDay = <String, int>{};
    for (final s in filteredSchedules) {
      if (s is! Map) continue;
      final dayId = s['day_id']?.toString();
      if (dayId == null) continue;
      countsByDay[dayId] = (countsByDay[dayId] ?? 0) + 1;
    }

    // ── 3. Apply day-tab client filter on top of server filter ────
    final List<dynamic> tabFiltered = _activeDayTab == null
        ? filteredSchedules
        : filteredSchedules
              .where(
                (s) => s is Map && s['day_id']?.toString() == _activeDayTab,
              )
              .toList(growable: false);

    final widgets = <Widget>[
      // Day-tab pill strip.
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: AdminScheduleDayTabStrip(
          days: visibleDays,
          selectedDayId: _activeDayTab,
          countsByDay: countsByDay,
          onChanged: (id) => setState(() => _activeDayTab = id),
        ),
      ),
    ];

    if (tabFiltered.isEmpty) {
      widgets.add(_buildEmptyListCard(lang));
      return widgets;
    }

    // ── 4. Group by day_id → Pagi / Siang sub-sections ─────────────
    final byDay = <String, List<Map<String, dynamic>>>{};
    for (final s in tabFiltered) {
      if (s is! Map) continue;
      final m = Map<String, dynamic>.from(s);
      final dayId = m['day_id']?.toString();
      if (dayId == null) continue;
      byDay.putIfAbsent(dayId, () => []).add(m);
    }

    // Render in visibleDays order so days always appear Senin → Sabtu
    // regardless of how the API ordered the rows.
    for (final day in visibleDays) {
      final dayId = day['id']?.toString();
      final rows = byDay[dayId] ?? const [];
      if (rows.isEmpty) continue;

      // Day-section header is only shown when "Semua" is selected; in
      // single-day mode the day tab itself is the header.
      if (_activeDayTab == null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Text(
              (day['name'] ?? '').toString().toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ColorUtils.brandDarkBlue,
                letterSpacing: 0.6,
              ),
            ),
          ),
        );
      }

      // Sort rows by start_time ascending so Pagi → Siang reads
      // naturally inside each section.
      rows.sort((a, b) {
        final aMin = _parseStartMinutes(a) ?? 99999;
        final bMin = _parseStartMinutes(b) ?? 99999;
        return aMin.compareTo(bMin);
      });

      final pagi = <Map<String, dynamic>>[];
      final siang = <Map<String, dynamic>>[];
      for (final row in rows) {
        final start = _parseStartMinutes(row) ?? 0;
        // Cutoff: 12:00 — adjust if some schools want a different
        // morning/afternoon split.
        if (start < 12 * 60) {
          pagi.add(row);
        } else {
          siang.add(row);
        }
      }

      if (pagi.isNotEmpty) {
        widgets.addAll(_buildSection('Pagi', pagi, ctrl, lang));
      }
      if (siang.isNotEmpty) {
        widgets.addAll(_buildSection('Siang', siang, ctrl, lang));
      }
    }

    return widgets;
  }

  /// Renders one Pagi/Siang section — kicker header + N row cards.
  List<Widget> _buildSection(
    String label,
    List<Map<String, dynamic>> rows,
    AdminScheduleController ctrl,
    LanguageProvider lang,
  ) {
    final widgets = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: AdminScheduleSectionHead(label: label, count: rows.length),
      ),
    ];
    for (var i = 0; i < rows.length; i++) {
      final m = rows[i];
      final id = m['id']?.toString() ?? '';
      final isSelected = _selectedIds.contains(id);
      final startTime = (m['start_time'] ?? '').toString();
      final endTime = (m['end_time'] ?? '').toString();
      final duration = _formatDuration(m);
      widgets.add(
        Padding(
          padding: EdgeInsets.fromLTRB(16, i == 0 ? 6 : 8, 16, 0),
          child: AdminScheduleRowCard(
            schedule: m,
            startTimeLabel: startTime,
            endTimeLabel: endTime,
            durationLabel: duration,
            subjectName:
                (m['subject_name'] ?? m['mata_pelajaran_nama'] ?? 'No Subject')
                    .toString(),
            className: (m['class_name'] ?? m['kelas_nama'] ?? '').toString(),
            teacherName: (m['teacher_name'] ?? m['guru_nama'] ?? '').toString(),
            roomName: (m['room'] ?? m['ruangan'] ?? '').toString(),
            selected: isSelected,
            onTap: () =>
                _bulkMode ? _toggleSelection(id) : _showScheduleDetail(m),
            onLongPress: () => _toggleSelection(id),
          ),
        ),
      );
    }
    return widgets;
  }

  /// Renders the empty-state card shown when the list (or any view
  /// mode) has zero schedules.
  ///
  /// Three flavours (TR.H):
  ///   * **Pristine empty** — no filters, no day tab, search cleared,
  ///     AY editable. Shows the "Belum ada jadwal" hero + dual CTAs
  ///     (Tambah Manual + Import Excel) so the admin can start
  ///     populating data right from the empty state without having to
  ///     find the FAB or hunt down the overflow menu.
  ///   * **Filter-empty** — at least one filter active or a day-tab
  ///     selected. Shows the "Tidak ada hasil" copy + a single
  ///     secondary button to clear filters. Hides the data-entry CTAs
  ///     because the issue is filtering, not lack of data.
  ///   * **Read-only AY** — admin is browsing a past academic year.
  ///     Shows the "Belum ada jadwal di tahun ajaran ini" copy with
  ///     no write CTAs (would 403 anyway), just a read-only pill so
  ///     it's clear the absence is intentional, not a missing import.
  Widget _buildEmptyListCard(LanguageProvider lang) {
    final isReadOnly = ref.read(academicYearRiverpod).isReadOnly;
    final hasFilters =
        _hasActiveFilter ||
        _activeDayTab != null ||
        _searchController.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorUtils.slate200),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Soft-tinted icon disc — same chrome as the empty state
            // patterns used by Buku Nilai / Raport hubs.
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ColorUtils.brandCobalt.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isReadOnly
                    ? Icons.lock_outline_rounded
                    : (hasFilters
                          ? Icons.filter_alt_off_rounded
                          : Icons.calendar_today_outlined),
                size: 26,
                color: ColorUtils.brandCobalt,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isReadOnly
                  ? lang.getTranslatedText(const {
                      'en': 'No schedules this year',
                      'id': 'Belum ada jadwal di tahun ini',
                    })
                  : (hasFilters
                        ? lang.getTranslatedText(const {
                            'en': 'No results',
                            'id': 'Tidak ada hasil',
                          })
                        : lang.getTranslatedText(const {
                            'en': 'No schedules yet',
                            'id': 'Belum ada jadwal',
                          })),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: ColorUtils.brandDarkBlue,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isReadOnly
                  ? lang.getTranslatedText(const {
                      'en':
                          'This academic year is read-only. Switch to the '
                          'current year to add or import.',
                      'id':
                          'Tahun ajaran ini hanya baca. Pindah ke tahun '
                          'berjalan untuk menambah atau import.',
                    })
                  : (hasFilters
                        ? lang.getTranslatedText(const {
                            'en':
                                'Try clearing filters or picking another day.',
                            'id': 'Coba bersihkan filter atau pilih hari lain.',
                          })
                        : lang.getTranslatedText(const {
                            'en':
                                'Add the first session manually, or import a '
                                'schedule sheet to bulk-populate.',
                            'id':
                                'Tambah sesi pertama manual, atau import '
                                'sheet jadwal sekaligus banyak.',
                          })),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: ColorUtils.slate600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // CTA row varies by flavour. Read-only AY: a single
            // status pill, no write CTAs (backend would 403 anyway).
            if (isReadOnly)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: ColorUtils.slate100,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: ColorUtils.slate200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: ColorUtils.slate600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lang.getTranslatedText(const {
                        'en': 'Read-only year',
                        'id': 'Hanya baca',
                      }),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              )
            else if (hasFilters)
              OutlinedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(
                  lang.getTranslatedText(const {
                    'en': 'Clear all filters',
                    'id': 'Bersihkan semua filter',
                  }),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColorUtils.brandCobalt,
                  side: BorderSide(color: ColorUtils.slate200),
                  minimumSize: const Size.fromHeight(40),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _importFromExcel,
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: Text(
                        lang.getTranslatedText(const {
                          'en': 'Import Excel',
                          'id': 'Import Excel',
                        }),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColorUtils.brandCobalt,
                        side: BorderSide(color: ColorUtils.slate200),
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openAddEditSheet,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                        lang.getTranslatedText(const {
                          'en': 'Add manually',
                          'id': 'Tambah Manual',
                        }),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorUtils.brandCobalt,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Fallback flat-row renderer when the [_dayList] reference data
  /// isn't loaded yet (e.g. very first paint). Skips tabs + sections
  /// and just lists each schedule with the new row card.
  List<Widget> _buildFlatRowCards({
    required List<dynamic> items,
    required LanguageProvider lang,
    required AdminScheduleController ctrl,
  }) {
    if (items.isEmpty) return [_buildEmptyListCard(lang)];
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (items[i] is! Map) continue;
      final m = Map<String, dynamic>.from(items[i] as Map);
      final id = m['id']?.toString() ?? '';
      widgets.add(
        Padding(
          padding: EdgeInsets.fromLTRB(16, i == 0 ? 6 : 8, 16, 0),
          child: AdminScheduleRowCard(
            schedule: m,
            startTimeLabel: (m['start_time'] ?? '').toString(),
            endTimeLabel: (m['end_time'] ?? '').toString(),
            durationLabel: _formatDuration(m),
            subjectName:
                (m['subject_name'] ?? m['mata_pelajaran_nama'] ?? 'No Subject')
                    .toString(),
            className: (m['class_name'] ?? m['kelas_nama'] ?? '').toString(),
            teacherName: (m['teacher_name'] ?? m['guru_nama'] ?? '').toString(),
            roomName: (m['room'] ?? m['ruangan'] ?? '').toString(),
            selected: _selectedIds.contains(id),
            onTap: () =>
                _bulkMode ? _toggleSelection(id) : _showScheduleDetail(m),
            onLongPress: () => _toggleSelection(id),
          ),
        ),
      );
    }
    return widgets;
  }

  // ── List-mode helpers ──────────────────────────────────────────────

  /// Returns today's day_id from the loaded day list, or null when
  /// today is Sunday (Minggu is filtered out of the school week) or
  /// the day data hasn't loaded yet. Drives the default focused day
  /// in the Grid view.
  String? _todayDayId() {
    final source = _dayList.isNotEmpty ? _dayList : _availableDays;
    final now = DateTime.now();
    for (final d in source) {
      if (d is! Map) continue;
      final order = (d['order_number'] as num?)?.toInt();
      if (order == now.weekday) return d['id']?.toString();
    }
    return null;
  }

  /// Seeds [_focusedDayId] to today's day_id the first time the day
  /// list becomes available, so the Grid view opens zoomed in on
  /// today by default. After the initial seed the admin's pick wins
  /// — re-entering the screen doesn't reset their last focus.
  void _maybeSeedFocusedDay() {
    if (_focusedDaySeeded) return;
    final today = _todayDayId();
    if (today != null) {
      _focusedDayId = today;
      _focusedDaySeeded = true;
    }
  }

  /// Returns the visible weekdays (Senin → Sabtu) sorted by
  /// order_number. Minggu (order 7 or 0) is filtered out.
  List<Map<String, dynamic>> _visibleListDays() {
    final source = _dayList.isNotEmpty ? _dayList : _availableDays;
    final mapped = source
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    mapped.removeWhere((d) {
      final order = d['order_number'];
      if (order is num) return order == 7 || order == 0;
      final name = (d['name'] ?? '').toString().toLowerCase();
      return name == 'sunday' || name == 'minggu';
    });
    mapped.sort((a, b) {
      final ao = (a['order_number'] as num?)?.toInt() ?? 99;
      final bo = (b['order_number'] as num?)?.toInt() ?? 99;
      return ao.compareTo(bo);
    });
    return mapped;
  }

  /// Parses a schedule row's `start_time` into total minutes from
  /// midnight. Returns null when the field is missing / malformed.
  int? _parseStartMinutes(Map<String, dynamic> schedule) {
    final raw = (schedule['start_time'] ?? '').toString();
    if (raw.isEmpty) return null;
    final parts = raw.replaceAll('.', ':').split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// Formats a session's duration in minutes (e.g. "90 mnt") by
  /// diffing start_time and end_time. Returns null when either field
  /// is missing so the row card can hide the duration label entirely.
  String? _formatDuration(Map<String, dynamic> schedule) {
    final start = _parseStartMinutes(schedule);
    final endRaw = (schedule['end_time'] ?? '').toString();
    if (start == null || endRaw.isEmpty) return null;
    final endParts = endRaw.replaceAll('.', ':').split(':');
    if (endParts.length < 2) return null;
    final eh = int.tryParse(endParts[0]);
    final em = int.tryParse(endParts[1]);
    if (eh == null || em == null) return null;
    final end = eh * 60 + em;
    final diff = end - start;
    if (diff <= 0) return null;
    return '$diff mnt';
  }
}

/// 2-tab view toggle strip — Grid · List.
///
/// The legacy "Matrix" tab was dropped: it rendered a row=time × col=day
/// table (`AdminScheduleMatrixView`) which the new Grid view supersedes
/// on every dimension (color coding, drag-drop, now-line, density
/// layout, zoom-in day view). The matrix widget file stays on disk for
/// now but is no longer reachable from the UI.
class _ScheduleViewToggleStrip extends StatelessWidget {
  const _ScheduleViewToggleStrip({required this.mode, required this.onChanged});

  final ScheduleViewMode mode;
  final ValueChanged<ScheduleViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _tab(
            label: 'Grid',
            icon: Icons.grid_view_rounded,
            active: mode == ScheduleViewMode.grid,
            onTap: () => onChanged(ScheduleViewMode.grid),
          ),
          _tab(
            label: 'List',
            icon: Icons.view_agenda_outlined,
            active: mode == ScheduleViewMode.list,
            onTap: () => onChanged(ScheduleViewMode.list),
          ),
        ],
      ),
    );
  }

  Widget _tab({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: ColorUtils.slate900.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? ColorUtils.brandDarkBlue : ColorUtils.slate600,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: active
                      ? ColorUtils.brandDarkBlue
                      : ColorUtils.slate600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// View modes for the admin Jadwal hub.
///
/// Local to the schedule feature (not promoted to the shared
/// `ViewToggleButton.ViewMode` enum) because the labels + ordering are
/// schedule-specific (Grid is the new mockup default; Matrix is the
/// legacy timetable; List is the existing card list).
enum ScheduleViewMode { grid, list, matrix }

/// Backwards-compat alias — legacy code and tests may still reference the
/// long-form screen-state name. The mutable state class name was preserved
/// during the refactor so no callers need to change.
///
/// (No alias needed: [TeachingScheduleManagementScreenState] is already the
/// public state type.)
