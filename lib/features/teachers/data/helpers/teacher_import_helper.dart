/// teacher_import_helper.dart - Excel import & template operations.
/// Manages Excel file downloads and teacher data imports.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:path_provider/path_provider.dart';

/// Handles teacher Excel import and template downloads.
/// Like Laravel's Excel::import() with Maatwebsite package.
class TeacherImportHelper {
  /// Downloads the teacher Excel import template.
  /// Returns the local file path where template is saved.
  /// Throws Exception on download or I/O failure.
  static Future<String> downloadTemplate() async {
    try {
      final response = await dioClient.get<List<int>>(
        '/teacher/template',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data ?? [];
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/template_import_guru.xlsx';
      final file = File(filePath);

      await file.writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      throw Exception('Failed to download template: $e');
    }
  }

  /// Legacy template download endpoint wrapper.
  /// Deprecated: use downloadTemplate() instead.
  static Future<void> downloadTeacherTemplate() async {
    try {
      await ApiService().get('/teacher/template');
    } catch (e) {
      throw Exception('Failed to download template: $e');
    }
  }

  /// Imports teachers from an Excel file via multipart upload.
  /// Like Laravel's Excel::import() batch operation.
  /// Returns response with import results (success count, errors, etc).
  /// Throws Exception on file read or upload failure.
  /// Caller must handle cache invalidation.
  static Future<Map<String, dynamic>> importTeachersFromExcel(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: 'import_teacher.xlsx',
        ),
      });

      final response = await dioClient.post('/teacher/import', data: formData);

      return response.data;
    } catch (e) {
      throw Exception('Failed to import teachers: $e');
    }
  }
}
