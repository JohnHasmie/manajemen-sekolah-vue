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
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/hero_stats_card.dart';
import 'package:manajemensekolah/core/widgets/modul_lain_strip.dart';
import 'package:manajemensekolah/core/widgets/pending_inbox_card.dart';
import 'package:manajemensekolah/core/widgets/quick_action_grid.dart';
import 'package:manajemensekolah/core/widgets/school_pill.dart';

import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_report_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/admin_class_activity_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_app_bar.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/admin_finance_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/admin_grade_overview_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/admin_lesson_plan_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/admin_report_card_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/admin_schedule_management_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/data_management_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/system_settings_screen.dart';

/// Admin brand-dark accent used across hero widgets and the header gradient.
/// Sourced from the Kamil Edu brand guide (Dark Blue, hex `#143068`).
const Color _adminNavy = Color(0xFF143068);

/// Second stop of the admin header gradient — same hue lightened ~16%
/// in HSL space so the gradient reads as "depth" without stepping outside
/// the brand. Roughly equivalent to a slate-overlay on the brand dark.
const Color _adminNavyFade = Color(0xFF1F4A8F);

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

class _AdminDashboardBodyState extends ConsumerState<AdminDashboardBody> {
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
    if (raw == null || raw.isEmpty) return 'Sekolah';
    return raw;
  }

  /// Hero subtitle: "Admin Sekolah · TP 2025/2026" (role + academic year).
  /// Mirrors the SVG mockup line 33 format.
  String get _greetingSubtitle {
    final year = widget.state.userData['academic_year']?.toString();
    if (year == null || year.isEmpty) return 'Admin Sekolah';
    return 'Admin Sekolah · TP $year';
  }

  /// Full display name shown under the time-of-day greeting in the hero.
  String get _userName {
    final raw = widget.state.userData['name']?.toString().trim();
    return (raw == null || raw.isEmpty) ? 'Admin Sekolah' : raw;
  }

  /// "pagi" / "siang" / "sore" / "malam" by local hour. Used for the
  /// Phase 3 hero greeting line "Selamat ${greetingPart()}".
  String _greetingPart() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'pagi';
    if (hour < 15) return 'siang';
    if (hour < 18) return 'sore';
    return 'malam';
  }

  /// Count helpers — read from the live stats map with 0 fallback so if the
  /// backend later adds these fields (see Phase 4 backlog) the UI picks
  /// them up automatically without another mobile release.
  int get _pendingVerifyCount => widget.state.unverifiedPaymentCount;
  int get _pendingRppCount =>
      _asInt(widget.state.stats['pending_lesson_plans']);
  int get _draftAnnouncementCount =>
      _asInt(widget.state.stats['draft_announcements']);
  int get _overdueBillCount => _asInt(widget.state.stats['overdue_bills']);

  static int _asInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  // ── Navigation — filter-scoped inbox taps (T3.2) ─────

  void _openFinanceVerification() {
    AppNavigator.push(context, const FinanceScreen(initialTabIndex: 2));
  }

  void _openFinanceClassReport() {
    AppNavigator.push(context, const FinanceScreen(initialTabIndex: 3));
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
  void _openLaporanRaport() =>
      AppNavigator.push(context, const AdminReportCardScreen());
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
    if (year == null || year.isEmpty) return 'Admin sekolah';
    return '$year · Admin sekolah';
  }

  // ── Build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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

  /// Combined hero + KPI section matching `Admin_Refactor_Phase3_Dashboard_Mockup.svg`.
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
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;
    final notifBadge = _asInt(widget.state.stats['unread_notifications']) +
        _asInt(widget.state.stats['unread_announcements']);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Gradient hero — full width, edge-to-edge, rounded bottom corners
        Padding(
          padding: const EdgeInsets.only(bottom: 70),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_adminNavy, _adminNavyFade],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: _adminNavy.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                statusBarHeight + AppSpacing.md,
                AppSpacing.md,
                // Extra space below the school pill so the floating KPI
                // cards overlap an empty navy band rather than the pill
                // itself — matches the Phase 3 mockup where the gradient
                // extends 24dp past the pill (line 200 → 248).
                48,
              ),
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
                              'Selamat ${_greetingPart()}',
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
                      _HeroIconButton(
                        icon: Icons.language_outlined,
                        onTap: widget.onLanguageTap,
                        gradientBg: _adminNavy,
                      ),
                      const SizedBox(width: 6),
                      _HeroIconButton(
                        icon: Icons.notifications_outlined,
                        onTap: widget.onNotificationTap,
                        gradientBg: _adminNavy,
                        showDot: notifBadge > 0,
                      ),
                      const SizedBox(width: 6),
                      _HeroIconButton(
                        icon: Icons.person_outline,
                        onTap: widget.onAccountTap,
                        gradientBg: _adminNavy,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Realtime indicator (mockup line 27-28): green/grey dot
                  // + faint white label, sits between greeting and school pill.
                  _RealtimePill(isFresh: _isFresh, lastSync: _lastSync),
                  const SizedBox(height: AppSpacing.md),
                  SchoolPill.expanded(
                    schoolName: _schoolName,
                    subtitle: _greetingSubtitle,
                    onTap: widget.onSchoolSwitchTap,
                    accentColor: _adminNavy,
                    actionLabel: 'Ganti',
                    onDarkSurface: true,
                  ),
                ],
              ),
            ),
          ),
        ),
        // KPI strip floating at the bottom of the gradient
        Positioned(
          key: widget.statsSectionKey,
          left: 16,
          right: 16,
          bottom: 0,
          child: _buildHeroStats(),
        ),
      ],
    );
  }

  // ── Hero stats — 2 cards in a row, matching the Phase 3 mockup ────

  Widget _buildHeroStats() {
    final stats = widget.state.stats;
    final attendanceRate = _asInt(stats['attendance_rate_today']);
    final attendanceDelta = _asInt(stats['attendance_delta_pct']);
    final classCount = _asInt(stats['total_classes']);
    return HeroStatsRow(
      cards: [
        HeroStatsCard(
          // TODO(backend): wire stats['attendance_rate_today'] (today's
          // school-wide attendance %) and stats['attendance_delta_pct']
          // (signed delta vs yesterday). Until then both default to 0.
          label: 'Kehadiran hari ini',
          value: '$attendanceRate%',
          icon: Icons.check_rounded,
          accentColor: ColorUtils.success600,
          trend: attendanceDelta == 0
              ? null
              : StatTrend(
                  direction: attendanceDelta > 0
                      ? StatTrendDirection.up
                      : StatTrendDirection.down,
                  label:
                      '${attendanceDelta > 0 ? '+' : ''}$attendanceDelta%',
                ),
          onTap: _openSiswa,
        ),
        HeroStatsCard(
          label: 'Siswa aktif',
          value: _formatNumber(_asInt(stats['total_students'])),
          icon: Icons.people_outline_rounded,
          accentColor: ColorUtils.corporateBlue600,
          caption: classCount > 0 ? '· $classCount kelas' : null,
          onTap: _openSiswa,
        ),
      ],
    );
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

  // ── Inbox — 4 filter-scoped worklist rows ────

  Widget _buildInboxCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PendingInboxCard(
        title: 'Perlu perhatian',
        onSeeAll: _openFinanceVerification,
        seeAllLabel: 'Lihat semua',
        totalLabel: 'total menunggu',
        accentColor: _adminNavy,
        entries: [
          PendingInboxEntry(
            icon: Icons.receipt_long_outlined,
            label: 'Verifikasi pembayaran',
            count: _pendingVerifyCount,
            color: ColorUtils.warning600,
            subtitle: _pendingVerifyCount > 0
                ? 'Bukti transfer menunggu review'
                : 'Tidak ada bukti transfer baru',
            onTap: _openFinanceVerification,
          ),
          PendingInboxEntry(
            icon: Icons.description_outlined,
            label: 'RPP menunggu review',
            count: _pendingRppCount,
            color: ColorUtils.corporateBlue600,
            subtitle: _pendingRppCount > 0
                ? 'RPP guru menunggu persetujuan'
                : 'Semua RPP sudah direview',
            onTap: _openLessonPlanReview,
          ),
          PendingInboxEntry(
            icon: Icons.campaign_outlined,
            label: 'Pengumuman draft',
            count: _draftAnnouncementCount,
            color: ColorUtils.info600,
            subtitle: _draftAnnouncementCount > 0
                ? 'Draft belum dipublikasikan'
                : 'Tidak ada draft tersimpan',
            onTap: _openAnnouncementDrafts,
          ),
          PendingInboxEntry(
            icon: Icons.warning_amber_outlined,
            label: 'Tagihan menunggak',
            count: _overdueBillCount,
            color: ColorUtils.error600,
            subtitle: _overdueBillCount > 0
                ? 'Jatuh tempo terlewat'
                : 'Tidak ada tunggakan aktif',
            onTap: _openFinanceClassReport,
          ),
        ],
      ),
    );
  }

  // ── Quick actions — 4 tiles ──────────────────

  Widget _buildQuickActions() {
    return QuickActionGrid(
      columnsPerRow: 4,
      actions: [
        QuickAction(
          icon: Icons.people_alt_outlined,
          label: 'Siswa',
          color: ColorUtils.corporateBlue600,
          caption: 'Kelola data',
          onTap: _openSiswa,
        ),
        QuickAction(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Keuangan',
          color: ColorUtils.success600,
          caption: 'Jenis & tagihan',
          showBadge: _pendingVerifyCount > 0,
          onTap: _openKeuangan,
        ),
        QuickAction(
          icon: Icons.assignment_turned_in_outlined,
          label: 'Laporan',
          color: ColorUtils.warning600,
          caption: 'Nilai & raport',
          onTap: _openLaporanRaport,
        ),
        QuickAction(
          icon: Icons.settings_outlined,
          // Shortened from "Pengaturan" → "Setelan" so the label fits the
          // 4-column tile width on Samsung portrait without wrapping to
          // two lines ("Pengatura\nn").
          label: 'Setelan',
          color: ColorUtils.slate700,
          caption: 'Sekolah',
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

  void _openPresensi() =>
      AppNavigator.push(context, const AdminAttendanceReportScreen());

  void _openAktivitasKelas() =>
      AppNavigator.push(context, const AdminClassActivityScreen());

  Widget _buildModulLain() {
    return ModulLainStrip(
      title: 'Modul lain',
      totalLabel: '8 modul',
      accentColor: _adminNavy,
      visibleItems: [
        ModulLainStripItem(
          label: 'Jadwal',
          icon: Icons.schedule_outlined,
          onTap: _openJadwal,
        ),
        ModulLainStripItem(
          label: 'Nilai',
          icon: Icons.edit_note_outlined,
          onTap: _openNilai,
        ),
        ModulLainStripItem(
          label: 'Presensi',
          icon: Icons.check_circle_outline,
          onTap: _openPresensi,
        ),
        ModulLainStripItem(
          label: 'Rapor',
          icon: Icons.assignment_turned_in_outlined,
          onTap: _openLaporanRaport,
        ),
      ],
      overflowItems: [
        ModulLainStripItem(
          label: 'Pengumuman',
          icon: Icons.announcement_outlined,
          onTap: () =>
              AppNavigator.push(context, const AdminAnnouncementScreen()),
        ),
        ModulLainStripItem(
          label: 'Aktivitas Kelas',
          icon: Icons.local_activity_outlined,
          onTap: _openAktivitasKelas,
        ),
        ModulLainStripItem(
          label: 'RPP',
          icon: Icons.description_outlined,
          onTap: () =>
              AppNavigator.push(context, const AdminLessonPlanScreen()),
        ),
        ModulLainStripItem(
          label: 'Akun',
          icon: Icons.person_outline,
          onTap: widget.onAccountTap,
        ),
      ],
    );
  }

}

// ── Realtime indicator pill (T3.3) ────────────

/// Small rounded pill rendered inside the navy gradient hero. Green dot when
/// [isFresh] is true, grey when the last poll failed. Copy flips between
/// "Terhubung realtime · HH:MM" and "Terakhir diperbarui N menit lalu".
///
/// Pure presentational — the parent owns the polling state and passes it
/// down so this widget can stay `StatelessWidget`.
class _RealtimePill extends StatelessWidget {
  final bool isFresh;
  final DateTime lastSync;

  const _RealtimePill({required this.isFresh, required this.lastSync});

  @override
  Widget build(BuildContext context) {
    // Match SVG mockup line 27-28: small green dot (no pill bg) + faint
    // 10.5pt white-72% text inline. Goes UNDER the greeting/name row, ABOVE
    // the school pill.
    final dotColor = isFresh ? const Color(0xFF4ADE80) : Colors.grey.shade400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PulsingDot(color: dotColor, animate: isFresh),
        const SizedBox(width: 8),
        Text(
          _buildLabel(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.72),
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  String _buildLabel() {
    if (isFresh) {
      final hh = lastSync.hour.toString().padLeft(2, '0');
      final mm = lastSync.minute.toString().padLeft(2, '0');
      return 'Terhubung realtime · $hh:$mm';
    }
    final mins = DateTime.now().difference(lastSync).inMinutes;
    if (mins <= 0) return 'Mencoba menyambungkan ulang…';
    return 'Terakhir diperbarui $mins menit lalu';
  }
}

/// Subtle 1.5 s pulse on the green "connected" dot. Skips the animation when
/// [animate] is false so the stale/grey dot is a static marker.
class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool animate;

  const _PulsingDot({required this.color, required this.animate});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final alpha = widget.animate ? (0.55 + 0.45 * _controller.value) : 1.0;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: alpha),
            shape: BoxShape.circle,
            boxShadow: widget.animate
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}

// ── Top-row icon button used inside the navy gradient hero ──

/// A 36×36 white-translucent button used in the hero's top row (replaces
/// the old DashboardAppBar icons). Optional [showDot] paints a small red
/// dot at top-right (matches the mockup's notification badge).
class _HeroIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color gradientBg;
  final bool showDot;

  const _HeroIconButton({
    required this.icon,
    required this.onTap,
    required this.gradientBg,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.14),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            onTap: onTap,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, size: 18, color: Colors.white),
            ),
          ),
        ),
        if (showDot)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                border: Border.all(color: gradientBg, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
