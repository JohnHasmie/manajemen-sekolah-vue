// Admin "People" tab root — hub of 3 people-management surfaces.
//
// Renders inside a [RoleShell] tab branch, so it does NOT include a back
// button (the shell owns back-nav). The header is a [ShellTabHeader]
// with title + subtitle; below it sits a list of [DashboardListTile]s
// that push the existing admin CRUD screens.
//
// Per `P1_BottomNav_Spec.md` § 2.1 — admin's People tab groups the
// entity-management screens that represent humans (Siswa, Guru) plus
// Kelas (a people-grouping rather than an academic concept).

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/constants/dashboard_modules.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/shell/widgets/shell_tab_header.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/dashboard_list_tile.dart';
import 'package:manajemensekolah/features/classrooms/presentation/screens/admin_classroom_management_screen.dart';
import 'package:manajemensekolah/features/students/presentation/screens/admin_student_management_screen.dart';
import 'package:manajemensekolah/features/teachers/presentation/screens/admin_teacher_management_screen.dart';

class AdminPeopleHub extends StatelessWidget {
  const AdminPeopleHub({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = ColorUtils.getRoleColor('admin');
    // Per-row icon colors come from `DashboardModules` so each list
    // tile gets its module-specific tint (blue Siswa, violet Guru,
    // amber Kelas) — same pattern as the parent Akademik hub.
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          ShellTabHeader(
            title: kCorSheTabPeople.tr,
            subtitle: kCorSheAdminPeopleSubtitle.tr,
            accentColor: accent,
          ),
          // Shared `DashboardListTile` — same card design as parent
          // Akademik hub. Icons + colors from the catalog so cross-
          // role identity stays consistent (blue Siswa, violet Guru,
          // amber Kelas).
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DashboardListTile(
                    title: kCorSheAdminManageStudents.tr,
                    subtitle: kCorSheAdminStudentsSubtitle.tr,
                    icon: DashboardModules.siswa.icon,
                    color: DashboardModules.siswa.color,
                    onTap: () => AppNavigator.push(
                      context,
                      const StudentManagementScreen(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DashboardListTile(
                    title: kCorSheAdminManageTeachers.tr,
                    subtitle: kCorSheAdminTeachersSubtitle.tr,
                    icon: DashboardModules.guru.icon,
                    color: DashboardModules.guru.color,
                    onTap: () =>
                        AppNavigator.push(context, const TeacherAdminScreen()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DashboardListTile(
                    title: kCorSheAdminManageClasses.tr,
                    subtitle: kCorSheAdminClassesSubtitle.tr,
                    icon: DashboardModules.kelas.icon,
                    color: DashboardModules.kelas.color,
                    onTap: () => AppNavigator.push(
                      context,
                      const AdminClassManagementScreen(),
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
