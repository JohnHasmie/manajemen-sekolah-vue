// Teacher "Grades" tab root — hub of assessment + attendance surfaces.
//
// Per `P1_BottomNav_Spec.md` § 2.2 — guru's Nilai & Absensi tab groups
// scoring (Input Nilai, Rekap Nilai), record-keeping (Absensi),
// and reporting (Raport). Wali-kelas-only screens stay accessible via
// the role-toggle inside each child screen (Theme 9 in the audit
// confirms the toggle earns its place — keeping it for now).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/constants/dashboard_modules.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/shell/widgets/shell_tab_header.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/dashboard_list_tile.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/teachers/presentation/providers/teacher_provider.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_input_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_recap_overview.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_overview.dart';

class TeacherGradesHub extends ConsumerWidget {
  const TeacherGradesHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ColorUtils.getRoleColor('guru');
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          ShellTabHeader(
            title: 'Nilai & Absensi',
            subtitle: 'Rekap nilai, input, raport, dan presensi siswa',
            accentColor: accent,
          ),
          // Shared `DashboardListTile` — same card design as parent
          // Akademik hub. Icons + colors from the catalog.
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DashboardListTile(
                    title: 'Rekap Nilai',
                    subtitle: 'Ringkasan nilai per kelas & mapel',
                    icon: DashboardModules.rekapNilai.icon,
                    color: DashboardModules.rekapNilai.color,
                    onTap: () => _openGradeRecap(context, ref),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DashboardListTile(
                    title: 'Input Nilai',
                    subtitle: 'Buku nilai per penilaian',
                    icon: DashboardModules.bukuNilai.icon,
                    color: DashboardModules.bukuNilai.color,
                    onTap: () => _openGradeInput(context, ref),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DashboardListTile(
                    title: 'Absensi Siswa',
                    subtitle: 'Catat kehadiran per sesi',
                    icon: DashboardModules.kehadiran.icon,
                    color: DashboardModules.kehadiran.color,
                    onTap: () => _openAttendance(context, ref),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DashboardListTile(
                    title: 'Raport',
                    subtitle: 'Isi & terbitkan raport siswa',
                    icon: DashboardModules.raport.icon,
                    color: DashboardModules.raport.color,
                    onTap: () => _openReportCard(context, ref),
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

  void _openGradeRecap(BuildContext context, WidgetRef ref) {
    final teacherData = _resolveTeacherData(ref);
    if (teacherData == null) {
      SnackBarUtils.showInfo(context, 'ID guru tidak ditemukan.');
      return;
    }
    AppNavigator.push(context, GradeRecapOverviewPage(teacher: teacherData));
  }

  void _openGradeInput(BuildContext context, WidgetRef ref) {
    final teacherData = _resolveTeacherData(ref);
    if (teacherData == null) {
      SnackBarUtils.showInfo(context, 'ID guru tidak ditemukan.');
      return;
    }
    AppNavigator.push(context, GradePage(teacher: teacherData));
  }

  void _openAttendance(BuildContext context, WidgetRef ref) {
    final teacherData = _resolveTeacherData(ref);
    if (teacherData == null) {
      SnackBarUtils.showInfo(context, 'ID guru tidak ditemukan.');
      return;
    }
    AppNavigator.push(context, AttendancePage(teacher: teacherData));
  }

  void _openReportCard(BuildContext context, WidgetRef ref) {
    final teacherData = _resolveTeacherData(ref);
    if (teacherData == null) {
      SnackBarUtils.showInfo(context, 'ID guru tidak ditemukan.');
      return;
    }
    AppNavigator.push(context, ReportCardOverviewPage(teacher: teacherData));
  }

  Map<String, String>? _resolveTeacherData(WidgetRef ref) {
    final tp = ref.read(teacherRiverpod);
    final id = tp.teacherId;
    if (id == null || id.isEmpty) return null;
    return {
      'id': id,
      'nama': tp.teacherName ?? 'Teacher',
      'email':
          ref
              .read(dashboardProvider)
              .asData
              ?.value
              .userData['email']
              ?.toString() ??
          '',
      'role': 'guru',
    };
  }
}
