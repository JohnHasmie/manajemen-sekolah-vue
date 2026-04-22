import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_form_sheet.dart';

/// Mixin for announcement form file picker logic.
mixin AnnouncementFormFileMixin on State<AnnouncementFormSheet> {
  /// Builds file display with remove button.
  Widget _buildSelectedFileDisplay(File file, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: ColorUtils.slate300),
      ),
      child: Row(
        children: [
          Icon(Icons.description, color: primaryColor, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              file.path.split('/').last,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: ColorUtils.error600, size: 20),
            onPressed: clearFile,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// Builds upload text content.
  Widget _buildUploadText(LanguageProvider lang, Color primaryColor) {
    return Column(
      children: [
        Icon(Icons.cloud_upload_outlined, color: primaryColor, size: 24),
        const SizedBox(height: AppSpacing.xs),
        Text(
          lang.getTranslatedText({
            'en': 'Tap to upload file',
            'id': 'Ketuk untuk unggah file',
          }),
          style: TextStyle(
            color: primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          'PDF, DOC, DOCX, JPG, PNG (Max 5MB)',
          style: TextStyle(color: ColorUtils.slate500, fontSize: 10),
        ),
      ],
    );
  }

  /// Builds upload prompt for empty file picker.
  Widget _buildUploadPrompt(LanguageProvider lang, Color primaryColor) {
    return InkWell(
      onTap: pickFile,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.5),
            style: BorderStyle.solid,
          ),
        ),
        child: _buildUploadText(lang, primaryColor),
      ),
    );
  }

  /// Builds file picker widget showing selected file or upload prompt.
  Widget buildFilePicker(LanguageProvider lang, Color primaryColor) {
    final selectedFile = getSelectedFile();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.getTranslatedText({
              'en': 'Attachment (Optional)',
              'id': 'Lampiran (Opsional)',
            }),
            style: TextStyle(
              fontSize: 12,
              color: ColorUtils.slate600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (selectedFile != null)
            _buildSelectedFileDisplay(selectedFile, primaryColor)
          else
            _buildUploadPrompt(lang, primaryColor),
        ],
      ),
    );
  }

  /// Opens file picker and stores selected file.
  Future<void> pickFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
      );

      if (result != null && result.files.single.path != null) {
        setSelectedFile(File(result.files.single.path!));
      }
    } catch (e) {
      AppLogger.error('announcement', 'Error picking file: $e');
    }
  }

  /// Returns currently selected file.
  File? getSelectedFile();

  /// Sets selected file.
  void setSelectedFile(File file);

  /// Clears selected file.
  void clearFile();
}
