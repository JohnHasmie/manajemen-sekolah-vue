import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/update_status_sheet.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_admin_detail_page.dart';

mixin DialogManagementMixin on State<LessonPlanAdminDetailPage> {
  late Map<String, dynamic> lessonPlan;

  // Name retained as "showUpdateStatusDialog" for API back-compat with
  // HeaderBuilderMixin (see header_builder_mixin.dart:172). Internally it
  // now opens the shared AppBottomSheet pattern.
  void showUpdateStatusDialog(BuildContext context, String status) {
    final model = LessonPlan.fromJson(lessonPlan);
    showUpdateStatusSheet(
      context: context,
      lessonPlanId: model.id,
      currentStatus: model.status,
      currentNote: model.notes,
      onStatusUpdated: () {
        AppNavigator.pop(context); // Return to list
      },
    );
  }
}
