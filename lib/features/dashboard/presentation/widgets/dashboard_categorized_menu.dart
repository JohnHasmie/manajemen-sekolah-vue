// Categorized menu widget for the dashboard navigation grid.
//
// Extracted from DashboardScreen to reduce file size.
// Renders role-specific CategorySection groups (admin) or a flat MenuItemCard
// list (wali/parent), and teacher sections.
//
// Like a Vue component that uses `v-if="role === 'admin'"` to switch between
// different menu layouts, each backed by its own list of MenuItem definitions.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/category_section.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/admin_menu_items_mixin.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/teacher_menu_items_mixin.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/parent_menu_items_mixin.dart';

/// Renders the role-specific categorized navigation menu on the dashboard.
///
/// Pass [effectiveRole] ('admin', 'guru', or 'wali'), [state], [primaryColor],
/// and the callbacks [onShowNoStudentsDialog] / [onShowStudentSelectionDialog]
/// that the parent screen provides for dialogs that need broader context.
class DashboardCategorizedMenu extends ConsumerStatefulWidget {
  final String effectiveRole;
  final DashboardState state;
  final Color primaryColor;

  /// Called when the parent menu item for "Presence" finds no linked
  /// students.
  final VoidCallback onShowNoStudentsDialog;

  /// Called when the parent menu item for "Presence" finds multiple
  /// students.
  final Future<void> Function(
    Map<String, dynamic> parent,
    List<dynamic> studentsData, {
    String? academicYearId,
  })
  onShowStudentSelectionDialog;

  const DashboardCategorizedMenu({
    super.key,
    required this.effectiveRole,
    required this.state,
    required this.primaryColor,
    required this.onShowNoStudentsDialog,
    required this.onShowStudentSelectionDialog,
  });

  @override
  ConsumerState<DashboardCategorizedMenu> createState() =>
      _DashboardCategorizedMenuState();
}

class _DashboardCategorizedMenuState
    extends ConsumerState<DashboardCategorizedMenu>
    with AdminMenuItemsMixin, TeacherMenuItemsMixin, ParentMenuItemsMixin {
  @override
  Widget build(BuildContext context) {
    if (widget.effectiveRole == 'admin') {
      return Column(
        children: [
          CategorySection(
            title: '📊 ${AppLocalizations.categoryDataManagement.tr}',
            icon: Icons.folder_shared,
            accentColor: ColorUtils.slate700,
            primaryColor: widget.primaryColor,
            items: getAdminDataManagementItems(context),
          ),
          CategorySection(
            title:
                '📢 '
                '${AppLocalizations.categoryAcademicCommunication.tr}',
            icon: Icons.school,
            accentColor: ColorUtils.slate700,
            primaryColor: widget.primaryColor,
            items: getAdminAcademicItems(context),
          ),
          CategorySection(
            title:
                '💰 '
                '${AppLocalizations.categoryFinanceSettings.tr}',
            icon: Icons.settings,
            accentColor: ColorUtils.slate700,
            primaryColor: widget.primaryColor,
            items: getAdminFinanceItems(context),
          ),
        ],
      );
    } else if (widget.effectiveRole == 'guru') {
      return Column(
        children: [
          CategorySection(
            title: '📚 ${AppLocalizations.categoryTeaching.tr}',
            icon: Icons.school,
            accentColor: ColorUtils.slate700,
            primaryColor: widget.primaryColor,
            items: getTeacherTeachingItems(context),
          ),
          CategorySection(
            title:
                '✏️ '
                '${AppLocalizations.categoryAssessmentPlanning.tr}',
            icon: Icons.edit_note,
            accentColor: ColorUtils.slate700,
            primaryColor: widget.primaryColor,
            items: getTeacherAssessmentItems(context),
          ),
        ],
      );
    } else if (widget.effectiveRole == 'wali') {
      return Column(
        children: [
          CategorySection(
            title: '🏠 MENU',
            icon: Icons.family_restroom,
            accentColor: ColorUtils.slate700,
            primaryColor: widget.primaryColor,
            items: getParentMenuItems(context),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
