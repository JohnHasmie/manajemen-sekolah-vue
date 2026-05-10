// AI-RPP read-only preview.
//
// Renders the structured-fields layout: a "Regenerasi Semua Field"
// banner, the header info card, one section card per RPP field, and
// the signature card at the bottom. No "formatted content" fallback
// branch — the dispatcher upstream guarantees this is an AI-generated
// plan.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan_format.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_field_card.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_file_card.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_section_renderers.dart';

class AiRppPreviewView extends StatelessWidget {
  final Map<String, dynamic> lessonPlanData;
  final LessonPlanFormat format;
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

  /// Per-section edit handler — fires when the pencil button on a
  /// field card is tapped. Null in admin contexts where the preview
  /// is read-only (admin can only approve/reject, not edit content).
  final void Function(String fieldKey, String fieldLabel)? onFieldEditTap;

  const AiRppPreviewView({
    super.key,
    required this.lessonPlanData,
    required this.format,
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
    this.onFieldEditTap,
  });

  @override
  Widget build(BuildContext context) {
    // Build numbered section cards. The label is prefixed with the
    // 1-based index so the detail mirrors Frame D's "1 Identitas / 2
    // KD & Indikator / 3 Tujuan / 4 Langkah Kegiatan / 5 Penilaian"
    // visual ladder. Empty-value fields render with a placeholder
    // ("—") so the teacher always sees the full schema.
    final fieldWidgets = <Widget>[];
    for (var i = 0; i < fieldDefinitions.length; i++) {
      final field = fieldDefinitions[i];
      final fieldKey = field['key']!;
      final fieldLabel = field['label']!;
      final altKey = field['altKey'] ?? '';
      final value = getFieldValue(fieldKey, altKey);
      // Format-specific renderer (K13 identitas grid, langkah_kegiatan
      // step rows, Modul Ajar TP cards, etc.). Returns null when no
      // custom layout matches → field card falls back to HtmlWidget.
      final customBody = buildSectionBody(
        format: format,
        fieldKey: fieldKey,
        html: value,
        lessonPlanData: lessonPlanData,
      );
      fieldWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: LessonPlanFieldCard(
            fieldKey: fieldKey,
            fieldLabel: '${i + 1}. $fieldLabel',
            value: value,
            regenInfo: getFieldRegenInfo(fieldKey),
            isLoadingLimits: isLoadingLimits,
            isRegeneratingThis: false,
            primaryColor: primaryColor,
            onRegenTap: () => onFieldRegenTap(fieldKey, fieldLabel),
            onEditTap: onFieldEditTap == null
                ? null
                : () => onFieldEditTap!(fieldKey, fieldLabel),
            stripHtml: stripHtml,
            customBody: customBody,
          ),
        ),
      );
    }

    // The legacy "Regenerasi Semua Field" hero card and the giant
    // "RENCANA PELAKSANAAN PEMBELAJARAN" `LessonPlanHeaderInfoCard`
    // metadata-table block are gone — Frame D communicates the title
    // / kelas / mapel / status / alokasi via the BrandPageHeader and
    // the KPI overlap card up the tree, so duplicating them inside
    // the body just made every detail page tall and noisy.
    //
    // Per-section regen lives on each card's footer + inside the
    // section editor sheet's violet ✦ button — bulk regen is rare
    // enough to live behind the 3-dot menu instead of as a hero.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
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
          ...fieldWidgets,
        ],
      ),
    );
  }
}
