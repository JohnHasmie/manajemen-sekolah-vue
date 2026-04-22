/// template_helper.dart - Excel template download utilities.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Helper for Excel template operations.
class TemplateHelper {
  /// Downloads the student Excel import template.
  /// Returns the saved file path.
  static Future<String> downloadTemplate() async {
    try {
      final response = await dioClient.get<List<int>>(
        '/student/template',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data ?? [];
      final directory = await getExternalStorageDirectory();
      final filePath = '${directory?.path}/template_import_siswa.xlsx';
      final file = File(filePath);

      await file.writeAsBytes(bytes);

      AppLogger.info('student', 'Template downloaded to: $filePath');
      return filePath;
    } catch (e) {
      AppLogger.error('student', e);
      throw Exception('Failed to download template: $e');
    }
  }

  /// Gets external storage directory path.
  static Future<Directory?> getExternalStorageDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory;
    } catch (e) {
      return null;
    }
  }
}
