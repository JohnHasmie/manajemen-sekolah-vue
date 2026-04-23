import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/classrooms/data/'
    'classroom_service.dart';
import 'package:manajemensekolah/features/classrooms/exports/'
    'classroom_export_service.dart';

/// Encapsulates Excel export and import operations.
class ClassroomExportHelper {
  /// Exports the [classes] list to an Excel file.
  Future<void> exportToExcel({
    required List<dynamic> classes,
    required BuildContext context,
  }) async {
    await ExcelClassService.exportClassesToExcel(
      classes: classes,
      context: context,
    );
  }

  /// Opens file picker, imports Excel, returns `true` on success.
  Future<bool> importFromExcel(BuildContext context, String errorPrefix) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await getIt<ApiClassService>().importClassesFromExcel(
          File(result.files.single.path!),
        );
        return true;
      }
      return false;
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(
          context,
          '$errorPrefix: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
      return false;
    }
  }

  /// Downloads the Excel import template.
  Future<void> downloadTemplate(BuildContext context) async {
    await ExcelClassService.downloadTemplate(context);
  }
}
