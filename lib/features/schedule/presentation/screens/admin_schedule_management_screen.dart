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
//
// The List-view body builder + day/time helpers were split out into the
// `admin_schedule_list_body_mixin.dart` part file during the Phase-2
// readability refactor; this file remains the orchestrator that owns the
// state and composes the extracted pieces.
library;

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
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_view_toggle_strip.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/admin_schedule_list_states.dart';

part 'admin_schedule_list_body_mixin.dart';
part 'admin_schedule_actions_extension.dart';

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
  ///   `{ id, start_time, end_time, hour_number,
  ///      day: {id, name, order_number} }`
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
      final prefix = lp.getTranslatedText(const {
        'en': 'Failed to save schedule: ',
        'id': 'Gagal menyimpan jadwal: ',
      });
      SnackBarUtils.showError(
        context,
        '$prefix${ErrorUtils.getFriendlyMessage(e)}',
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

  /// Sets the List view's client-side day-tab filter. Lives on the state
  /// so the [_AdminScheduleListBody] extension (which can't call the
  /// protected [setState] directly) can flip the tab from its day-tab
  /// strip's `onChanged` callback.
  void _setActiveDayTab(String? id) {
    setState(() => _activeDayTab = id);
  }

  /// Sets the Grid view's zoomed-in focused day. Lives on the state so
  /// the [_AdminScheduleListBody] extension's `_buildViewBody` can wire
  /// the grid's `onFocusedDayChanged` callback without touching the
  /// protected [setState].
  void _setFocusedDayId(String? id) {
    setState(() => _focusedDayId = id);
  }

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

  /// Clears the bulk selection unconditionally inside a [setState].
  ///
  /// Lives on the state so the [_AdminScheduleActions] extension (which
  /// can't invoke the protected [setState]) can drop the selection after
  /// a bulk move / change-teacher / delete completes.
  void _clearSelectedIds() {
    setState(_selectedIds.clear);
  }

  /// Bulk-deletes every row in [_selectedIds] in a single server call.
  ///
  /// Uses the [ApiScheduleService.bulkDeleteSessions] endpoint (one
  /// transaction, one round-trip) instead of the legacy per-row
  /// `deleteSchedule` loop. After the call the list + KPI are refreshed
  /// and the selection is cleared. The success snack quotes the server's
  /// `deleted_count` so partial failures show up honestly.

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
      final prefix = lp.getTranslatedText(const {
        'en': 'Failed to import file: ',
        'id': 'Gagal mengimpor berkas: ',
      });
      SnackBarUtils.showError(
        context,
        '$prefix${ErrorUtils.getFriendlyMessage(e)}',
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
                child: ScheduleViewToggleStrip(
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
}

/// Backwards-compat alias — legacy code and tests may still reference the
/// long-form screen-state name. The mutable state class name was preserved
/// during the refactor so no callers need to change.
///
/// (No alias needed: [TeachingScheduleManagementScreenState] is already the
/// public state type.)
