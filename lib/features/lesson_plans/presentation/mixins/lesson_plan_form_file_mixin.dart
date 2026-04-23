import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

  /// Views the current attached file.
  Future<void> viewCurrentFile() async {
    final filePath = widget.lessonPlanData?['file_path'];
    if (filePath != null) {
      await downloadAndOpenFile(context, filePath);
    }
  }

  /// Downloads and opens file from server.
  Future<void> downloadAndOpenFile(
    BuildContext context,
    String filePath,
  ) async {
    try {
      final rootUrl = ApiService.baseUrl.replaceFirst('/api', '');

      String cleanPath = filePath;
      if (!cleanPath.startsWith('/')) {
        cleanPath = '/$cleanPath';
      }

      final fullUrl = '$rootUrl$cleanPath';

      AppLogger.debug('lesson_plan', 'Downloading file from: $fullUrl');

      final languageProvider = ref.read(languageRiverpod);
      SnackBarUtils.showInfo(
        context,
        languageProvider.getTranslatedText({
          'en': 'Downloading file...',
          'id': 'Mengunduh file...',
        }),
      );

      final dio = Dio();
      final response = await dio.get<List<int>>(
        fullUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      final dir = await getTemporaryDirectory();
      final fileName = cleanPath.split('/').last;
      final file = File('${dir.path}/$fileName');

      await file.writeAsBytes(response.data ?? []);

      AppLogger.info('lesson_plan', 'File saved to: ${file.path}');

      await OpenFile.open(file.path);
    } catch (e) {
      AppLogger.error('lesson_plan', 'Error opening file: $e');

      final String message = e.toString().replaceFirst('Exception: ', '');

      if (context.mounted) {
        SnackBarUtils.showError(context, message);
      }
    }
  }

  /// Setter for selected file (implemented in main state).
  void setSelectedFile(String fileName, File file);
}
