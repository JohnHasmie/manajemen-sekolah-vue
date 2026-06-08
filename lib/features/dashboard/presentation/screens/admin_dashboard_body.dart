// Admin-only dashboard body (Phase 3 redesign + P1 closeout).
//
// Why this exists
// ---------------
// The shared `buildDashboardContent` from ContentBuildersMixin was optimized
// around the guru/wali mental model: "what's on my plate today" (hero ribbon
// of stats → quick actions → today's overview). That shape does not fit
// the admin's daily loop — they come in every morning to triage worklists
// (verifikasi pembayaran, RPP menunggu review, draft pengumuman, tagihan
// menunggak) and only drill into individual modules when an item demands it.
// Phase 0 shipped the shared widgets (HeroStatsRow, PendingInboxCard,
// QuickActionGrid, SchoolPill.expanded); this body wires them into the
// admin dashboard without disturbing the guru/wali flow.
//
// Shape of the screen (top-to-bottom)
// -----------------------------------
//   1. DashboardAppBar   — kept for continuity: school name / lang / bell /
//                          profile, same across every role.
//   2. Navy gradient hero — SchoolPill.expanded (on-dark variant) plus the
//                           realtime indicator (T3.3 — green dot + "Terhubung
//                           realtime · HH:MM" or grey + "Terakhir N menit
//                           lalu").
//   3. HeroStatsRow       — 3 cards: Siswa Aktif, Guru, Verifikasi.
//   4. PendingInboxCard   — 4 worklist rows (T3.2 deep-links into Finance
//                           tab 2, AdminLessonPlanScreen(pending_review),
//                           AdminAnnouncementScreen(draft), Finance tab 3).
//   5. QuickActionGrid    — 4 tiles: Siswa, Keuangan, Laporan, Pengaturan.
//
// The legacy "Modul lain" categorized menu was retired in P1 closeout —
// its destinations are reachable via the Orang / Akademik / Keuangan /
// Sistem bottom-nav tabs.
//
// Realtime + refresh (T3.3)
// -------------------------
// This widget is a ConsumerStatefulWidget because it owns three bits of
// local state that are not part of DashboardState:
//   • [_pollTimer]  — 60-second Timer.periodic invoking refreshStats()
//   • [_lastSync]   — DateTime of the most recent successful poll
//   • [_isFresh]    — false when the last poll threw, flips the dot to grey
// On pull-to-refresh we cancel+restart the timer so the next tick is a full
// 60 s away (avoids double-fetching right after a manual refresh).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/constants/dashboard_modules.dart';
import 'package:manajemensekolah/core/mixins/admin_academic_year_reload_mixin.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/academic_year_chip.dart';
import 'package:manajemensekolah/core/widgets/brand_kpi_carousel.dart';
import 'package:manajemensekolah/core/widgets/hero_stats_card.dart';
import 'package:manajemensekolah/core/widgets/modul_lain_strip.dart';
import 'package:manajemensekolah/core/widgets/pending_inbox_card.dart';
import 'package:manajemensekolah/core/widgets/quick_action_grid.dart';
import 'package:manajemensekolah/core/widgets/role_dashboard_hero.dart';
import 'package:manajemensekolah/core/widgets/school_pill.dart';

import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_dashboard_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/admin_class_activity_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/admin_dashboard_hero_widgets.dart';
import 'package:manajemensekolah/features/dashboard/data/dashboard_service.dart';
import 'package:manajemensekolah/features/dashboard/domain/models/priority_inbox_item.dart';
import 'package:manajemensekolah/features/dashboard/presentation/screens/admin_inbox_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/academic_year_picker_sheet.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_app_bar.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/admin_finance_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/admin_grade_overview_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/admin_grade_recap_overview_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/admin_lesson_plan_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/admin_rpp_review_hub_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/admin_raport_hub_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/admin_schedule_management_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/data_management_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/system_settings_screen.dart';

/// Admin brand-dark accent used across hero widgets and the header gradient.
/// Sourced from `ColorUtils.brandDarkBlue` so any future brand refresh
/// updates one place.
final Color _adminNavy = ColorUtils.brandDarkBlue;

/// Polling cadence for the realtime indicator. Not configurable yet — Phase
/// 3 keeps it fixed at 60 s; Phase 4 may expose it if analytics shows the
/// admin tab is backgrounded for long stretches.
const Duration _pollInterval = Duration(seconds: 60);

/// Admin-only dashboard body.
///
/// Delegated to by [Dashboard] when `effectiveRole == 'admin'`. Receives
/// everything it needs from the parent as plain props so it does not depend
/// on HelpersMixin / CardsMixin / DialogMixin — mixin wiring stays scoped to
/// the parent widget.
class AdminDashboardBody extends ConsumerStatefulWidget {
  /// Already-resolved admin theme color (ColorUtils.corporateBlue600).
  final Color primaryColor;

  /// The loaded dashboard state. We never receive an empty/loading state
  /// here — the parent only mounts us inside the `data:` branch of its
  /// `AsyncValue.when`.
  final DashboardState state;

  /// Tour / animation keys owned by the parent state (so the tour can still
  /// anchor targets on this body).
  final GlobalKey profileHeaderKey;
  final GlobalKey heroSectionKey;
  final GlobalKey quickActionsKey;
  final GlobalKey statsSectionKey;

  /// Callbacks for the [DashboardAppBar] icons. The parent forwards these
  /// so the app bar keeps the same behaviour across every role.
  final VoidCallback onLanguageTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onAccountTap;
  final VoidCallback onSchoolSwitchTap;

  const AdminDashboardBody({
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
  ConsumerState<AdminDashboardBody> createState() => _AdminDashboardBodyState();
}

class _AdminDashboardBodyState extends ConsumerState<AdminDashboardBody>
    with AdminAcademicYearReloadMixin<AdminDashboardBody> {
  Timer? _pollTimer;

  /// Timestamp of the most recent successful stats refresh. Initialized to
  /// `DateTime.now()` at mount time because the parent only builds this
  /// body once state has already been fetched — so "now" is accurate to
  /// within a few hundred ms of the real-fetch moment.
  DateTime _lastSync = DateTime.now();

  /// True while we are connected and the last poll succeeded. Flips to
  /// false on the first poll error, which is the signal for the indicator
  /// to turn grey and the copy to switch to "Terakhir diperbarui N menit".
  bool _isFresh = true;

  // Server-driven Perlu Perhatian (Inbox B.4). When the fetch returns
  // items, the inbox card switches from the legacy static-counts mode
  // (entries:) to the ranked priorityItems mode — same widget, richer
  // payload. Empty list (no signals OR backend not yet deployed)
  // falls back to the entries-mode counts so the card always renders.
  List<PriorityInboxItem> _priorityInbox = const [];
  int _priorityInboxTotal = 0;

  @override
  void initState() {
    super.initState();
    _startPolling();
    // Fire the first inbox fetch right away; subsequent refreshes
    // ride the 60s poll cycle via _pollStats.
    _loadPriorityInbox();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── Polling ──────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollStats());
  }

  /// Runs one stats refresh. We deliberately call `refreshStats()` (not
  /// `pullToRefresh()`) so the UI does not show the spinner every minute.
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
    // Refresh inbox in the same cycle — failures are absorbed by the
    // service method, so this never throws or affects _isFresh.
    await _loadPriorityInbox();
  }

  /// Reload the summary inbox when the user switches academic year via
  /// the global picker. The "Lihat semua" inbox screen
  /// (`AdminInboxScreen`) already reacts to this provider through the
  /// same mixin; without this the dashboard card would keep showing a
  /// stale snapshot taken under the previously-selected year — the
  /// exact "Semua aman" vs "3 item" mismatch reported on production
  /// (the card lagged the full list after a year/context change).
  @override
  void onAcademicYearChanged() {
    _loadPriorityInbox();
  }

  /// Pulls the latest Perlu Perhatian items from the admin endpoint.
  ///
  /// The summary card and the "Lihat semua" screen share the same
  /// composer, so they must stay in sync. We pass the currently-selected
  /// academic year (same source the full inbox screen uses) so a card
  /// rendered right after a year switch reflects the same scope as the
  /// list behind "Lihat semua".
  ///
  /// A *failed* fetch (`ok == false` — network error, or the 400 the
  /// backend returns when the school-context header isn't ready yet)
  /// must not overwrite a known-good list with the "Semua aman" empty
  /// state: that produced the production mismatch where the card read
  /// "Semua aman" while "Lihat semua" still listed real items. So on a
  /// failed load we keep whatever rows we already have. A *successful*
  /// empty response (`ok == true`) is a genuine "all clear" and is
  /// applied, so the card still clears once the admin resolves
  /// everything.
  Future<void> _loadPriorityInbox() async {
    final result = await DashboardService.getAdminPriorityInbox(
      academicYearId: currentAcademicYearId,
    );
    if (!mounted) return;
    if (!result.ok) {
      // Couldn't load — leave the existing card untouched rather than
      // flashing the empty state over real items.
      return;
    }
    setState(() {
      _priorityInbox = PriorityInboxItem.parseList(result.items);
      _priorityInboxTotal = result.total;
    });
  }

  /// Manual pull-to-refresh entry point. Running a full [pullToRefresh]
  /// resets our "last sync" marker and the 60 s timer, so the next auto
  /// poll happens a clean minute after the user lifted their finger.
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
      rethrow; // let AppRefreshIndicator show its error snackbar
    }
  }

  // ── Derived values ───────────────────────────

  /// School name with a sensible fallback so the pill never renders blank
  /// during the tiny window between login and the first data fetch.
  String get _schoolName {
    final ud = widget.state.userData;
    final raw = (ud['school_name'] ?? ud['nama_sekolah'])?.toString().trim();
    if (raw == null || raw.isEmpty) return AppLocalizations.dbSchool.tr;
    return raw;
  }

  /// Hero subtitle: "Admin Sekolah · TP 2025/2026" (role + academic year).
  /// Mirrors the SVG mockup line 33 format.
  String get _greetingSubtitle {
    final year = widget.state.userData['academic_year']?.toString();
    if (year == null || year.isEmpty) return AppLocalizations.dbAdminSchool.tr;
    return '${AppLocalizations.dbAdminSchool.tr} · TP $year';
  }

  /// Full display name shown under the time-of-day greeting in the hero.
  String get _userName {
    final raw = widget.state.userData['name']?.toString().trim();
    return (raw == null || raw.isEmpty)
        ? AppLocalizations.dbAdminSchool.tr
        : raw;
  }

  /// Display label for the academic-year chip in the hero. Watches
  /// `academicYearRiverpod` so the chip updates when the user picks a
  /// different year via [showAcademicYearPickerSheet].
  String get _academicYearLabel {
    final year = ref.watch(academicYearRiverpod).selectedAcademicYear;
    return year?['year']?.toString() ?? '—';
  }

  /// "pagi" / "siang" / "sore" / "malam" by local hour. Used for the
  /// Phase 3 hero greeting line "Selamat ${greetingPart()}".
  // Removed greetingPart in favor of AppLocalizations.greeting

  /// Verification count is still surfaced as a badge on the Keuangan
  /// quick-action tile, so this one survives the B.5 inbox cleanup.
  /// The other three (RPP / draft / overdue) used to feed the legacy
  /// entries-mode inbox card; they were dropped along with the
  /// `_buildLegacyInboxCard` method when the priority endpoint
  /// became the single rendering path.
  int get _pendingVerifyCount => widget.state.unverifiedPaymentCount;

  static int _asInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  // ── Navigation — filter-scoped inbox taps (T3.2) ─────

  void _openFinanceVerification() {
    // v3 (Mockup #13) layout: Pembayaran is tab index 1. Was 2 in
    // the legacy 4-tab Dashboard/PaymentTypes/Verification/ClassReport
    // layout — the index moved when Dashboard was folded out of the
    // hub.
    AppNavigator.push(context, const FinanceScreen(initialTabIndex: 1));
  }

  void _openFinanceClassReport() {
    // Per-kelas Laporan no longer has a standalone landing screen. The
    // admin now drills in via the Tagihan tab's grouped Tingkat → Kelas
    // rows, which is the same data, but already in context (status +
    // outstanding amount visible). We just route to the Tagihan tab.
    AppNavigator.push(context, const FinanceScreen(initialTabIndex: 0));
  }

  void _openLessonPlanReview() {
    AppNavigator.push(
      context,
      const AdminLessonPlanScreen(initialStatusFilter: 'pending_review'),
    );
  }

  void _openAnnouncementDrafts() {
    AppNavigator.push(
      context,
      const AdminAnnouncementScreen(initialStatusFilter: 'draft'),
    );
  }

  void _openSiswa() =>
      AppNavigator.push(context, const AdminDataManagementScreen());
  void _openKeuangan() => AppNavigator.push(context, const FinanceScreen());
  // Mockup #08 v3 hub — pipeline strip + per-tingkat group cards.
  // The legacy AdminReportCardScreen still exists for direct class
  // drill-downs; the hub becomes the menu entry point.
  void _openLaporanRaport() =>
      AppNavigator.push(context, const AdminRaportHubScreen());
  void _openPengaturan() => AppNavigator.push(
    context,
    SystemSettingsScreen(
      schoolName: widget.state.userData['nama_sekolah']?.toString(),
      schoolLogoUrl: widget.state.userData['school_logo_url']?.toString(),
      subtitle: _pengaturanSubtitle,
    ),
  );

  /// Subtitle shown under the school name on the Pengaturan hub's hero.
  /// Mirrors the dashboard hero so the same context carries across surfaces.
  String get _pengaturanSubtitle {
    final year = widget.state.userData['academic_year']?.toString();
    if (year == null || year.isEmpty) return kDasAdminSettingsSubtitle.tr;
    return '$year · ${kDasAdminSettingsSubtitle.tr}';
  }

  // ── Build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch language provider to rebuild when language changes — flips
    // all Flutter-local `.tr` strings instantly.
    ref.watch(languageRiverpod);

    // Re-fetch the server-localized "Perlu Perhatian" inbox when the
    // language change has been persisted server-side. The inbox rows
    // are rendered with backend-localized labels/subtitles, so a plain
    // rebuild isn't enough — we need fresh data in the new language.
    // The signal is bumped only AFTER the `PATCH /profile/language`
    // round-trip (see main.dart), so this re-fetch reads the new
    // locale. `_loadPriorityInbox` swallows its own errors.
    ref.listen<int>(languageChangeSignalProvider, (_, _) {
      _loadPriorityInbox();
    });

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

  // ── Header — navy gradient + realtime pill + KPI overlay ───

  /// Combined hero + KPI section matching
  /// `Admin_Refactor_Phase3_Dashboard_Mockup.svg`.
  ///
  /// The navy gradient extends edge-to-edge from the top of the screen
  /// (under the system status bar), with rounded bottom corners. Inside,
  /// top-to-bottom:
  ///   1. icon row (globe, bell with red-dot, profile) on right; greeting
  ///      "Selamat pagi" + user name on left
  ///   2. green dot + "Terhubung realtime · HH:MM"
  ///   3. expanded school pill
  ///
  /// The KPI row is `Positioned(bottom: 0)` of an outer 92dp padding zone —
  /// cards float onto the gradient's lower edge, then extend onto the page bg.
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
          // [RoleDashboardHero]. 100dp bottomOverlap reserves the
          // empty navy band where the KPI strip floats.
          RoleDashboardHero(
            role: 'admin',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: greeting + name on left, icon buttons on right
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
                    AdminDashboardHeroIconButton(
                      icon: Icons.language_outlined,
                      onTap: widget.onLanguageTap,
                      gradientBg: _adminNavy,
                    ),
                    const SizedBox(width: 6),
                    AdminDashboardHeroIconButton(
                      icon: Icons.notifications_outlined,
                      onTap: widget.onNotificationTap,
                      gradientBg: _adminNavy,
                      showDot: notifBadge > 0,
                    ),
                    const SizedBox(width: 6),
                    AdminDashboardHeroIconButton(
                      icon: Icons.person_outline,
                      onTap: widget.onAccountTap,
                      gradientBg: _adminNavy,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Realtime indicator (mockup line 27-28): green/grey dot
                // + faint white label, sits between greeting and school pill.
                AdminDashboardRealtimePill(
                  isFresh: _isFresh,
                  lastSync: _lastSync,
                ),
                const SizedBox(height: AppSpacing.md),
                // School pill (flex 3) + tahun-ajaran chip (flex 2)
                // side-by-side, mirroring the parent + teacher
                // dashboards. Single source of truth for academic
                // year context across roles.
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
                          accentColor: _adminNavy,
                          actionLabel: AppLocalizations.dbSwitch.tr,
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
                            role: 'admin',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // KPI strip floating at the bottom of the gradient. Positioned
          // edge-to-edge (left: 0, right: 0) — BrandKpiCarousel applies
          // its own 16dp horizontal padding so we don't double-pad.
          Positioned(
            key: widget.statsSectionKey,
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildHeroStats(),
          ),
        ],
      ),
    );
  }

  // ── Hero stats — paired auto-slide via the shared BrandKpiCarousel ──
  //
  // Why BrandKpiCarousel
  // --------------------
  // Same widget the parent dashboard uses — matches the v3 mockup
  // (2 cards per page, auto-slide, top progress strip when slices
  // exist, capsule/dot page indicator below, no "Page 1 of N" text).
  //
  // Slice schema (target)
  // ---------------------
  // Slice 0 = SEMUA (school-wide aggregate, what we ship today).
  // Slices 1+ = per Tingkat (Tingkat 7, 8, 9). When the backend adds
  // `slices` to the admin stats payload (mirroring
  // `DashboardController::buildParentChildSlices`), bump
  // `sliceCount` and the carousel auto-engages the cycle. Until
  // then `sliceCount: 1` keeps the strip flat — exactly what
  // BrandKpiCarousel does in the no-slices case.
  //
  // Card pages (4 cards × perPage = 2 → 2 pages auto-slide):
  //   Page 1: Kehadiran hari ini · Siswa aktif
  //   Page 2: Nilai rata-rata     · RPP menunggu
  Widget _buildHeroStats() {
    final stats = widget.state.stats;
    final slices = _parseAdminSlices(stats);

    return BrandKpiCarousel(
      scope: 'admin_dashboard',
      sliceCount: slices.length,
      autoSlideCards: true,
      cardBuilder: (sliceIndex) {
        final slice = slices[sliceIndex.clamp(0, slices.length - 1)];
        final ctxLabel = slice.label;

        return [
          // 1. Kehadiran hari ini
          HeroStatsCard(
            label: AppLocalizations.dbPresenceToday.tr,
            sliceLabel: ctxLabel,
            sliceLabelMuted: slice.isAggregate,
            value: '${slice.attendanceRate}%',
            icon: Icons.check_rounded,
            accentColor: ColorUtils.success600,
            trend: slice.attendanceDelta == 0
                ? null
                : StatTrend(
                    direction: slice.attendanceDelta > 0
                        ? StatTrendDirection.up
                        : StatTrendDirection.down,
                    label:
                        '${slice.attendanceDelta > 0 ? '+' : ''}'
                        '${slice.attendanceDelta}%',
                  ),
            onTap: _openSiswa,
          ),
          // 2. Siswa aktif
          HeroStatsCard(
            label: AppLocalizations.dbActiveStudents.tr,
            sliceLabel: ctxLabel,
            sliceLabelMuted: slice.isAggregate,
            value: _formatNumber(slice.totalStudents),
            icon: Icons.people_outline_rounded,
            accentColor: ColorUtils.corporateBlue600,
            caption: slice.totalClasses > 0
                ? '· ${slice.totalClasses} ${AppLocalizations.dbClasses.tr}'
                : null,
            onTap: _openSiswa,
          ),
          // 3. Nilai rata-rata sekolah
          // TODO(i18n): promote 'Rata-rata Nilai', 'Semester ini',
          // 'Belum ada data' to AppLocalizations once the EN copy
          // is signed off.
          HeroStatsCard(
            label: kDasAverageGrade.tr,
            sliceLabel: ctxLabel,
            sliceLabelMuted: slice.isAggregate,
            value: slice.avgGrade != null
                ? slice.avgGrade!.toStringAsFixed(1)
                : '—',
            icon: Icons.bar_chart_rounded,
            accentColor: const Color(0xFF6366F1),
            caption: slice.avgGrade != null ? kDasThisSemester.tr : kDasNoDataYet.tr,
            onTap: _openNilai,
          ),
          // 4. RPP menunggu persetujuan
          // TODO(i18n): promote 'RPP Menunggu', 'Perlu ditinjau',
          // 'Semua disetujui' to AppLocalizations.
          HeroStatsCard(
            label: kDasPendingLessonPlans.tr,
            sliceLabel: ctxLabel,
            sliceLabelMuted: slice.isAggregate,
            value: _formatNumber(slice.pendingLessonPlans),
            icon: Icons.assignment_outlined,
            accentColor: ColorUtils.warning600,
            caption: slice.pendingLessonPlans > 0
                ? kDasNeedsReview.tr
                : kDasAllApproved.tr,
            onTap: _openLessonPlanReview,
          ),
        ];
      },
    );
  }

  /// Parse the admin `slices` array out of [DashboardState.stats]. The
  /// backend ships an array of per-Tingkat slice records (see
  /// `DashboardController::buildAdminTingkatSlices`); when it's missing
  /// (older backend or no enrolment yet), synthesise a single
  /// "Semua tingkat" slice from the top-level stat fields so the
  /// carousel always has at least one entry to render.
  List<_AdminSlice> _parseAdminSlices(Map<String, dynamic> stats) {
    final raw = stats['slices'];
    if (raw is List && raw.isNotEmpty) {
      final parsed = raw
          .whereType<Map>()
          .map((e) => _AdminSlice.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (parsed.isNotEmpty) return parsed;
    }
    // Fallback — synthesise a single "Semua" slice from top-level fields
    // so the migration ships gracefully even when the backend hasn't
    // yet emitted the slices array.
    return [
      _AdminSlice(
        key: 'all',
        label: kDasAllGrades.tr,
        attendanceRate: _asInt(stats['attendance_rate_today']),
        attendanceDelta: _asInt(stats['attendance_delta_pct']),
        totalStudents: _asInt(stats['total_students']),
        totalClasses: _asInt(stats['total_classes']),
        pendingLessonPlans: _asInt(stats['pending_lesson_plans']),
        avgGrade: () {
          final v = stats['avg_grade_school'] ?? stats['avg_grade'];
          return v is num ? v.toDouble() : null;
        }(),
      ),
    ];
  }

  /// Narrow number formatter: thousands separator only. Avoids pulling in
  /// `intl` here since we already ship it transitively — but formatting is
  /// a one-off and not worth the dependency surface.
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

  // ── Inbox — server-ranked Perlu Perhatian (Inbox B.4 / B.5) ────
  //
  // Single rendering path: `PendingInboxCard.priorityItems` reads from
  // the server-ranked admin priority endpoint. When the endpoint
  // returns no items (quiet day, or aggregators silenced), the card
  // surfaces its own "Semua aman 🎉" empty state.
  //
  // The legacy `entries:` mode that pulled from local stats (verify,
  // RPP, draft, overdue counts) was removed in the B.5 cleanup — it
  // duplicated what the new endpoint surfaces and risked the UI
  // silently regressing to the old card layout the moment the new
  // endpoint returned an empty list. Single source of truth.

  Widget _buildInboxCard() {
    final count = _priorityInbox.length;
    final total = _priorityInboxTotal;
    final countLabel = total > count ? '$count/$total' : '$count';
    final title = count == 0
        ? AppLocalizations.dbAttentionRequired.tr
        : '${AppLocalizations.dbAttentionRequired.tr} · $countLabel';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PendingInboxCard.priorityItems(
        title: title,
        items: _priorityInbox,
        accentColor: _adminNavy,
        emptyStateTitle: kDasAllClear.tr,
        emptyStateSubtitle: kDasNothingToAttend.tr,
        onPriorityTap: _navigateToAdminInboxTarget,
        // B.5 — full-screen Lihat semua surface.
        onSeeAll: _openFullAdminInbox,
      ),
    );
  }

  /// Pushes the admin Lihat semua inbox. Hands the currently-known
  /// (capped) items in as `initialItems` so the screen paints
  /// instantly while the uncapped fetch runs in the background, and
  /// reuses the deep-link dispatch via `_navigateToAdminInboxTarget`.
  void _openFullAdminInbox() {
    AppNavigator.push(
      context,
      AdminInboxScreen(
        initialItems: _priorityInbox,
        onItemTap: _navigateToAdminInboxTarget,
      ),
    );
  }

  /// Routes a priority-inbox tap to the right destination screen.
  /// Closed set lives in the admin aggregators' `target_route`
  /// strings; unknown values are silently no-op'd so a newer backend
  /// doesn't crash an older client.
  void _navigateToAdminInboxTarget(PriorityInboxItem item) {
    switch (item.targetRoute) {
      case 'admin_payment_verification':
        _openFinanceVerification();
        break;
      case 'admin_overdue_bills':
        _openFinanceClassReport();
        break;
      case 'admin_rpp_review':
        _openLessonPlanReview();
        break;
      case 'admin_schedule_conflict':
      case 'admin_schedule_conflicts':
      case 'admin_schedule_management':
        AppNavigator.push(context, const TeachingScheduleManagementScreen());
        break;
      case 'admin_raport_hub':
        _openLaporanRaport();
        break;
      case 'admin_announcement_drafts':
        _openAnnouncementDrafts();
        break;
      case 'admin_class_management':
        // Class management lives under Data Management for admin
        // — same screen as the Siswa quick action target.
        _openSiswa();
        break;
      case 'admin_academic_year_settings':
        _openPengaturan();
        break;
      default:
        // Unknown target — swallow rather than crash a newer-backend
        // build on an older app.
        break;
    }
  }

  // ── Quick actions — 4 tiles ──────────────────

  Widget _buildQuickActions() {
    // Icons + colors come from the shared `DashboardModules` catalog
    // so admin's Keuangan / Rapor / Pengaturan share visual identity
    // with the matching parent + teacher entries.
    return QuickActionGrid(
      columnsPerRow: 4,
      actions: [
        QuickAction(
          icon: DashboardModules.kegiatanKelas.icon,
          label: AppLocalizations.classActivities.tr,
          color: DashboardModules.kegiatanKelas.color,
          caption: AppLocalizations.dbLessonsAndMaterials.tr,
          onTap: _openAktivitasKelas,
        ),
        QuickAction(
          icon: DashboardModules.keuangan.icon,
          label: AppLocalizations.finance.tr,
          color: DashboardModules.keuangan.color,
          caption: AppLocalizations.dbTypesAndBills.tr,
          showBadge: _pendingVerifyCount > 0,
          onTap: _openKeuangan,
        ),
        QuickAction(
          icon: DashboardModules.raport.icon,
          label: AppLocalizations.reports.tr,
          color: DashboardModules.raport.color,
          caption: AppLocalizations.dbGradesAndReportCards.tr,
          onTap: _openLaporanRaport,
        ),
        QuickAction(
          icon: DashboardModules.pengaturan.icon,
          // Shortened from "Pengaturan" → "Setelan" so the label fits the
          // 4-column tile width on Samsung portrait without wrapping to
          // two lines ("Pengatura\nn").
          label: AppLocalizations.settings.tr,
          color: DashboardModules.pengaturan.color,
          caption: AppLocalizations.dbSchool.tr,
          onTap: _openPengaturan,
        ),
      ],
    );
  }

  // ── Modul Lain strip ─────────────────────

  void _openJadwal() =>
      AppNavigator.push(context, const TeachingScheduleManagementScreen());

  void _openNilai() =>
      AppNavigator.push(context, const AdminGradeOverviewScreen());

  /// Fix-FF — admin Rekap Nilai aggregator (Frame C). Split out from
  /// the Buku Nilai tile because the previous "Nilai" menu was the
  /// only entry and it actually opened Buku Nilai; admins still need
  /// a real Rekap surface.
  void _openRekapNilai() =>
      AppNavigator.push(context, const AdminGradeRecapOverviewScreen());

  // Mockup #11 v3 dashboard — ring + KPI strip + per-tingkat trend.
  // Tap a tingkat row → drills into per-student CalendarHeatmap
  // (Mockup #12). Legacy class-list AdminAttendanceReportScreen
  // still reachable from elsewhere if needed.
  void _openPresensi() =>
      AppNavigator.push(context, const AdminAttendanceDashboardScreen());

  void _openAktivitasKelas() =>
      AppNavigator.push(context, const AdminClassActivityScreen());

  Widget _buildModulLain() {
    ref.watch(languageRiverpod);
    // Fix-FF — split the single "Nilai" tile into "Buku Nilai" + "Rekap
    // Nilai" so admins can reach the new aggregator screen. Total goes
    // from 8 → 9; Rekap rides into the overflow row to keep the visible
    // strip at 4 tiles.
    return ModulLainStrip(
      title: AppLocalizations.dbOtherModules.tr,
      totalLabel: '9 ${AppLocalizations.dbOtherModules.tr.toLowerCase()}',
      accentColor: _adminNavy,
      visibleItems: [
        ModulLainStripItem(
          label: AppLocalizations.dbSchedule.tr,
          icon: DashboardModules.jadwal.icon,
          onTap: _openJadwal,
        ),
        ModulLainStripItem(
          label: DashboardModules.bukuNilai.defaultLabel.tr,
          icon: DashboardModules.bukuNilai.icon,
          onTap: _openNilai,
        ),
        // Fix-FF.7 — Rekap Nilai promoted to visible row so the new
        // aggregator screen is one tap from the dashboard. Rapor moves
        // to overflow.
        ModulLainStripItem(
          label: DashboardModules.rekapNilai.defaultLabel.tr,
          icon: DashboardModules.rekapNilai.icon,
          onTap: _openRekapNilai,
        ),
        ModulLainStripItem(
          label: kDasAttendanceModule.tr,
          icon: DashboardModules.kehadiran.icon,
          onTap: _openPresensi,
        ),
      ],
      overflowItems: [
        ModulLainStripItem(
          label: kDasReportCardModule.tr,
          icon: DashboardModules.raport.icon,
          onTap: _openLaporanRaport,
        ),
        ModulLainStripItem(
          label: DashboardModules.pengumuman.defaultLabel.tr,
          icon: DashboardModules.pengumuman.icon,
          onTap: () =>
              AppNavigator.push(context, const AdminAnnouncementScreen()),
        ),
        ModulLainStripItem(
          label: DashboardModules.kegiatanKelas.defaultLabel.tr,
          icon: DashboardModules.kegiatanKelas.icon,
          onTap: _openAktivitasKelas,
        ),
        ModulLainStripItem(
          label: DashboardModules.rpp.defaultLabel.tr,
          icon: DashboardModules.rpp.icon,
          // Mockup #09 v3 — review queue with 3-tier hero counts
          // and inline approve. Old AdminLessonPlanScreen still
          // reachable from inbox deep-links (initialStatusFilter).
          onTap: () =>
              AppNavigator.push(context, const AdminRppReviewHubScreen()),
        ),
        ModulLainStripItem(
          label: DashboardModules.akun.defaultLabel.tr,
          icon: DashboardModules.akun.icon,
          onTap: widget.onAccountTap,
        ),
      ],
    );
  }
}

/// One slice of the admin BrandKpiCarousel — either the school-wide
/// aggregate (`'all'`) or a per-Tingkat breakdown. Mirrors the shape
/// of the `slices` array emitted by
/// `DashboardController::buildAdminTingkatSlices` on the backend.
///
/// Fields that the backend hasn't filled (e.g., `avg_grade` when the
/// per-Tingkat grade query is skipped) come through as null and the
/// card renders an em-dash.
class _AdminSlice {
  final String key;
  final String label;
  final int attendanceRate;
  final int attendanceDelta;
  final int totalStudents;
  final int totalClasses;
  final int pendingLessonPlans;
  final double? avgGrade;

  const _AdminSlice({
    required this.key,
    required this.label,
    required this.attendanceRate,
    required this.attendanceDelta,
    required this.totalStudents,
    required this.totalClasses,
    required this.pendingLessonPlans,
    required this.avgGrade,
  });

  /// True when this slice represents the school-wide aggregate.
  /// Used to grey out the slice label so "Semua tingkat" reads as
  /// muted context rather than competing with the primary value.
  bool get isAggregate => key == 'all';

  factory _AdminSlice.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) {
      if (v is int) return v;
      if (v is double) return v.round();
      return int.tryParse('$v') ?? 0;
    }

    final avg = json['avg_grade'];
    return _AdminSlice(
      key: (json['key'] ?? 'unknown').toString(),
      label: (json['label'] ?? '').toString(),
      attendanceRate: asInt(json['attendance_rate']),
      attendanceDelta: asInt(json['attendance_delta']),
      totalStudents: asInt(json['total_students']),
      totalClasses: asInt(json['total_classes']),
      pendingLessonPlans: asInt(json['pending_lesson_plans']),
      avgGrade: avg is num ? avg.toDouble() : null,
    );
  }
}
