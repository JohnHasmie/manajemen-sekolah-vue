// Admin data management hub screen - navigation menu to CRUD sub-screens.
//
// Like `pages/admin/data-management/index.vue` in a Vue app - a menu page
// that links to Students, Teachers, Classes, and Subjects management screens.
// In Laravel terms, this is like a resource index that links to individual
// resource controllers (StudentController, TeacherController, etc.).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/classrooms/presentation/screens/admin_classroom_management_screen.dart';
import 'package:manajemensekolah/features/students/presentation/screens/admin_student_management_screen.dart';
import 'package:manajemensekolah/features/subjects/presentation/screens/admin_subject_management_screen.dart';
import 'package:manajemensekolah/features/teachers/presentation/screens/admin_teacher_management_screen.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/menu_item_card.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Admin data management hub - a navigation menu linking to CRUD sub-screens.
///
/// This is a [StatelessWidget] (no local state, like a Vue component with no `data()`).
/// Each menu item navigates to a full CRUD screen using `Navigator.push()`,
/// which is Flutter's equivalent of Vue Router's `router.push('/admin/students')`.
class AdminDataManagementScreen extends StatelessWidget {
  const AdminDataManagementScreen({super.key});

  /// Builds the menu grid layout. Like Vue's `<template>` with a list of
  /// `<MenuItemCard>` components. Each card uses `Navigator.push` (like `router.push`).
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Header with gradient (matching Schedule Management style)
          _buildGradientHeader(context),

          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                MenuItemCard(
                  title: AppLocalizations.manageStudents.tr,
                  icon: Icons.people_alt_outlined,
                  onTap: () =>
                      AppNavigator.push(context, StudentManagementScreen()),
                  primaryColor: ColorUtils.corporateBlue600,
                ),
                SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: AppLocalizations.manageTeachers.tr,
                  icon: Icons.person_outline,
                  onTap: () => AppNavigator.push(context, TeacherAdminScreen()),
                  primaryColor: ColorUtils.corporateBlue600,
                ),
                SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: AppLocalizations.manageClasses.tr,
                  icon: Icons.class_outlined,
                  onTap: () =>
                      AppNavigator.push(context, AdminClassManagementScreen()),
                  primaryColor: ColorUtils.corporateBlue600,
                ),
                SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: AppLocalizations.manageSubjects.tr,
                  icon: Icons.book_outlined,
                  onTap: () =>
                      AppNavigator.push(context, SubjectManagementScreen()),
                  primaryColor: ColorUtils.corporateBlue600,
                ),
                SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the gradient header with back button and title.
  /// A reusable UI pattern across admin screens - like a Vue `<AppHeader>` component.
  Widget _buildGradientHeader(BuildContext context) {
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
          colors: [
            ColorUtils.corporateBlue600,
            ColorUtils.corporateBlue600.withValues(alpha: 0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.corporateBlue600.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => AppNavigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kelola Data',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Kelola semua data master sistem',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
