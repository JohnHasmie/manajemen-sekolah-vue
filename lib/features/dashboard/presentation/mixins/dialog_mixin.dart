import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_alert_dialog.dart';
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
  /// Shows academic year selection dialog.
  /// Allows user to switch between available academic years and
  /// reloads dashboard for the selected year.
  void showAcademicYearDialog(BuildContext context) {
    final provider = ref.read(academicYearRiverpod);
    final years = provider.academicYears;

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.selectAcademicYear.tr),
        children: years.map((year) {
          final isSelected = provider.selectedAcademicYear?['id'] == year['id'];
          return SimpleDialogOption(
            onPressed: () {
              provider.setSelectedYear(year['id'].toString());
              ref.read(dashboardProvider.notifier).reloadForYearChange();
              AppNavigator.pop(context);
            },
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
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
                    color: isSelected
                        ? ColorUtils.corporateBlue600
                        : ColorUtils.slate900,
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check,
                    color: ColorUtils.corporateBlue600,
                    size: 20,
                  ),
              ],
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

  /// Shows student selection dialog for parent users to view
  /// individual child attendance records.
  Future<void> showStudentSelectionDialog(
    BuildContext context,
    Map<String, dynamic> parent,
    List<dynamic> studentData, {
    String? academicYearId,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        title: Text(
          AppLocalizations.selectChild.tr,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: studentData.length,
            itemBuilder: (context, index) {
              final student = studentData[index];
              final model = Student.fromJson(student as Map<String, dynamic>);
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Text(
                      model.initials,
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
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
            },
          ),
        ),
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
