/// api_student_services.dart - Manages student (siswa) CRUD with caching and Excel import.
/// Like Laravel's StudentController / Vue's student store module.
///
/// Handles paginated listing with filters, CRUD operations, stats,
/// Excel import with error handling, template download, guardian lookups,
/// and student-by-class queries. Uses cache with manual invalidation.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Service for student (siswa) management API calls with local caching.
/// Like a Laravel Resource Controller + Repository pattern.
/// In Vue terms, this is a Pinia store with cache for student data.
///
/// Key patterns:
/// - Laravel validation error parsing (422 with 'errors' map)
/// - Excel import with row-level error extraction
class ApiStudentService {
  /// Base URL from central config.
  static String get baseUrl => ApiService.baseUrl;

  /// Imports students from an Excel file via multipart upload.
  /// Like Laravel's `Excel::import()` with Maatwebsite. Handles row-level errors
  /// by stripping "Row N:" prefixes for cleaner UI messages.
  /// Clears student cache after successful import. Side effect: modifies DB.
  static Future<Map<String, dynamic>> importStudentsFromExcel(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await dioClient.post(
        '/students/import',
        data: formData,
      );

      AppLogger.debug('student', 'Import Response Status: ${response.statusCode}');
      AppLogger.debug('student', 'Import Response Body: ${response.data}');

      final body = response.data;

      // Check for specific import result structure
      if (body is Map && body['results'] != null) {
        final results = body['results'];
        if (results['failed'] is int && results['failed'] > 0) {
          // Handle failures
          List<dynamic> errors = results['errors'] ?? [];
          String errorMsg = errors.isNotEmpty
              ? errors.first.toString()
              : 'Import failed';

          // Strip "Row N: " prefix for cleaner UI messages
          final rowPrefixRegex = RegExp(r'^Row \d+: ');
          if (errorMsg.startsWith(rowPrefixRegex)) {
            errorMsg = errorMsg.replaceFirst(rowPrefixRegex, '');
          }

          throw Exception(errorMsg);
        }
      }

      // Clear cache after successful import
      await _clearStudentCache();

      return body;
    } catch (e) {
      AppLogger.error('student', e);
      throw Exception('Import error: $e');
    }
  }

  /// Downloads the student Excel import template to local storage.
  /// Like Laravel's file download response. Returns the saved file path.
  static Future<String> downloadTemplate() async {
    try {
      final response = await dioClient.get<List<int>>(
        '/student/template',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data ?? [];
      final directory = await getExternalStorageDirectory();
      final filePath = '${directory?.path}/template_import_siswa.xlsx';
      final file = File(filePath);

      await file.writeAsBytes(bytes);

      AppLogger.info('student', 'Template downloaded to: $filePath');
      return filePath;
    } catch (e) {
      AppLogger.error('student', e);
      throw Exception('Failed to download template: $e');
    }
  }

  static Future<Directory?> getExternalStorageDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory;
    } catch (e) {
      return null;
    }
  }

  /// Fetches the parent/guardian user account linked to a student.
  /// Like `User::where('student_id', $id)->first()` in Laravel.
  /// Returns null if no parent account is linked.
  static Future<Map<String, dynamic>?> getParentUser(String studentId) async {
    try {
      final response = await ApiService().get('users?student_id=$studentId');
      if (response != null && response is List && response.isNotEmpty) {
        return response.first;
      }
      return null;
    } catch (e) {
      AppLogger.error('student', e);
      return null;
    }
  }

  /// Fetches students with optional filters (academic year, user, guardian).
  /// Like `Student::filter($request)->get()` in Laravel.
  static Future<List<dynamic>> getStudent({
    String? academicYearId,
    String? userId,
    String? guardianEmail,
  }) async {
    String url = '/student';
    List<String> queryParams = [];

    if (academicYearId != null) {
      queryParams.add('academic_year_id=$academicYearId');
    }
    if (userId != null) {
      queryParams.add('user_id=$userId');
    }
    if (guardianEmail != null) {
      queryParams.add('guardian_email=$guardianEmail');
    }

    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join('&')}';
    }

    final response = await dioClient.get(url);

    final result = response.data;
    if (result is Map<String, dynamic> && result.containsKey('data')) {
      return result['data'];
    }
    return result;
  }

  /// Fetches a single student by UUID. Like `Student::findOrFail($id)` in Laravel.
  static Future<dynamic> getStudentById(String id) async {
    final response = await dioClient.get('/student/$id');
    final result = response.data;
    if (result is Map<String, dynamic> && result.containsKey('data')) {
      return result['data'];
    }
    return result;
  }

  /// Fetches filter dropdown options (grade levels, classes, gender, status).
  /// Like a Laravel endpoint returning distinct values for Vue filter selects.
  static Future<Map<String, dynamic>> getStudentFilterOptions() async {
    try {
      final response = await dioClient.get('/student/filter-options');

      final result = response.data;

      if (result is Map<String, dynamic>) {
        return result;
      }

      return {
        'success': false,
        'data': {
          'grade_levels': [],
          'kelas': [],
          'gender_options': [
            {'value': 'L', 'label': 'Laki-laki'},
            {'value': 'P', 'label': 'Perempuan'},
          ],
          'status_options': [
            {'value': 'active', 'label': 'Aktif'},
            {'value': 'inactive', 'label': 'Tidak Aktif'},
          ],
        },
      };
    } catch (e) {
      AppLogger.error('student', e);
      rethrow;
    }
  }

  /// Fetches students with server-side pagination, filters, and local caching.
  /// Like `Student::filter($request)->paginate()` in Laravel.
  /// Set [useCache] to false to bypass cache.
  static Future<Map<String, dynamic>> getStudentPaginated({
    int page = 1,
    int limit = 10,
    String? classId,
    String? gradeLevel,
    String? gender,
    String? search,
    String? academicYearId,
    String? guardianName,
    String? status,
    bool useCache = true,
  }) async {
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }
    if (gradeLevel != null && gradeLevel.isNotEmpty) {
      queryParams['grade_level'] = gradeLevel;
    }
    if (gender != null && gender.isNotEmpty) {
      queryParams['gender'] = gender;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }
    if (guardianName != null && guardianName.isNotEmpty) {
      queryParams['guardian_name'] = guardianName;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    String queryString = Uri(queryParameters: queryParams).query;
    final cacheKey = 'student_paginated_$queryString';

    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null) {
        AppLogger.debug('student', 'Using cached students for $cacheKey');
        return cached;
      }
    }

    try {
      final response = await dioClient.get('/student?$queryString');

      final result = response.data;

      if (result is Map<String, dynamic>) {
        await LocalCacheService.save(cacheKey, result);
        return result;
      }

      final fallback = {
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
      await LocalCacheService.save(cacheKey, fallback);
      return fallback;
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches aggregated student statistics (counts by class, gender, etc.).
  /// Like a Laravel endpoint with `DB::select()` aggregate queries.
  static Future<Map<String, dynamic>> getStudentStats({
    String? classId,
    String? gender,
    String? search,
    String? academicYearId,
    String? status,
  }) async {
    Map<String, dynamic> queryParams = {};
    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }
    if (gender != null && gender.isNotEmpty) queryParams['gender'] = gender;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    String queryString = Uri(queryParameters: queryParams).query;

    try {
      final response = await dioClient.get('/student/stats?$queryString');

      final result = response.data;
      return result['data'] ?? {};
    } catch (e) {
      AppLogger.error('student', e);
      return {};
    }
  }

  /// Clears all student-related cache entries from SharedPreferences.
  /// Called after any mutation. Like Laravel's `Cache::tags('students')->flush()`.
  static Future<void> _clearStudentCache() async {
    final prefs = PreferencesService();
    final keys = prefs.prefs
        .getKeys()
        .where((key) => key.startsWith('api_cache_student_'))
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
    AppLogger.info('student', 'Student cache cleared due to changes');
  }

  /// Creates a new student record. Clears cache after success.
  /// Like `Student::create($data)` in Laravel.
  static Future<dynamic> addStudent(Map<String, dynamic> data) async {
    final response = await dioClient.post('/student', data: data);
    final result = response.data;
    await _clearStudentCache();
    return result;
  }

  /// Updates a student record by ID. Clears cache after success.
  /// Like `Student::find($id)->update($data)` in Laravel.
  static Future<void> updateStudent(
    String id,
    Map<String, dynamic> data,
  ) async {
    await dioClient.put('/student/$id', data: data);
    await _clearStudentCache();
  }

  /// Deletes a student by ID. Clears cache after success.
  /// Like `Student::find($id)->delete()` in Laravel.
  static Future<void> deleteStudent(String id) async {
    await dioClient.delete('/student/$id');
    await _clearStudentCache();
  }

  /// Fetches students belonging to a specific class, optionally for an academic year.
  /// Like `Student::where('class_id', $classId)->get()` in Laravel.
  static Future<List<dynamic>> getStudentByClass(
    String classId, {
    String? academicYearId,
  }) async {
    try {
      String url = '/student/class/$classId';
      if (academicYearId != null) {
        url += '?academic_year_id=$academicYearId';
      }
      final response = await dioClient.get(url);

      final result = response.data;
      if (result is Map<String, dynamic>) {
        return (result['data'] as List?) ?? [];
      }
      return result is List ? result : [];
    } catch (e) {
      AppLogger.error('student', e);
      return [];
    }
  }

  /// Searches guardian names for autocomplete suggestions.
  /// Like a Laravel endpoint returning `DISTINCT guardian_name` matches.
  /// [query] - Search term for guardian name lookup.
  static Future<List<String>> getGuardians(String query) async {
    try {
      final response = await ApiService().get(
        '/student/guardians?search=${Uri.encodeComponent(query)}',
      );
      if (response['success'] == true && response['data'] != null) {
        return List<String>.from(response['data']);
      }
      return [];
    } catch (e) {
      AppLogger.error('student', e);
      return [];
    }
  }
}
