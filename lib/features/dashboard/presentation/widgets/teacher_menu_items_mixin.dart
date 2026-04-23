import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/teacher_announcement_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_categorized_menu.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/category_section.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_input_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_recap_overview.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/teacher_lesson_plan_screen.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_class_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_overview.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/teacher_schedule_screen.dart';

mixin TeacherMenuItemsMixin on ConsumerState<DashboardCategorizedMenu> {
  List<MenuItem> getTeacherTeachingItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.teachingSchedule.tr,
        icon: Icons.schedule_outlined,
        onTap: () => AppNavigator.push(context, const TeachingScheduleScreen()),
      ),
      MenuItem(
        title: AppLocalizations.classActivities.tr,
        icon: Icons.local_activity_outlined,
        onTap: () =>
            AppNavigator.push(context, const TeacherClassActivityScreen()),
      ),
      MenuItem(
        title: AppLocalizations.studentAttendance.tr,
        icon: Icons.check_circle_outline,
        onTap: () => _handleTeacherAttendanceTap(context),
      ),
      MenuItem(
        title: AppLocalizations.learningMaterials.tr,
        icon: Icons.book_outlined,
        onTap: () => _handleTeacherMaterialsTap(context),
      ),
    ];
  }

  Future<void> _handleTeacherAttendanceTap(BuildContext context) async {
    final Map<String, String> teacherData = {
      'id':
          (widget.state.userData['teacher_id'] ?? widget.state.userData['id'])
              ?.toString() ??
          '',
      'nama':
          widget.state.userData['nama'] ??
          widget.state.userData['name'] ??
          'Teacher',
      'email': widget.state.userData['email']?.toString() ?? '',
      'role': widget.effectiveRole,
    };
    if (teacherData['id']!.isEmpty) {
      if (context.mounted) {
        SnackBarUtils.showInfo(
          context,
          AppLocalizations.errorTeacherIdNotFound.tr,
        );
      }
      return;
    }
    if (!context.mounted) return;
    AppNavigator.push(context, AttendancePage(teacher: teacherData));
  }

  Future<void> _handleTeacherMaterialsTap(BuildContext context) async {
    final Map<String, String> teacherData = {
      'id':
          (widget.state.userData['teacher_id'] ?? widget.state.userData['id'])
              ?.toString() ??
          '',
      'name':
          widget.state.userData['name'] ??
          widget.state.userData['nama'] ??
          'Teacher',
      'role': widget.effectiveRole,
    };
    if (teacherData['id']!.isEmpty) {
      if (context.mounted) {
        SnackBarUtils.showInfo(
          context,
          AppLocalizations.errorTeacherIdNotFound.tr,
        );
      }
      return;
    }
    if (!context.mounted) return;
    AppNavigator.push(context, TeacherMaterialScreen(teacher: teacherData));
  }

  List<MenuItem> getTeacherAssessmentItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.inputGrades.tr,
        icon: Icons.edit_note_outlined,
        onTap: () => _handleTeacherGradeInputTap(context),
      ),
      MenuItem(
        title: AppLocalizations.gradeRecap.tr,
        icon: Icons.assessment_outlined,
        onTap: () => _handleTeacherGradeRecapTap(context),
      ),
      MenuItem(
        title: AppLocalizations.reportCard.tr,
        icon: Icons.contact_page_outlined,
        onTap: () => _handleTeacherReportCardTap(context),
      ),
      MenuItem(
        title: AppLocalizations.myLessonPlans.tr,
        icon: Icons.description_outlined,
        onTap: () => _handleTeacherLessonPlansTap(context),
      ),
      MenuItem(
        title: AppLocalizations.announcements.tr,
        icon: Icons.announcement_outlined,
        badgeCount: widget.state.stats['unread_announcements'],
        onTap: () => _handleTeacherAnnouncementsTap(context),
      ),
      if (widget.state.homeroomClasses.isNotEmpty)
        MenuItem(
          title: AppLocalizations.learningRecommendation.tr,
          icon: Icons.auto_awesome_outlined,
          onTap: () => _handleTeacherRecommendationTap(context),
        ),
    ];
  }

  Future<void> _handleTeacherGradeInputTap(BuildContext context) async {
    final Map<String, String> teacherData = _buildTeacherData();
    if (teacherData['id']!.isEmpty) {
      if (context.mounted) {
        SnackBarUtils.showInfo(
          context,
          AppLocalizations.errorTeacherIdNotFound.tr,
        );
      }
      return;
    }
    if (!context.mounted) return;
    AppNavigator.push(context, GradePage(teacher: teacherData));
  }

  Future<void> _handleTeacherGradeRecapTap(BuildContext context) async {
    final Map<String, String> teacherData = _buildTeacherData();
    if (teacherData['id']!.isEmpty) {
      if (context.mounted) {
        SnackBarUtils.showInfo(
          context,
          AppLocalizations.errorTeacherIdNotFound.tr,
        );
      }
      return;
    }
    if (!context.mounted) return;
    AppNavigator.push(context, GradeRecapOverviewPage(teacher: teacherData));
  }

  Future<void> _handleTeacherReportCardTap(BuildContext context) async {
    final Map<String, String> teacherData = _buildTeacherData();
    if (teacherData['id']!.isEmpty) {
      if (context.mounted) {
        SnackBarUtils.showInfo(
          context,
          AppLocalizations.errorTeacherIdNotFound.tr,
        );
      }
      return;
    }
    if (!context.mounted) return;
    AppNavigator.push(context, ReportCardOverviewPage(teacher: teacherData));
  }

  Future<void> _handleTeacherLessonPlansTap(BuildContext context) async {
    final Map<String, String> teacherData = _buildTeacherData();
    if (teacherData['id']!.isEmpty) {
      if (context.mounted) {
        SnackBarUtils.showInfo(
          context,
          AppLocalizations.errorTeacherIdNotFound.tr,
        );
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
  }

  Future<void> _handleTeacherAnnouncementsTap(BuildContext context) async {
    await AppNavigator.push(context, const TeacherAnnouncementScreen());
    ref.read(dashboardProvider.notifier).refreshStats();
  }

  Future<void> _handleTeacherRecommendationTap(BuildContext context) async {
    final Map<String, String> teacherData = _buildTeacherData();
    if (!context.mounted) return;

    AppNavigator.push(
      context,
      LearningRecommendationClassScreen(
        teacher: teacherData,
        classes: widget.state.homeroomClasses,
      ),
    );
  }

  Map<String, String> _buildTeacherData() {
    return {
      'id':
          (widget.state.userData['teacher_id'] ?? widget.state.userData['id'])
              ?.toString() ??
          '',
      'nama':
          widget.state.userData['nama'] ??
          widget.state.userData['name'] ??
          'Teacher',
      'email': widget.state.userData['email']?.toString() ?? '',
      'role': widget.effectiveRole,
    };
  }
}
