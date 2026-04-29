// Parent "Academic" tab root — Phase 3 redesign.
//
// Per `Parent_Phase3_AkademikHub_Mockup.svg`. The hub is no longer a
// flat menu list — it's a feature-card dashboard that gives the
// parent a per-section snapshot before they drill in:
//
//   • Brand-azure gradient hero with title + subtitle. (No child
//     selector at the hub level — each deep screen owns its own
//     ChildSelectorChipRow so child switching stays consistent
//     with the rest of the parent surface area.)
//   • 4 feature cards stacked vertically. Each card is tappable
//     and pushes its corresponding deep screen:
//       · Nilai (gradients via ParentGradeScreen)
//       · E-Raport (ParentReportCardScreen)
//       · Kegiatan Kelas (ParentClassActivityScreen)
//       · Pengumuman (ParentAnnouncementScreen)
//
// All four destinations take an optional `academicYearId` so the
// child screens can scope to the active year. We pull it from the
// shared `academicYearRiverpod` provider on tap.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/parent_report_card_screen.dart';

class ParentAcademicHub extends ConsumerWidget {
  const ParentAcademicHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: ListView(
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
            onTap: () => AppNavigator.push(
              context,
              const ParentAnnouncementScreen(),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  /// Brand-azure gradient hero with the title block. Mirrors the
  /// dashboard / Kehadiran hero idiom — solid white text on the
  /// gradient, no semi-transparent fades.
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
      padding: EdgeInsets.fromLTRB(
        20,
        statusBarHeight + 20,
        20,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Untuk anak Anda',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Akademik',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.1,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pantau nilai, raport, kegiatan, & pengumuman',
            style: TextStyle(
              fontSize: 12,
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
}

/// Feature card for the Akademik hub. Tinted icon tile on the
/// left, title + subtitle in the middle, chevron on the right.
/// Pressing the card pushes a deep screen via the hub's tap
/// handler — the card itself is purely presentational.
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
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: ColorUtils.slate200, width: 0.75),
              borderRadius: const BorderRadius.all(Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                  ),
                  child: Icon(icon, size: 26, color: iconFg),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
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
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: ColorUtils.slate600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
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
