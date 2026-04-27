// Teacher dashboard body (guru) — mirrors admin Phase 3 redesign with teal gradient.
//
// Shape of the screen (top-to-bottom)
// -----------------------------------
//   1. DashboardAppBar   — school name, lang, bell, profile
//   2. Teal gradient hero — SchoolPill.expanded + realtime indicator
//   3. KPI row (2x2 grid) — 4 cards: Siswa diampu, Kelas, Sesi hari ini, RPP
//   4. Perlu perhatian    — 4 inbox rows (RPP butuh revisi, draft pengumuman, etc.)
//   5. Aksi cepat         — 4 quick action tiles (Jadwal, Absensi, Aktivitas, Nilai)
//   6. Modul lain strip   — horizontal with overflow sheet
//
// TODO (backend): Wire these stats['...'] keys:
//   - pending_rpp_revisions: count of RPP where status='revision_requested'
//   - draft_announcements: count of Announcement where status='draft'
//   - pending_materials: count of GeneratedMaterial where status='pending_publication'
//   - pending_class_activities: count of ClassActivity where status='pending'
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

import 'package:manajemensekolah/features/announcements/presentation/screens/teacher_announcement_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_app_bar.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_input_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/teacher_lesson_plan_screen.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/teacher_schedule_screen.dart';

const Color _teacherTeal = Color(0xFF0F6E56);
const Color _teacherTealFade = Color(0xFF1B7A65);
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
    final raw = widget.state.userData['nama_sekolah']?.toString();
    if (raw == null || raw.isEmpty) return 'Sekolah';
    return raw;
  }

  String get _greetingSubtitle {
    final raw = widget.state.userData['name']?.toString().trim();
    final first = (raw == null || raw.isEmpty) ? 'Guru' : raw.split(' ').first;
    return 'Halo, $first · Guru';
  }

  // Count helpers — read from the live stats map with 0 fallback
  int get _studentCount => _asInt(widget.state.stats['student_count']);
  int get _classCount => _asInt(widget.state.stats['class_count']);
  int get _sessionsTodayCount => _asInt(widget.state.stats['sessions_today']);
  int get _totalRppCount => _asInt(widget.state.stats['total_rpps']);

  // Inbox counts
  int get _pendingRppRevisions =>
      _asInt(widget.state.stats['pending_rpp_revisions']);
  int get _draftAnnouncements =>
      _asInt(widget.state.stats['draft_announcements']);
  int get _pendingMaterials => _asInt(widget.state.stats['pending_materials']);
  int get _pendingActivities =>
      _asInt(widget.state.stats['pending_class_activities']);

  static int _asInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  // Navigation handlers
  void _openSchedule() =>
      AppNavigator.push(context, const TeachingScheduleScreen());

  void _openMaterials() =>
      AppNavigator.push(context, TeacherMaterialScreen(teacher: widget.state.userData));

  void _openLessonPlans() => AppNavigator.push(
    context,
    LessonPlanScreen(
      teacherId:
          (widget.state.userData['teacher_id'] ?? widget.state.userData['id'])
              .toString(),
    ),
  );

  void _openGrades() => AppNavigator.push(
    context,
    GradePage(
      teacher: {
        'id': (widget.state.userData['teacher_id'] ??
                widget.state.userData['id'])
            ?.toString() ??
            '',
        'nama': widget.state.userData['nama'] ?? 'Guru',
        'email': widget.state.userData['email'] ?? '',
        'role': 'guru',
      },
    ),
  );

  void _openAttendance() =>
      AppNavigator.push(context, AttendancePage(teacher: widget.state.userData));

  void _openActivities() => AppNavigator.push(
    context,
    const TeacherClassActivityScreen(autoShowActivityDialog: true),
  );

  void _openAnnouncementDrafts() =>
      AppNavigator.push(context, const TeacherAnnouncementScreen(initialStatusFilter: 'draft'));

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
          colors: [_teacherTeal, _teacherTealFade],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: _teacherTeal.withValues(alpha: 0.18),
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
            accentColor: _teacherTeal,
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
                  label: 'Siswa diampu',
                  value: _formatNumber(_studentCount),
                  icon: Icons.people_alt_outlined,
                  accentColor: widget.primaryColor,
                  caption: 'terdaftar',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: HeroStatsCard(
                  label: 'Kelas',
                  value: _formatNumber(_classCount),
                  icon: Icons.class_outlined,
                  accentColor: ColorUtils.success600,
                  caption: 'mengajar',
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
                  label: 'Sesi hari ini',
                  value: _formatNumber(_sessionsTodayCount),
                  icon: Icons.schedule_outlined,
                  accentColor: ColorUtils.info600,
                  caption: 'terjadwal',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: HeroStatsCard(
                  label: 'RPP',
                  value: _formatNumber(_totalRppCount),
                  icon: Icons.description_outlined,
                  accentColor: ColorUtils.warning600,
                  caption: 'tersimpan',
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
        onSeeAll: _openLessonPlans,
        seeAllLabel: 'Lihat semua',
        totalLabel: 'total menunggu',
        accentColor: _teacherTeal,
        entries: [
          PendingInboxEntry(
            icon: Icons.description_outlined,
            label: 'RPP butuh revisi',
            count: _pendingRppRevisions,
            color: ColorUtils.warning600,
            subtitle: _pendingRppRevisions > 0
                ? 'RPP memerlukan perbaikan'
                : 'Semua RPP sudah sesuai',
            onTap: _openLessonPlans,
          ),
          PendingInboxEntry(
            icon: Icons.campaign_outlined,
            label: 'Pengumuman draft',
            count: _draftAnnouncements,
            color: ColorUtils.info600,
            subtitle: _draftAnnouncements > 0
                ? 'Draft belum dipublikasikan'
                : 'Tidak ada draft tersimpan',
            onTap: _openAnnouncementDrafts,
          ),
          PendingInboxEntry(
            icon: Icons.article_outlined,
            label: 'Materi belum terbit',
            count: _pendingMaterials,
            color: ColorUtils.corporateBlue600,
            subtitle: _pendingMaterials > 0
                ? 'Materi menunggu publikasi'
                : 'Semua materi sudah terbit',
            onTap: _openMaterials,
          ),
          PendingInboxEntry(
            icon: Icons.event_outlined,
            label: 'Aktivitas tertunda',
            count: _pendingActivities,
            color: ColorUtils.success600,
            subtitle: _pendingActivities > 0
                ? 'Kegiatan kelas menunggu'
                : 'Tidak ada kegiatan tertunda',
            onTap: _openActivities,
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
          icon: Icons.schedule_outlined,
          label: 'Jadwal',
          color: widget.primaryColor,
          caption: 'Mengajar',
          onTap: _openSchedule,
        ),
        QuickAction(
          icon: Icons.how_to_reg_outlined,
          label: 'Absensi',
          color: ColorUtils.warning600,
          caption: 'Kehadiran',
          onTap: _openAttendance,
        ),
        QuickAction(
          icon: Icons.local_activity_outlined,
          label: 'Aktivitas',
          color: ColorUtils.info600,
          caption: 'Kelas',
          onTap: _openActivities,
        ),
        QuickAction(
          icon: Icons.edit_note_outlined,
          label: 'Nilai',
          color: ColorUtils.success600,
          caption: 'Input',
          onTap: _openGrades,
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
        accentColor: _teacherTeal,
        visibleItems: [
          ModulLainStripItem(
            label: 'Materi',
            icon: Icons.article_outlined,
            onTap: _openMaterials,
          ),
          ModulLainStripItem(
            label: 'RPP',
            icon: Icons.description_outlined,
            onTap: _openLessonPlans,
          ),
          ModulLainStripItem(
            label: 'Rekap Nilai',
            icon: Icons.assessment_outlined,
            onTap: _openGrades,
          ),
          ModulLainStripItem(
            label: 'Rapor',
            icon: Icons.school_outlined,
            onTap: () {}, // TODO: wire to report card screen
          ),
        ],
        overflowItems: [
          ModulLainStripItem(
            label: 'Pengumuman',
            icon: Icons.announcement_outlined,
            onTap: _openAnnouncementDrafts,
          ),
          ModulLainStripItem(
            label: 'Rekomendasi',
            icon: Icons.lightbulb_outline,
            onTap: () {}, // TODO: wire to recommendation screen
          ),
          ModulLainStripItem(
            label: 'Akun',
            icon: Icons.account_circle_outlined,
            onTap: () {}, // TODO: wire to account settings
          ),
        ],
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
