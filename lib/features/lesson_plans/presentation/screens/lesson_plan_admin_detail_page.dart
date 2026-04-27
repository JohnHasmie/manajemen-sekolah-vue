// Admin-side RPP detail view, now presented as a flat-flow bottom sheet
// (#145-pattern) so approval/rejection happens over the list screen instead
// of pushing a new route. Call [LessonPlanAdminDetailPage.show] instead of
// pushing this widget as a route — the Scaffold shell was replaced with a
// sheet-shaped Container to match the teacher detail sheet.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/status_utils_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/ui_builders_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/file_operations_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/dialog_management_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/card_builders_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/header_builder_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/content_card_builder_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';

class LessonPlanAdminDetailPage extends StatefulWidget {
  final Map<String, dynamic> lessonPlan;

  const LessonPlanAdminDetailPage({super.key, required this.lessonPlan});

  /// Opens the admin RPP detail view as a modal bottom sheet.
  ///
  /// Matches the teacher flow — sheet takes ~95% of screen height and
  /// adjusts for keyboard inset so any approve/reject dialogs launched
  /// from inside keep their TextField visible.
  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> lessonPlan,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => LessonPlanAdminDetailPage(lessonPlan: lessonPlan),
    );
  }

  @override
  State<LessonPlanAdminDetailPage> createState() =>
      _LessonPlanAdminDetailPageState();
}

class _LessonPlanAdminDetailPageState extends State<LessonPlanAdminDetailPage>
    with
        StatusUtilsMixin,
        UIBuildersMixin,
        FileOperationsMixin,
        DialogManagementMixin,
        CardBuildersMixin,
        HeaderBuilderMixin,
        ContentCardBuilderMixin {
  @override
  late Map<String, dynamic> lessonPlan;

  @override
  void initState() {
    super.initState();
    lessonPlan = widget.lessonPlan;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = getStatusColor(LessonPlan.fromJson(lessonPlan).status);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final mediaHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: mediaHeight * 0.95),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildHeader(context, statusColor),
                Expanded(child: buildScrollableBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildScrollableBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildStatusCard(),
          const SizedBox(height: AppSpacing.lg),
          buildInfoCard(),
          const SizedBox(height: AppSpacing.lg),
          buildContentCard(),
          if (lessonPlan['file_path'] != null) ...[
            const SizedBox(height: AppSpacing.lg),
            buildAttachmentCard(context),
          ],
        ],
      ),
    );
  }
}
