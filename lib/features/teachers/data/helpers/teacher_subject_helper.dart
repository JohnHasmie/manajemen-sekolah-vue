/// teacher_subject_helper.dart - Subject assignment & relationships.
/// Manages teacher-subject pivot table and class relationships.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Handles subject assignments, teacher classes, and relationships.
/// Like Laravel's belongsToMany pivot table operations.
class TeacherSubjectHelper {
  /// Fetches subjects assigned to a teacher.
  /// Like `$teacher->subjects()->get()` in Laravel.
  /// Optionally filters by classId.
  /// Returns empty list on error.
  static Future<List<dynamic>> getSubjectByTeacher(
    String teacherId, {
    String? classId,
  }) async {
    try {
      String url = '/teacher/$teacherId/subjects';
      if (classId != null && classId.isNotEmpty) {
        url += '?class_id=$classId';
      }
      final result = await ApiService().get(url);
      if (result is List) return result;
      if (result is Map<String, dynamic> && result['data'] != null) {
        return result['data'] is List ? result['data'] : [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetches classes assigned to a teacher.
  /// Like `$teacher->classes()->get()` in Laravel.
  /// Optionally filters by academicYearId.
  /// Returns empty list on error.
  static Future<List<dynamic>> getTeacherClasses(
    String teacherId, {
    String? academicYearId,
  }) async {
    try {
      String url = '/teacher/$teacherId/classes';
      if (academicYearId != null) {
        url += '?academic_year_id=$academicYearId';
      }

      final response = await dioClient.get(url);
      final result = response.data;

      if (result is Map<String, dynamic> && result['data'] is List) {
        return result['data'];
      }
      return [];
    } catch (e) {
      AppLogger.error('teacher', e);
      return [];
    }
  }

  /// Fetches subjects by teacher with pagination.
  /// Like `$teacher->subjects()->paginate()` in Laravel.
  /// For teacher detail/subject assignment views.
  /// Returns paginated response with fallback structure.
  static Future<Map<String, dynamic>> getSubjectsByTeacherPaginated({
    required String teacherId,
    int page = 1,
    int limit = 10,
    String? search,
    List<String>? subjectIds,
    String? academicYearId,
  }) async {
    final Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    if (subjectIds != null && subjectIds.isNotEmpty) {
      queryParams['subject_ids'] = subjectIds.join(',');
    }

    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }

    final String queryString = Uri(queryParameters: queryParams).query;

    try {
      final response = await dioClient.get(
        '/teacher/$teacherId/subjects?$queryString',
      );

      final result = response.data;

      if (result is Map<String, dynamic>) {
        return result;
      }

      return {
        'success': true,
        'data': result is List ? result : [],
        'pagination': {
          'total_items': result is List ? result.length : 0,
          'total_pages': 1,
          'current_page': 1,
          'per_page': limit,
          'has_next_page': false,
          'has_prev_page': false,
        },
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Assigns a subject to a teacher (pivot table).
  /// Like `$teacher->subjects()->attach($subjectId)`.
  /// Caller must handle cache invalidation.
  static Future<dynamic> addSubjectToTeacher(
    String teacherId,
    String subjectId,
  ) async {
    return await ApiService().post('/teacher/$teacherId/subjects', {
      'subject_id': subjectId,
    });
  }

  /// Removes a subject from a teacher (pivot table).
  /// Like `$teacher->subjects()->detach($subjectId)`.
  /// Caller must handle cache invalidation.
  static Future<void> removeSubjectFromTeacher(
    String teacherId,
    String subjectId,
  ) async {
    await ApiService().delete('/teacher/$teacherId/subjects/$subjectId');
  }
}
