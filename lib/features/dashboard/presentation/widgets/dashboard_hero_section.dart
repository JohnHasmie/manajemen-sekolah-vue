// DashboardHeroSection — the gradient hero card at the top of the dashboard body.
// Shows a greeting, the user's name, the current academic year/semester, and 4 KPI stat cells.
// Uses ConsumerWidget because it calls ref.watch(academicYearRiverpod) for reactive year display.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/hero_stat_cell.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/hero_stat_skeleton.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// The gradient hero card shown directly below the app bar.
///
/// Analogous to a Vue "hero banner" component — it takes all display data via
/// constructor props (like Vue `:stats`, `:userData`) and delegates interaction
/// back to the parent via [onAcademicYearTap].
///
/// Extends [ConsumerWidget] because the academic-year badge uses
/// `ref.watch(academicYearRiverpod)` to reactively update when the year changes.
class DashboardHeroSection extends ConsumerWidget {
  /// Role-specific primary color (blue for admin, green for guru, purple for wali).
  final Color primaryColor;

  /// The effective role string: 'admin', 'guru', or 'wali'.
  final String effectiveRole;

  /// Full dashboard state — provides [userData], [stats], [isStatsLoaded], etc.
  final DashboardState state;

  /// Called when the academic-year badge is tapped (opens the year picker dialog).
  final VoidCallback onAcademicYearTap;

  /// Optional GlobalKey placed on the outer Container for the onboarding tour.
  final GlobalKey? heroSectionKey;

  const DashboardHeroSection({
    super.key,
    required this.primaryColor,
    required this.effectiveRole,
    required this.state,
    required this.onAcademicYearTap,
    this.heroSectionKey,
  });

  // ── Greeting helpers ────────────────────────────────────────────────────────

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppLocalizations.goodMorning.tr;
    if (hour < 17) return AppLocalizations.goodAfternoon.tr;
    return AppLocalizations.goodEvening.tr;
  }

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '🌅';
    if (hour < 17) return '☀️';
    return '🌙';
  }

  // ── Role-specific stat cells ─────────────────────────────────────────────────

  List<Widget> _buildFourColumnStats() {
    final lp = languageProvider;
    if (effectiveRole == 'admin') {
      return [
        HeroStatCell(
          icon: Icons.people_outline,
          value: state.stats['total_students']?.toString() ?? '0',
          label: lp.getTranslatedText({'en': 'Students', 'id': 'Siswa'}),
        ),
        HeroStatCell(
          icon: Icons.school_outlined,
          value: state.stats['total_teachers']?.toString() ?? '0',
          label: lp.getTranslatedText({'en': 'Teachers', 'id': 'Guru'}),
        ),
        HeroStatCell(
          icon: Icons.class_outlined,
          value: state.stats['total_classes']?.toString() ?? '0',
          label: lp.getTranslatedText({'en': 'Classes', 'id': 'Kelas'}),
        ),
        HeroStatCell(
          icon: Icons.book_outlined,
          value: state.stats['total_subjects']?.toString() ?? '0',
          label: lp.getTranslatedText({'en': 'Subjects', 'id': 'Mapel'}),
        ),
      ];
    } else if (effectiveRole == 'guru') {
      return [
        HeroStatCell(
          icon: Icons.people_outline,
          value: state.stats['total_students']?.toString() ?? '0',
          label: lp.getTranslatedText({'en': 'Students', 'id': 'Siswa'}),
        ),
        HeroStatCell(
          icon: Icons.class_outlined,
          value: state.stats['total_classes']?.toString() ?? '0',
          label: lp.getTranslatedText({'en': 'Classes', 'id': 'Kelas'}),
        ),
        HeroStatCell(
          icon: Icons.schedule_outlined,
          value: state.stats['classes_today']?.toString() ?? '0',
          label: lp.getTranslatedText({'en': 'Today', 'id': 'Hari Ini'}),
        ),
        HeroStatCell(
          icon: Icons.assignment_outlined,
          value: state.stats['total_rpps']?.toString() ?? '0',
          label: lp.getTranslatedText({'en': 'Plans', 'id': 'RPP'}),
        ),
      ];
    } else {
      return [
        HeroStatCell(
          icon: Icons.child_care_outlined,
          value: state.stats['children_registered']?.toString() ?? '0',
          label: lp.getTranslatedText({'en': 'Children', 'id': 'Anak'}),
        ),
        HeroStatCell(
          icon: Icons.announcement_outlined,
          value: state.stats['unread_announcements']?.toString() ?? '0',
          label: lp.getTranslatedText({'en': 'News', 'id': 'Info'}),
        ),
        HeroStatCell(
          icon: Icons.grade_outlined,
          value: state.stats['unread_grades']?.toString() ?? '0',
          label: lp.getTranslatedText({'en': 'Grades', 'id': 'Nilai'}),
        ),
        HeroStatCell(
          icon: Icons.calendar_today_outlined,
          value: state.stats['unread_presence']?.toString() ?? '0',
          label: lp.getTranslatedText({'en': 'Attendance', 'id': 'Absen'}),
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch so the academic-year badge re-renders when the selected year changes.
    // Like a Vue computed property that depends on an academicYear store value.
    final academicYearProvider = ref.watch(academicYearRiverpod);
    final academicYear =
        academicYearProvider.selectedAcademicYear?['year'] ?? '-';
    final semester = state.currentSemesterLabel ?? '-';

    return Container(
      key: heroSectionKey,
      margin: EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        gradient: ColorUtils.heroGradient(primaryColor: primaryColor),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Decorative circle - top right
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            // Decorative circle - bottom left
            Positioned(
              bottom: -25,
              left: 15,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            // Small accent dot
            Positioned(
              top: 20,
              right: 70,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),

            // Academic Year & Semester badge - Top Right
            Positioned(
              top: 10,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onAcademicYearTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              academicYear,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              semester,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Main content
            Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Greeting row
                  Row(
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(width: AppSpacing.xs),
                      Text(
                        _getGreetingEmoji(),
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  SizedBox(height: 3),

                  // User name
                  Text(
                    state.userData['name'] ?? state.userData['nama'] ?? 'User',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 14),

                  // 4-Column Stats Grid — shows skeletons while loading
                  Row(
                    children: state.isStatsLoaded
                        ? _buildFourColumnStats()
                              .map((stat) => Expanded(child: stat))
                              .toList()
                        : List.generate(
                            4,
                            (_) => Expanded(child: HeroStatSkeleton()),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
