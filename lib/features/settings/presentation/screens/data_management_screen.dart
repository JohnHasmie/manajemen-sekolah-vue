// Admin · Kelola Data hub.
//
// Brand-aligned navigation hub linking to the four master-data CRUD
// screens (Siswa, Guru, Kelas, Mata Pelajaran). Visual contract
// mirrors `SystemSettingsScreen`'s DashboardListTile pattern so every
// admin list-menu reads as the same chrome:
//
//   1. `BrandPageHeader` — admin gradient + back arrow + title
//      "Kelola Data" + descriptive subtitle. Replaces the legacy
//      hand-rolled gradient + Row chrome.
//   2. Vertical list of `DashboardListTile` rows — icons + accents
//      pulled from the shared `DashboardModules` catalog so the icon
//      next to "Siswa" here matches the icon on the Beranda People
//      tile, the Priority Inbox deep-link, etc.
//
// Reached from the admin Sistem tab and from priority inbox items
// like "Wali kelas belum dipilih".
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/constants/dashboard_modules.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/dashboard_list_tile.dart';
import 'package:manajemensekolah/features/classrooms/presentation/screens/admin_classroom_management_screen.dart';
import 'package:manajemensekolah/features/students/presentation/screens/admin_student_management_screen.dart';
import 'package:manajemensekolah/features/subjects/presentation/screens/admin_subject_management_screen.dart';
import 'package:manajemensekolah/features/teachers/presentation/screens/admin_teacher_management_screen.dart';

class AdminDataManagementScreen extends StatelessWidget {
  const AdminDataManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          BrandPageHeader(
            role: 'admin',
            subtitle: 'MANAJEMEN DATA',
            title: 'Kelola Data',
          ),
          const SizedBox(height: AppSpacing.md),
          ..._buildTiles(context),
          SizedBox(
            height: AppSpacing.xl + MediaQuery.of(context).padding.bottom,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTiles(BuildContext context) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DashboardListTile(
          title: AppLocalizations.manageStudents.tr,
          subtitle: 'Daftar siswa · NIS · kelas aktif',
          icon: DashboardModules.siswa.icon,
          color: DashboardModules.siswa.color,
          onTap: () =>
              AppNavigator.push(context, const StudentManagementScreen()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DashboardListTile(
          title: AppLocalizations.manageTeachers.tr,
          subtitle: 'Profil guru · mapel diampu · kontak',
          icon: DashboardModules.guru.icon,
          color: DashboardModules.guru.color,
          onTap: () => AppNavigator.push(context, const TeacherAdminScreen()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DashboardListTile(
          title: AppLocalizations.manageClasses.tr,
          subtitle: 'Rombel · wali kelas · tingkat',
          icon: DashboardModules.kelas.icon,
          color: DashboardModules.kelas.color,
          onTap: () =>
              AppNavigator.push(context, const AdminClassManagementScreen()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DashboardListTile(
          title: AppLocalizations.manageSubjects.tr,
          subtitle: 'Mapel · KKM · kelas penerima',
          icon: DashboardModules.mataPelajaran.icon,
          color: DashboardModules.mataPelajaran.color,
          onTap: () =>
              AppNavigator.push(context, const AdminSubjectManagementScreen()),
        ),
      ),
    ];
  }
}
