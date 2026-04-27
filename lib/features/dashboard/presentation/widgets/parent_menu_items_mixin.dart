import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/shell/shell_nav.dart';
import 'package:manajemensekolah/core/shell/shell_tab.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_categorized_menu.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/category_section.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/parent_report_card_screen.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';

mixin ParentMenuItemsMixin on ConsumerState<DashboardCategorizedMenu> {
  List<MenuItem> getParentMenuItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.announcements.tr,
        icon: Icons.announcement_outlined,
        badgeCount: widget.state.stats['unread_announcements'],
        onTap: () => _handleParentAnnouncementsTap(context),
      ),
      MenuItem(
        title: AppLocalizations.classActivities.tr,
        icon: Icons.local_activity_outlined,
        badgeCount: widget.state.stats['unread_class_activities'],
        onTap: () => _handleParentClassActivitiesTap(context),
      ),
      MenuItem(
        title: AppLocalizations.inputGrades.tr,
        icon: Icons.grade_outlined,
        badgeCount: widget.state.stats['unread_grades'],
        onTap: () => _handleParentGradesTap(context),
      ),
      MenuItem(
        title: AppLocalizations.presence.tr,
        icon: Icons.check_circle_outline,
        badgeCount: widget.state.stats['unread_presence'],
        onTap: () => _handleParentPresenceTap(context),
      ),
      MenuItem(
        title: AppLocalizations.billing.tr,
        icon: Icons.account_balance_wallet_outlined,
        badgeCount: widget.state.stats['unread_billings'],
        onTap: () => _handleParentBillingTap(context),
      ),
      MenuItem(
        title: AppLocalizations.eReportCard.tr,
        icon: Icons.assignment_turned_in_outlined,
        onTap: () => _handleParentReportCardTap(context),
      ),
    ];
  }

  Future<void> _handleParentAnnouncementsTap(BuildContext context) async {
    ShellNav.goTo(
      ref,
      role: 'wali',
      tab: ShellTab.academic,
      pushOnTop: const ParentAnnouncementScreen(),
    );
    ref.read(dashboardProvider.notifier).refreshStats();
  }

  Future<void> _handleParentClassActivitiesTap(BuildContext context) async {
    final academicYearId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
    ShellNav.goTo(
      ref,
      role: 'wali',
      tab: ShellTab.academic,
      pushOnTop: ParentClassActivityScreen(academicYearId: academicYearId),
    );
    ref.read(dashboardProvider.notifier).refreshStats();
  }

  Future<void> _handleParentGradesTap(BuildContext context) async {
    final academicYearId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
    ShellNav.goTo(
      ref,
      role: 'wali',
      tab: ShellTab.academic,
      pushOnTop: ParentGradeScreen(academicYearId: academicYearId),
    );
    ref.read(dashboardProvider.notifier).refreshStats();
  }

  Future<void> _handleParentPresenceTap(BuildContext context) async {
    // The Attendance tab IS the ParentAttendanceTab which already handles
    // the load-students flow (0 / 1 / multi-anak). Just switch tabs and
    // let it do its own loading — no manual dialog plumbing needed.
    ShellNav.goTo(ref, role: 'wali', tab: ShellTab.attendance);
    ref.read(dashboardProvider.notifier).refreshStats();
  }

  Future<void> _handleParentBillingTap(BuildContext context) async {
    // ParentBillingScreen IS the Finance tab root — switch tabs, no push.
    ShellNav.goTo(ref, role: 'wali', tab: ShellTab.finance);
    ref.read(dashboardProvider.notifier).refreshStats();
  }

  Future<void> _handleParentReportCardTap(BuildContext context) async {
    final academicYearId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
    ShellNav.goTo(
      ref,
      role: 'wali',
      tab: ShellTab.academic,
      pushOnTop: ParentReportCardScreen(academicYearId: academicYearId),
    );
  }

  /// Kept for callers that resolve the parent's children outside the
  /// Attendance tab flow (e.g. older onboarding tour or in-app help).
  /// The Attendance tab does its own resolution via `ApiStudentService`.
  Future<List<dynamic>> getStudentDataForParent(String guardianEmail) async {
    try {
      if (guardianEmail.isEmpty) return [];
      return await ApiStudentService().getStudent(guardianEmail: guardianEmail);
    } catch (_) {
      return [];
    }
  }
}
