/// Material progress tracking for teachers.
/// Tracks which chapters/sub-chapters are checked/generated.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/cache_invalidation_service.dart';

/// Manages material progress state: which materials have been
/// checked by teachers and which have been AI-generated.
/// Like a todo/checklist system for curriculum coverage.
class SubjectProgressService {
  /// Fetches material progress grouped by class+subject for
  /// the overview screen.
  Future<List<dynamic>> getMaterialTeacherSummary({
    required String teacherId,
    String? academicYearId,
  }) async {
    final params = <String, dynamic>{'teacher_id': teacherId};
    if (academicYearId != null) {
      params['academic_year_id'] = academicYearId;
    }
    final response = await dioClient.get(
      '/material-progress/teacher-summary',
      queryParameters: params,
    );
    final result = response.data;
    if (result is Map && result['data'] is List) {
      return result['data'];
    }
    return result is List ? result : [];
  }

  /// Fetches material progress summary WITH teaching schedules
  /// piggy-backed in the same response. Returns the full response
  /// map: { data: [...], schedules: [...] }.
  Future<Map<String, dynamic>> getMaterialTeacherSummaryWithSchedules({
    required String teacherId,
    String? academicYearId,
    String view = 'mengajar',
    String? search,
  }) async {
    final params = <String, dynamic>{
      'teacher_id': teacherId,
      'include_schedules': '1',
      'view': view,
    };
    if (academicYearId != null) {
      params['academic_year_id'] = academicYearId;
    }
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }
    final response = await dioClient.get(
      '/material-progress/teacher-summary',
      queryParameters: params,
    );
    final result = response.data;
    if (result is Map<String, dynamic>) return result;
    return {'data': result is List ? result : [], 'schedules': []};
  }

  /// Fetches material progress (checked/generated state) for a
  /// teacher + subject combo.
  /// Like: MaterialProgress::where('teacher_id', ...)
  ///       ->where('subject_id', ...)->get()
  Future<List<dynamic>> getMaterialProgress({
    required String teacherId,
    required String subjectId,
    String? classId,
  }) async {
    String url =
        '/material-progress?teacher_id=$teacherId&subject_id=$subjectId';
    if (classId != null) url += '&class_id=$classId';

    final response = await dioClient.get(url);

    final result = response.data;
    return result is List ? result : [];
  }

  /// Saves or toggles the checked state for a single material
  /// progress item.
  /// Like: MaterialProgress::updateOrCreate() in Laravel.
  Future<dynamic> saveMateriProgress(Map<String, dynamic> data) async {
    final response = await dioClient.post('/material-progress', data: data);
    await CacheInvalidationService.onMaterialChanged();
    return response.data;
  }

  /// Batch-saves multiple material progress items at once.
  /// Remaps frontend keys (guru_id, bab_id) to backend keys
  /// (teacher_id, chapter_id). Like a Laravel batch upsert
  /// with key remapping middleware.
  Future<dynamic> batchSaveMateriProgress(Map<String, dynamic> data) async {
    // Remap keys to match backend expectations
    final requestData = {
      'teacher_id': data['guru_id'],
      'subject_id': data['mata_pelajaran_id'],
      'class_id': data['class_id'],
      'progress_items': (data['progress_items'] as List).map((item) {
        return {
          'chapter_id': item['bab_id'],
          'sub_chapter_id': item['sub_bab_id'],
          'is_checked': item['is_checked'],
          'is_generated': item['is_generated'] ?? false,
        };
      }).toList(),
    };

    final response = await dioClient.post(
      '/material-progress/batch',
      data: requestData,
    );
    await CacheInvalidationService.onMaterialChanged();
    return response.data;
  }

  /// Marks specific materials as AI-generated (after RPP/activity
  /// generation). Prevents accidental re-generation.
  /// Like setting a `generated_at` timestamp.
  Future<dynamic> markMaterialGenerated(Map<String, dynamic> data) async {
    // Remap keys
    final requestData = {
      'teacher_id': data['teacher_id'],
      'subject_id': data['subject_id'],
      'class_id': data['class_id'],
      'items': (data['items'] as List).map((item) {
        return {
          'chapter_id': item['bab_id'],
          'sub_chapter_id': item['sub_bab_id'],
        };
      }).toList(),
    };

    final response = await dioClient.post(
      '/material-progress/mark-generated',
      data: requestData,
    );
    return response.data;
  }

  /// Resets the generated status to allow re-generation.
  /// Like clearing the `generated_at` flag so AI can regenerate
  /// content.
  Future<dynamic> resetMaterialGenerated(Map<String, dynamic> data) async {
    // Remap keys
    final requestData = {
      'teacher_id': data['teacher_id'],
      'subject_id': data['subject_id'],
      'class_id': data['class_id'],
      'items': (data['items'] as List).map((item) {
        return {
          'chapter_id': item['bab_id'],
          'sub_chapter_id': item['sub_bab_id'],
        };
      }).toList(),
    };

    final response = await dioClient.post(
      '/material-progress/reset-generated',
      data: requestData,
    );
    return response.data;
  }
}
