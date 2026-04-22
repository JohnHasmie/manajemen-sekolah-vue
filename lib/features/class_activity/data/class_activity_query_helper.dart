/// class_activity_query_helper.dart - Query operations for class activities.
library;

import 'package:flutter/foundation.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Helper class for querying class activities (pagination, by teacher, by
/// class).
class QueryHelper {
  /// Fetches class activities with server-side pagination and multiple
  /// filters.
  /// Like `ClassActivity::filter($request)->paginate()` in Laravel.
  /// Similar to a Vuex action that calls the paginated index endpoint.
  /// Returns a Map with 'data' (list) and 'pagination' metadata.
  Future<Map<String, dynamic>> getClassActivityPaginated({
    int page = 1,
    int limit = 10,
    String? teacherId,
    String? classId,
    String? subjectId,
    String? target,
    String? date,
    String? search,
    String? chapterId,
    String? subChapterId,
    String? academicYearId,
    String? startDate,
    String? endDate,
  }) async {
    final Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    _addIfNotEmpty(queryParams, 'teacher_id', teacherId);
    _addIfNotEmpty(queryParams, 'class_id', classId);
    _addIfNotEmpty(queryParams, 'subject_id', subjectId);
    _addIfNotEmpty(queryParams, 'target', target);
    _addIfNotEmpty(queryParams, 'date', date);
    _addIfNotEmpty(queryParams, 'search', search);
    _addIfNotEmpty(queryParams, 'chapter_id', chapterId);
    _addIfNotEmpty(queryParams, 'sub_chapter_id', subChapterId);
    _addIfNotEmpty(queryParams, 'academic_year_id', academicYearId);
    _addIfNotEmpty(queryParams, 'start_date', startDate);
    _addIfNotEmpty(queryParams, 'end_date', endDate);

    final String queryString = Uri(queryParameters: queryParams).query;

    final response = await dioClient.get('/class-activity?$queryString');

    AppLogger.debug(
      'class_activity',
      'GET /class-activity?$queryString - Status: '
          '${response.statusCode}',
    );
    if (kDebugMode && response.statusCode != 200) {
      AppLogger.error(
        'class_activity',
        'Response Body (Error): ${response.data}',
      );
    }

    return _normalizeResponse(response.data, limit);
  }

  /// Fetches activities created by a specific teacher.
  /// Like `ClassActivity::where('teacher_id', $teacherId)->get()` in
  /// Laravel.
  /// [teacherId] - The teacher's UUID.
  Future<List<dynamic>> getActivityByTeacher(String teacherId) async {
    try {
      final response = await dioClient.get(
        '/class-activity/teacher/$teacherId',
      );
      return _extractData(response.data);
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }

  /// Fetches activities for a specific class, optionally filtered by student
  /// and academic year.
  /// Used by students/parents to see what happened in their class.
  /// Like `ClassActivity::where('class_id', $classId)->get()` in Laravel.
  Future<List<dynamic>> getActivityByClass(
    String classId, {
    String? studentId,
    String? academicYearId,
  }) async {
    try {
      final params = <String, String>{};
      if (studentId != null) params['student_id'] = studentId;
      if (academicYearId != null) {
        params['academic_year_id'] = academicYearId;
      }

      String url = '/class-activity/class/$classId';
      if (params.isNotEmpty) {
        final qs = Uri(queryParameters: params).query;
        url += '?$qs';
      }

      AppLogger.debug('class_activity', 'Request: GET $url');

      final response = await dioClient.get(url);

      AppLogger.debug(
        'class_activity',
        'Response Status: ${response.statusCode}',
      );
      AppLogger.debug('class_activity', 'Response Body: ${response.data}');

      return _extractData(response.data);
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }

  /// Helper: Adds parameter to map only if value is not null/empty.
  void _addIfNotEmpty(Map<String, dynamic> map, String key, String? value) {
    if (value != null && value.isNotEmpty) {
      map[key] = value;
    }
  }

  /// Helper: Extracts data list from response (handles various formats).
  List<dynamic> _extractData(dynamic result) {
    if (result is List) {
      return result;
    } else if (result is Map && result.containsKey('data')) {
      return result['data'] ?? [];
    } else {
      return [];
    }
  }

  /// Helper: Normalizes paginated response to consistent format.
  Map<String, dynamic> _normalizeResponse(dynamic result, int limit) {
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
  }
}
