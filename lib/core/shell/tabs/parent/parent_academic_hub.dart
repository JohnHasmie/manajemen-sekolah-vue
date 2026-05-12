// Parent "Academic" tab root — Phase 3 v2 (compact).
//
// Per `Parent_Phase3_AkademikHub_Mockup_v2.svg`. The hub is a
// landing page, not a launcher: shorter brand-azure gradient hero,
// 4 compact feature cards, and an "Aktivitas terbaru" preview
// strip surfacing the latest 1-2 unread items inline so the parent
// gets a snapshot before drilling in.
//
//   • Hero (160 px) — title + subtitle. No PILIH ANAK chips at the
//     hub level; child switching happens inside each deep screen
//     via its own ChildSelectorChipRow.
//   • 4 cards (64 px each) — Nilai / E-Raport / Kegiatan Kelas /
//     Pengumuman. Tinted 44 px icon tile + title + subtitle +
//     chevron. Tap pushes the corresponding deep screen with the
//     active academicYearId from `academicYearRiverpod`.
//   • Aktivitas terbaru — fetched via `DashboardService` and
//     rendered as inline preview rows showing type / title /
//     timestamp; tap routes to the matching deep screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart';
import 'package:manajemensekolah/features/dashboard/data/dashboard_service.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/parent_report_card_screen.dart';

class ParentAcademicHub extends ConsumerStatefulWidget {
  const ParentAcademicHub({super.key});

  @override
  ConsumerState<ParentAcademicHub> createState() => _ParentAcademicHubState();
}

class _ParentAcademicHubState extends ConsumerState<ParentAcademicHub> {
  Future<List<Map<String, dynamic>>>? _recentFuture;

  @override
  void initState() {
    super.initState();
    _recentFuture = _loadRecent();
  }

  Future<List<Map<String, dynamic>>> _loadRecent() async {
    final yearId = _activeAcademicYearId(ref);
    return DashboardService.getParentAcademicRecent(academicYearId: yearId);
  }

  Future<void> _refresh() async {
    final next = _loadRecent();
    setState(() => _recentFuture = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: RefreshIndicator(
        color: ColorUtils.brandAzureDeep,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _buildHero(context),
            const SizedBox(height: AppSpacing.lg),
            _AcademicFeatureCard(
              iconBg: const Color(0xFFDCFCE7),
              iconFg: const Color(0xFF15803D),
              icon: Icons.star_rounded,
              title: 'Nilai',
              subtitle: 'Daftar penilaian per mapel',
              onTap: () => _openGrades(context, ref),
            ),
            _AcademicFeatureCard(
              iconBg: const Color(0xFFDBEAFE),
              iconFg: const Color(0xFF1D4ED8),
              icon: Icons.assignment_turned_in_outlined,
              title: 'E-Raport',
              subtitle: 'Ringkasan rapor tiap semester',
              onTap: () => _openReportCard(context, ref),
            ),
            _AcademicFeatureCard(
              iconBg: const Color(0xFFFEF3C7),
              iconFg: const Color(0xFFB45309),
              icon: Icons.menu_book_rounded,
              title: 'Kegiatan Kelas',
              subtitle: 'Tugas & materi yang diberikan guru',
              onTap: () => _openClassActivity(context, ref),
            ),
            _AcademicFeatureCard(
              iconBg: const Color(0xFFE0F2FE),
              iconFg: const Color(0xFF0E7490),
              icon: Icons.campaign_outlined,
              title: 'Pengumuman',
              subtitle: 'Informasi resmi dari sekolah',
              onTap: () =>
                  AppNavigator.push(context, const ParentAnnouncementScreen()),
            ),
            _RecentActivitySection(future: _recentFuture, onTapItem: _openItem),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  /// Brand-azure gradient hero. Solid white text — no
  /// semi-transparent fades.
  Widget _buildHero(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: ColorUtils.brandGradient('wali'),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.brandAzure.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, statusBarHeight + 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            'Untuk anak Anda',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Akademik',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Pantau nilai, raport, kegiatan & pengumuman',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String? _activeAcademicYearId(WidgetRef ref) {
    return ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
  }

  void _openGrades(BuildContext context, WidgetRef ref) {
    AppNavigator.push(
      context,
      ParentGradeScreen(academicYearId: _activeAcademicYearId(ref)),
    );
  }

  void _openReportCard(BuildContext context, WidgetRef ref) {
    AppNavigator.push(
      context,
      ParentReportCardScreen(academicYearId: _activeAcademicYearId(ref)),
    );
  }

  void _openClassActivity(BuildContext context, WidgetRef ref) {
    AppNavigator.push(
      context,
      ParentClassActivityScreen(academicYearId: _activeAcademicYearId(ref)),
    );
  }

  /// Routes a tapped recent item to its matching deep screen, keyed
  /// off `type` returned by the backend.
  void _openItem(Map<String, dynamic> item) {
    final type = (item['type'] ?? '').toString();
    switch (type) {
      case 'announcement':
        AppNavigator.push(context, const ParentAnnouncementScreen());
      case 'grade':
        _openGrades(context, ref);
      case 'class_activity':
        _openClassActivity(context, ref);
      case 'report_card':
        _openReportCard(context, ref);
      default:
        // Unknown type — best-effort fallback to announcements since
        // it's the most common parent-facing feed.
        AppNavigator.push(context, const ParentAnnouncementScreen());
    }
  }
}

/// Compact feature card per v2 mockup — 64 px tall, 44 px icon
/// tile, 14 pt title, single-line subtitle, chevron on the right.
class _AcademicFeatureCard extends StatelessWidget {
  final Color iconBg;
  final Color iconFg;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AcademicFeatureCard({
    required this.iconBg,
    required this.iconFg,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            decoration: BoxDecoration(
              border: Border.all(color: ColorUtils.slate200, width: 0.75),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: const BorderRadius.all(Radius.circular(11)),
                  ),
                  child: Icon(icon, size: 22, color: iconFg),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: ColorUtils.slate600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: ColorUtils.slate400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "AKTIVITAS TERBARU" section with up to 2 preview rows.
/// Hidden entirely if the backend returns nothing — keeps the hub
/// visually clean for new parents with no activity yet.
class _RecentActivitySection extends StatelessWidget {
  final Future<List<Map<String, dynamic>>>? future;
  final void Function(Map<String, dynamic> item) onTapItem;

  const _RecentActivitySection({required this.future, required this.onTapItem});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Map<String, dynamic>>[];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Text(
                'AKTIVITAS TERBARU',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            for (final item in items.take(2))
              _RecentActivityCard(item: item, onTap: () => onTapItem(item)),
          ],
        );
      },
    );
  }
}

/// Single preview row in the "Aktivitas terbaru" feed. Backend is
/// the source of truth for the fields; this widget is purely
/// presentational and tolerant of missing fields.
class _RecentActivityCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _RecentActivityCard({required this.item, required this.onTap});

  ({Color bg, Color fg, IconData icon, String label}) _appearance() {
    final type = (item['type'] ?? '').toString();
    switch (type) {
      case 'announcement':
        return (
          bg: const Color(0xFFFEE2E2),
          fg: const Color(0xFFDC2626),
          icon: Icons.priority_high_rounded,
          label: 'Pengumuman',
        );
      case 'grade':
        return (
          bg: const Color(0xFFDCFCE7),
          fg: const Color(0xFF15803D),
          icon: Icons.check_rounded,
          label: 'Nilai',
        );
      case 'class_activity':
        return (
          bg: const Color(0xFFFEF3C7),
          fg: const Color(0xFFB45309),
          icon: Icons.menu_book_outlined,
          label: 'Kegiatan',
        );
      case 'report_card':
        return (
          bg: const Color(0xFFDBEAFE),
          fg: const Color(0xFF1D4ED8),
          icon: Icons.assignment_turned_in_outlined,
          label: 'Raport',
        );
      default:
        return (
          bg: const Color(0xFFE0F2FE),
          fg: const Color(0xFF0E7490),
          icon: Icons.notifications_none_rounded,
          label: 'Update',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _appearance();
    final title = (item['title'] ?? '').toString();
    final source = (item['source'] ?? a.label).toString();
    final timeAgo = (item['time_ago'] ?? '').toString();
    final extra = (item['extra'] ?? '').toString();
    final badge = (item['badge'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: ColorUtils.slate200, width: 0.75),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: a.bg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(a.icon, size: 14, color: a.fg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              source,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: ColorUtils.slate600,
                              ),
                            ),
                          ),
                          if (timeAgo.isNotEmpty)
                            Text(
                              timeAgo,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: ColorUtils.slate500,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title.isEmpty ? a.label : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate900,
                        ),
                      ),
                      if (badge.isNotEmpty || extra.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (badge.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: a.bg,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(9),
                                  ),
                                ),
                                child: Text(
                                  badge,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: a.fg,
                                  ),
                                ),
                              ),
                            if (badge.isNotEmpty && extra.isNotEmpty)
                              const SizedBox(width: 6),
                            if (extra.isNotEmpty)
                              Expanded(
                                child: Text(
                                  extra,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: ColorUtils.slate600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
