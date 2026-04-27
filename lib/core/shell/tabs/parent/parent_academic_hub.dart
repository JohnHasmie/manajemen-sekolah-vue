// Parent "Academic" tab root — hub of academic-monitoring surfaces for
// the parent role.
//
// Per `P1_BottomNav_Spec.md` § 2.3 — wali's Akademik tab groups what a
// parent monitors academically: Nilai (grades), Raport (report card),
// Kegiatan Kelas (class activities), Pengumuman (announcements).
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
import 'package:manajemensekolah/features/dashboard/presentation/widgets/menu_item_card.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/parent_report_card_screen.dart';

class ParentAcademicHub extends ConsumerWidget {
  const ParentAcademicHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ColorUtils.getRoleColor('wali');
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _ShellTabHeader(
            title: 'Akademik',
            subtitle: 'Nilai, raport, kegiatan kelas, dan pengumuman',
            accentColor: accent,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                MenuItemCard(
                  title: 'Nilai',
                  icon: Icons.grade_outlined,
                  primaryColor: accent,
                  onTap: () => _openGrades(context, ref),
                ),
                const SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: 'Raport',
                  icon: Icons.assignment_turned_in_outlined,
                  primaryColor: accent,
                  onTap: () => _openReportCard(context, ref),
                ),
                const SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: 'Kegiatan Kelas',
                  icon: Icons.local_activity_outlined,
                  primaryColor: accent,
                  onTap: () => _openClassActivity(context, ref),
                ),
                const SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: 'Pengumuman',
                  icon: Icons.announcement_outlined,
                  primaryColor: accent,
                  onTap: () => AppNavigator.push(
                    context,
                    const ParentAnnouncementScreen(),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
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

class _ShellTabHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;

  const _ShellTabHeader({
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentColor, accentColor.withValues(alpha: 0.85)],
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
