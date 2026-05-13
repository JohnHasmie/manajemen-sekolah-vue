import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_alert_dialog.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/language_picker_sheet.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/parent_attendance_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_account_sheet.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_school_selection_dialog.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Provides dialog and modal methods for Dashboard.
/// Handles language selection, account details, school switching,
/// role picking, student selection, and error messages.
mixin DialogMixin on ConsumerState<Dashboard> {
  /// Picker sheet for switching the active academic year.
  ///
  /// Tap-to-select dismisses immediately, so no footer — the row's
  /// own `InkWell` is the commit. Brand-color follows the dashboard
  /// role (admin / teacher / parent) via `ColorUtils.getRoleColor`.
  ///
  /// Migrated from `showDialog(SimpleDialog(...))` in the HH brand
  /// sweep: list-pickers belong in sheets, not centered modals.
  void showAcademicYearDialog(BuildContext context) {
    final provider = ref.read(academicYearRiverpod);
    final years = provider.academicYears;
    final primary = ColorUtils.getRoleColor(widget.role);

    AppBottomSheet.show<void>(
      context: context,
      title: AppLocalizations.selectAcademicYear.tr,
      icon: Icons.event_rounded,
      primaryColor: primary,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: years.map((year) {
          final isSelected = provider.selectedAcademicYear?['id'] == year['id'];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                provider.setSelectedYear(year['id'].toString());
                ref.read(dashboardProvider.notifier).reloadForYearChange();
                AppNavigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: AppSpacing.md,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      year['year'] ?? '-',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? primary : ColorUtils.slate900,
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_rounded, color: primary, size: 20),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Shows the brand language picker bottom sheet (Phase-5 redesign).
  /// The legacy `AlertDialog` form was replaced by
  /// [showLanguagePickerSheet] — same entry point name preserved so
  /// existing call sites in the dashboard app bar keep compiling.
  /// `languageProvider` and `primaryColor` parameters are kept for
  /// signature compatibility but unused by the new sheet (the sheet
  /// reads `languageRiverpod` directly).
  void showLanguageDialog(
    BuildContext context,
    LanguageProvider languageProvider,
    Color primaryColor,
  ) {
    showLanguagePickerSheet(context: context, ref: ref);
  }

  /// Shows account bottom sheet with user profile and school info.
  /// Delegates to [DashboardAccountSheet] widget.
  void showAccountBottomSheet(
    BuildContext context,
    DashboardState state,
    Color primaryColor,
    String effectiveRole, {
    required VoidCallback onLanguageTap,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DashboardAccountSheet(
        state: state,
        primaryColor: primaryColor,
        effectiveRole: effectiveRole,
        onLanguageTap: onLanguageTap,
        onShowSchoolSelection: () =>
            showSchoolSelectionDialog(context, state, primaryColor),
        onShowRoleSelection: (schoolId, roleList) =>
            showRolePickerDialog(context, schoolId, roleList),
      ),
    );
  }

  /// Shows school-selection dialog for multi-school users.
  /// Delegates to [showDashboardSchoolSelectionDialog].
  void showSchoolSelectionDialog(
    BuildContext ctx,
    DashboardState state,
    Color primaryColor,
  ) {
    showDashboardSchoolSelectionDialog(
      context: ctx,
      ref: ref,
      state: state,
      currentRole: widget.role,
      primaryColor: primaryColor,
      onNeedsRoleSelection: showRolePickerDialog,
    );
  }

  /// Shows role-picker dialog after school switch that exposes
  /// multiple roles. Delegates to [showDashboardRolePickerDialog].
  void showRolePickerDialog(
    BuildContext ctx,
    String schoolId,
    List<String> roleList,
  ) {
    final primaryColor = ColorUtils.primaryColor;
    showDashboardRolePickerDialog(
      context: ctx,
      ref: ref,
      schoolId: schoolId,
      roleList: roleList,
      currentRole: widget.role,
      primaryColor: primaryColor,
    );
  }

  /// Picker sheet for parent users to choose which child's
  /// attendance to inspect.
  ///
  /// Migrated from `showDialog(AlertDialog(ListView.builder))` in
  /// the HH brand sweep — a per-child list is a sheet-shape
  /// interaction. Brand-color uses the parent (`wali`) role token,
  /// since this picker is only invoked from parent surfaces.
  Future<void> showStudentSelectionDialog(
    BuildContext context,
    Map<String, dynamic> parent,
    List<dynamic> studentData, {
    String? academicYearId,
  }) async {
    final primary = ColorUtils.getRoleColor('wali');

    await AppBottomSheet.show<void>(
      context: context,
      title: AppLocalizations.selectChild.tr,
      icon: Icons.family_restroom_rounded,
      primaryColor: primary,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: studentData.map((student) {
          final model = Student.fromJson(student as Map<String, dynamic>);
          return Material(
            color: Colors.transparent,
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: CircleAvatar(
                backgroundColor: primary.withValues(alpha: 0.12),
                child: Text(
                  model.initials,
                  style: TextStyle(color: primary, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                model.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                model.className.isNotEmpty
                    ? model.className
                    : AppLocalizations.classNotAvailable.tr,
              ),
              onTap: () async {
                AppNavigator.pop(context);
                await AppNavigator.push(
                  context,
                  ParentAttendanceScreen(
                    parent: parent,
                    studentId: model.id,
                    academicYearId: academicYearId,
                  ),
                );
                ref.read(dashboardProvider.notifier).refreshStats();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Shows error dialog when a parent has no linked students.
  void showNoStudentsDialog(BuildContext context) {
    AppAlertDialog.show(
      context: context,
      title: AppLocalizations.information.tr,
      message: AppLocalizations.noStudentLinked.tr,
      confirmText: AppLocalizations.ok.tr,
      showCancel: false,
    );
  }
}
