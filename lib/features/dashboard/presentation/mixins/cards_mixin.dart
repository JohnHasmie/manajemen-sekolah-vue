import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/attendance_bar_chart_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/attendance_overview_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/finance_bar_chart_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/lesson_plan_status_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/material_slider_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/overview_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/quick_action_button.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/schedule_slider_card.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/admin_finance_screen.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/parent_billing_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_input_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/teacher_lesson_plan_screen.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/admin_schedule_management_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/teacher_schedule_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/data_management_screen.dart';

/// Provides card and quick-action building methods for Dashboard.
/// Constructs role-specific overview cards and quick action buttons.
mixin CardsMixin on ConsumerState<Dashboard> {
  /// Builds role-specific overview cards (stats, charts, etc.).
  /// - Admin: Finance chart, attendance chart, teachers, announcements
  /// - Guru/Teacher: Schedule, attendance, materials, lesson plans
  /// - Wali/Parent: Children, grades, attendance, announcements
  List<Widget> getTodaysOverviewCards(
    DashboardState state,
    String effectiveRole,
    GlobalKey scheduleSectionKey,
    void Function(BuildContext, List<dynamic>) onFinanceTap,
    void Function(BuildContext, String?, List<dynamic>) onAttendanceTap,
  ) {
    if (effectiveRole == 'admin') {
      return _getAdminOverviewCards(state, onFinanceTap, onAttendanceTap);
    } else if (effectiveRole == 'guru') {
      return _getTeacherOverviewCards(state, scheduleSectionKey);
    } else {
      return _getParentOverviewCards(state, onAttendanceTap);
    }
  }

  /// Admin overview cards: finance, attendance, active teachers, news.
  List<Widget> _getAdminOverviewCards(
    DashboardState state,
    void Function(BuildContext, List<dynamic>) onFinanceTap,
    void Function(BuildContext, String?, List<dynamic>) onAttendanceTap,
  ) {
    return [
      if (state.financeChartData.isNotEmpty)
        FinanceBarChartCard(
          title: AppLocalizations.finance.tr,
          icon: Icons.account_balance_wallet_outlined,
          accentColor: ColorUtils.success600,
          semestersData: state.financeChartData,
          onTap: () => onFinanceTap(context, state.financeChartData),
        ),
      if (state.attendanceChartData.isNotEmpty)
        AttendanceBarChartCard(
          title: AppLocalizations.attendance.tr,
          icon: Icons.ssid_chart_outlined,
          accentColor: ColorUtils.warning600,
          classesData: state.attendanceChartData,
          onTap: () {
            final selectedYearId = ref
                .read(academicYearRiverpod)
                .selectedAcademicYear?['id']
                ?.toString();
            onAttendanceTap(context, selectedYearId, state.attendanceChartData);
          },
        ),
      OverviewCard(
        title: AppLocalizations.activeTeachers.tr,
        value: state.stats['total_teachers']?.toString() ?? '0',
        subtitle: AppLocalizations.currentlyTeaching.tr,
        icon: Icons.people_alt_outlined,
        accentColor: ColorUtils.success600,
        onTap: () {
          // Navigate to teachers
        },
      ),
      OverviewCard(
        title: AppLocalizations.announcements.tr,
        value: state.stats['unread_announcements']?.toString() ?? '0',
        subtitle: AppLocalizations.recentUpdates.tr,
        icon: Icons.campaign_outlined,
        accentColor: ColorUtils.info600,
        onTap: () {
          // Navigate to announcements
        },
      ),
    ];
  }

  /// Teacher overview cards: schedule, attendance, materials, lesson plans.
  List<Widget> _getTeacherOverviewCards(
    DashboardState state,
    GlobalKey scheduleSectionKey,
  ) {
    final attendanceSummary = state.stats['attendance_summary'] is Map
        ? state.stats['attendance_summary']
        : {};
    return [
      ScheduleSliderCard(
        key: scheduleSectionKey,
        schedules: state.todaysSchedule,
        onTap: () {
          AppNavigator.push(context, const TeachingScheduleScreen());
        },
      ),
      AttendanceOverviewCard(
        hadir: attendanceSummary['hadir'] ?? 0,
        izin: attendanceSummary['izin'] ?? 0,
        sakit: attendanceSummary['sakit'] ?? 0,
        alpha: attendanceSummary['alpha'] ?? 0,
        total: attendanceSummary['total'] ?? 0,
        onTap: () {
          AppNavigator.push(context, AttendancePage(teacher: state.userData));
        },
      ),
      MaterialSliderCard(
        materials: state.materialOverview,
        onTap: () {
          AppNavigator.push(
            context,
            TeacherMaterialScreen(teacher: state.userData),
          );
        },
      ),
      LessonPlanStatusCard(
        approved: state.stats['rpp_approved'] ?? 0,
        rejected: state.stats['rpp_rejected'] ?? 0,
        pending: state.stats['rpp_pending'] ?? 0,
        onTap: () {
          AppNavigator.push(
            context,
            LessonPlanScreen(
              teacherId: (state.userData['teacher_id'] ?? state.userData['id'])
                  .toString(),
              teacherName: state.userData['name'] ?? 'Guru',
            ),
          );
        },
      ),
    ];
  }

  /// Parent overview cards: children, grades, attendance, announcements.
  List<Widget> _getParentOverviewCards(
    DashboardState state,
    void Function(BuildContext, String?, List<dynamic>) onAttendanceTap,
  ) {
    return [
      OverviewCard(
        title: AppLocalizations.myChildren.tr,
        value: state.stats['children_registered']?.toString() ?? '0',
        subtitle: AppLocalizations.registeredStudents.tr,
        icon: Icons.family_restroom_outlined,
        accentColor: ColorUtils.corporateBlue600,
        onTap: () {
          // Navigate to children
        },
      ),
      OverviewCard(
        title: AppLocalizations.newGrades.tr,
        value: state.stats['unread_grades']?.toString() ?? '0',
        subtitle: AppLocalizations.recentUpdates.tr,
        icon: Icons.grade_outlined,
        accentColor: ColorUtils.success600,
        onTap: () {
          // Navigate to grades
        },
      ),
      if (state.attendanceChartData.isNotEmpty)
        AttendanceBarChartCard(
          title: AppLocalizations.childAttendance.tr,
          icon: Icons.ssid_chart_outlined,
          accentColor: ColorUtils.warning600,
          classesData: state.attendanceChartData,
          hideSubtitle: true,
          onTap: () {
            final selectedYearId = ref
                .read(academicYearRiverpod)
                .selectedAcademicYear?['id']
                ?.toString();
            onAttendanceTap(context, selectedYearId, state.attendanceChartData);
          },
        )
      else
        OverviewCard(
          title: AppLocalizations.attendance.tr,
          value: state.stats['unread_presence']?.toString() ?? '0',
          subtitle: AppLocalizations.newRecords.tr,
          icon: Icons.calendar_month_outlined,
          accentColor: ColorUtils.warning600,
          onTap: () {
            // Navigate to attendance
          },
        ),
      OverviewCard(
        title: AppLocalizations.announcements.tr,
        value: state.stats['unread_announcements']?.toString() ?? '0',
        subtitle: AppLocalizations.latestInformation.tr,
        icon: Icons.announcement_outlined,
        accentColor: ColorUtils.info600,
        onTap: () {
          // Navigate to announcements
        },
      ),
    ];
  }

  /// Builds role-specific quick action buttons.
  /// - Admin: Data, Schedule, Finance, Announcements
  /// - Guru/Teacher: Schedule, Attendance, Activity, Grade Input
  /// - Wali/Parent: Announcements, Billing
  List<Widget> getQuickActions(
    DashboardState state,
    String effectiveRole,
    Color primaryColor,
  ) {
    if (effectiveRole == 'admin') {
      return _getAdminQuickActions(state, primaryColor);
    } else if (effectiveRole == 'guru') {
      return _getTeacherQuickActions(state, primaryColor);
    } else {
      return _getParentQuickActions(state, primaryColor);
    }
  }

  /// Admin quick actions: data, schedule, finance, announcements.
  List<Widget> _getAdminQuickActions(DashboardState state, Color primaryColor) {
    return [
      QuickActionButton(
        label: AppLocalizations.data.tr,
        icon: Icons.folder_outlined,
        color: primaryColor,
        onTap: () =>
            AppNavigator.push(context, const AdminDataManagementScreen()),
      ),
      QuickActionButton(
        label: AppLocalizations.schedule.tr,
        icon: Icons.schedule_outlined,
        color: ColorUtils.info600,
        onTap: () => AppNavigator.push(
          context,
          const TeachingScheduleManagementScreen(),
        ),
      ),
      QuickActionButton(
        label: AppLocalizations.finance.tr,
        icon: Icons.account_balance_wallet_outlined,
        color: ColorUtils.success600,
        badgeCount: state.unverifiedPaymentCount > 0
            ? state.unverifiedPaymentCount
            : null,
        onTap: () => AppNavigator.push(context, const FinanceScreen()),
      ),
      QuickActionButton(
        label: AppLocalizations.announcements.tr,
        icon: Icons.announcement_outlined,
        color: ColorUtils.warning600,
        badgeCount: state.stats['unread_announcements'],
        onTap: () async {
          await AppNavigator.push(context, const AdminAnnouncementScreen());
          ref.read(dashboardProvider.notifier).refreshStats();
        },
      ),
    ];
  }

  /// Teacher quick actions: schedule, attendance, activity, grades.
  List<Widget> _getTeacherQuickActions(
    DashboardState state,
    Color primaryColor,
  ) {
    return [
      QuickActionButton(
        label: AppLocalizations.schedule.tr,
        icon: Icons.schedule_outlined,
        color: primaryColor,
        onTap: () => AppNavigator.push(context, const TeachingScheduleScreen()),
      ),
      QuickActionButton(
        label: AppLocalizations.attendance.tr,
        icon: Icons.how_to_reg_outlined,
        color: ColorUtils.warning600,
        onTap: () =>
            AppNavigator.push(context, AttendancePage(teacher: state.userData)),
      ),
      QuickActionButton(
        label: AppLocalizations.activity.tr,
        icon: Icons.local_activity_outlined,
        color: ColorUtils.info600,
        onTap: () => AppNavigator.push(
          context,
          const TeacherClassActivityScreen(autoShowActivityDialog: true),
        ),
      ),
      QuickActionButton(
        label: AppLocalizations.inputGrades.tr,
        icon: Icons.edit_note_outlined,
        color: ColorUtils.success600,
        onTap: () async {
          final teacherData = {
            'id':
                (state.userData['teacher_id'] ?? state.userData['id'])
                    ?.toString() ??
                '',
            'nama': state.userData['nama'] ?? 'Teacher',
            'email': state.userData['email'] ?? '',
            'role': 'guru',
          };
          if (teacherData['id']!.isEmpty) return;
          if (!context.mounted) return;
          AppNavigator.push(context, GradePage(teacher: teacherData));
        },
      ),
    ];
  }

  /// Parent quick actions: announcements, billing.
  List<Widget> _getParentQuickActions(
    DashboardState state,
    Color primaryColor,
  ) {
    return [
      QuickActionButton(
        label: AppLocalizations.announcements.tr,
        icon: Icons.announcement_outlined,
        color: primaryColor,
        badgeCount: state.stats['unread_announcements'],
        onTap: () async {
          await AppNavigator.push(context, const ParentAnnouncementScreen());
          ref.read(dashboardProvider.notifier).refreshStats();
        },
      ),
      QuickActionButton(
        label: AppLocalizations.billing.tr,
        icon: Icons.account_balance_wallet_outlined,
        color: ColorUtils.error600,
        badgeCount: state.stats['unread_billings'],
        onTap: () async {
          await AppNavigator.push(context, const ParentBillingScreen());
          ref.read(dashboardProvider.notifier).refreshStats();
        },
      ),
    ];
  }
}
