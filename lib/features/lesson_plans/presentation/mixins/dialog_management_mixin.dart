import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/update_status_dialog.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_admin_detail_page.dart';

mixin DialogManagementMixin on State<LessonPlanAdminDetailPage> {
  late Map<String, dynamic> lessonPlan;

  void showUpdateStatusDialog(BuildContext context, String status) {
    final model = LessonPlan.fromJson(lessonPlan);
    showDialog(
      context: context,
      builder: (context) => UpdateStatusDialog(
        lessonPlanId: model.id,
        currentStatus: model.status,
        currentNote: model.notes,
        onStatusUpdated: () {
          AppNavigator.pop(context); // Return to list
        },
      ),
    );
  }
}
