// Admin "People" tab root — hub of 3 people-management surfaces.
//
// Renders inside a [RoleShell] tab branch, so it does NOT include a back
// button (the shell owns back-nav). The header is a gradient strip with
// title + subtitle; below it sits a list of [MenuItemCard]s that push
// the existing admin CRUD screens.
//
// Per `P1_BottomNav_Spec.md` § 2.1 — admin's People tab groups the
// entity-management screens that represent humans (Siswa, Guru) plus
// Kelas (a people-grouping rather than an academic concept).

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/shell/widgets/shell_tab_header.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/classrooms/presentation/screens/admin_classroom_management_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/menu_item_card.dart';
import 'package:manajemensekolah/features/students/presentation/screens/admin_student_management_screen.dart';
import 'package:manajemensekolah/features/teachers/presentation/screens/admin_teacher_management_screen.dart';

class AdminPeopleHub extends StatelessWidget {
  const AdminPeopleHub({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = ColorUtils.getRoleColor('admin');
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          ShellTabHeader(
            title: 'Orang',
            subtitle: 'Kelola data siswa, guru, dan kelas',
            accentColor: accent,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                MenuItemCard(
                  title: 'Kelola Siswa',
                  icon: Icons.people_alt_outlined,
                  primaryColor: accent,
                  onTap: () => AppNavigator.push(
                    context,
                    const StudentManagementScreen(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: 'Kelola Guru',
                  icon: Icons.person_outline,
                  primaryColor: accent,
                  onTap: () =>
                      AppNavigator.push(context, const TeacherAdminScreen()),
                ),
                const SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: 'Kelola Kelas',
                  icon: Icons.class_outlined,
                  primaryColor: accent,
                  onTap: () => AppNavigator.push(
                    context,
                    const AdminClassManagementScreen(),
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

