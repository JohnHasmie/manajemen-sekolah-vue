import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_form_dialog.dart';

/// Mixin handling form field and file section UI construction.
mixin LessonPlanFormFieldsMixin on State<LessonPlanFormDialog> {
  /// Builds file section (file icon, info, view and choose buttons).
  Widget buildFileSection(
    dynamic lang,
    Color color,
    String? selectedFileName,
    bool isEditMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.getTranslatedText({
            'en': 'File Attachment',
            'id': 'Lampiran File',
          }),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            border: Border.all(color: ColorUtils.slate200),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: Row(
            children: [
              buildFileIcon(selectedFileName),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: buildFileInfo(lang, selectedFileName)),
              if (isEditMode && widget.lessonPlanData!['file_path'] != null)
                buildViewButton(),
              const SizedBox(width: AppSpacing.sm),
              buildChooseButton(lang, color),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds file icon based on selection state.
  Widget buildFileIcon(String? selectedFileName) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: selectedFileName != null
            ? ColorUtils.info600.withValues(alpha: 0.1)
            : ColorUtils.slate100,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Icon(
        selectedFileName != null
            ? Icons.description_rounded
            : Icons.upload_file_rounded,
        color: selectedFileName != null
            ? ColorUtils.info600
            : ColorUtils.slate400,
        size: 20,
      ),
    );
  }

  /// Builds file info text (name or placeholder).
  Widget buildFileInfo(dynamic lang, String? selectedFileName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedFileName ??
              lang.getTranslatedText({
                'en': 'No file selected',
                'id': 'Belum ada file dipilih',
              }),
          style: TextStyle(
            fontSize: 13,
            color: selectedFileName != null
                ? ColorUtils.slate800
                : ColorUtils.slate400,
            fontWeight: selectedFileName != null
                ? FontWeight.w500
                : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (selectedFileName == null)
          Text(
            'PDF, DOC, DOCX',
            style: TextStyle(fontSize: 11, color: ColorUtils.slate400),
          ),
      ],
    );
  }

  /// Builds view button for existing file.
  Widget buildViewButton() {
    return GestureDetector(
      onTap: viewCurrentFileAction,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: ColorUtils.info600.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(color: ColorUtils.info600.withValues(alpha: 0.25)),
        ),
        child: Icon(
          Icons.visibility_outlined,
          size: 18,
          color: ColorUtils.info600,
        ),
      ),
    );
  }

  /// Builds choose file button.
  Widget buildChooseButton(dynamic lang, Color color) {
    return GestureDetector(
      onTap: showFilePickerDialogAction,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
          lang.getTranslatedText({'en': 'Choose', 'id': 'Pilih'}),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  /// Action methods to be implemented in state.
  void showFilePickerDialogAction();
  void viewCurrentFileAction();
}
