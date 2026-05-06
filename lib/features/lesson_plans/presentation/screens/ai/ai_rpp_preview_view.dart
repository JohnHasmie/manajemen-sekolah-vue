// AI-RPP read-only preview.
//
// Renders the structured-fields layout: a "Regenerasi Semua Field"
// banner, the header info card, one section card per RPP field, and
// the signature card at the bottom. No "formatted content" fallback
// branch — the dispatcher upstream guarantees this is an AI-generated
// plan.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_field_card.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_file_card.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_header_info_card.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_regen_all_button.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_signature_card.dart';

class AiRppPreviewView extends StatelessWidget {
  final Map<String, dynamic> lessonPlanData;
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

  const AiRppPreviewView({
    super.key,
    required this.lessonPlanData,
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
          isRegeneratingThis: false,
          primaryColor: primaryColor,
          onRegenTap: () => onFieldRegenTap(fieldKey, fieldLabel),
          stripHtml: stripHtml,
        ),
      );
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          if (filePath != null) ...[
            LessonPlanFileCard(
              filePath: filePath!,
              isDownloading: isDownloading,
              primaryColor: primaryColor,
              onTap: onFileDownloadTap,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (canRegen) ...[
            LessonPlanRegenAllButton(
              isRegenerating: isRegeneratingAll,
              primaryColor: primaryColor,
              onTap: onRegenAllTap,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          LessonPlanHeaderInfoCard(
            lessonPlanData: lessonPlanData,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: AppSpacing.md),
          ...fieldWidgets,
          LessonPlanSignatureCard(
            isAiGenerated: true,
            primaryColor: primaryColor,
          ),
        ],
      ),
    );
  }
}
