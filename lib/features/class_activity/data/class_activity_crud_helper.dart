/// class_activity_crud_helper.dart - CRUD operations for class activities.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/cache_invalidation_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Helper class for Create, Update, Delete operations on class activities.
class CrudHelper {
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
}
