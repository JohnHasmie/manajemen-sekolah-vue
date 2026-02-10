import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/local_cache_service.dart';
import 'package:path_provider/path_provider.dart';

class ApiTeacherService {
  static String get baseUrl => ApiService.baseUrl;

  static dynamic _handleResponse(http.Response response) {
    final responseBody = json.decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    } else {
      if (response.statusCode == 422 && responseBody['errors'] != null) {
        final errors = responseBody['errors'] as Map<String, dynamic>;
        final firstError = errors.values.first;
        final errorMessage = firstError is List
            ? firstError.first
            : firstError.toString();
        throw Exception(errorMessage);
      }

      throw Exception(
        responseBody['message'] ??
            responseBody['error'] ??
            'Request failed with status: ${response.statusCode}',
      );
    }
  }

  static Future<String> downloadTemplate() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teacher/template'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/template_import_guru.xlsx';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      } else {
        throw Exception('Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to download template: $e');
    }
  }

  static Future<Map<String, dynamic>> getTeacherFilterOptions({
    String? academicYearId,
  }) async {
    try {
      String url = '$baseUrl/teacher/filter-options';
      if (academicYearId != null) {
        url += '?academic_year_id=$academicYearId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await ApiService.getHeaders(),
      );

      final result = _handleResponse(response);
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

  static Future<Map<String, dynamic>?> getGuruByUserId(
    String userId, {
    String? academicYearId,
  }) async {
    try {
      String url = '$baseUrl/teacher?user_id=$userId';
      if (academicYearId != null) {
        url += '&academic_year_id=$academicYearId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await ApiService.getHeaders(),
      );

      final result = _handleResponse(response);

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
      final response = await http.get(
        Uri.parse('$baseUrl/teacher?$queryString'),
        headers: await ApiService.getHeaders(),
      );

      final result = _handleResponse(response);

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
      final response = await http.get(
        Uri.parse('$baseUrl/teacher/stats?$queryString'),
        headers: await ApiService.getHeaders(),
      );

      final result = _handleResponse(response);
      return result['data'] ?? {};
    } catch (e) {
      if (kDebugMode) print('Error fetching teacher stats: $e');
      return {};
    }
  }

  static Future<void> _clearTeacherCache() async {
    await LocalCacheService.clearStartingWith('teacher_');
    if (kDebugMode) print('🧹 Teacher cache cleared due to changes');
  }

  Future<List<dynamic>> getTeacher() async {
    final result = await ApiService().get('/teacher');
    if (result is Map<String, dynamic>) {
      return result['data'] ?? [];
    }
    return result is List ? result : [];
  }

  Future<dynamic> getTeacherById(String id, {String? academicYearId}) async {
    String url = '/teacher/$id';
    if (academicYearId != null) {
      url += '?academic_year_id=$academicYearId';
    }
    return await ApiService().get(url);
  }

  Future<dynamic> addTeacher(Map<String, dynamic> data) async {
    final result = await ApiService().post('/teacher', data);
    await _clearTeacherCache();
    return result;
  }

  Future<void> updateTeacher(String id, Map<String, dynamic> data) async {
    await ApiService().put('/teacher/$id', data);
    await _clearTeacherCache();
  }

  Future<void> deleteTeacher(String id) async {
    await ApiService().delete('/teacher/$id');
    await _clearTeacherCache();
  }

  Future<List<dynamic>> getSubjectByTeacher(
    String guruId, {
    String? classId,
  }) async {
    try {
      String url = '/teacher/$guruId/subjects';
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

  static Future<List<dynamic>> getTeacherClasses(
    String teacherId, {
    String? academicYearId,
  }) async {
    try {
      String url = '$baseUrl/teacher/$teacherId/classes';
      if (academicYearId != null) {
        url += '?academic_year_id=$academicYearId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await ApiService.getHeaders(),
      );

      final result = _handleResponse(response);
      if (result is Map<String, dynamic> && result['data'] is List) {
        return result['data'];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

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
      final response = await http.get(
        Uri.parse('$baseUrl/teacher/$teacherId/subjects?$queryString'),
        headers: await ApiService.getHeaders(),
      );

      final result = _handleResponse(response);

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

  Future<void> removeSubjectFromTeacher(
    String teacherId,
    String subjectId,
  ) async {
    await ApiService().delete('/teacher/$teacherId/subjects/$subjectId');
    await _clearTeacherCache();
  }

  static Future<Map<String, dynamic>> importTeachersFromExcel(File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/teacher/import'),
      );

      final headers = await ApiService.getHeaders();
      request.headers.addAll(headers);
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: 'import_teacher.xlsx',
        ),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        await _clearTeacherCache();
        return json.decode(responseData);
      } else {
        throw Exception('Failed to import teachers: $responseData');
      }
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
