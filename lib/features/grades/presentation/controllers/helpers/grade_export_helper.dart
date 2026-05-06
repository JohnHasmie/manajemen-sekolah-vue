import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// Helper for exporting grades to Excel files.
class GradeExportHelper {
  /// Exports grades to an Excel file and opens/saves it.
  /// Returns null on success, or an error message on failure.
  static Future<String?> exportGrades(String endpoint) async {
    try {
      final bytes = await ApiService.downloadFile(endpoint);

      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: 'grades_export_${DateTime.now().millisecond}',
          bytes: bytes,
          fileExtension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File(
          '${directory.path}/'
          'grades_export_${DateTime.now().millisecondsSinceEpoch}'
          '.xlsx',
        );
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
      }

      return null;
    } on DioException catch (e) {
      // Extract actual server error message from response
      final data = e.response?.data;
      String msg;
      if (data is Map) {
        msg = (data['error'] ?? data['message'] ?? e.message)
            .toString();
      } else if (data is List<int>) {
        // Server returned error as bytes (ResponseType.bytes)
        msg = String.fromCharCodes(data);
      } else {
        msg = data?.toString() ?? e.message ?? 'Unknown';
      }
      AppLogger.error('grades', 'Export failed: $msg');
      return msg;
    } catch (e) {
      AppLogger.error('grades', e);
      return ErrorUtils.getFriendlyMessage(e);
    }
  }
}
