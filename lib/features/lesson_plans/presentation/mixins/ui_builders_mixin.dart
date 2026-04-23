import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_admin_detail_page.dart';

mixin UIBuildersMixin on State<LessonPlanAdminDetailPage> {
  Widget buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(value, style: TextStyle(color: ColorUtils.slate700)),
          ),
        ],
      ),
    );
  }

  Widget buildContentSection(String title, String? content) {
    if (content == null || content.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [buildSectionTitle(title), buildSectionContent(content)],
      ),
    );
  }

  Widget buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: ColorUtils.slate800,
        fontSize: 14,
      ),
    );
  }

  Widget buildSectionContent(String content) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Text(
            content,
            style: TextStyle(color: ColorUtils.slate800, height: 1.5),
          ),
        ),
      ],
    );
  }
}
