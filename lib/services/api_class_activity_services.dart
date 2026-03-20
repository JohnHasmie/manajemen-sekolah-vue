/// api_class_activity_services.dart - Manages class activities (kegiatan kelas) CRUD.
/// Like Laravel's ClassActivityController / Vue's classActivity store module.
///
/// Class activities represent daily teaching events: what was taught, by whom,
/// in which class, for which subject. Teachers create them; students/parents view them.
/// Supports paginated listing, filtering, export, read-tracking, and schedule lookups.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';

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
    String? guruId,
    String? classId,
    String? mataPelajaranId,
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

    if (guruId != null && guruId.isNotEmpty) {
      queryParams['teacher_id'] = guruId;
    }
    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }
    if (mataPelajaranId != null && mataPelajaranId.isNotEmpty) {
      queryParams['subject_id'] = mataPelajaranId;
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

    final response = await http.get(
      Uri.parse('$baseUrl/class-activity?$queryString'),
      headers: await _getHeaders(),
    );

    print('GET /class-activity?$queryString - Status: ${response.statusCode}');
    if (kDebugMode && response.statusCode != 200) {
      print('Response Body (Error): ${response.body}');
    }
    final result = _handleResponse(response);

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

  /// Auth headers with Bearer token. Like Laravel's `Http::withToken()`.
  static Future<Map<String, String>> _getHeaders() => ApiService.getHeaders();

  /// Parses JSON response and throws on non-2xx status.
  /// Like a shared Axios interceptor or Laravel Http macro.
  static dynamic _handleResponse(http.Response response) {
    try {
      final responseBody = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseBody;
      } else {
        throw Exception(
          responseBody['error'] ??
              'Request failed with status: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing response: $e');
      }
      throw Exception('Failed to parse server response');
    }
  }

  /// Exports class activities to a downloadable format.
  /// Like Laravel's export endpoint that returns a file response.
  /// Returns raw http.Response so the caller can handle the file bytes.
  static Future<http.Response> exportClassActivities(
    List<Map<String, dynamic>> activities,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/export/class-activities'),
      headers: await _getHeaders(),
      body: json.encode({'activities': activities}),
    );
    return response;
  }

  /// Fetches activities created by a specific teacher.
  /// Like `ClassActivity::where('teacher_id', $guruId)->get()` in Laravel.
  /// [guruId] - The teacher's UUID.
  static Future<List<dynamic>> getActivityByGuru(String guruId) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/class-activity/teacher/$guruId'),
        headers: headers,
      );

      final result = _handleResponse(response);

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
      final headers = await _getHeaders();

      final params = {
        if (siswaId != null) 'student_id': siswaId,
        if (academicYearId != null) 'academic_year_id': academicYearId,
      };

      final uri = Uri.parse(
        '$baseUrl/class-activity/class/$classId',
      ).replace(queryParameters: params.isNotEmpty ? params : null);

      if (kDebugMode) {
        print('📤 Request: GET $uri');
      }

      final response = await http.get(uri, headers: headers);

      if (kDebugMode) {
        print('📥 Response Status: ${response.statusCode}');
        print('📥 Response Body: ${response.body}');
      }

      final result = _handleResponse(response);

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
      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse('$baseUrl/class-activity'),
        headers: headers,
        body: json.encode(data),
      );

      return _handleResponse(response);
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
      final headers = await _getHeaders();

      final response = await http.put(
        Uri.parse('$baseUrl/class-activity/$id'),
        headers: headers,
        body: json.encode(data),
      );

      return _handleResponse(response);
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
      final headers = await _getHeaders();

      final response = await http.delete(
        Uri.parse('$baseUrl/class-activity/$id'),
        headers: headers,
      );

      return _handleResponse(response);
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
    required String guruId,
    String? hari,
    String? tahunAjaran,
  }) async {
    try {
      final headers = await _getHeaders();

      final params = {
        if (hari != null && hari != 'Semua Hari') 'day': hari,
        if (tahunAjaran != null) 'academic_year': tahunAjaran,
      };

      final uri = Uri.parse(
        '$baseUrl/schedule/teacher/$guruId',
      ).replace(queryParameters: params.isNotEmpty ? params : null);

      final response = await http.get(uri, headers: headers);
      final result = _handleResponse(response);

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
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/student/class/$classId'),
        headers: headers,
      );

      if (kDebugMode) {
        print('API Response Status: ${response.statusCode}');
        print('API Response Body: ${response.body}');
      }

      final result = _handleResponse(response);

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
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: headers,
      );

      return _handleResponse(response);
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
    String? guruId,
    String? classId,
    String? tanggal,
    String? bulan,
    String? tahun,
    String? mataPelajaranId,
  }) async {
    try {
      final params = <String, String>{};
      if (guruId != null && guruId.isNotEmpty) params['teacher_id'] = guruId;
      if (classId != null && classId.isNotEmpty) params['class_id'] = classId;
      if (tanggal != null && tanggal.isNotEmpty) params['date'] = tanggal;
      if (bulan != null && bulan.isNotEmpty) params['month'] = bulan;
      if (tahun != null && tahun.isNotEmpty) params['year'] = tahun;
      if (mataPelajaranId != null && mataPelajaranId.isNotEmpty) {
        params['subject_id'] = mataPelajaranId;
      }

      final uri = Uri.parse(
        '$baseUrl/class-activity/filter-options',
      ).replace(queryParameters: params.isNotEmpty ? params : null);

      final response = await http.get(uri, headers: await _getHeaders());
      final result = _handleResponse(response);

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
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/class-activity/unread-count'),
        headers: headers,
      );

      final result = _handleResponse(response);
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
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/class-activity/mark-read'),
        headers: headers,
        body: json.encode({'activity_ids': activityIds}),
      );

      final result = _handleResponse(response);
      return result is Map && result['success'] == true;
    } catch (e) {
      if (kDebugMode) print('Error markAsRead: $e');
      return false;
    }
  }
}
