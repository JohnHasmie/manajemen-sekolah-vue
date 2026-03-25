/// api_teacher_services.dart - Manages teacher (guru) CRUD with caching and subject assignment.
/// Like Laravel's TeacherController / Vue's teacher store module.
///
/// Handles paginated listing, CRUD, stats, Excel import/template download,
/// subject assignment (attach/detach), teacher-class relationships, and
/// looking up teachers by user ID. Uses cache with manual invalidation.
///
/// Note: mixes static methods and instance methods -- instance methods use
/// [ApiService] instance, while static methods use raw http calls.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:path_provider/path_provider.dart';

/// Service for teacher (guru) management API calls with caching.
/// Like a Laravel Resource Controller + pivot table management (teacher-subject).
/// Mixes static methods (for paginated/filtered queries) and instance methods
/// (for basic CRUD via ApiService).
class ApiTeacherService {
  /// Base URL from central config.
  static String get baseUrl => ApiService.baseUrl;

  /// Downloads the teacher Excel import template. Returns the local file path.
  static Future<String> downloadTemplate() async {
    try {
      final response = await dioClient.get<List<int>>(
        '/teacher/template',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data!;
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/template_import_guru.xlsx';
      final file = File(filePath);

      await file.writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      throw Exception('Failed to download template: $e');
    }
  }

  /// Fetches filter dropdown options for teacher listing.
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

  /// Finds a teacher record by their user account ID.
  /// Like `Teacher::where('user_id', $userId)->first()` in Laravel.
  /// Returns null if no teacher is linked to this user.
  static Future<Map<String, dynamic>?> getGuruByUserId(
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

  /// Fetches teachers with server-side pagination, filters, and local caching.
  /// Like `Teacher::filter($request)->paginate()` in Laravel.
  static Future<Map<String, dynamic>> getTeachersPaginated({
    int page = 1,
    int limit = 10,
    String? classId,
    String? gender,
    String? employmentStatus,
    String? teachingClassId,
    String? search,
    String? academicYearId,
    String? teacherId,
    bool useCache = true,
  }) async {
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (classId != null && classId.isNotEmpty) {
      queryParams['homeroom_class_id'] = classId;
    }
    if (gender != null && gender.isNotEmpty) {
      queryParams['gender'] = gender;
    }
    if (employmentStatus != null && employmentStatus.isNotEmpty) {
      queryParams['employment_status'] = employmentStatus;
    }
    if (teachingClassId != null && teachingClassId.isNotEmpty) {
      queryParams['teaching_class_id'] = teachingClassId;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }
    if (teacherId != null && teacherId.isNotEmpty) {
      queryParams['teacher_id'] = teacherId;
    }

    String queryString = Uri(queryParameters: queryParams).query;
    final cacheKey = 'teacher_paginated_$queryString';

    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null) {
        if (kDebugMode) print('📦 Using cached teachers for $cacheKey');
        return cached;
      }
    }

    try {
      final response = await dioClient.get('/teacher?$queryString');

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

  /// Fetches aggregated teacher statistics. Like a Laravel aggregate query endpoint.
  static Future<Map<String, dynamic>> getTeacherStats({
    String? gender,
    String? employmentStatus,
    String? name,
    String? employeeNumber,
    String? academicYearId,
  }) async {
    Map<String, dynamic> queryParams = {};
    if (gender != null && gender.isNotEmpty) queryParams['gender'] = gender;
    if (employmentStatus != null && employmentStatus.isNotEmpty) {
      queryParams['employment_status'] = employmentStatus;
    }
    if (name != null && name.isNotEmpty) queryParams['name'] = name;
    if (employeeNumber != null && employeeNumber.isNotEmpty) {
      queryParams['employee_number'] = employeeNumber;
    }
    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }

    String queryString = Uri(queryParameters: queryParams).query;

    try {
      final response = await dioClient.get('/teacher/stats?$queryString');

      final result = response.data;
      return result['data'] ?? {};
    } catch (e) {
      if (kDebugMode) print('Error fetching teacher stats: $e');
      return {};
    }
  }

  /// Invalidates all teacher-related cache entries.
  /// Like Laravel's `Cache::tags('teachers')->flush()`.
  static Future<void> _clearTeacherCache() async {
    await LocalCacheService.clearStartingWith('teacher_');
    if (kDebugMode) print('🧹 Teacher cache cleared due to changes');
  }

  /// Fetches all teachers as a flat list (instance method).
  /// Like `Teacher::all()` in Laravel. Use [getTeachersPaginated] for new code.
  Future<List<dynamic>> getTeacher() async {
    final result = await ApiService().get('/teacher');
    if (result is Map<String, dynamic>) {
      return result['data'] ?? [];
    }
    return result is List ? result : [];
  }

  /// Fetches a single teacher by ID. Like `Teacher::findOrFail($id)` in Laravel.
  Future<dynamic> getTeacherById(String id, {String? academicYearId}) async {
    String url = '/teacher/$id';
    if (academicYearId != null) {
      url += '?academic_year_id=$academicYearId';
    }
    return await ApiService().get(url);
  }

  /// Creates a new teacher. Clears cache. Like `Teacher::create($data)` in Laravel.
  Future<dynamic> addTeacher(Map<String, dynamic> data) async {
    final result = await ApiService().post('/teacher', data);
    await _clearTeacherCache();
    return result;
  }

  /// Updates a teacher by ID. Clears cache. Like `Teacher::find($id)->update()`.
  Future<void> updateTeacher(String id, Map<String, dynamic> data) async {
    await ApiService().put('/teacher/$id', data);
    await _clearTeacherCache();
  }

  /// Deletes a teacher by ID. Clears cache. Like `Teacher::find($id)->delete()`.
  Future<void> deleteTeacher(String id) async {
    await ApiService().delete('/teacher/$id');
    await _clearTeacherCache();
  }

  /// Fetches subjects assigned to a teacher, optionally filtered by class.
  /// Like `$teacher->subjects()->get()` in Laravel (belongsToMany relationship).
  Future<List<dynamic>> getSubjectByTeacher(
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
      if (kDebugMode) print('Error getTeacherClasses: $e');
      return [];
    }
  }

  /// Fetches subjects by teacher with pagination -- for teacher detail views.
  /// Like `$teacher->subjects()->paginate()` in Laravel.
  static Future<Map<String, dynamic>> getSubjectsByTeacherPaginated({
    required String teacherId,
    int page = 1,
    int limit = 10,
    String? search,
    List<String>? subjectIds,
    String? academicYearId,
  }) async {
    Map<String, dynamic> queryParams = {
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

    String queryString = Uri(queryParameters: queryParams).query;

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
  /// Like `$teacher->subjects()->attach($subjectId)` in Laravel.
  Future<dynamic> addSubjectToTeacher(
    String teacherId,
    String subjectId,
  ) async {
    final result = await ApiService().post('/teacher/$teacherId/subjects', {
      'subject_id': subjectId,
    });
    await _clearTeacherCache();
    return result;
  }

  /// Removes a subject from a teacher (pivot table).
  /// Like `$teacher->subjects()->detach($subjectId)` in Laravel.
  Future<void> removeSubjectFromTeacher(
    String teacherId,
    String subjectId,
  ) async {
    await ApiService().delete('/teacher/$teacherId/subjects/$subjectId');
    await _clearTeacherCache();
  }

  /// Imports teachers from an Excel file via multipart upload. Clears cache.
  /// Like Laravel's `Excel::import()` with Maatwebsite package.
  static Future<Map<String, dynamic>> importTeachersFromExcel(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: 'import_teacher.xlsx',
        ),
      });

      final response = await dioClient.post('/teacher/import', data: formData);

      await _clearTeacherCache();
      return response.data;
    } catch (e) {
      throw Exception('Failed to import teachers: $e');
    }
  }

  Future<void> downloadTeacherTemplate() async {
    try {
      await ApiService().get('/teacher/template');
    } catch (e) {
      throw Exception('Failed to download template: $e');
    }
  }
}
