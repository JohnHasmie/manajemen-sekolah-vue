// Admin "Academic" tab root — hub of academic-domain surfaces.
//
// Per `P1_BottomNav_Spec.md` § 2.1 — admin's Academic tab groups
// teaching/learning screens: Mapel, Jadwal, Nilai (overview), RPP,
// Raport, Pengumuman, Kegiatan Kelas, Presensi.
//
// 8 tiles is on the busy side; the audit's Theme 1 explicitly called
// this out as a "hub-with-many-children" case where the hub pattern
// beats a flat tab landing.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/shell/widgets/shell_tab_header.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_dashboard_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/admin_class_activity_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/menu_item_card.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/admin_grade_overview_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/admin_rpp_review_hub_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/admin_raport_hub_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/admin_schedule_management_screen.dart';
import 'package:manajemensekolah/features/subjects/presentation/screens/admin_subject_management_screen.dart';

class AdminAcademicHub extends StatelessWidget {
  const AdminAcademicHub({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = ColorUtils.getRoleColor('admin');
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          ShellTabHeader(
            title: 'Akademik',
            subtitle: 'Mata pelajaran, jadwal, nilai, dan komunikasi',
            accentColor: accent,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                MenuItemCard(
                  title: 'Mata Pelajaran',
                  icon: Icons.book_outlined,
                  primaryColor: accent,
                  onTap: () => AppNavigator.push(
                    context,
                    const AdminSubjectManagementScreen(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: 'Jadwal Mengajar',
                  icon: Icons.schedule_outlined,
                  primaryColor: accent,
                  onTap: () => AppNavigator.push(
                    context,
                    const TeachingScheduleManagementScreen(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: 'Rekap Nilai',
                  icon: Icons.assessment_outlined,
                  primaryColor: accent,
                  onTap: () => AppNavigator.push(
                    context,
                    const AdminGradeOverviewScreen(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: 'Kelola RPP',
                  icon: Icons.description_outlined,
                  primaryColor: accent,
                  onTap: () => AppNavigator.push(
                    context,
                    const AdminRppReviewHubScreen(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: 'Raport Siswa',
                  icon: Icons.assignment_turned_in_outlined,
                  primaryColor: accent,
                  onTap: () => AppNavigator.push(
                    context,
                    const AdminRaportHubScreen(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: 'Pengumuman',
                  icon: Icons.announcement_outlined,
                  primaryColor: accent,
                  onTap: () => AppNavigator.push(
                    context,
                    const AdminAnnouncementScreen(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: 'Kegiatan Kelas',
                  icon: Icons.local_activity_outlined,
                  primaryColor: accent,
                  onTap: () => AppNavigator.push(
                    context,
                    const AdminClassActivityScreen(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: 'Laporan Presensi',
                  icon: Icons.check_circle_outline,
                  primaryColor: accent,
                  onTap: () => AppNavigator.push(
                    context,
                    const AdminAttendanceDashboardScreen(),
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
}

/// Same header pattern as `admin_people_hub.dart`. Duplicated locally
/// rather than extracted to keep each tab file self-contained while we
/// figure out the shared-tab-header API in Sub-PR 5/6.
