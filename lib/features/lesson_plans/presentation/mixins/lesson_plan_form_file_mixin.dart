import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_form_dialog.dart';

/// Mixin handling file operations for lesson plan form.
///
/// Manages file picker, file viewing, and file download/open.
mixin LessonPlanFormFileMixin on ConsumerState<LessonPlanFormDialog> {
  /// Shows file picker dialog to select PDF/DOC/DOCX files.
  void showFilePickerDialog() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final PlatformFile file = result.files.first;

        final File selectedFile = File(file.path!);
        final bool fileExists = await selectedFile.exists();

        AppLogger.debug('lesson_plan', 'File picked: ${file.name}');
        AppLogger.debug('lesson_plan', 'File path: ${file.path}');
        AppLogger.debug('lesson_plan', 'File exists: $fileExists');
        AppLogger.debug('lesson_plan', 'File size: ${file.size} bytes');

        if (fileExists) {
          // This setter is defined in the main state class
          setSelectedFile(file.name, selectedFile);
        }
      }
    } catch (e) {
      AppLogger.error('lesson_plan', 'Error picking file: $e');
    }
  }

  /// Views the current attached file via the download proxy.
  Future<void> viewCurrentFile() async {
    final lpId = widget.lessonPlanData?['id']?.toString();
    final fp =
        widget.lessonPlanData?['file_path'] ??
        widget.lessonPlanData?['file_url'];
    if (fp == null || lpId == null) return;

    try {
      final languageProvider = ref.read(languageRiverpod);
      SnackBarUtils.showInfo(
        context,
        languageProvider.getTranslatedText({
          'en': 'Downloading file...',
          'id': 'Mengunduh file...',
        }),
      );

      // Use the backend download proxy — works with
      // both local storage and S3/Minio.
      final bytes = await ApiService.downloadFile('/rpp/$lpId/download');

      final dir = await getTemporaryDirectory();
      final fileName = fp.toString().split('/').last;
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      AppLogger.info('lesson_plan', 'File saved to: ${file.path}');

      await OpenFile.open(file.path);
    } catch (e) {
      AppLogger.error('lesson_plan', 'Error opening file: $e');
      if (context.mounted) {
        SnackBarUtils.showError(
          context,
          'File tidak dapat diunduh. Coba lagi.',
        );
      }
    }
  }

  /// Setter for selected file (implemented in main state).
  void setSelectedFile(String fileName, File file);
}
