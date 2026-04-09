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
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_report_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/admin_class_activity_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/category_section.dart';

import 'package:manajemensekolah/features/finance/presentation/screens/admin_finance_screen.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/parent_billing_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_input_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_recap_overview.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/admin_lesson_plan_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/teacher_lesson_plan_screen.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_class_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/admin_report_card_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/parent_report_card_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_overview.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/admin_schedule_management_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/teacher_schedule_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/data_management_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/school_settings_screen.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/parent_attendance_screen.dart';

/// Renders the role-specific categorized navigation menu on the dashboard.
///
/// Pass [effectiveRole] ('admin', 'guru', or 'wali'), [state], [primaryColor],
/// and the callbacks [onShowNoStudentsDialog] / [onShowStudentSelectionDialog]
/// that the parent screen provides for dialogs that need broader context.
class DashboardCategorizedMenu extends ConsumerWidget {
  final String effectiveRole;
  final DashboardState state;
  final Color primaryColor;

  /// Called when the parent menu item for "Presence" finds no linked students.
  final VoidCallback onShowNoStudentsDialog;

  /// Called when the parent menu item for "Presence" finds multiple students.
  final Future<void> Function(
    Map<String, dynamic> parent,
    List<dynamic> studentsData, {
    String? academicYearId,
  }) onShowStudentSelectionDialog;

  const DashboardCategorizedMenu({
    super.key,
    required this.effectiveRole,
    required this.state,
    required this.primaryColor,
    required this.onShowNoStudentsDialog,
    required this.onShowStudentSelectionDialog,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (effectiveRole == 'admin') {
      return Column(
        children: [
          CategorySection(
            title: '📊 ${AppLocalizations.categoryDataManagement.tr}',
            icon: Icons.folder_shared,
            accentColor: ColorUtils.slate700,
            primaryColor: primaryColor,
            items: _getAdminDataManagementItems(context, ref),
          ),
          CategorySection(
            title: '📢 ${AppLocalizations.categoryAcademicCommunication.tr}',
            icon: Icons.school,
            accentColor: ColorUtils.slate700,
            primaryColor: primaryColor,
            items: _getAdminAcademicItems(context, ref),
          ),
          CategorySection(
            title: '💰 ${AppLocalizations.categoryFinanceSettings.tr}',
            icon: Icons.settings,
            accentColor: ColorUtils.slate700,
            primaryColor: primaryColor,
            items: _getAdminFinanceItems(context),
          ),
        ],
      );
    } else if (effectiveRole == 'guru') {
      return Column(
        children: [
          CategorySection(
            title: '📚 ${AppLocalizations.categoryTeaching.tr}',
            icon: Icons.school,
            accentColor: ColorUtils.slate700,
            primaryColor: primaryColor,
            items: _getTeacherTeachingItems(context, ref),
          ),
          CategorySection(
            title: '✏️ ${AppLocalizations.categoryAssessmentPlanning.tr}',
            icon: Icons.edit_note,
            accentColor: ColorUtils.slate700,
            primaryColor: primaryColor,
            items: _getTeacherAssessmentItems(context, ref),
          ),
        ],
      );
    } else if (effectiveRole == 'wali') {
      return Column(
        children: [
          CategorySection(
            title: '🏠 MENU',
            icon: Icons.family_restroom,
            accentColor: ColorUtils.slate700,
            primaryColor: primaryColor,
            items: _getParentMenuItems(context, ref),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ── Admin ──────────────────────────────────────────────────────────────────

  List<MenuItem> _getAdminDataManagementItems(BuildContext context, WidgetRef ref) {
    return [
      MenuItem(
        title: AppLocalizations.manageData.tr,
        icon: Icons.folder_shared_outlined,
        onTap: () => AppNavigator.push(context, AdminDataManagementScreen()),
      ),
      MenuItem(
        title: AppLocalizations.manageTeachingSchedule.tr,
        icon: Icons.schedule_outlined,
        onTap: () =>
            AppNavigator.push(context, TeachingScheduleManagementScreen()),
      ),
      MenuItem(
        title: AppLocalizations.inputGrades.tr,
        icon: Icons.edit_note_outlined,
        onTap: () async {
          final adminData = {
            'id': (state.userData['teacher_id'] ?? state.userData['id'])?.toString() ?? '',
            'nama': state.userData['nama'] ?? 'Admin',
            'email': state.userData['email'] ?? '',
            'role': effectiveRole,
          };
          if (adminData['id']!.isEmpty) {
            if (context.mounted) {
              SnackBarUtils.showInfo(context, AppLocalizations.errorAdminIdNotFound.tr);
            }
            return;
          }
          if (!context.mounted) return;
          AppNavigator.push(context, GradePage(teacher: adminData));
        },
      ),
    ];
  }

  List<MenuItem> _getAdminAcademicItems(BuildContext context, WidgetRef ref) {
    return [
      MenuItem(
        title: AppLocalizations.announcements.tr,
        icon: Icons.announcement_outlined,
        badgeCount: state.stats['unread_announcements'],
        onTap: () async {
          await AppNavigator.push(context, AdminAnnouncementScreen());
          ref.read(dashboardProvider.notifier).refreshStats();
        },
      ),
      MenuItem(
        title: AppLocalizations.classActivities.tr,
        icon: Icons.local_activity_outlined,
        onTap: () => AppNavigator.push(context, AdminClassActivityScreen()),
      ),
      MenuItem(
        title: AppLocalizations.presenceReport.tr,
        icon: Icons.check_circle_outline,
        onTap: () => AppNavigator.push(context, AdminAttendanceReportScreen()),
      ),
      MenuItem(
        title: AppLocalizations.manageLessonPlans.tr,
        icon: Icons.description_outlined,
        onTap: () => AppNavigator.push(context, AdminLessonPlanScreen()),
      ),
      MenuItem(
        title: AppLocalizations.studentReport.tr,
        icon: Icons.assignment_turned_in_outlined,
        onTap: () => AppNavigator.push(context, const AdminReportCardScreen()),
      ),
    ];
  }

  List<MenuItem> _getAdminFinanceItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.finance.tr,
        icon: Icons.account_balance_wallet_outlined,
        badgeCount: state.unverifiedPaymentCount > 0
            ? state.unverifiedPaymentCount
            : null,
        onTap: () => AppNavigator.push(context, FinanceScreen()),
      ),
      MenuItem(
        title: AppLocalizations.schoolSettings.tr,
        icon: Icons.settings_applications,
        onTap: () => AppNavigator.push(context, SchoolSettingsScreen()),
      ),
    ];
  }

  // ── Teacher ────────────────────────────────────────────────────────────────

  List<MenuItem> _getTeacherTeachingItems(BuildContext context, WidgetRef ref) {
    return [
      MenuItem(
        title: AppLocalizations.teachingSchedule.tr,
        icon: Icons.schedule_outlined,
        onTap: () => AppNavigator.push(context, TeachingScheduleScreen()),
      ),
      MenuItem(
        title: AppLocalizations.classActivities.tr,
        icon: Icons.local_activity_outlined,
        onTap: () => AppNavigator.push(context, ClassActivityScreen()),
      ),
      MenuItem(
        title: AppLocalizations.studentAttendance.tr,
        icon: Icons.check_circle_outline,
        onTap: () async {
          final Map<String, String> teacherData = {
            'id':
                (state.userData['teacher_id'] ?? state.userData['id'])?.toString() ?? '',
            'nama': state.userData['nama'] ?? state.userData['name'] ?? 'Teacher',
            'email': state.userData['email']?.toString() ?? '',
            'role': effectiveRole,
          };
          if (teacherData['id']!.isEmpty) {
            if (context.mounted) {
              SnackBarUtils.showInfo(context, AppLocalizations.errorTeacherIdNotFound.tr);
            }
            return;
          }
          if (!context.mounted) return;
          AppNavigator.push(context, AttendancePage(teacher: teacherData));
        },
      ),
      MenuItem(
        title: AppLocalizations.learningMaterials.tr,
        icon: Icons.book_outlined,
        onTap: () async {
          final Map<String, String> teacherData = {
            'id':
                (state.userData['teacher_id'] ?? state.userData['id'])?.toString() ?? '',
            'name': state.userData['name'] ?? state.userData['nama'] ?? 'Teacher',
            'role': effectiveRole,
          };
          if (teacherData['id']!.isEmpty) {
            if (context.mounted) {
              SnackBarUtils.showInfo(context, AppLocalizations.errorTeacherIdNotFound.tr);
            }
            return;
          }
          if (!context.mounted) return;
          AppNavigator.push(context, TeacherMaterialScreen(teacher: teacherData));
        },
      ),
    ];
  }

  List<MenuItem> _getTeacherAssessmentItems(BuildContext context, WidgetRef ref) {
    return [
      MenuItem(
        title: AppLocalizations.inputGrades.tr,
        icon: Icons.edit_note_outlined,
        onTap: () async {
          final Map<String, String> teacherData = {
            'id':
                (state.userData['teacher_id'] ?? state.userData['id'])?.toString() ?? '',
            'nama': state.userData['nama'] ?? state.userData['name'] ?? 'Teacher',
            'email': state.userData['email']?.toString() ?? '',
            'role': effectiveRole,
          };
          if (teacherData['id']!.isEmpty) {
            if (context.mounted) {
              SnackBarUtils.showInfo(context, AppLocalizations.errorTeacherIdNotFound.tr);
            }
            return;
          }
          if (!context.mounted) return;
          AppNavigator.push(context, GradePage(teacher: teacherData));
        },
      ),
      MenuItem(
        title: AppLocalizations.gradeRecap.tr,
        icon: Icons.assessment_outlined,
        onTap: () async {
          final Map<String, String> teacherData = {
            'id':
                (state.userData['teacher_id'] ?? state.userData['id'])?.toString() ?? '',
            'nama': state.userData['nama'] ?? state.userData['name'] ?? 'Teacher',
            'email': state.userData['email']?.toString() ?? '',
            'role': effectiveRole,
          };
          if (teacherData['id']!.isEmpty) {
            if (context.mounted) {
              SnackBarUtils.showInfo(context, AppLocalizations.errorTeacherIdNotFound.tr);
            }
            return;
          }
          if (!context.mounted) return;
          AppNavigator.push(context, GradeRecapOverviewPage(teacher: teacherData));
        },
      ),
      MenuItem(
        title: AppLocalizations.reportCard.tr,
        icon: Icons.contact_page_outlined,
        onTap: () async {
          final Map<String, String> teacherData = {
            'id':
                (state.userData['teacher_id'] ?? state.userData['id'])?.toString() ?? '',
            'nama': state.userData['nama'] ?? state.userData['name'] ?? 'Teacher',
            'email': state.userData['email']?.toString() ?? '',
            'role': effectiveRole,
          };
          if (teacherData['id']!.isEmpty) {
            if (context.mounted) {
              SnackBarUtils.showInfo(context, AppLocalizations.errorTeacherIdNotFound.tr);
            }
            return;
          }
          if (!context.mounted) return;
          AppNavigator.push(context, ReportCardOverviewPage(teacher: teacherData));
        },
      ),
      MenuItem(
        title: AppLocalizations.myLessonPlans.tr,
        icon: Icons.description_outlined,
        onTap: () async {
          final Map<String, String> teacherData = {
            'id':
                (state.userData['teacher_id'] ?? state.userData['id'])?.toString() ?? '',
            'nama': state.userData['nama']?.toString() ?? 'Teacher',
            'email': state.userData['email']?.toString() ?? '',
            'role': effectiveRole,
          };
          if (teacherData['id']!.isEmpty) {
            if (context.mounted) {
              SnackBarUtils.showInfo(context, AppLocalizations.errorTeacherIdNotFound.tr);
            }
            return;
          }
          if (!context.mounted) return;
          AppNavigator.push(
            context,
            LessonPlanScreen(
              teacherId: teacherData['id']!,
              teacherName: teacherData['nama']!,
            ),
          );
        },
      ),
      MenuItem(
        title: AppLocalizations.announcements.tr,
        icon: Icons.announcement_outlined,
        badgeCount: state.stats['unread_announcements'],
        onTap: () async {
          await AppNavigator.push(context, AnnouncementScreen());
          ref.read(dashboardProvider.notifier).refreshStats();
        },
      ),
      if (state.homeroomClasses.isNotEmpty)
        MenuItem(
          title: AppLocalizations.learningRecommendation.tr,
          icon: Icons.auto_awesome_outlined,
          onTap: () async {
            final Map<String, String> teacherData = {
              'id':
                  (state.userData['teacher_id'] ?? state.userData['id'])?.toString() ??
                  '',
              'nama': state.userData['nama'] ?? state.userData['name'] ?? 'Teacher',
              'email': state.userData['email']?.toString() ?? '',
              'role': effectiveRole,
            };
            if (!context.mounted) return;

            AppNavigator.push(
              context,
              LearningRecommendationClassScreen(
                teacher: teacherData,
                classes: state.homeroomClasses,
              ),
            );
          },
        ),
    ];
  }

  // ── Parent ─────────────────────────────────────────────────────────────────

  List<MenuItem> _getParentMenuItems(BuildContext context, WidgetRef ref) {
    return [
      MenuItem(
        title: AppLocalizations.announcements.tr,
        icon: Icons.announcement_outlined,
        badgeCount: state.stats['unread_announcements'],
        onTap: () async {
          await AppNavigator.push(context, AnnouncementScreen());
          ref.read(dashboardProvider.notifier).refreshStats();
        },
      ),
      MenuItem(
        title: AppLocalizations.classActivities.tr,
        icon: Icons.local_activity_outlined,
        badgeCount: state.stats['unread_class_activities'],
        onTap: () async {
          final academicYearId = ref
              .read(academicYearRiverpod)
              .selectedAcademicYear?['id']
              ?.toString();
          await AppNavigator.push(
            context,
            ParentClassActivityScreen(academicYearId: academicYearId),
          );
          ref.read(dashboardProvider.notifier).refreshStats();
        },
      ),
      MenuItem(
        title: AppLocalizations.grades.tr,
        icon: Icons.grade_outlined,
        badgeCount: state.stats['unread_grades'],
        onTap: () async {
          final academicYearId = ref
              .read(academicYearRiverpod)
              .selectedAcademicYear?['id']
              ?.toString();
          await AppNavigator.push(
            context,
            ParentGradeScreen(academicYearId: academicYearId),
          );
          ref.read(dashboardProvider.notifier).refreshStats();
        },
      ),
      MenuItem(
        title: AppLocalizations.presence.tr,
        icon: Icons.check_circle_outline,
        badgeCount: state.stats['unread_presence'],
        onTap: () async {
          final academicYearId = ref
              .read(academicYearRiverpod)
              .selectedAcademicYear?['id']
              ?.toString();

          // Load students by parent email instead of user_id
          final studentsData = await _getStudentDataForParent(
            state.userData['email'] ?? '',
          );

          if (studentsData.isEmpty) {
            onShowNoStudentsDialog();
            return;
          }

          if (!context.mounted) return;

          if (studentsData.length == 1) {
            await AppNavigator.push(
              context,
              PresenceParentPage(
                parent: state.userData,
                studentId: studentsData[0]['id'],
                academicYearId: academicYearId,
              ),
            );
            ref.read(dashboardProvider.notifier).refreshStats();
          } else {
            await onShowStudentSelectionDialog(
              state.userData,
              studentsData,
              academicYearId: academicYearId,
            );
            ref.read(dashboardProvider.notifier).refreshStats();
          }
        },
      ),
      MenuItem(
        title: AppLocalizations.billing.tr,
        icon: Icons.account_balance_wallet_outlined,
        badgeCount: state.stats['unread_billings'],
        onTap: () async {
          await AppNavigator.push(context, ParentBillingScreen());
          ref.read(dashboardProvider.notifier).refreshStats();
        },
      ),
      MenuItem(
        title: AppLocalizations.eReportCard.tr,
        icon: Icons.assignment_turned_in_outlined,
        onTap: () async {
          final academicYearId = ref
              .read(academicYearRiverpod)
              .selectedAcademicYear?['id']
              ?.toString();

          await AppNavigator.push(
            context,
            ParentReportCardScreen(academicYearId: academicYearId),
          );
        },
      ),
    ];
  }

  Future<List<dynamic>> _getStudentDataForParent(String guardianEmail) async {
    try {
      if (guardianEmail.isEmpty) return [];
      return await ApiStudentService().getStudent(guardianEmail: guardianEmail);
    } catch (_) {
      return [];
    }
  }
}
