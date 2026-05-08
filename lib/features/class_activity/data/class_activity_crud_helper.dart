/// class_activity_crud_helper.dart - CRUD operations for class activities.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/cache_invalidation_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Helper class for Create, Update, Delete operations on class activities.
class CrudHelper {
  /// Fetches a single class activity by ID with full detail fields.
  /// Like `ClassActivity::find($id)` in Laravel — returns the full record
  /// including `description`, `material_title`, `student_count`, and
  /// `submission_count` that the list summary endpoint omits.
  Future<Map<String, dynamic>> getActivity(String id) async {
    try {
      final response = await dioClient.get('/class-activity/$id');
      final data = response.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return <String, dynamic>{};
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }

  /// Creates a new class activity record.
  /// Like `ClassActivity::create($data)` in Laravel or a Vuex `store`
  /// action.
  /// [data] - Activity fields (teacher_id, class_id, subject_id, date,
  /// description, etc.).
  Future<dynamic> createActivity(Map<String, dynamic> data) async {
    try {
      final response = await dioClient.post('/class-activity', data: data);
      await CacheInvalidationService.onClassActivityChanged();
      return response.data;
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }

  /// Updates an existing class activity by ID.
  /// Like `ClassActivity::find($id)->update($data)` in Laravel.
  Future<dynamic> updateActivity(String id, Map<String, dynamic> data) async {
    try {
      final response = await dioClient.put('/class-activity/$id', data: data);
      await CacheInvalidationService.onClassActivityChanged();
      return response.data;
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }

  /// Deletes a class activity by ID.
  /// Like `ClassActivity::find($id)->delete()` in Laravel.
  Future<dynamic> deleteActivity(String id) async {
    try {
      final response = await dioClient.delete('/class-activity/$id');
      await CacheInvalidationService.onClassActivityChanged();
      return response.data;
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }

  /// Returns the merged audience + submission rows for an activity.
  /// One entry per student in the audience, each with student_id /
  /// student_name / status (submitted | pending | late | excused) /
  /// submitted_at / score / note. Used by the Catat Submit picker
  /// sheet so the teacher can mark every student even before any row
  /// exists in the DB.
  Future<List<Map<String, dynamic>>> getSubmissions(String activityId) async {
    try {
      final response = await dioClient.get(
        '/class-activity/$activityId/submissions',
      );
      final data = response.data;
      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return <Map<String, dynamic>>[];
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }

  /// Bulk-upserts the per-student submission status for an activity.
  /// Payload: list of { student_id, status, note?, score? }. The
  /// backend writes `submitted_at` automatically when status flips to
  /// submitted/late and clears it when flipped back to pending/excused.
  Future<void> saveSubmissions(
    String activityId,
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      await dioClient.post(
        '/class-activity/$activityId/submissions',
        data: {'rows': rows},
      );
      // Bump activity caches so the list/detail counts refresh.
      await CacheInvalidationService.onClassActivityChanged();
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }
}
