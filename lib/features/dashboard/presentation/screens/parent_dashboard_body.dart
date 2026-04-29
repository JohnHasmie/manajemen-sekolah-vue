// Parent dashboard body (wali) — mirrors admin Phase 3 redesign with violet gradient.
//
// Shape of the screen (top-to-bottom)
// -----------------------------------
//   1. DashboardAppBar   — school name, lang, bell, profile
//   2. Violet gradient hero — SchoolPill.expanded + realtime indicator
//   3. KPI row (2x2 grid) — 4 cards: Anak terdaftar, Kehadiran, Nilai baru, Tagihan
//   4. Perlu perhatian    — 4 inbox rows (Tagihan jatuh tempo, Nilai baru anak, etc.)
//   5. Aksi cepat         — 4 quick action tiles (Pengumuman, Tagihan, Nilai, Kehadiran)
//   6. Modul lain strip   — horizontal with overflow sheet
//
// TODO (backend): Wire these stats['...'] keys:
//   - children_count: count of registered children
//   - attendance_rate: overall attendance percentage
//   - new_grades_7days: count of new grades in last 7 days
//   - overdue_bills_count: count of unpaid bills
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/shell/shell_nav.dart';
import 'package:manajemensekolah/core/shell/shell_tab.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/hero_stats_card.dart';
import 'package:manajemensekolah/core/widgets/pending_inbox_card.dart';
import 'package:manajemensekolah/core/widgets/quick_action_grid.dart';
import 'package:manajemensekolah/core/widgets/school_pill.dart';
import 'package:manajemensekolah/core/widgets/modul_lain_strip.dart';

import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/providers/academic_year_provider.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_app_bar.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/parent_report_card_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/settings_screen.dart';

// Parent role uses the Kamil Edu brand Azzure Blue. The hero gradient
// goes from brand azure → a slightly darker shade so the gradient still
// reads as "depth" while staying inside the brand swatch. Tokens live in
// `ColorUtils.brandAzure` / `ColorUtils.brandAzureDeep` so deep-tab parent
// screens share the same gradient endpoints via `ColorUtils.brandGradient('wali')`.
final Color _parentBrandAzure = ColorUtils.brandAzure;
final Color _parentBrandAzureDeep = ColorUtils.brandAzureDeep;
const Duration _pollInterval = Duration(seconds: 60);

/// Parent dashboard body.
class ParentDashboardBody extends ConsumerStatefulWidget {
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

  const ParentDashboardBody({
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
  ConsumerState<ParentDashboardBody> createState() =>
      _ParentDashboardBodyState();
}

class _ParentDashboardBodyState extends ConsumerState<ParentDashboardBody> {
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
    if (raw == null || raw.isEmpty) return 'Sekolah';
    return raw;
  }

  String get _greetingSubtitle {
    final year = widget.state.userData['academic_year']?.toString();
    if (year == null || year.isEmpty) return 'Orang Tua';
    return 'Orang Tua · TP $year';
  }

  String get _userName {
    final raw = widget.state.userData['name']?.toString().trim();
    return (raw == null || raw.isEmpty) ? 'Orang Tua' : raw;
  }

  String _greetingPart() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'pagi';
    if (hour < 15) return 'siang';
    if (hour < 18) return 'sore';
    return 'malam';
  }

  // KPI counts
  int get _childrenCount => _asInt(widget.state.stats['children_count']);
  int get _attendanceRate => _asInt(widget.state.stats['attendance_rate']);
  int get _newGradesCount => _asInt(widget.state.stats['new_grades_7days']);
  int get _overdueBillsCount => _asInt(widget.state.stats['overdue_bills_count']);

  // Inbox counts
  int get _overdueBills => _asInt(widget.state.stats['overdue_bills_count']);
  int get _newGrades => _asInt(widget.state.stats['unread_grades']);
  int get _newAnnouncements =>
      _asInt(widget.state.stats['unread_announcements']);
  int get _attendanceAlpha => _asInt(widget.state.stats['unread_presence']);

  static int _asInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  // Navigation handlers — every parent quick-action / inbox row routes
  // through `ShellNav.goTo` so the bottom-nav shell highlights the
  // correct tab AND pushes the deep screen on top. Mirrors the
  // `cards_mixin` pattern so dashboard and worklist links behave
  // identically.

  String? get _academicYearId =>
      ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();

  void _openAnnouncements() {
    ShellNav.goTo(
      ref,
      role: 'wali',
      tab: ShellTab.academic,
      pushOnTop: const ParentAnnouncementScreen(),
    );
  }

  void _openGrades() {
    ShellNav.goTo(
      ref,
      role: 'wali',
      tab: ShellTab.academic,
      pushOnTop: ParentGradeScreen(academicYearId: _academicYearId),
    );
  }

  void _openAttendance() {
    // ParentAttendanceTab handles 0 / 1 / multi-anak resolution itself.
    ShellNav.goTo(ref, role: 'wali', tab: ShellTab.attendance);
  }

  void _openBilling() {
    // ParentBillingScreen IS the Finance tab root — switch tabs.
    ShellNav.goTo(ref, role: 'wali', tab: ShellTab.finance);
  }

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

  /// Combined hero + KPI section matching the Phase 3 mockup pattern.
  /// Edge-to-edge violet gradient under the system status bar with rounded
  /// bottom corners; greeting + name + icon row at top, then realtime,
  /// school pill, and KPI cards floating onto the bottom edge.
  Widget _buildHeroWithKpiOverlay(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;
    final notifBadge = _asInt(widget.state.stats['unread_notifications']) +
        _asInt(widget.state.stats['unread_announcements']);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 70),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_parentBrandAzure, _parentBrandAzureDeep],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: _parentBrandAzure.withValues(alpha: 0.18),
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
                // cards overlap an empty violet band rather than the pill.
                48,
              ),
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
                        gradientBg: _parentBrandAzure,
                      ),
                      const SizedBox(width: 6),
                      _HeroIconButton(
                        icon: Icons.notifications_outlined,
                        onTap: widget.onNotificationTap,
                        gradientBg: _parentBrandAzure,
                        showDot: notifBadge > 0,
                      ),
                      const SizedBox(width: 6),
                      _HeroIconButton(
                        icon: Icons.person_outline,
                        onTap: widget.onAccountTap,
                        gradientBg: _parentBrandAzure,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _RealtimePill(isFresh: _isFresh, lastSync: _lastSync),
                  const SizedBox(height: AppSpacing.md),
                  SchoolPill.expanded(
                    schoolName: _schoolName,
                    subtitle: _greetingSubtitle,
                    onTap: widget.onSchoolSwitchTap,
                    accentColor: _parentBrandAzure,
                    actionLabel: 'Ganti',
                    onDarkSurface: true,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          key: widget.statsSectionKey,
          left: 16,
          right: 16,
          bottom: 0,
          child: _buildKpiCards(),
        ),
      ],
    );
  }

  /// Build 3 KPI cards in a single horizontal row (unified for all roles).
  Widget _buildKpiCards() {
    // Count helpers for caption values
    final alphaCount = _asInt(widget.state.stats['unread_presence'] ?? 0);

    return HeroStatsRow(
      cards: [
        HeroStatsCard(
          label: 'Anak',
          value: _formatNumber(_childrenCount),
          icon: Icons.family_restroom_outlined,
          accentColor: widget.primaryColor,
          caption: 'terdaftar',
          onTap: () {},
        ),
        HeroStatsCard(
          label: 'Kehadiran',
          value: '$_attendanceRate%',
          icon: Icons.check_circle_outline,
          accentColor: ColorUtils.success600,
          caption: '$alphaCount alpha',
          onTap: () {},
        ),
        HeroStatsCard(
          label: 'Tagihan',
          value: _formatNumber(_overdueBillsCount),
          icon: Icons.account_balance_wallet_outlined,
          accentColor: ColorUtils.error600,
          caption: 'jatuh tempo',
          onTap: () {},
        ),
      ],
    );
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PendingInboxCard(
        title: 'Perlu perhatian',
        onSeeAll: _openBilling,
        seeAllLabel: 'Lihat semua',
        totalLabel: 'total menunggu',
        accentColor: _parentBrandAzure,
        entries: [
          PendingInboxEntry(
            icon: Icons.warning_amber_outlined,
            label: 'Tagihan jatuh tempo',
            count: _overdueBills,
            color: ColorUtils.error600,
            subtitle: _overdueBills > 0
                ? 'Beberapa tagihan belum dibayar'
                : 'Tidak ada tunggakan aktif',
            onTap: _openBilling,
          ),
          PendingInboxEntry(
            icon: Icons.grade_outlined,
            label: 'Nilai baru anak',
            count: _newGrades,
            color: ColorUtils.success600,
            subtitle: _newGrades > 0
                ? 'Ada nilai terbaru untuk dilihat'
                : 'Belum ada nilai terbaru',
            onTap: _openGrades,
          ),
          PendingInboxEntry(
            icon: Icons.announcement_outlined,
            label: 'Pengumuman baru',
            count: _newAnnouncements,
            color: ColorUtils.info600,
            subtitle: _newAnnouncements > 0
                ? 'Informasi terbaru dari sekolah'
                : 'Tidak ada pengumuman baru',
            onTap: _openAnnouncements,
          ),
          PendingInboxEntry(
            icon: Icons.check_circle_outline,
            label: 'Kehadiran anak',
            count: _attendanceAlpha,
            color: ColorUtils.warning600,
            subtitle: _attendanceAlpha > 0
                ? 'Data kehadiran terbaru tersedia'
                : 'Kehadiran anak terdokumentasi',
            onTap: _openAttendance,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return QuickActionGrid(
      columnsPerRow: 4,
      actions: [
        QuickAction(
          icon: Icons.announcement_outlined,
          label: 'Pengumuman',
          color: widget.primaryColor,
          caption: 'Informasi',
          showBadge: _newAnnouncements > 0,
          onTap: _openAnnouncements,
        ),
        QuickAction(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Tagihan',
          color: ColorUtils.error600,
          caption: 'Pembayaran',
          showBadge: _overdueBills > 0,
          onTap: _openBilling,
        ),
        QuickAction(
          icon: Icons.grade_outlined,
          label: 'Nilai',
          color: ColorUtils.success600,
          caption: 'Akademik',
          showBadge: _newGrades > 0,
          onTap: _openGrades,
        ),
        QuickAction(
          icon: Icons.check_circle_outline,
          label: 'Kehadiran',
          color: ColorUtils.warning600,
          caption: 'Presensi',
          showBadge: _attendanceAlpha > 0,
          onTap: _openAttendance,
        ),
      ],
    );
  }

  void _openReportCard() {
    ShellNav.goTo(
      ref,
      role: 'wali',
      tab: ShellTab.academic,
      pushOnTop: ParentReportCardScreen(academicYearId: _academicYearId),
    );
  }

  void _openClassActivity() {
    ShellNav.goTo(
      ref,
      role: 'wali',
      tab: ShellTab.academic,
      pushOnTop: ParentClassActivityScreen(academicYearId: _academicYearId),
    );
  }

  void _openAccount() {
    AppNavigator.push(context, const SettingsScreen());
  }

  Widget _buildModulLain() {
    return ModulLainStrip(
      title: 'Modul lain',
      totalLabel: '7 modul',
      accentColor: _parentBrandAzureDeep,
      visibleItems: [
        ModulLainStripItem(
          label: 'Raport',
          icon: Icons.school_outlined,
          onTap: _openReportCard,
        ),
        ModulLainStripItem(
          label: 'Kegiatan\nKelas',
          icon: Icons.event_outlined,
          onTap: _openClassActivity,
        ),
        ModulLainStripItem(
          label: 'Kehadiran',
          icon: Icons.check_circle_outline,
          onTap: _openAttendance,
        ),
      ],
      overflowItems: [
        ModulLainStripItem(
          label: 'Nilai',
          icon: Icons.grade_outlined,
          onTap: _openGrades,
        ),
        ModulLainStripItem(
          label: 'Pengumuman',
          icon: Icons.announcement_outlined,
          onTap: _openAnnouncements,
        ),
        ModulLainStripItem(
          label: 'Tagihan',
          icon: Icons.account_balance_wallet_outlined,
          onTap: _openBilling,
        ),
        ModulLainStripItem(
          label: 'Akun',
          icon: Icons.account_circle_outlined,
          onTap: _openAccount,
        ),
      ],
    );
  }
}

class _RealtimePill extends StatelessWidget {
  final bool isFresh;
  final DateTime lastSync;

  const _RealtimePill({required this.isFresh, required this.lastSync});

  @override
  Widget build(BuildContext context) {
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

/// 36x36 white-translucent button rendered inside the violet gradient hero.
/// [showDot] paints a small red dot at top-right (notification badge).
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
