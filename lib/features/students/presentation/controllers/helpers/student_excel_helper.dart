import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/students/exports/student_export_service.dart';

/// Helper class for student Excel export/import operations.
/// Handles exporting students to Excel, importing from Excel, and downloading
/// templates.
class StudentExcelHelper {
  /// Exports students matching current filters to an Excel file.
  static Future<void> exportToExcel({
    required Ref ref,
    required BuildContext context,
    required List<String> selectedClassIds,
    required String? selectedGradeLevel,
    required String? selectedGenderFilter,
    required String searchText,
  }) async {
    try {
      SnackBarUtils.showInfo(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Preparing export...',
          'id': 'Menyiapkan export...',
        }),
      );

      final response = await getIt<ApiStudentService>().getStudentPaginated(
        page: 1,
        limit: 10000,
        classId: selectedClassIds.isNotEmpty ? selectedClassIds.first : null,
        gradeLevel: selectedGradeLevel,
        gender: selectedGenderFilter,
        search: searchText.trim().isEmpty ? null : searchText.trim(),
      );

      if (!context.mounted) return;

      await ExcelService.exportStudentsToExcel(
        students: response['data'] ?? [],
        context: context,
      );
    } catch (e) {
      AppLogger.error('student', 'Export to Excel error: $e');
      if (!context.mounted) return;
      SnackBarUtils.showError(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Failed to export: ${ErrorUtils.getFriendlyMessage(e)}',
          'id': 'Gagal mengekspor: ${ErrorUtils.getFriendlyMessage(e)}',
        }),
      );
    }
  }

  /// Lets the user pick an Excel file and imports it.
  /// Returns true if import succeeded (screen can reload), false on
  /// cancel/error.
  static Future<bool> importFromExcel(BuildContext context, Ref ref) async {
    final languageProvider = ref.read(languageRiverpod);

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await getIt<ApiStudentService>().importStudentsFromExcel(
          File(result.files.single.path!),
        );
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('student', 'Import from Excel error: $e');
      if (!context.mounted) return false;
      SnackBarUtils.showError(
        context,
        languageProvider.getTranslatedText({
          'en': 'Failed to import file: ${ErrorUtils.getFriendlyMessage(e)}',
          'id': 'Gagal mengimpor file: ${ErrorUtils.getFriendlyMessage(e)}',
        }),
      );
      return false;
    }
  }

  /// Downloads the import template Excel file.
  static Future<void> downloadTemplate(BuildContext context) async {
    await ExcelService.downloadTemplate(context);
  }
}
