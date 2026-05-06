/// Lesson Plan (RPP - Rencana Pelaksanaan Pembelajaran)
/// management. Handles CRUD and file operations for lesson
/// plans.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Manages lesson plans (RPP) and curriculum materials
/// import/export. Like Laravel's LessonPlanController and
/// ImportController combined.
class SubjectLessonPlanService {
  /// Saves a lesson plan (RPP).
  ///
  /// Picks the right verb based on whether `data` carries an `id`:
  /// `POST /rpp` for create, `PATCH /rpp/{id}` for update. Without
  /// this branch the previous implementation always POSTed, which
  /// happily inserted a new record on every "save edit" tap so the
  /// teacher's edits silently never overwrote the original RPP.
  Future<dynamic> saveRPP(Map<String, dynamic> data) async {
    final rawId = data['id'] ?? data['rpp_id'] ?? data['lesson_plan_id'];
    final id = rawId?.toString().trim();

    if (id != null && id.isNotEmpty) {
      // Strip the id from the payload — it lives in the URL — to
      // avoid overlap with the backend Form Request validators.
      final payload = Map<String, dynamic>.from(data)
        ..remove('id')
        ..remove('rpp_id')
        ..remove('lesson_plan_id');
      final response = await dioClient.patch('/rpp/$id', data: payload);
      return response.data;
    }

    final response = await dioClient.post('/rpp', data: data);
    return response.data;
  }

  /// Fetches lesson plans for a specific teacher.
  Future<List<dynamic>> getLessonPlansByTeacher(String teacherId) async {
    final response = await dioClient.get('/rpp?teacher_id=$teacherId');

    final result = response.data;
    return result is List ? result : [];
  }

  /// Imports subjects from an Excel file.
  /// Invalidates subject cache after import.
  Future<Map<String, dynamic>> importSubjectFromExcel(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await dioClient.post('/subject/import', data: formData);

      AppLogger.debug(
        'subject',
        'Import Response Status: ${response.statusCode}',
      );
      AppLogger.debug('subject', 'Import Response Body: ${response.data}');

      await LocalCacheService.clearStartingWith('subject_');
      return response.data;
    } catch (e) {
      AppLogger.error('subject', e);
      throw Exception('Import error: $e');
    }
  }

  /// Downloads Excel import template to external storage.
  /// Returns the file path where template was saved.
  Future<String> downloadTemplate() async {
    try {
      final response = await dioClient.get<List<int>>(
        '/subject/template',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data ?? [];

      // Save file locally
      final directory = await getExternalStorageDirectory();
      final filePath = '${directory?.path}/template_import_kelas.xlsx';
      final file = File(filePath);

      await file.writeAsBytes(bytes);

      AppLogger.info('subject', 'Template downloaded to: $filePath');
      return filePath;
    } catch (e) {
      AppLogger.error('subject', e);
      throw Exception('Failed to download template: $e');
    }
  }

  /// Gets external storage directory for file operations.
  Future<Directory?> getExternalStorageDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory;
    } catch (e) {
      return null;
    }
  }
}
