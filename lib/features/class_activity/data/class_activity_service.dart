/// api_class_activity_services.dart - Manages class activities (kegiatan kelas) CRUD.
/// Like Laravel's ClassActivityController / Vue's classActivity store module.
///
/// Class activities represent daily teaching events: what was taught, by whom,
/// in which class, for which subject. Teachers create them; students/parents view them.
/// Supports paginated listing, filtering, export, read-tracking, and schedule lookups.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Service for class activity (kegiatan kelas) API interactions.
/// Like a Laravel Resource Controller with additional custom actions
/// (export, unread-count, mark-read). All methods are static.
///
/// In Vue terms, this is like a Pinia/Vuex store actions file that
/// handles all API calls related to class activities.
class ApiClassActivityService {
  /// Fetches class activities with server-side pagination and multiple filters.
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
    // Build query parameters
    final Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (teacherId != null && teacherId.isNotEmpty) {
      queryParams['teacher_id'] = teacherId;
    }
    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }
    if (subjectId != null && subjectId.isNotEmpty) {
      queryParams['subject_id'] = subjectId;
    }
    if (target != null && target.isNotEmpty) {
      queryParams['target'] = target;
    }
    if (date != null && date.isNotEmpty) {
      queryParams['date'] = date;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (chapterId != null && chapterId.isNotEmpty) {
      queryParams['chapter_id'] = chapterId;
    }
    if (subChapterId != null && subChapterId.isNotEmpty) {
      queryParams['sub_chapter_id'] = subChapterId;
    }

    if (subChapterId != null && subChapterId.isNotEmpty) {
      queryParams['sub_chapter_id'] = subChapterId;
    }
    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }
    if (startDate != null && startDate.isNotEmpty) {
      queryParams['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      queryParams['end_date'] = endDate;
    }

    // Build URI with query parameters
    final String queryString = Uri(queryParameters: queryParams).query;

    final response = await dioClient.get('/class-activity?$queryString');

    AppLogger.debug(
      'class_activity',
      'GET /class-activity?$queryString - Status: ${response.statusCode}',
    );
    if (kDebugMode && response.statusCode != 200) {
      AppLogger.error(
        'class_activity',
        'Response Body (Error): ${response.data}',
      );
    }
    final result = response.data;

    // Return full response with pagination metadata
    if (result is Map<String, dynamic>) {
      return result;
    }

    // Fallback for old format
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

  /// Exports class activities to a downloadable format.
  /// Like Laravel's export endpoint that returns a file response.
  /// Returns raw Response so the caller can handle the file bytes.
  Future<Response> exportClassActivities(
    List<Map<String, dynamic>> activities,
  ) async {
    final response = await dioClient.post<List<int>>(
      '/export/class-activities',
      data: {'activities': activities},
      options: Options(responseType: ResponseType.bytes),
    );
    return response;
  }

  /// Fetches activities created by a specific teacher.
  /// Like `ClassActivity::where('teacher_id', $teacherId)->get()` in Laravel.
  /// [teacherId] - The teacher's UUID.
  Future<List<dynamic>> getActivityByTeacher(String teacherId) async {
    try {
      final response = await dioClient.get(
        '/class-activity/teacher/$teacherId',
      );

      final result = response.data;

      // Handle if response is a direct array
      if (result is List) {
        return result;
      }
      // Handle if response is an object with data property
      else if (result is Map && result.containsKey('data')) {
        return result['data'] ?? [];
      }
      // Handle format lainnya
      else {
        return [];
      }
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }

  /// Fetches activities for a specific class, optionally filtered by student and academic year.
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
      if (academicYearId != null) params['academic_year_id'] = academicYearId;

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

      final result = response.data;

      if (result is List) {
        return result;
      } else if (result is Map && result.containsKey('data')) {
        return result['data'] ?? [];
      } else {
        return [];
      }
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }

  /// Creates a new class activity record.
  /// Like `ClassActivity::create($data)` in Laravel or a Vuex `store` action.
  /// [data] - Activity fields (teacher_id, class_id, subject_id, date, description, etc.).
  Future<dynamic> createActivity(Map<String, dynamic> data) async {
    try {
      final response = await dioClient.post('/class-activity', data: data);
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
      return response.data;
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }

  /// Fetches the teacher's schedule to populate form dropdowns.
  /// Like loading relationship data for a Laravel form (e.g., `Teacher::find($id)->schedules`).
  /// Used to show which class/subject/day options are available when creating activities.
  Future<List<dynamic>> getScheduleForForm({
    required String teacherId,
    String? day,
    String? academicYear,
  }) async {
    try {
      final params = <String, String>{};
      if (day != null && day != 'Semua Hari') params['day'] = day;
      if (academicYear != null) params['academic_year'] = academicYear;

      String url = '/schedule/teacher/$teacherId';
      if (params.isNotEmpty) {
        final qs = Uri(queryParameters: params).query;
        url += '?$qs';
      }

      final response = await dioClient.get(url);
      final result = response.data;

      if (result is List) {
        return result;
      } else if (result is Map && result.containsKey('data')) {
        return result['data'] ?? [];
      } else {
        return [];
      }
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }

  /// Fetches students belonging to a specific class.
  /// Like `Student::where('class_id', $classId)->get()` in Laravel.
  /// Used to select which students an activity targets.
  Future<List<dynamic>> getStudentsByClass(String classId) async {
    try {
      final response = await dioClient.get('/student/class/$classId');

      AppLogger.debug(
        'class_activity',
        'API Response Status: ${response.statusCode}',
      );
      AppLogger.debug('class_activity', 'API Response Body: ${response.data}');

      final result = response.data;

      if (result is List) {
        return result;
      } else if (result is Map && result.containsKey('data')) {
        return result['data'] ?? [];
      } else {
        return [];
      }
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }

  /// Tests API connectivity by hitting the health endpoint.
  /// Like Laravel's `/api/health` route. Useful for debugging connection issues.
  Future<dynamic> testConnection() async {
    try {
      final response = await dioClient.get('/health');
      return response.data;
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }

  /// Fetches filter dropdown options for the activity list screen.
  /// Like a Laravel endpoint returning distinct values for filter selects.
  /// Similar to a Vue composable that loads filter metadata on mount.
  Future<Map<String, dynamic>> getActivityFilterOptions({
    String? teacherId,
    String? classId,
    String? date,
    String? month,
    String? year,
    String? subjectId,
  }) async {
    try {
      final params = <String, String>{};
      if (teacherId != null && teacherId.isNotEmpty)
        params['teacher_id'] = teacherId;
      if (classId != null && classId.isNotEmpty) params['class_id'] = classId;
      if (date != null && date.isNotEmpty) params['date'] = date;
      if (month != null && month.isNotEmpty) params['month'] = month;
      if (year != null && year.isNotEmpty) params['year'] = year;
      if (subjectId != null && subjectId.isNotEmpty) {
        params['subject_id'] = subjectId;
      }

      String url = '/class-activity/filter-options';
      if (params.isNotEmpty) {
        final qs = Uri(queryParameters: params).query;
        url += '?$qs';
      }

      final response = await dioClient.get(url);
      final result = response.data;

      if (result is Map<String, dynamic>) return result;

      return {'success': false};
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }

  /// Gets the count of unread class activities for badge display.
  /// Like a Laravel notification count endpoint. Returns 0 on error.
  Future<int> getUnreadCount() async {
    try {
      final response = await dioClient.get('/class-activity/unread-count');

      final result = response.data;
      if (result is Map && result.containsKey('count')) {
        return int.tryParse(result['count'].toString()) ?? 0;
      }
      return 0;
    } catch (e) {
      AppLogger.error('class_activity', e);
      return 0;
    }
  }

  /// Marks specific class activities as read (like Laravel's notification markAsRead).
  /// [activityIds] - List of activity UUIDs to mark. Returns true on success.
  Future<bool> markAsRead(List<String> activityIds) async {
    try {
      final response = await dioClient.post(
        '/class-activity/mark-read',
        data: {'activity_ids': activityIds},
      );

      final result = response.data;
      return result is Map && result['success'] == true;
    } catch (e) {
      AppLogger.error('class_activity', e);
      return false;
    }
  }
}
