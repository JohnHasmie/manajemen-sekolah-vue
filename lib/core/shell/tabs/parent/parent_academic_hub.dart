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
import 'package:manajemensekolah/core/shell/widgets/shell_tab_header.dart';
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
          ShellTabHeader(
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

