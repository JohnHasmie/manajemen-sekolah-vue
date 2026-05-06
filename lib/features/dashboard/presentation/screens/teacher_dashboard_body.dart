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
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/hero_stats_card.dart';
import 'package:manajemensekolah/core/widgets/pending_inbox_card.dart';
import 'package:manajemensekolah/core/widgets/quick_action_grid.dart';
import 'package:manajemensekolah/core/widgets/school_pill.dart';
import 'package:manajemensekolah/core/widgets/modul_lain_strip.dart';

import 'package:manajemensekolah/features/announcements/presentation/screens/teacher_announcement_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_app_bar.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_input_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_recap_overview.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/teacher_lesson_plan_screen.dart';
import 'package:manajemensekolah/features/teachers/presentation/providers/teacher_provider.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_class_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_overview.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/teacher_schedule_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/settings_screen.dart';

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
final Color _teacherBrandAzure = ColorUtils.brandAzure;
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

  // Removed greetingPart in favor of AppLocalizations.greeting

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

  void _openMaterials() =>
      AppNavigator.push(context, TeacherMaterialScreen(teacher: widget.state.userData));

  void _openLessonPlans() {
    final tp = ref.read(teacherRiverpod);
    final tId = tp.teacherId
        ?? widget.state.userData['teacher_id']?.toString()
        ?? '';
    if (tId.isEmpty) return;
    AppNavigator.push(
      context,
      LessonPlanScreen(
        teacherId: tId,
        teacherName: tp.teacherName
            ?? widget.state.userData['name']?.toString()
            ?? 'Guru',
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

  void _openAttendance() =>
      AppNavigator.push(context, AttendancePage(teacher: widget.state.userData));

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
  void _openAccount() =>
      AppNavigator.push(context, const SettingsScreen());

  void _openReportCards() {
    final tp = ref.read(teacherRiverpod);
    AppNavigator.push(
      context,
      ReportCardOverviewPage(
        teacher: {
          'id': tp.teacherId ?? '',
          'nama': tp.teacherName ?? 'Guru',
          'email':
              widget.state.userData['email']?.toString()
                  ?? '',
          'role': 'guru',
        },
      ),
    );
  }

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
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;
    final notifBadge = _asInt(widget.state.stats['unread_notifications']) +
        _asInt(widget.state.stats['unread_announcements']);
    return ExcludeSemantics(
     child: Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 70),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_teacherBrandDark, _teacherBrandAzure],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: _teacherBrandDark.withValues(alpha: 0.18),
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
                // cards overlap an empty teal band rather than the pill.
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
                      _HeroIconButton(
                        icon: Icons.language_outlined,
                        onTap: widget.onLanguageTap,
                        gradientBg: _teacherBrandDark,
                      ),
                      const SizedBox(width: 6),
                      _HeroIconButton(
                        icon: Icons.notifications_outlined,
                        onTap: widget.onNotificationTap,
                        gradientBg: _teacherBrandDark,
                        showDot: notifBadge > 0,
                      ),
                      const SizedBox(width: 6),
                      _HeroIconButton(
                        icon: Icons.person_outline,
                        onTap: widget.onAccountTap,
                        gradientBg: _teacherBrandDark,
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
                    accentColor: _teacherCobalt,
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
    ),
    );
  }

  /// Build 3 KPI cards in a single horizontal row (unified for all roles).
  Widget _buildKpiCards() {
    final approvedRppCount = _asInt(
      widget.state.stats['approved_lesson_plans'] ?? 0,
    );

    return HeroStatsRow(
      cards: [
        HeroStatsCard(
          label: AppLocalizations.dbStudentsTaught.tr,
          value: _formatNumber(_studentCount),
          icon: Icons.school_outlined,
          accentColor: widget.primaryColor,
          caption: '${_classCount} ${AppLocalizations.dbClasses.tr}',
          onTap: () {},
        ),
        HeroStatsCard(
          label: AppLocalizations.dbSessionsToday.tr,
          value: _formatNumber(_sessionsTodayCount),
          icon: Icons.schedule_outlined,
          accentColor: ColorUtils.success600,
          caption: AppLocalizations.dbSchedule.tr,
          onTap: () {},
        ),
        HeroStatsCard(
          label: AppLocalizations.dbTeacher.tr == 'Guru' ? 'RPP' : 'Lesson Plans',
          value: _formatNumber(_totalRppCount),
          icon: Icons.description_outlined,
          accentColor: ColorUtils.warning600,
          caption: '$approvedRppCount ${AppLocalizations.dbApproved.tr}',
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
        title: AppLocalizations.dbAttentionRequired.tr,
        onSeeAll: _openLessonPlans,
        seeAllLabel: AppLocalizations.dbSeeAll.tr,
        totalLabel: AppLocalizations.dbTotalWaiting.tr,
        accentColor: _teacherCobalt,
        entries: [
          PendingInboxEntry(
            icon: Icons.description_outlined,
            label: AppLocalizations.dbRppNeedsRevision.tr,
            count: _pendingRppRevisions,
            color: ColorUtils.warning600,
            subtitle: _pendingRppRevisions > 0
                ? AppLocalizations.dbRppNeedsFix.tr
                : AppLocalizations.dbAllRppCompliant.tr,
            onTap: _openLessonPlans,
          ),
          PendingInboxEntry(
            icon: Icons.campaign_outlined,
            label: AppLocalizations.dbAnnouncementDrafts.tr,
            count: _draftAnnouncements,
            color: ColorUtils.info600,
            subtitle: _draftAnnouncements > 0
                ? AppLocalizations.dbDraftNotPublished.tr
                : AppLocalizations.dbNoDraftsSaved.tr,
            onTap: _openAnnouncementDrafts,
          ),
          PendingInboxEntry(
            icon: Icons.article_outlined,
            label: AppLocalizations.dbMaterialsNotPublished.tr,
            count: _pendingMaterials,
            color: ColorUtils.corporateBlue600,
            subtitle: _pendingMaterials > 0
                ? AppLocalizations.dbMaterialsWaitingPublication.tr
                : AppLocalizations.dbAllMaterialsPublished.tr,
            onTap: _openMaterials,
          ),
          PendingInboxEntry(
            icon: Icons.event_outlined,
            label: AppLocalizations.dbPendingActivities.tr,
            count: _pendingActivities,
            color: ColorUtils.success600,
            subtitle: _pendingActivities > 0
                ? AppLocalizations.dbClassActivitiesWaiting.tr
                : AppLocalizations.dbNoPendingActivities.tr,
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
          label: 'Kegiatan',
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
    return ModulLainStrip(
      title: AppLocalizations.dbOtherModules.tr,
      totalLabel: '7 ${AppLocalizations.dbOtherModules.tr.toLowerCase()}',
      accentColor: _teacherCobalt,
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
          onTap: _openGradeRecap,
        ),
        ModulLainStripItem(
          label: 'Rapor',
          icon: Icons.school_outlined,
          onTap: _openReportCards,
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
          onTap: _openRecommendation,
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
      return '${AppLocalizations.dbConnectedRealtime.tr}$hh:$mm';
    }
    final mins = DateTime.now().difference(lastSync).inMinutes;
    if (mins <= 0) return AppLocalizations.dbConnecting.tr;
    return '${AppLocalizations.dbLastUpdated.tr} $mins ${AppLocalizations.dbMinsAgo.tr}';
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool animate;

  const _PulsingDot({required this.animate, required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: widget.color,
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
  }
}

/// 36x36 white-translucent button rendered inside the teal gradient hero.
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
