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
import 'package:manajemensekolah/core/constants/dashboard_modules.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/shell/widgets/shell_tab_header.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/dashboard_list_tile.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_dashboard_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/admin_class_activity_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/admin_grade_recap_overview_screen.dart';
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
          // Shared `DashboardListTile` — same card design as parent
          // Akademik hub. Icons + colors from the catalog so cross-
          // role identity stays consistent.
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DashboardListTile(
                    title: 'Mata Pelajaran',
                    subtitle: 'Daftar mapel & beban jam',
                    icon: DashboardModules.mataPelajaran.icon,
                    color: DashboardModules.mataPelajaran.color,
                    onTap: () => AppNavigator.push(
                      context,
                      const AdminSubjectManagementScreen(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DashboardListTile(
                    title: 'Jadwal Mengajar',
                    subtitle: 'Atur jadwal per kelas & guru',
                    icon: DashboardModules.jadwal.icon,
                    color: DashboardModules.jadwal.color,
                    onTap: () => AppNavigator.push(
                      context,
                      const TeachingScheduleManagementScreen(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DashboardListTile(
                    title: 'Rekap Nilai',
                    subtitle: 'Ringkasan nilai per kelas & mapel',
                    icon: DashboardModules.rekapNilai.icon,
                    color: DashboardModules.rekapNilai.color,
                    // The "Rekap Nilai" tile must open the Rekap Nilai
                    // (grade recap) screen — it previously opened
                    // AdminGradeOverviewScreen ("Buku Nilai"), a different
                    // screen, so the label and destination disagreed.
                    onTap: () => AppNavigator.push(
                      context,
                      const AdminGradeRecapOverviewScreen(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DashboardListTile(
                    title: 'Kelola RPP',
                    subtitle: 'Antrian review & persetujuan RPP',
                    icon: DashboardModules.rpp.icon,
                    color: DashboardModules.rpp.color,
                    onTap: () => AppNavigator.push(
                      context,
                      const AdminRppReviewHubScreen(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DashboardListTile(
                    title: 'Raport Siswa',
                    subtitle: 'Pipeline raport tiap kelas',
                    icon: DashboardModules.raport.icon,
                    color: DashboardModules.raport.color,
                    onTap: () => AppNavigator.push(
                      context,
                      const AdminRaportHubScreen(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DashboardListTile(
                    title: 'Pengumuman',
                    subtitle: 'Pengumuman resmi sekolah',
                    icon: DashboardModules.pengumuman.icon,
                    color: DashboardModules.pengumuman.color,
                    onTap: () => AppNavigator.push(
                      context,
                      const AdminAnnouncementScreen(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DashboardListTile(
                    title: 'Kegiatan Kelas',
                    subtitle: 'Tugas & aktivitas dari guru',
                    icon: DashboardModules.kegiatanKelas.icon,
                    color: DashboardModules.kegiatanKelas.color,
                    onTap: () => AppNavigator.push(
                      context,
                      const AdminClassActivityScreen(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DashboardListTile(
                    title: 'Laporan Presensi',
                    subtitle: 'Rekap kehadiran siswa sekolah',
                    icon: DashboardModules.kehadiran.icon,
                    color: DashboardModules.kehadiran.color,
                    onTap: () => AppNavigator.push(
                      context,
                      const AdminAttendanceDashboardScreen(),
                    ),
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
