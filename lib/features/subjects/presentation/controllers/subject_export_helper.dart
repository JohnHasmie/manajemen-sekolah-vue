/// Helper for subject import/export operations.
/// Handles Excel file operations, template downloads, and file picking.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/subjects/exports/'
    'subject_export_service.dart';

/// Pure export helper — handles file operations and API calls.
class SubjectExportHelper {
  /// Exports subjects to Excel.
  /// Delegates to [ExcelSubjectService] which handles file save/open.
  static Future<void> exportToExcel({
    required List<dynamic> subjects,
    required BuildContext context,
  }) async {
    await ExcelSubjectService.exportSubjectsToExcel(
      subjects: subjects,
      context: context,
    );
  }

  /// Imports subjects from an Excel file picked by the user.
  /// Returns `null` on success, or an error message string on failure.
  static Future<String?> importFromExcel() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await getIt<ApiSubjectService>().importSubjectFromExcel(
          File(result.files.single.path!),
        );
        return null; // null = success
      }

      return null; // User cancelled picker — not an error
    } catch (e) {
      AppLogger.error('subject', 'Import subjects error: $e');
      return ErrorUtils.getFriendlyMessage(e);
    }
  }

  /// Downloads the Excel import template.
  static Future<void> downloadTemplate(BuildContext context) async {
    await ExcelSubjectService.downloadTemplate(context);
  }
}
