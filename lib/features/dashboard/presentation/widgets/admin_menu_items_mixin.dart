import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_report_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/admin_class_activity_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_categorized_menu.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/category_section.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/data_management_screen.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/admin_finance_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/admin_grade_overview_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/admin_lesson_plan_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/admin_report_card_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/admin_schedule_management_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/system_settings_screen.dart';

mixin AdminMenuItemsMixin on ConsumerState<DashboardCategorizedMenu> {
  List<MenuItem> getAdminDataManagementItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.manageData.tr,
        icon: Icons.folder_shared_outlined,
        onTap: () =>
            AppNavigator.push(context, const AdminDataManagementScreen()),
      ),
      MenuItem(
        title: AppLocalizations.manageTeachingSchedule.tr,
        icon: Icons.schedule_outlined,
        onTap: () => AppNavigator.push(
          context,
          const TeachingScheduleManagementScreen(),
        ),
      ),
      MenuItem(
        title: AppLocalizations.inputGrades.tr,
        icon: Icons.edit_note_outlined,
        onTap: () =>
            AppNavigator.push(context, const AdminGradeOverviewScreen()),
      ),
    ];
  }

  List<MenuItem> getAdminAcademicItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.announcements.tr,
        icon: Icons.announcement_outlined,
        badgeCount: widget.state.stats['unread_announcements'],
        onTap: () => _handleAdminAnnouncementsTap(context),
      ),
      MenuItem(
        title: AppLocalizations.classActivities.tr,
        icon: Icons.local_activity_outlined,
        onTap: () =>
            AppNavigator.push(context, const AdminClassActivityScreen()),
      ),
      MenuItem(
        title: AppLocalizations.presenceReport.tr,
        icon: Icons.check_circle_outline,
        onTap: () =>
            AppNavigator.push(context, const AdminAttendanceReportScreen()),
      ),
      MenuItem(
        title: AppLocalizations.manageLessonPlans.tr,
        icon: Icons.description_outlined,
        onTap: () => AppNavigator.push(context, const AdminLessonPlanScreen()),
      ),
      MenuItem(
        title: AppLocalizations.studentReport.tr,
        icon: Icons.assignment_turned_in_outlined,
        onTap: () => AppNavigator.push(context, const AdminReportCardScreen()),
      ),
    ];
  }

  Future<void> _handleAdminAnnouncementsTap(BuildContext context) async {
    await AppNavigator.push(context, const AdminAnnouncementScreen());
    ref.read(dashboardProvider.notifier).refreshStats();
  }

  List<MenuItem> getAdminFinanceItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.finance.tr,
        icon: Icons.account_balance_wallet_outlined,
        badgeCount: widget.state.unverifiedPaymentCount > 0
            ? widget.state.unverifiedPaymentCount
            : null,
        onTap: () => AppNavigator.push(context, const FinanceScreen()),
      ),
      MenuItem(
        title: AppLocalizations.schoolSettings.tr,
        icon: Icons.settings_applications,
        // Routes to the admin-only Pengaturan hub (SystemSettingsScreen) so
        // the "Modul lain" surface matches the primary Pengaturan tile in
        // the QuickActionGrid above it — one destination, one hub.
        onTap: () => AppNavigator.push(
          context,
          SystemSettingsScreen(
            schoolName: widget.state.userData['nama_sekolah']?.toString(),
            schoolLogoUrl: widget.state.userData['school_logo_url']?.toString(),
          ),
        ),
      ),
    ];
  }
}
