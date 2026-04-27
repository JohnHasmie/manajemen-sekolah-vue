import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/shell/shell_nav.dart';
import 'package:manajemensekolah/core/shell/shell_tab.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_report_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/admin_class_activity_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_categorized_menu.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/category_section.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/admin_grade_overview_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/admin_lesson_plan_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/admin_report_card_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/admin_schedule_management_screen.dart';

mixin AdminMenuItemsMixin on ConsumerState<DashboardCategorizedMenu> {
  /// Dispatch via `ShellNav.goTo` so the menu tile jumps to the canonical
  /// tab and pushes the destination on that tab's stack.
  void _navAware({required ShellTab tab, required Widget screen}) {
    ShellNav.goTo(ref, role: 'admin', tab: tab, pushOnTop: screen);
  }

  /// Switch to a tab whose root IS the destination (no push).
  void _navAwareToTab({required ShellTab tab}) {
    ShellNav.goTo(ref, role: 'admin', tab: tab);
  }

  List<MenuItem> getAdminDataManagementItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.manageData.tr,
        icon: Icons.folder_shared_outlined,
        // The People tab IS the Manajemen Data hub — switch tabs.
        onTap: () => _navAwareToTab(tab: ShellTab.people),
      ),
      MenuItem(
        title: AppLocalizations.manageTeachingSchedule.tr,
        icon: Icons.schedule_outlined,
        onTap: () => _navAware(
          tab: ShellTab.academic,
          screen: const TeachingScheduleManagementScreen(),
        ),
      ),
      MenuItem(
        title: AppLocalizations.inputGrades.tr,
        icon: Icons.edit_note_outlined,
        onTap: () => _navAware(
          tab: ShellTab.academic,
          screen: const AdminGradeOverviewScreen(),
        ),
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
        onTap: () => _navAware(
          tab: ShellTab.academic,
          screen: const AdminClassActivityScreen(),
        ),
      ),
      MenuItem(
        title: AppLocalizations.presenceReport.tr,
        icon: Icons.check_circle_outline,
        onTap: () => _navAware(
          tab: ShellTab.academic,
          screen: const AdminAttendanceReportScreen(),
        ),
      ),
      MenuItem(
        title: AppLocalizations.manageLessonPlans.tr,
        icon: Icons.description_outlined,
        onTap: () => _navAware(
          tab: ShellTab.academic,
          screen: const AdminLessonPlanScreen(),
        ),
      ),
      MenuItem(
        title: AppLocalizations.studentReport.tr,
        icon: Icons.assignment_turned_in_outlined,
        onTap: () => _navAware(
          tab: ShellTab.academic,
          screen: const AdminReportCardScreen(),
        ),
      ),
    ];
  }

  Future<void> _handleAdminAnnouncementsTap(BuildContext context) async {
    ShellNav.goTo(
      ref,
      role: 'admin',
      tab: ShellTab.academic,
      pushOnTop: const AdminAnnouncementScreen(),
    );
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
        // FinanceScreen IS the Finance tab root — switch tabs, no push.
        onTap: () => _navAwareToTab(tab: ShellTab.finance),
      ),
      MenuItem(
        title: AppLocalizations.schoolSettings.tr,
        icon: Icons.settings_applications,
        // SystemSettingsScreen IS the System tab root — switch, no push.
        onTap: () => _navAwareToTab(tab: ShellTab.system),
      ),
    ];
  }
}
