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
import 'package:manajemensekolah/core/services/api_service.dart';

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
  static Future<Map<String, dynamic>> getClassActivityPaginated({
    int page = 1,
    int limit = 10,
    String? teacherId,
    String? classId,
    String? subjectId,
    String? target,
    String? tanggal,
    String? search,
    String? chapterId,
    String? subChapterId,
    String? academicYearId,
  }) async {
    // Build query parameters
    Map<String, dynamic> queryParams = {
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
    if (tanggal != null && tanggal.isNotEmpty) {
      queryParams['date'] = tanggal;
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

    // Build URI with query parameters
    String queryString = Uri(queryParameters: queryParams).query;

    final response = await dioClient.get('/class-activity?$queryString');

    print('GET /class-activity?$queryString - Status: ${response.statusCode}');
    if (kDebugMode && response.statusCode != 200) {
      print('Response Body (Error): ${response.data}');
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

  /// Base URL from central config. Like `config('app.url')` in Laravel.
  static String get baseUrl => ApiService.baseUrl;

  /// Exports class activities to a downloadable format.
  /// Like Laravel's export endpoint that returns a file response.
  /// Returns raw Response so the caller can handle the file bytes.
  static Future<Response> exportClassActivities(
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
  static Future<List<dynamic>> getActivityByGuru(String teacherId) async {
    try {
      final response = await dioClient.get(
        '/class-activity/teacher/$teacherId',
      );

      final result = response.data;

      // Handle jika response adalah array langsung
      if (result is List) {
        return result;
      }
      // Handle jika response adalah object dengan data property
      else if (result is Map && result.containsKey('data')) {
        return result['data'] ?? [];
      }
      // Handle format lainnya
      else {
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error get kegiatan by guru: $e');
      }
      rethrow;
    }
  }

  /// Fetches activities for a specific class, optionally filtered by student and academic year.
  /// Used by students/parents to see what happened in their class.
  /// Like `ClassActivity::where('class_id', $classId)->get()` in Laravel.
  static Future<List<dynamic>> getKegiatanByKelas(
    String classId, {
    String? siswaId,
    String? academicYearId,
  }) async {
    try {
      final params = <String, String>{};
      if (siswaId != null) params['student_id'] = siswaId;
      if (academicYearId != null) params['academic_year_id'] = academicYearId;

      String url = '/class-activity/class/$classId';
      if (params.isNotEmpty) {
        final qs = Uri(queryParameters: params).query;
        url += '?$qs';
      }

      if (kDebugMode) {
        print('📤 Request: GET $url');
      }

      final response = await dioClient.get(url);

      if (kDebugMode) {
        print('📥 Response Status: ${response.statusCode}');
        print('📥 Response Body: ${response.data}');
      }

      final result = response.data;

      if (result is List) {
        return result;
      } else if (result is Map && result.containsKey('data')) {
        return result['data'] ?? [];
      } else {
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error get kegiatan by kelas: $e');
      }
      rethrow;
    }
  }

  /// Creates a new class activity record.
  /// Like `ClassActivity::create($data)` in Laravel or a Vuex `store` action.
  /// [data] - Activity fields (teacher_id, class_id, subject_id, date, description, etc.).
  static Future<dynamic> tambahKegiatan(Map<String, dynamic> data) async {
    try {
      final response = await dioClient.post('/class-activity', data: data);
      return response.data;
    } catch (e) {
      if (kDebugMode) {
        print('Error tambah kegiatan: $e');
      }
      rethrow;
    }
  }

  /// Updates an existing class activity by ID.
  /// Like `ClassActivity::find($id)->update($data)` in Laravel.
  static Future<dynamic> updateKegiatan(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await dioClient.put('/class-activity/$id', data: data);
      return response.data;
    } catch (e) {
      if (kDebugMode) {
        print('Error update kegiatan: $e');
      }
      rethrow;
    }
  }

  /// Deletes a class activity by ID.
  /// Like `ClassActivity::find($id)->delete()` in Laravel.
  static Future<dynamic> deleteKegiatan(String id) async {
    try {
      final response = await dioClient.delete('/class-activity/$id');
      return response.data;
    } catch (e) {
      if (kDebugMode) {
        print('Error delete kegiatan: $e');
      }
      rethrow;
    }
  }

  /// Fetches the teacher's schedule to populate form dropdowns.
  /// Like loading relationship data for a Laravel form (e.g., `Teacher::find($id)->schedules`).
  /// Used to show which class/subject/day options are available when creating activities.
  static Future<List<dynamic>> getJadwalForForm({
    required String teacherId,
    String? hari,
    String? tahunAjaran,
  }) async {
    try {
      final params = <String, String>{};
      if (hari != null && hari != 'Semua Hari') params['day'] = hari;
      if (tahunAjaran != null) params['academic_year'] = tahunAjaran;

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
      if (kDebugMode) {
        print('Error get jadwal for form: $e');
      }
      rethrow;
    }
  }

  /// Fetches students belonging to a specific class.
  /// Like `Student::where('class_id', $classId)->get()` in Laravel.
  /// Used to select which students an activity targets.
  static Future<List<dynamic>> getSiswaByKelas(String classId) async {
    try {
      final response = await dioClient.get('/student/class/$classId');

      if (kDebugMode) {
        print('API Response Status: ${response.statusCode}');
        print('API Response Body: ${response.data}');
      }

      final result = response.data;

      if (result is List) {
        return result;
      } else if (result is Map && result.containsKey('data')) {
        return result['data'] ?? [];
      } else {
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error get siswa by kelas: $e');
      }
      rethrow;
    }
  }

  /// Tests API connectivity by hitting the health endpoint.
  /// Like Laravel's `/api/health` route. Useful for debugging connection issues.
  static Future<dynamic> testConnection() async {
    try {
      final response = await dioClient.get('/health');
      return response.data;
    } catch (e) {
      if (kDebugMode) {
        print('Error test connection: $e');
      }
      rethrow;
    }
  }

  /// Fetches filter dropdown options for the activity list screen.
  /// Like a Laravel endpoint returning distinct values for filter selects.
  /// Similar to a Vue composable that loads filter metadata on mount.
  static Future<Map<String, dynamic>> getKegiatanFilterOptions({
    String? teacherId,
    String? classId,
    String? tanggal,
    String? bulan,
    String? tahun,
    String? subjectId,
  }) async {
    try {
      final params = <String, String>{};
      if (teacherId != null && teacherId.isNotEmpty) params['teacher_id'] = teacherId;
      if (classId != null && classId.isNotEmpty) params['class_id'] = classId;
      if (tanggal != null && tanggal.isNotEmpty) params['date'] = tanggal;
      if (bulan != null && bulan.isNotEmpty) params['month'] = bulan;
      if (tahun != null && tahun.isNotEmpty) params['year'] = tahun;
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
      if (kDebugMode) print('Error getKegiatanFilterOptions: $e');
      rethrow;
    }
  }

  /// Gets the count of unread class activities for badge display.
  /// Like a Laravel notification count endpoint. Returns 0 on error.
  static Future<int> getUnreadCount() async {
    try {
      final response = await dioClient.get('/class-activity/unread-count');

      final result = response.data;
      if (result is Map && result.containsKey('count')) {
        return int.tryParse(result['count'].toString()) ?? 0;
      }
      return 0;
    } catch (e) {
      if (kDebugMode) print('Error getUnreadCount: $e');
      return 0;
    }
  }

  /// Marks specific class activities as read (like Laravel's notification markAsRead).
  /// [activityIds] - List of activity UUIDs to mark. Returns true on success.
  static Future<bool> markAsRead(List<String> activityIds) async {
    try {
      final response = await dioClient.post(
        '/class-activity/mark-read',
        data: {'activity_ids': activityIds},
      );

      final result = response.data;
      return result is Map && result['success'] == true;
    } catch (e) {
      if (kDebugMode) print('Error markAsRead: $e');
      return false;
    }
  }
}
