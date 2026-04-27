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
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/hero_stats_card.dart';
import 'package:manajemensekolah/core/widgets/pending_inbox_card.dart';
import 'package:manajemensekolah/core/widgets/quick_action_grid.dart';
import 'package:manajemensekolah/core/widgets/school_pill.dart';
import 'package:manajemensekolah/core/widgets/modul_lain_strip.dart';

import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_app_bar.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart';

const Color _parentViolet = Color(0xFF534AB7);
const Color _parentVioletFade = Color(0xFF6B5AC9);
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
    final raw = widget.state.userData['nama_sekolah']?.toString();
    if (raw == null || raw.isEmpty) return 'Sekolah';
    return raw;
  }

  String get _greetingSubtitle {
    final raw = widget.state.userData['name']?.toString().trim();
    final first = (raw == null || raw.isEmpty) ? 'Orang Tua' : raw.split(' ').first;
    return 'Halo, $first · Orang Tua';
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

  // Navigation handlers
  void _openAnnouncements() =>
      AppNavigator.push(context, const ParentAnnouncementScreen());

  void _openGrades() => AppNavigator.push(
    context,
    ParentGradeScreen(academicYearId: widget.state.userData['academic_year_id']?.toString()),
  );

  void _openAttendance() {
    // TODO: wire to parent attendance screen
  }

  void _openBilling() {
    // TODO: wire to parent billing screen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: AppRefreshIndicator(
        onRefresh: _manualRefresh,
        color: widget.primaryColor,
        edgeOffset: MediaQuery.of(context).padding.top + kToolbarHeight,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            DashboardAppBar(
              schoolName: widget.state.userData['nama_sekolah'],
              primaryColor: widget.primaryColor,
              unreadNotifications: widget.state.stats['unread_notifications'],
              unreadAnnouncements: widget.state.stats['unread_announcements'],
              profileHeaderKey: widget.profileHeaderKey,
              onLanguageTap: widget.onLanguageTap,
              onNotificationTap: widget.onNotificationTap,
              onAccountTap: widget.onAccountTap,
            ),
            SliverToBoxAdapter(
              key: widget.heroSectionKey,
              child: _buildGradientHeader(),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            SliverToBoxAdapter(
              key: widget.statsSectionKey,
              child: _buildKpiCards(),
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

  Widget _buildGradientHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_parentViolet, _parentVioletFade],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: _parentViolet.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SchoolPill.expanded(
            schoolName: _schoolName,
            subtitle: _greetingSubtitle,
            onTap: widget.onSchoolSwitchTap,
            accentColor: _parentViolet,
            actionLabel: 'Ganti',
          ),
          const SizedBox(height: AppSpacing.md),
          _RealtimePill(isFresh: _isFresh, lastSync: _lastSync),
        ],
      ),
    );
  }

  Widget _buildKpiCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          // First row of 2 cards
          Row(
            children: [
              Expanded(
                child: HeroStatsCard(
                  label: 'Anak terdaftar',
                  value: _formatNumber(_childrenCount),
                  icon: Icons.family_restroom_outlined,
                  accentColor: widget.primaryColor,
                  caption: 'di sekolah',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: HeroStatsCard(
                  label: 'Kehadiran',
                  value: '$_attendanceRate%',
                  icon: Icons.check_circle_outline,
                  accentColor: ColorUtils.warning600,
                  caption: 'hari ini',
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Second row of 2 cards
          Row(
            children: [
              Expanded(
                child: HeroStatsCard(
                  label: 'Nilai baru',
                  value: _formatNumber(_newGradesCount),
                  icon: Icons.grade_outlined,
                  accentColor: ColorUtils.success600,
                  caption: '7 hari terakhir',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: HeroStatsCard(
                  label: 'Tagihan',
                  value: _formatNumber(_overdueBillsCount),
                  icon: Icons.warning_amber_outlined,
                  accentColor: ColorUtils.error600,
                  caption: 'jatuh tempo',
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
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
        accentColor: _parentViolet,
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
          badgeCount: _newAnnouncements > 0 ? _newAnnouncements : null,
          onTap: _openAnnouncements,
        ),
        QuickAction(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Tagihan',
          color: ColorUtils.error600,
          caption: 'Pembayaran',
          badgeCount: _overdueBills > 0 ? _overdueBills : null,
          onTap: _openBilling,
        ),
        QuickAction(
          icon: Icons.grade_outlined,
          label: 'Nilai',
          color: ColorUtils.success600,
          caption: 'Akademik',
          badgeCount: _newGrades > 0 ? _newGrades : null,
          onTap: _openGrades,
        ),
        QuickAction(
          icon: Icons.check_circle_outline,
          label: 'Kehadiran',
          color: ColorUtils.warning600,
          caption: 'Presensi',
          badgeCount: _attendanceAlpha > 0 ? _attendanceAlpha : null,
          onTap: _openAttendance,
        ),
      ],
    );
  }

  Widget _buildModulLain() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: ModulLainStrip(
        title: 'Modul lain',
        totalLabel: '7 modul',
        accentColor: _parentViolet,
        visibleItems: [
          ModulLainStripItem(
            label: 'Raport',
            icon: Icons.school_outlined,
            onTap: () {}, // TODO: wire to report card screen
          ),
          ModulLainStripItem(
            label: 'Kegiatan Kelas',
            icon: Icons.event_outlined,
            onTap: () {}, // TODO: wire to class activity screen
          ),
          ModulLainStripItem(
            label: 'Akun',
            icon: Icons.account_circle_outlined,
            onTap: () {}, // TODO: wire to account settings
          ),
          ModulLainStripItem(
            label: 'Placeholder',
            icon: Icons.more_horiz,
            onTap: () {},
          ),
        ],
        overflowItems: const [],
      ),
    );
  }
}

class _RealtimePill extends StatelessWidget {
  final bool isFresh;
  final DateTime lastSync;

  const _RealtimePill({required this.isFresh, required this.lastSync});

  @override
  Widget build(BuildContext context) {
    final dotColor = isFresh ? const Color(0xFF22C55E) : Colors.grey.shade400;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: dotColor, animate: isFresh),
          const SizedBox(width: 6),
          Text(
            _buildLabel(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
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
