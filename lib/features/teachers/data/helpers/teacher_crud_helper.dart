/// teacher_crud_helper.dart - Basic teacher CRUD operations.
/// Like Laravel's Teacher model CRUD methods.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/api_service.dart';

/// Handles basic teacher CRUD operations and lookups.
class TeacherCrudHelper {
  /// Fetches all teachers as a flat list.
  /// Like `Teacher::all()` in Laravel.
  /// Returns List from response or empty list on error.
  static Future<List<dynamic>> getTeacher() async {
    final result = await ApiService().get('/teacher');
    if (result is Map<String, dynamic>) {
      return result['data'] ?? [];
    }
    return result is List ? result : [];
  }

  /// Fetches a single teacher by ID.
  /// Like `Teacher::findOrFail($id)` in Laravel.
  /// Supports optional academicYearId filtering.
  static Future<dynamic> getTeacherById(
    String id, {
    String? academicYearId,
  }) async {
    String url = '/teacher/$id';
    if (academicYearId != null) {
      url += '?academic_year_id=$academicYearId';
    }
    return await ApiService().get(url);
  }

  /// Creates a new teacher record.
  /// Like `Teacher::create($data)` in Laravel.
  /// Caller must handle cache invalidation.
  static Future<dynamic> addTeacher(Map<String, dynamic> data) async {
    return await ApiService().post('/teacher', data);
  }

  /// Updates a teacher by ID.
  /// Like `Teacher::find($id)->update()` in Laravel.
  /// Caller must handle cache invalidation.
  static Future<void> updateTeacher(
    String id,
    Map<String, dynamic> data,
  ) async {
    await ApiService().put('/teacher/$id', data);
  }

  /// Deletes a teacher by ID.
  /// Like `Teacher::find($id)->delete()` in Laravel.
  /// Caller must handle cache invalidation.
  static Future<void> deleteTeacher(String id) async {
    await ApiService().delete('/teacher/$id');
  }

  /// Finds a teacher by their linked user account ID.
  /// Like `Teacher::where('user_id', $userId)->first()`.
  /// Returns null if not found. Handles both List and
  /// Map response formats from the API.
  static Future<Map<String, dynamic>?> getTeacherByUserId(
    String userId, {
    String? academicYearId,
  }) async {
    try {
      String url = '/teacher?user_id=$userId';
      if (academicYearId != null) {
        url += '&academic_year_id=$academicYearId';
      }

      final response = await dioClient.get(url);
      final result = response.data;

      // Handle List response (when not paginated)
      if (result is List && result.isNotEmpty) {
        return result[0];
      }

      // Handle Map response (when wrapped in 'data')
      if (result is Map<String, dynamic> &&
          result['data'] is List &&
          (result['data'] as List).isNotEmpty) {
        return result['data'][0];
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetches filter dropdown options for teacher listings.
  /// Returns success/data structure or empty defaults on error.
  /// Supports optional academicYearId filtering.
  static Future<Map<String, dynamic>> getTeacherFilterOptions({
    String? academicYearId,
  }) async {
    try {
      String url = '/teacher/filter-options';
      if (academicYearId != null) {
        url += '?academic_year_id=$academicYearId';
      }

      final response = await dioClient.get(url);
      final result = response.data;

      return result is Map<String, dynamic>
          ? result
          : {
              'success': false,
              'data': {'kelas': [], 'gender_options': []},
            };
    } catch (e) {
      rethrow;
    }
  }
}
