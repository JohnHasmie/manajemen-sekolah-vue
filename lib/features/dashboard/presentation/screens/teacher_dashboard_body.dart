// Teacher dashboard body (guru) — mirrors admin Phase 3 redesign with teal
// gradient.
//
// Shape of the screen (top-to-bottom)
// -----------------------------------
//   1. DashboardAppBar   — school name, lang, bell, profile
//   2. Teal gradient hero — SchoolPill.expanded + realtime indicator
//   3. KPI row (2x2 grid) — 4 cards: Siswa diampu, Kelas, Sesi hari ini, RPP
//   4. Perlu perhatian    — server-ranked priority inbox (FF.* series)
//   5. Aksi cepat         — 4 quick action tiles
//                           (Jadwal, Absensi, Aktivitas, Nilai)
//   6. Modul lain strip   — horizontal with overflow sheet
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/constants/dashboard_modules.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/academic_year_chip.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/brand_kpi_carousel.dart';
import 'package:manajemensekolah/core/widgets/hero_stats_card.dart';
import 'package:manajemensekolah/core/widgets/pending_inbox_card.dart';
import 'package:manajemensekolah/core/widgets/quick_action_grid.dart';
import 'package:manajemensekolah/core/widgets/role_dashboard_hero.dart';
import 'package:manajemensekolah/core/widgets/school_pill.dart';
import 'package:manajemensekolah/core/widgets/modul_lain_strip.dart';

import 'package:manajemensekolah/features/announcements/presentation/screens/teacher_announcement_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';
import 'package:manajemensekolah/features/dashboard/data/priority_inbox_snooze_store.dart';
import 'package:manajemensekolah/features/dashboard/domain/models/priority_inbox_item.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/providers/academic_year_provider.dart';
import 'package:manajemensekolah/features/dashboard/presentation/screens/teacher_inbox_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/academic_year_picker_sheet.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/priority_inbox_snooze_sheet.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/teacher_dashboard_hero_widgets.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_input_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_recap_overview.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/teacher_lesson_plan_screen.dart';
import 'package:manajemensekolah/features/teachers/presentation/providers/teacher_provider.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/recommendations/data/recommendation_service.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_class_screen.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_result_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/teacher_schedule_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/settings_screen.dart';
import 'package:manajemensekolah/features/teacher_attendance/presentation/screens/teacher_presensi_screen.dart';

// Teacher = "between admin and parent" in the brand. The hero gradient
// literally combines both brand colors (Dark Blue → Azzure Blue), which
// echoes the role's job: managing data like admin, day-to-day with
// students/parents like the parent role.
//
// Solid-color accents (Lihat semua link, "+N Lainnya" tile, school pill,
// inbox header) use the brand's HSL midpoint — a "Cobalt Blue" — so the
// teacher reads as its OWN identity rather than borrowing admin's dark
// blue or parent's azure. Tokens live in `ColorUtils` so a brand refresh
// updates one place; `ColorUtils.getRoleColor('guru')` returns cobalt.
final Color _teacherBrandDark = ColorUtils.brandDarkBlue;

final Color _teacherCobalt = ColorUtils.brandCobalt;
const Duration _pollInterval = Duration(seconds: 60);

/// Teacher dashboard body.
class TeacherDashboardBody extends ConsumerStatefulWidget {
  final Color primaryColor;
  final DashboardState state;
  final GlobalKey profileHeaderKey;
  final GlobalKey heroSectionKey;
  final GlobalKey quickActionsKey;
  final GlobalKey statsSectionKey;

  final VoidCallback onLanguageTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onAccountTap;
  final VoidCallback onSchoolSwitchTap;

  const TeacherDashboardBody({
    super.key,
    required this.primaryColor,
    required this.state,
    required this.profileHeaderKey,
    required this.heroSectionKey,
    required this.quickActionsKey,
    required this.statsSectionKey,
    required this.onLanguageTap,
    required this.onNotificationTap,
    required this.onAccountTap,
    required this.onSchoolSwitchTap,
  });

  @override
  ConsumerState<TeacherDashboardBody> createState() =>
      _TeacherDashboardBodyState();
}

class _TeacherDashboardBodyState extends ConsumerState<TeacherDashboardBody> {
  Timer? _pollTimer;
  DateTime _lastSync = DateTime.now();
  bool _isFresh = true;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollStats());
  }

  Future<void> _pollStats() async {
    if (!mounted) return;
    try {
      await ref.read(dashboardProvider.notifier).refreshStats();
      if (!mounted) return;
      setState(() {
        _lastSync = DateTime.now();
        _isFresh = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFresh = false);
    }
  }

  Future<void> _manualRefresh() async {
    try {
      await ref.read(dashboardProvider.notifier).pullToRefresh();
      if (!mounted) return;
      setState(() {
        _lastSync = DateTime.now();
        _isFresh = true;
      });
      _startPolling();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFresh = false);
      rethrow;
    }
  }

  String get _schoolName {
    final ud = widget.state.userData;
    final raw = (ud['school_name'] ?? ud['nama_sekolah'])?.toString().trim();
    if (raw == null || raw.isEmpty) return AppLocalizations.dbSchool.tr;
    return raw;
  }

  String get _greetingSubtitle {
    final year = widget.state.userData['academic_year']?.toString();
    if (year == null || year.isEmpty) return AppLocalizations.dbTeacher.tr;
    return '${AppLocalizations.dbTeacher.tr} · TP $year';
  }

  String get _userName {
    final raw = widget.state.userData['name']?.toString().trim();
    return (raw == null || raw.isEmpty) ? AppLocalizations.dbTeacher.tr : raw;
  }

  /// Display label for the academic-year chip in the hero. Watches
  /// `academicYearRiverpod` so the chip updates when the user picks a
  /// different year via [showAcademicYearPickerSheet].
  String get _academicYearLabel {
    final year = ref.watch(academicYearRiverpod).selectedAcademicYear;
    return year?['year']?.toString() ?? '—';
  }

  // Server-ranked Perlu Perhatian rows. Backend caps at 5 and ranks
  // by severity × recency. Empty list ⇒ render "Semua aman" empty
  // state; null (feature flag off) is treated as empty.
  //
  // GG.9 — locally-snoozed items are filtered out before render.
  // The snooze store is in-memory (hydrated on app bootstrap via
  // service_locator), so this is a cheap O(n) check.
  List<PriorityInboxItem> get _priorityInbox {
    final raw = PriorityInboxItem.parseList(
      widget.state.stats['priority_inbox'],
    );
    final store = PriorityInboxSnoozeStore.instance;
    final now = DateTime.now();
    return raw
        .where((item) => !store.isSnoozed(item.id, now: now))
        .toList(growable: false);
  }

  // Derived counts used in the UI. Fallback to 0 if data is missing.

  static int _asInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  // Navigation handlers
  void _openSchedule() =>
      AppNavigator.push(context, const TeachingScheduleScreen());

  void _openMaterials() => AppNavigator.push(
    context,
    TeacherMaterialScreen(teacher: widget.state.userData),
  );

  void _openLessonPlans() {
    final tp = ref.read(teacherRiverpod);
    final tId =
        tp.teacherId ?? widget.state.userData['teacher_id']?.toString() ?? '';
    if (tId.isEmpty) return;
    AppNavigator.push(
      context,
      LessonPlanScreen(
        teacherId: tId,
        teacherName:
            tp.teacherName ??
            widget.state.userData['name']?.toString() ??
            'Guru',
      ),
    );
  }

  void _openGrades() {
    final tp = ref.read(teacherRiverpod);
    AppNavigator.push(
      context,
      GradePage(
        teacher: {
          'id': tp.teacherId ?? '',
          'nama': tp.teacherName ?? 'Guru',
          'email': widget.state.userData['email'] ?? '',
          'role': 'guru',
        },
      ),
    );
  }

  void _openAttendance() => AppNavigator.push(
    context,
    AttendancePage(teacher: widget.state.userData),
  );

  void _openActivities() => AppNavigator.push(
    context,
    const TeacherClassActivityScreen(autoShowActivityDialog: true),
  );

  void _openAnnouncementDrafts() =>
      AppNavigator.push(context, const TeacherAnnouncementScreen());

  /// Builds a slim teacher map matching the shape that the grade /
  /// recommendation / report-card screens expect when constructed
  /// outside the Lainnya hub. Centralised here so each navigation
  /// handler doesn't repeat the same null-coalescing.
  Map<String, dynamic> _teacherPayload() {
    final user = widget.state.userData;
    return {
      'id': (user['teacher_id'] ?? user['id'])?.toString() ?? '',
      'nama': (user['nama'] ?? user['name'] ?? 'Guru').toString(),
      'email': (user['email'] ?? '').toString(),
      'role': 'guru',
    };
  }

  /// Rekap Nilai overview — distinct from `_openGrades` which opens
  /// the per-class Buku Nilai input screen. The Modul lain "Rekap
  /// Nilai" tile previously routed here too, sending teachers to the
  /// wrong screen.
  void _openGradeRecap() => AppNavigator.push(
    context,
    GradeRecapOverviewPage(teacher: _teacherPayload()),
  );

  /// Rekomendasi Belajar (wali-kelas only). Mirrors the Lainnya hub's
  /// gate — if the teacher has no homeroom class assignment, surface
  /// an info snackbar instead of opening an empty screen.
  void _openRecommendation() {
    final classes = widget.state.homeroomClasses;
    if (classes.isEmpty) {
      SnackBarUtils.showInfo(
        context,
        'Rekomendasi Belajar hanya tersedia untuk wali kelas.',
      );
      return;
    }
    final payload = _teacherPayload();
    if ((payload['id'] as String).isEmpty) {
      SnackBarUtils.showInfo(context, 'ID guru tidak ditemukan.');
      return;
    }
    AppNavigator.push(
      context,
      LearningRecommendationClassScreen(
        teacher: payload.cast<String, String>(),
        classes: classes,
      ),
    );
  }

  /// Akun → settings screen (same destination as the app-bar avatar
  /// and the Lainnya hub's Akun row).
  void _openAccount() => AppNavigator.push(context, const SettingsScreen());

  /// Presensi Guru → the teacher's OWN daily check-in / check-out.
  /// Distinct from `_openAttendance` (which opens the student-attendance
  /// taker). The screen bootstraps itself from the config endpoint, so
  /// no payload is needed here.
  void _openTeacherPresensi() =>
      AppNavigator.push(context, const TeacherPresensiScreen());

  // NOTE: `_openReportCards` (the Raport overview entry point) was
  // removed together with the "Raport" tile per Luay's request — the
  // teacher dashboard no longer surfaces the Raport module here. The
  // report-card flow stays reachable via the priority-inbox
  // `report_card_class` deep-link, which uses [ReportCardScreen]
  // through `_openReportCardClass` below.

  @override
  Widget build(BuildContext context) {
    // Watch language provider to rebuild when language changes.
    ref.watch(languageRiverpod);

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: AppRefreshIndicator(
        onRefresh: _manualRefresh,
        color: widget.primaryColor,
        edgeOffset: MediaQuery.of(context).padding.top,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              key: widget.heroSectionKey,
              child: _buildHeroWithKpiOverlay(context),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            SliverToBoxAdapter(child: _buildInboxCard()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverToBoxAdapter(
              key: widget.quickActionsKey,
              child: _buildQuickActions(),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverToBoxAdapter(child: _buildModulLain()),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }

  /// Combined hero + KPI section matching the Phase 3 mockup pattern.
  /// Edge-to-edge teal gradient under the system status bar with rounded
  /// bottom corners; greeting + name + icon row at top, then realtime,
  /// school pill, and KPI cards floating onto the bottom edge.
  Widget _buildHeroWithKpiOverlay(BuildContext context) {
    final notifBadge =
        _asInt(widget.state.stats['unread_notifications']) +
        _asInt(widget.state.stats['unread_announcements']);
    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Shared dashboard hero shell (HH.7) — gradient + radius +
          // shadow + status-bar-aware padding live in
          // [RoleDashboardHero]. The 100dp bottomOverlap leaves an
          // empty teal band where the KPI carousel floats; matches
          // admin / parent so the carousel lands at the same anchor.
          RoleDashboardHero(
            role: 'guru',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppLocalizations.greeting(DateTime.now().hour),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.72),
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.1,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TeacherDashboardHeroIconButton(
                      icon: Icons.language_outlined,
                      onTap: widget.onLanguageTap,
                      gradientBg: _teacherBrandDark,
                    ),
                    const SizedBox(width: 6),
                    TeacherDashboardHeroIconButton(
                      icon: Icons.notifications_outlined,
                      onTap: widget.onNotificationTap,
                      gradientBg: _teacherBrandDark,
                      showDot: notifBadge > 0,
                    ),
                    const SizedBox(width: 6),
                    TeacherDashboardHeroIconButton(
                      icon: Icons.person_outline,
                      onTap: widget.onAccountTap,
                      gradientBg: _teacherBrandDark,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TeacherDashboardRealtimePill(
                  isFresh: _isFresh,
                  lastSync: _lastSync,
                ),
                const SizedBox(height: AppSpacing.md),
                // School pill (flex 3) + tahun-ajaran chip (flex 2)
                // side-by-side, mirroring the parent dashboard. The
                // pill ellipsises on narrow screens; the chip stays
                // legible. Tapping the chip opens the same shared
                // academic-year picker sheet — single source of truth
                // for the year context across all three role
                // dashboards.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: SchoolPill.expanded(
                          schoolName: _schoolName,
                          subtitle: _greetingSubtitle,
                          onTap: widget.onSchoolSwitchTap,
                          accentColor: _teacherCobalt,
                          actionLabel: 'Ganti',
                          onDarkSurface: true,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 2,
                        child: AcademicYearChip(
                          yearLabel: _academicYearLabel,
                          semesterLabel: widget.state.currentSemesterLabel
                              ?.replaceAll(RegExp(r'\s*[-–—·].*'), '')
                              .trim(),
                          onTap: () => showAcademicYearPickerSheet(
                            context: context,
                            ref: ref,
                            currentSemesterLabel:
                                widget.state.currentSemesterLabel,
                            role: 'guru',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // KPI strip floats at the bottom of the gradient. Edge-to-edge
          // (left: 0, right: 0) — BrandKpiCarousel applies its own 16dp
          // horizontal padding so we don't double-pad. Matches admin /
          // parent positioning.
          Positioned(
            key: widget.statsSectionKey,
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildKpiCards(),
          ),
        ],
      ),
    );
  }

  /// Build the teacher KPI carousel — same pattern as admin / parent.
  ///
  /// Slice axis (auto-cycles ~6 s, story-style progress strip):
  ///   • Mengajar      — all teaching classes, today scope
  ///   • Wali `<X>`      — one slice per homeroom class held
  ///   • Hari Ini      — time view, today
  ///   • Pekan Ini     — time view, current week
  ///
  /// 4 cards per slice → 2 pages (perPage=2):
  ///   Page 1: Sesi Hari Ini · Kehadiran (with delta vs prior window)
  ///   Page 2: RPP (status mix) · Nilai Belum Input
  ///
  /// Auto-slide is on; tap pauses (matches admin / wali murid). With
  /// only one slice (teacher with no homeroom + backend without slices
  /// yet), the slice strip is suppressed automatically by the carousel.
  Widget _buildKpiCards() {
    final slices = _parseGuruSlices(widget.state.stats);
    return BrandKpiCarousel(
      scope: 'teacher_dashboard',
      sliceCount: slices.length,
      autoSlideCards: true,
      cardBuilder: (sliceIndex) {
        final slice = slices[sliceIndex.clamp(0, slices.length - 1)];
        return _buildGuruSliceCards(slice);
      },
    );
  }

  List<HeroStatsCard> _buildGuruSliceCards(_GuruSlice slice) {
    // TODO(i18n): promote the inline copy below to AppLocalizations
    // once the EN strings are signed off. Mirrors admin/parent
    // dashboards which already mix literal id-locale strings for
    // late-binding labels — keeps this migration shippable without
    // touching the (large) localization tables.
    final isEn = AppLocalizations.dbTeacher.tr != 'Guru';

    // Card 1 — Sesi Hari Ini (with done/total ratio)
    final sessionsCaption = slice.sessionsToday > 0
        ? '${slice.sessionsTodayDone} ${isEn ? 'done' : 'selesai'} · '
              '${slice.sessionsToday - slice.sessionsTodayDone} '
              '${isEn ? 'pending' : 'belum'}'
        : (isEn ? 'No sessions today' : 'Tidak ada sesi hari ini');

    // Card 2 — Kehadiran (with delta if non-zero)
    final attendanceTrend = slice.attendanceDelta == 0
        ? null
        : StatTrend(
            direction: slice.attendanceDelta > 0
                ? StatTrendDirection.up
                : StatTrendDirection.down,
            label:
                '${slice.attendanceDelta > 0 ? '+' : ''}'
                '${slice.attendanceDelta}%',
          );

    // Card 3 — RPP status mix. Pending+revision drives the warning
    // accent so the teacher's eye lands on what needs attention.
    final rppNeedsAttention =
        slice.lessonPlansPending + slice.lessonPlansRevision;
    final rppCaption = rppNeedsAttention > 0
        ? '${slice.lessonPlansPending} ${isEn ? 'waiting' : 'menunggu'} · '
              '${slice.lessonPlansRevision} ${isEn ? 'revision' : 'revisi'}'
        : '${slice.lessonPlansApproved} '
              '${AppLocalizations.dbApproved.tr.toLowerCase()}';

    // Card 4 — Nilai Belum Input
    final gradesCaption = slice.gradesPendingSessions > 0
        ? (isEn ? 'Needs grade input' : 'Butuh input nilai')
        : (isEn ? 'All grades in' : 'Semua nilai masuk');

    return [
      HeroStatsCard(
        label: AppLocalizations.dbSessionsToday.tr,
        sliceLabel: slice.label,
        sliceLabelMuted: slice.isAggregate,
        value: _formatNumber(slice.sessionsToday),
        icon: Icons.schedule_outlined,
        accentColor: widget.primaryColor,
        caption: sessionsCaption,
        onTap: _openSchedule,
      ),
      HeroStatsCard(
        label: isEn ? 'Attendance' : 'Kehadiran',
        sliceLabel: slice.label,
        sliceLabelMuted: slice.isAggregate,
        value: '${slice.attendanceRateWindow}%',
        icon: Icons.check_circle_outline_rounded,
        accentColor: ColorUtils.success600,
        caption: isEn ? 'avg this period' : 'rata-rata periode',
        trend: attendanceTrend,
        onTap: _openAttendance,
      ),
      HeroStatsCard(
        label: isEn ? 'Lesson Plans' : 'RPP',
        sliceLabel: slice.label,
        sliceLabelMuted: slice.isAggregate,
        value: _formatNumber(slice.lessonPlansApproved),
        icon: Icons.description_outlined,
        accentColor: rppNeedsAttention > 0
            ? ColorUtils.warning600
            : ColorUtils.success600,
        caption: rppCaption,
        onTap: _openLessonPlans,
      ),
      HeroStatsCard(
        label: isEn ? 'Grades Pending' : 'Nilai Belum Input',
        sliceLabel: slice.label,
        sliceLabelMuted: slice.isAggregate,
        value: _formatNumber(slice.gradesPendingSessions),
        icon: Icons.edit_note_outlined,
        accentColor: slice.gradesPendingSessions > 0
            ? ColorUtils.indigo500
            : ColorUtils.success600,
        caption: gradesCaption,
        onTap: _openGrades,
      ),
    ];
  }

  /// Parse the teacher slices array out of [DashboardState.stats]. Falls
  /// back to a single "Mengajar" slice synthesised from top-level
  /// counts so the migration ships gracefully when the backend hasn't
  /// yet emitted the slices array (older API versions).
  List<_GuruSlice> _parseGuruSlices(Map<String, dynamic> stats) {
    final raw = stats['slices'];
    if (raw is List && raw.isNotEmpty) {
      final parsed = raw
          .whereType<Map>()
          .map((e) => _GuruSlice.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (parsed.isNotEmpty) return parsed;
    }
    return [
      _GuruSlice(
        key: 'mengajar',
        label: 'Mengajar',
        isAggregate: true,
        sessionsToday: _asInt(
          stats['classes_today'] ?? stats['sessions_today'],
        ),
        sessionsTodayDone: 0,
        attendanceRateWindow: 0,
        attendanceDelta: 0,
        lessonPlansApproved: _asInt(stats['rpp_approved']),
        lessonPlansPending: _asInt(stats['rpp_pending']),
        lessonPlansRevision: _asInt(stats['rpp_rejected']),
        gradesPendingSessions: 0,
      ),
    ];
  }

  String _formatNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final remain = s.length - i;
      buf.write(s[i]);
      if (remain > 1 && (remain - 1) % 3 == 0) buf.write('.');
    }
    return buf.toString();
  }

  Widget _buildInboxCard() {
    final inbox = _priorityInbox;
    // Title carries an active-item badge ("Perlu Perhatian · 3").
    // When the list is empty, the card itself shows its empty
    // state — we drop the badge to avoid "· 0".
    //
    // When the uncapped total (set by the backend) exceeds what the
    // card shows, render "N/total" so the user knows "Lihat semua"
    // pulls in more rows than the visible top-N.
    final totalRaw = widget.state.stats['priority_inbox_total'];
    final total = totalRaw is int
        ? totalRaw
        : (totalRaw is num ? totalRaw.toInt() : inbox.length);
    final countLabel = total > inbox.length
        ? '${inbox.length}/$total'
        : '${inbox.length}';
    final title = inbox.isEmpty
        ? AppLocalizations.dbAttentionRequired.tr
        : '${AppLocalizations.dbAttentionRequired.tr} · $countLabel';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PendingInboxCard.priorityItems(
        title: title,
        items: inbox,
        accentColor: _teacherCobalt,
        emptyStateTitle: 'Semua aman 🎉',
        emptyStateSubtitle: 'Tidak ada yang perlu perhatian saat ini.',
        onPriorityTap: _navigateToInboxTarget,
        // GG.9 — long-press surfaces the local snooze sheet.
        onPriorityLongPress: _snoozeInboxItem,
        // GG.7 — "Lihat semua" pushes the full-screen inbox.
        // The inbox screen owns its own (uncapped) fetch but
        // hands tap navigation back to us via [onItemTap] so we
        // don't duplicate getIt/ref.read/teacherPayload lookups.
        onSeeAll: _openFullInbox,
      ),
    );
  }

  /// Push the GG.7 full-screen inbox. Hands the currently-known
  /// (capped) items in as `initialItems` so the screen renders
  /// instantly while the uncapped fetch runs in the background.
  void _openFullInbox() {
    AppNavigator.push(
      context,
      TeacherInboxScreen(
        initialItems: _priorityInbox,
        onItemTap: _navigateToInboxTarget,
      ),
    );
  }

  /// GG.9 — long-press handler. Opens the snooze sheet; on confirm
  /// the store hides the row and we [setState] to re-run the
  /// [_priorityInbox] filter (the source data on
  /// `widget.state.stats` doesn't change — we just drop the row
  /// from the rendered list until the snooze expires).
  Future<void> _snoozeInboxItem(PriorityInboxItem item) async {
    final didSnooze = await showPriorityInboxSnoozeSheet(
      context: context,
      item: item,
    );
    if (didSnooze == true && mounted) {
      setState(() {});
    }
  }

  /// Routes a priority-inbox tap to the right destination screen.
  ///
  /// The closed set of `target_route` values lives in
  /// `docs/teacher_priority_inbox.md §6` on the backend. Unknown
  /// values are silently no-op'd so an older client doesn't crash
  /// when the backend adds a new signal type.
  ///
  /// For routes whose destination screens already accept filter
  /// params (`teacher_attendance`, `report_card_class`), the
  /// targetParams flow straight through and the screen opens
  /// pre-scoped. For the remainder (`lesson_plan_detail`,
  /// `grade_book`, `recommendation_detail`) the screen opens
  /// unfiltered — see TODO(FF.12-followup) below for per-screen
  /// arg additions.
  void _navigateToInboxTarget(PriorityInboxItem item) {
    final params = item.targetParams;
    switch (item.targetRoute) {
      case 'teacher_attendance':
        _openAttendanceForInboxItem(params);
        break;
      case 'lesson_plan_detail':
        _openLessonPlansForInboxItem(params);
        break;
      case 'report_card_class':
        _openReportCardClass(params);
        break;
      case 'grade_book':
        _openGradeBookForInboxItem(params);
        break;
      case 'recommendation_detail':
        // Mark-as-seen fires at TAP — see GG.2. Independent of
        // whether the detail-fetch below succeeds, the inbox row
        // clears on next refresh.
        final recId = params['recommendation_id']?.toString();
        if (recId != null && recId.isNotEmpty) {
          unawaited(
            getIt<ApiRecommendationService>()
                .markRecommendationSharesSeenByTeacher(recommendationId: recId),
          );
        }
        _openRecommendationDetailById(recId);
        break;
      default:
        // Unknown route — older client, newer backend. No-op.
        break;
    }
  }

  /// Resolves a `recommendation_id` (from priority-inbox target
  /// params) into the full `(student, classData)` shape required
  /// by [LearningRecommendationResultScreen.show], then pushes
  /// the screen. On any failure (network blip, missing rec, etc.)
  /// we degrade to the class hub so the teacher still ends up in
  /// a useful place.
  Future<void> _openRecommendationDetailById(String? recId) async {
    if (recId == null || recId.isEmpty) {
      _openRecommendation();
      return;
    }
    try {
      final rec = await getIt<ApiRecommendationService>().getRecommendationById(
        recId,
      );

      final student = rec['student'];
      final klass = rec['class_'] ?? rec['class'];
      if (student is! Map || klass is! Map) {
        _openRecommendation();
        return;
      }
      if (!mounted) return;

      await LearningRecommendationResultScreen.show(
        context: context,
        teacher: _teacherPayload().map(
          (k, v) => MapEntry(k, v?.toString() ?? ''),
        ),
        student: Map<String, dynamic>.from(student),
        classData: Map<String, dynamic>.from(klass),
      );
    } catch (e) {
      AppLogger.error('priority_inbox', 'rec deep-link fetch failed: $e');
      if (mounted) _openRecommendation();
    }
  }

  void _openGradeBookForInboxItem(Map<String, dynamic> params) {
    final classId = params['class_id']?.toString();
    final subjectId = params['subject_id']?.toString();
    final columnId = params['column_id']?.toString();

    AppNavigator.push(
      context,
      GradePage(
        teacher: _teacherPayload(),
        initialClassId: classId,
        initialSubjectId: subjectId,
        initialColumnId: columnId,
      ),
    );
  }

  void _openLessonPlansForInboxItem(Map<String, dynamic> params) {
    final tp = ref.read(teacherRiverpod);
    final tId =
        tp.teacherId ?? widget.state.userData['teacher_id']?.toString() ?? '';
    if (tId.isEmpty) return;
    final lessonPlanId = params['lesson_plan_id']?.toString();
    AppNavigator.push(
      context,
      LessonPlanScreen(
        teacherId: tId,
        teacherName:
            tp.teacherName ??
            widget.state.userData['name']?.toString() ??
            'Guru',
        initialLessonPlanId: lessonPlanId,
      ),
    );
  }

  void _openAttendanceForInboxItem(Map<String, dynamic> params) {
    final classId = params['class_id']?.toString();
    final subjectId = params['subject_id']?.toString();
    final lessonHourId = params['lesson_hour_id']?.toString();
    final dateStr = params['date']?.toString();
    DateTime? initialDate;
    if (dateStr != null && dateStr.isNotEmpty) {
      initialDate = DateTime.tryParse(dateStr);
    }

    AppNavigator.push(
      context,
      AttendancePage(
        teacher: widget.state.userData,
        initialclassId: classId,
        initialSubjectId: subjectId,
        initialLessonHourId: lessonHourId,
        initialDate: initialDate,
      ),
    );
  }

  void _openReportCardClass(Map<String, dynamic> params) {
    final classId = params['class_id']?.toString();
    AppNavigator.push(
      context,
      ReportCardScreen(
        teacher: _teacherPayload().map(
          (k, v) => MapEntry(k, v?.toString() ?? ''),
        ),
        initialClassId: classId,
      ),
    );
  }

  Widget _buildQuickActions() {
    // Icons + colors come from the shared `DashboardModules` catalog
    // so every role uses the same icon identity per module (Kehadiran
    // is violet across all roles; Nilai is green; etc.).
    return QuickActionGrid(
      columnsPerRow: 4,
      actions: [
        QuickAction(
          icon: DashboardModules.jadwal.icon,
          label: DashboardModules.jadwal.defaultLabel.tr,
          color: DashboardModules.jadwal.color,
          caption: 'Mengajar',
          onTap: _openSchedule,
        ),
        QuickAction(
          icon: DashboardModules.kehadiran.icon,
          label: 'Absensi',
          color: DashboardModules.kehadiran.color,
          caption: 'Kehadiran',
          onTap: _openAttendance,
        ),
        QuickAction(
          icon: DashboardModules.kegiatanKelas.icon,
          label: 'Kegiatan',
          color: DashboardModules.kegiatanKelas.color,
          caption: 'Kelas',
          onTap: _openActivities,
        ),
        QuickAction(
          icon: DashboardModules.nilai.icon,
          label: DashboardModules.nilai.defaultLabel.tr,
          color: DashboardModules.nilai.color,
          caption: 'Input',
          onTap: _openGrades,
        ),
      ],
    );
  }

  Widget _buildModulLain() {
    return ModulLainStrip(
      title: AppLocalizations.dbOtherModules.tr,
      // 7 modules total now: 3 front tiles (Materi, RPP, Rekap Nilai) +
      // 4 in the "Lainnya" overflow sheet (Presensi Guru, Pengumuman,
      // Rekomendasi, Akun). Was 8 before Raport was removed per Luay's
      // request — Raport no longer surfaces from the teacher dashboard
      // here (the report-card flow stays reachable via the priority
      // inbox `report_card_class` deep-link).
      totalLabel: '7 ${AppLocalizations.dbOtherModules.tr.toLowerCase()}',
      accentColor: _teacherCobalt,
      // Front tiles (the always-visible "Modul lain" strip). Presensi
      // Guru moved OUT of here into the "Lainnya" overflow below, and
      // Raport was removed entirely — both per Luay's request.
      visibleItems: [
        ModulLainStripItem(
          label: DashboardModules.materi.defaultLabel.tr,
          icon: DashboardModules.materi.icon,
          onTap: _openMaterials,
        ),
        ModulLainStripItem(
          label: DashboardModules.rpp.defaultLabel.tr,
          icon: DashboardModules.rpp.icon,
          onTap: _openLessonPlans,
        ),
        ModulLainStripItem(
          label: DashboardModules.rekapNilai.defaultLabel.tr,
          icon: DashboardModules.rekapNilai.icon,
          onTap: _openGradeRecap,
        ),
      ],
      // "Lainnya" overflow sheet (opened from the "+N Lainnya" tile).
      // Presensi Guru lives here now instead of as a front tile, as
      // Luay asked ("pada menu lainnya masukkan presensi guru").
      overflowItems: [
        // Presensi Guru — the teacher's own daily check-in/out. Uses the
        // shared Kehadiran (violet) module icon; the "Presensi Guru"
        // label sets it apart from the student "Absensi" quick action.
        ModulLainStripItem(
          label: 'Presensi Guru',
          icon: DashboardModules.kehadiran.icon,
          onTap: _openTeacherPresensi,
        ),
        ModulLainStripItem(
          label: DashboardModules.pengumuman.defaultLabel.tr,
          icon: DashboardModules.pengumuman.icon,
          onTap: _openAnnouncementDrafts,
        ),
        ModulLainStripItem(
          label: DashboardModules.rekomendasi.defaultLabel.tr,
          icon: DashboardModules.rekomendasi.icon,
          onTap: _openRecommendation,
        ),
        ModulLainStripItem(
          label: DashboardModules.akun.defaultLabel.tr,
          icon: DashboardModules.akun.icon,
          onTap: _openAccount,
        ),
      ],
    );
  }
}

/// One slice of the teacher BrandKpiCarousel — either the aggregate
/// "Mengajar" / "Hari Ini" / "Pekan Ini" view, or one per homeroom
/// class the teacher holds. Built server-side in
/// `DashboardController::buildGuruSlices` and passed through
/// untouched by the dashboard transformer.
class _GuruSlice {
  final String key;
  final String label;
  final bool isAggregate;
  final int sessionsToday;
  final int sessionsTodayDone;
  final int attendanceRateWindow;
  final int attendanceDelta;
  final int lessonPlansApproved;
  final int lessonPlansPending;
  final int lessonPlansRevision;
  final int gradesPendingSessions;

  const _GuruSlice({
    required this.key,
    required this.label,
    required this.isAggregate,
    required this.sessionsToday,
    required this.sessionsTodayDone,
    required this.attendanceRateWindow,
    required this.attendanceDelta,
    required this.lessonPlansApproved,
    required this.lessonPlansPending,
    required this.lessonPlansRevision,
    required this.gradesPendingSessions,
  });

  factory _GuruSlice.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) {
      if (v is int) return v;
      if (v is num) return v.round();
      return int.tryParse('$v') ?? 0;
    }

    return _GuruSlice(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      isAggregate: json['is_aggregate'] == true,
      sessionsToday: asInt(json['sessions_today']),
      sessionsTodayDone: asInt(json['sessions_today_done']),
      attendanceRateWindow: asInt(json['attendance_rate_window']),
      attendanceDelta: asInt(json['attendance_delta']),
      lessonPlansApproved: asInt(json['lesson_plans_approved']),
      lessonPlansPending: asInt(json['lesson_plans_pending']),
      lessonPlansRevision: asInt(json['lesson_plans_revision']),
      gradesPendingSessions: asInt(json['grades_pending_sessions']),
    );
  }
}
