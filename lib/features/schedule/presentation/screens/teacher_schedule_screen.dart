/// Teaching schedule screen — the teacher's timetable / calendar view.
///
/// Brand-aligned redesign (Jadwal P.3 — May 2026)
/// ----------------------------------------------
/// Replaces the legacy `TeacherPageHeader` shell with the same brand
/// chrome shipped on Presensi / Kegiatan Kelas / Rekap Nilai / RPP /
/// Buku Nilai:
///
///   • [BrandPageHeader] — cobalt gradient, kicker `Jadwal Mengajar`
///     with inline live dot, title `Pekan Ini` (or `Wali · 7A` in
///     homeroom mode), centered. Action icons: filter (with badge) +
///     view-toggle (card/table). Back button auto-resolves.
///   • [RoleToggleChipRow] in `childSelector` slot — Mengajar plus one
///     chip per homeroom class (`Wali · 7A`, `Wali · 8B`).
///   • Pinned KPI strip below the header — Sesi/Pekan, Hari Ini,
///     Mapel, Kelas (or Pengajar in wali mode). Computed client-side
///     from the loaded schedule list.
///   • [TeacherTodayBanner] — cobalt gradient banner at the top of the
///     body showing the day's progress (`X selesai dari Y`) plus the
///     live or next subject. Renders only when there are schedules
///     today.
///   • Body: kept as `TeacherAsyncView` with its own scrollable. We
///     don't wrap in BrandPageLayout because the inner scrollable would
///     nest inside a ListView and throw "vertical viewport given
///     unbounded height" — same trade-off Buku Nilai made.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/role_toggle_chip_row.dart';
import 'package:manajemensekolah/core/widgets/teacher_async_view.dart';
import 'package:manajemensekolah/core/widgets/teacher_role_options.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/teacher_schedule_card_view.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/teacher_schedule_table_view.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/teacher_today_banner.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/teacher_schedule_data_loading_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/teacher_schedule_cache_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/teacher_schedule_filter_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/teacher_schedule_preferences_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/teacher_schedule_ui_mixin.dart';

/// Teacher's weekly schedule screen with card and table view modes.
class TeachingScheduleScreen extends ConsumerStatefulWidget {
  const TeachingScheduleScreen({super.key});

  @override
  TeachingScheduleScreenState createState() => TeachingScheduleScreenState();
}

/// State for [TeachingScheduleScreen].
/// Manages schedule display, filtering, view modes, and real-time sync.
class TeachingScheduleScreenState extends ConsumerState<TeachingScheduleScreen>
    with
        TeacherScheduleDataLoadingMixin,
        TeacherScheduleCacheMixin,
        TeacherScheduleFilterMixin,
        TeacherSchedulePreferencesMixin,
        TeacherScheduleUiMixin {
  // Widget anchor keys — exposed via the getter bridge below to the
  // header/card mixins. Originally targets for the onboarding tour;
  // the tour was retired but the keys still anchor real widgets.
  final GlobalKey _toggleViewKey = GlobalKey();
  final GlobalKey _searchFilterKey = GlobalKey();
  final GlobalKey _firstScheduleKey = GlobalKey();
  final GlobalKey _actionButtonsKey = GlobalKey();

  final TextEditingController _searchController = TextEditingController();

  /// True only until the first schedule load completes. Controls whether the
  /// card view auto-scrolls to the current/next lesson.
  bool _isInitialLoad = true;

  GlobalKey get toggleViewKey => _toggleViewKey;
  GlobalKey get searchFilterKey => _searchFilterKey;
  GlobalKey get firstScheduleKey => _firstScheduleKey;
  GlobalKey get actionButtonsKey => _actionButtonsKey;

  @override
  void initState() {
    super.initState();
    setDefaultAcademicPeriod();
    loadUserData().then((_) {
      if (!mounted) return;
      loadSchedule(
        searchController: _searchController,
        selectedDayIds: selectedDayIdsInternal,
        selectedClassId: selectedClassIdInternal,
        selectedFilterSemester: selectedFilterSemesterInternal,
        dayIdMap: dayIdMapInternal,
      ).then((_) {
        if (mounted) _isInitialLoad = false;
      });
    });
    loadViewPreference();
    FCMService().syncTrigger.addListener(onSyncTriggered);
  }

  @override
  void dispose() {
    FCMService().syncTrigger.removeListener(onSyncTriggered);
    _searchController.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(languageRiverpod);
    final filteredSchedules = getFilteredSchedules(
      scheduleList,
      _searchController.text,
    );

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _buildBrandHeader(lp),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _buildKpiStrip(filteredSchedules),
          ),
          if (filteredSchedules.isNotEmpty)
            TeacherTodayBanner(
              allSchedules: filteredSchedules,
              dailySummary: dailySummary,
            ),
          Expanded(child: _buildBody(lp, filteredSchedules)),
        ],
      ),
    );
  }

  // ── Brand header ─────────────────────────────────────────────────

  Widget _buildBrandHeader(LanguageProvider lp) {
    final activeFilters = hasActiveFilter ? buildFilterChipsForCount() : 0;
    final isWali = isHomeroomView && (selectedHomeroomClass?['name'] != null);
    final title = isWali
        ? 'Wali · ${selectedHomeroomClass!['name']}'
        : lp.getTranslatedText({'en': 'This Week', 'id': 'Pekan Ini'});

    return BrandPageHeader(
      role: 'guru',
      subtitle: lp.getTranslatedText({
        'en': 'Teaching Schedule',
        'id': 'Jadwal Mengajar',
      }),
      title: title,
      isRealtimeFresh: true,
      kpiOverlayHeight: 0,
      actionIcons: [
        BrandHeaderIconButton(
          icon: isTableView
              ? Icons.view_agenda_rounded
              : Icons.calendar_view_week_rounded,
          // `toggleView` flips the bool AND persists it via
          // LocalCacheService — same call site Buku Nilai uses for
          // its card/table preference.
          onTap: toggleView,
        ),
        BrandHeaderIconButton(
          icon: Icons.tune_rounded,
          onTap: () => showFilterSheet(
            getPrimaryColor(),
            ref.read(languageRiverpod),
            selectedTerm,
            ({
              required dayIdMap,
              required searchController,
              required selectedDayIds,
              required selectedClassId,
              required selectedFilterSemester,
            }) => loadSchedule(
              useCache: true,
              searchController: searchController,
              selectedDayIds: selectedDayIds,
              selectedClassId: selectedClassId,
              selectedFilterSemester: selectedFilterSemester,
              dayIdMap: dayIdMap,
            ),
            _searchController,
          ),
          badgeCount: activeFilters > 0 ? activeFilters : null,
          badgeBorderColor: ColorUtils.brandDarkBlue,
        ),
      ],
      childSelector: _buildRoleSelector(lp),
      bottomSlot: _buildSearchOrChips(lp),
    );
  }

  /// Returns the count of active filters for the badge — same logic as
  /// `buildFilterChips` but cheaper (no widget construction).
  int buildFilterChipsForCount() {
    var count = selectedDayIdsInternal.length;
    if (selectedClassIdInternal != null) count++;
    if (selectedFilterSemesterInternal != null &&
        selectedFilterSemesterInternal != selectedTerm) {
      count++;
    }
    return count;
  }

  /// Mengajar / Wali · 7A / Wali · 8B chip strip. Returns null when
  /// the teacher has no homeroom classes — `BrandPageHeader` will skip
  /// the slot entirely.
  Widget? _buildRoleSelector(LanguageProvider lp) {
    if (homeroomClassesList.isEmpty) return null;
    final selectedId = isHomeroomView && selectedHomeroomClass?['id'] != null
        ? 'wali:${selectedHomeroomClass!['id']}'
        : 'mengajar';
    return RoleToggleChipRow(
      roles: buildMultiWaliRoleOptions(
        homeroomClasses: homeroomClassesList,
        lp: lp,
      ),
      selectedRoleId: selectedId,
      accentColor: ColorUtils.brandCobalt,
      onSelected: (id) {
        if (id == 'mengajar') {
          if (!isHomeroomView) return;
          setState(() {
            isHomeroomView = false;
            scheduleList = [];
            isLoading = true;
          });
        } else {
          // wali:<classId>
          final classId = id.substring('wali:'.length);
          final cls = homeroomClassesList.firstWhere(
            (c) => (c is Map ? c['id']?.toString() : '') == classId,
            orElse: () => homeroomClassesList.first,
          );
          setState(() {
            isHomeroomView = true;
            selectedHomeroomClass = Map<String, dynamic>.from(cls as Map);
            scheduleList = [];
            isLoading = true;
          });
        }
        loadSchedule(
          useCache: true,
          searchController: _searchController,
          selectedDayIds: selectedDayIds,
          selectedClassId: selectedClassId,
          selectedFilterSemester: selectedFilterSemester,
          dayIdMap: dayIdMap,
        );
      },
    );
  }

  /// Bottom slot under the title — currently surfaces the active
  /// filters as a `BrandFilterChipStrip`. The strip auto-hides when
  /// no filters are applied.
  Widget? _buildSearchOrChips(LanguageProvider lp) {
    if (!hasActiveFilter) return null;

    final chips = <BrandFilterChip>[];

    // Day chips (one per selected day).
    for (final dayId in selectedDayIdsInternal) {
      final dayName = dayOptionsInternal.firstWhere(
        (n) => dayIdMapInternal[n] == dayId,
        orElse: () => 'Hari',
      );
      chips.add(
        BrandFilterChip(
          label: kDay.tr,
          value: dayName,
          showChevron: false,
          onTap: () {
            setState(() {
              selectedDayIdsInternal.remove(dayId);
              checkActiveFilter(selectedTerm);
            });
            loadSchedule(
              useCache: true,
              searchController: _searchController,
              selectedDayIds: selectedDayIdsInternal,
              selectedClassId: selectedClassIdInternal,
              selectedFilterSemester: selectedFilterSemesterInternal,
              dayIdMap: dayIdMapInternal,
            );
          },
        ),
      );
    }

    // Class chip.
    if (selectedClassIdInternal != null) {
      final cls = availableClassesInternal.firstWhere(
        (c) => c['id'] == selectedClassIdInternal,
        orElse: () => {'name': 'Kelas'},
      );
      chips.add(
        BrandFilterChip(
          label: kClass.tr,
          value: cls['name'] ?? 'Kelas',
          showChevron: false,
          onTap: () {
            setState(() {
              selectedClassIdInternal = null;
              checkActiveFilter(selectedTerm);
            });
            loadSchedule(
              useCache: true,
              searchController: _searchController,
              selectedDayIds: selectedDayIdsInternal,
              selectedClassId: selectedClassIdInternal,
              selectedFilterSemester: selectedFilterSemesterInternal,
              dayIdMap: dayIdMapInternal,
            );
          },
        ),
      );
    }

    // Semester chip — only when overridden from the default.
    if (selectedFilterSemesterInternal != null &&
        selectedFilterSemesterInternal != selectedTerm) {
      final semester = termListInternal.firstWhere(
        (s) => s['id'].toString() == selectedFilterSemesterInternal,
        orElse: () => {'nama': 'Smt $selectedFilterSemesterInternal'},
      );
      chips.add(
        BrandFilterChip(
          label: kSchSemester.tr,
          value: (semester['nama'] ?? 'Smt').toString(),
          showChevron: false,
          onTap: () {
            setState(() {
              selectedFilterSemesterInternal = null;
              checkActiveFilter(selectedTerm);
            });
            loadSchedule(
              useCache: true,
              searchController: _searchController,
              selectedDayIds: selectedDayIdsInternal,
              selectedClassId: selectedClassIdInternal,
              selectedFilterSemester: selectedFilterSemesterInternal,
              dayIdMap: dayIdMapInternal,
            );
          },
        ),
      );
    }

    if (chips.isEmpty) return null;
    return BrandFilterChipStrip(chips: chips);
  }

  // ── KPI strip ────────────────────────────────────────────────────

  Widget _buildKpiStrip(List<dynamic> schedules) {
    final stats = _kpiStats(schedules);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _kpiCell(
              '${stats.weekTotal}',
              kSchSessionsPerWeek.tr,
              ColorUtils.brandCobalt,
            ),
            _kpiDivider(),
            _kpiCell('${stats.todayCount}', kSchToday.tr, ColorUtils.success600),
            _kpiDivider(),
            _kpiCell('${stats.subjectCount}', kSchSubjects.tr, ColorUtils.warning600),
            _kpiDivider(),
            _kpiCell(
              '${stats.fourthCount}',
              isHomeroomView ? kSchTeachers.tr : kSchClasses.tr,
              ColorUtils.slate700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCell(String value, String label, Color color) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.3,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiDivider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: ColorUtils.slate100,
    );
  }

  ({int weekTotal, int todayCount, int subjectCount, int fourthCount})
  _kpiStats(List<dynamic> schedules) {
    final today = DateTime.now();
    final todayName = _todayIndoName(today.weekday);
    final subjectIds = <String>{};
    final classIds = <String>{};
    final teacherIds = <String>{};
    var todayCount = 0;

    for (final s in schedules) {
      if (s is! Map) continue;
      final m = Schedule.fromJson(Map<String, dynamic>.from(s));
      if ((m.subjectId ?? '').isNotEmpty) subjectIds.add(m.subjectId!);
      if ((m.classId ?? '').isNotEmpty) classIds.add(m.classId!);
      if ((m.teacherId ?? '').isNotEmpty) teacherIds.add(m.teacherId!);
      final raw = (m.dayName ?? '').toLowerCase();
      if (raw.contains(todayName.toLowerCase()) ||
          raw.contains(_todayEngName(today.weekday).toLowerCase())) {
        todayCount++;
      }
    }

    return (
      weekTotal: schedules.length,
      todayCount: todayCount,
      subjectCount: subjectIds.length,
      fourthCount: isHomeroomView ? teacherIds.length : classIds.length,
    );
  }

  static String _todayIndoName(int wd) => switch (wd) {
    DateTime.monday => 'Senin',
    DateTime.tuesday => 'Selasa',
    DateTime.wednesday => 'Rabu',
    DateTime.thursday => 'Kamis',
    DateTime.friday => 'Jumat',
    DateTime.saturday => 'Sabtu',
    _ => 'Minggu',
  };

  static String _todayEngName(int wd) => switch (wd) {
    DateTime.monday => 'Monday',
    DateTime.tuesday => 'Tuesday',
    DateTime.wednesday => 'Wednesday',
    DateTime.thursday => 'Thursday',
    DateTime.friday => 'Friday',
    DateTime.saturday => 'Saturday',
    _ => 'Sunday',
  };

  // ── Body — async view + card/table swap ─────────────────────────

  Widget _buildBody(LanguageProvider lp, List<dynamic> filteredSchedules) {
    return TeacherAsyncView(
      isLoading: isLoading,
      errorMessage: errorMessage,
      isEmpty: filteredSchedules.isEmpty,
      onRefresh: () => forceRefresh(
        _searchController,
        selectedDayIds,
        selectedClassId,
        selectedFilterSemester,
        dayIdMap,
        ({
          required searchController,
          required selectedDayIds,
          required selectedClassId,
          required selectedFilterSemester,
        }) => loadSchedule(
          useCache: true,
          searchController: searchController,
          selectedDayIds: selectedDayIds,
          selectedClassId: selectedClassId,
          selectedFilterSemester: selectedFilterSemester,
          dayIdMap: dayIdMap,
        ),
      ),
      role: 'guru',
      emptyTitle: lp.getTranslatedText({
        'en': 'No Teaching Schedules',
        'id': 'Belum ada jadwal',
      }),
      emptySubtitle: lp.getTranslatedText({
        'en': _searchController.text.isNotEmpty || hasActiveFilter
            ? 'No schedules found for search and filters'
            : 'There are no teaching schedules available',
        'id': _searchController.text.isNotEmpty || hasActiveFilter
            ? 'Tidak ada jadwal yang sesuai filter'
            : 'Tidak ada jadwal mengajar pekan ini',
      }),
      emptyIcon: Icons.calendar_today_rounded,
      childBuilder: () => isTableView
          ? TeacherScheduleTableView(
              schedules: filteredSchedules,
              dayIdMap: dayIdMap,
              dayColorMap: dayColorMap,
              dayOptions: dayOptions,
              primaryColor: getPrimaryColor(),
              teacherId: teacherId,
              teacherNama: teacherNama,
              dailySummary: dailySummary,
              isHomeroomView: isHomeroomView,
              onRefresh: () => forceRefresh(
                _searchController,
                selectedDayIds,
                selectedClassId,
                selectedFilterSemester,
                dayIdMap,
                ({
                  required searchController,
                  required selectedDayIds,
                  required selectedClassId,
                  required selectedFilterSemester,
                }) => loadSchedule(
                  useCache: true,
                  searchController: searchController,
                  selectedDayIds: selectedDayIds,
                  selectedClassId: selectedClassId,
                  selectedFilterSemester: selectedFilterSemester,
                  dayIdMap: dayIdMap,
                ),
              ),
              languageProvider: lp,
            )
          : TeacherScheduleCardView(
              schedules: filteredSchedules,
              languageProvider: lp,
              dayIdMap: dayIdMap,
              dayColorMap: dayColorMap,
              dayOptions: dayOptions,
              selectedAcademicYear: selectedAcademicYear,
              teacherId: teacherId,
              teacherNama: teacherNama,
              firstScheduleKey: _firstScheduleKey,
              actionButtonsKey: _actionButtonsKey,
              dailySummary: dailySummary,
              onRefresh: refreshDailySummary,
              isHomeroomView: isHomeroomView,
              autoScroll: _isInitialLoad,
            ),
    );
  }
}
