import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_field_card.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_file_card.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_formatted_content.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_header_info_card.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_regen_all_button.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_signature_card.dart';

/// Preview view for lesson plan details with optional file and field sections.
class LessonPlanDetailPreview extends StatelessWidget {
  final Map<String, dynamic> lessonPlanData;
  final String editedContent;
  final bool canRegen;
  final bool isRegeneratingAll;
  final bool isLoadingLimits;
  final Color primaryColor;
  final String? filePath;
  final bool isDownloading;
  final List<Map<String, String>> fieldDefinitions;
  final String Function(String key, String altKey) getFieldValue;
  final Map<String, dynamic>? Function(String fieldKey) getFieldRegenInfo;
  final String Function(String html) stripHtml;
  final VoidCallback onRegenAllTap;
  final void Function(String fieldKey, String fieldLabel) onFieldRegenTap;
  final VoidCallback onFileDownloadTap;

  const LessonPlanDetailPreview({
    super.key,
    required this.lessonPlanData,
    required this.editedContent,
    required this.canRegen,
    required this.isRegeneratingAll,
    required this.isLoadingLimits,
    required this.primaryColor,
    required this.filePath,
    required this.isDownloading,
    required this.fieldDefinitions,
    required this.getFieldValue,
    required this.getFieldRegenInfo,
    required this.stripHtml,
    required this.onRegenAllTap,
    required this.onFieldRegenTap,
    required this.onFileDownloadTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          if (filePath != null)
            LessonPlanFileCard(
              filePath: filePath!,
              isDownloading: isDownloading,
              primaryColor: primaryColor,
              onTap: onFileDownloadTap,
            ),
          if (canRegen) ...[
            LessonPlanRegenAllButton(
              isRegenerating: isRegeneratingAll,
              primaryColor: primaryColor,
              onTap: onRegenAllTap,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (canRegen)
            _buildStructuredFieldsView()
          else
            _buildFormattedContent(),
        ],
      ),
    );
  }

  Widget _buildStructuredFieldsView() {
    final headerWidgets = <Widget>[
      LessonPlanHeaderInfoCard(
        lessonPlanData: lessonPlanData,
        primaryColor: primaryColor,
      ),
      const SizedBox(height: AppSpacing.md),
    ];

    final fieldWidgets = fieldDefinitions.map((field) {
      final fieldKey = field['key']!;
      final fieldLabel = field['label']!;
      final altKey = field['altKey'] ?? '';
      final value = getFieldValue(fieldKey, altKey);
      if (value.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: LessonPlanFieldCard(
          fieldKey: fieldKey,
          fieldLabel: fieldLabel,
          value: value,
          regenInfo: getFieldRegenInfo(fieldKey),
          isLoadingLimits: isLoadingLimits,
          isRegeneratingThis: false, // Pass from parent
          primaryColor: primaryColor,
          onRegenTap: () => onFieldRegenTap(fieldKey, fieldLabel),
          stripHtml: stripHtml,
        ),
      );
    }).toList();

    final signatureWidget = LessonPlanSignatureCard(
      isAiGenerated:
          lessonPlanData['ai_generated'] == true ||
          lessonPlanData['is_ai_generated'] == true,
      primaryColor: primaryColor,
    );

    return Column(
      children: [...headerWidgets, ...fieldWidgets, signatureWidget],
    );
  }

  Widget _buildFormattedContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: LessonPlanFormattedContent(
          content: editedContent,
          primaryColor: primaryColor,
        ),
      ),
    );
  }
}
