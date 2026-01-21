import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiTeacherService {
  // static const String baseUrl = ApiService.baseUrl;
  static String get baseUrl => ApiService.baseUrl;

  static dynamic _handleResponse(http.Response response) {
    final responseBody = json.decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    } else {
      // Handle Laravel validation errors (422)
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

  // Download template Excel untuk guru
  static Future<String> downloadTemplate() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teacher/template'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        // Save file locally
        final directory = await getExternalStorageDirectory();
        final filePath = '${directory?.path}/template_import_guru.xlsx';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);

        print('Template downloaded to: $filePath');
        return filePath;
      } else {
        throw Exception('Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Download template error: $e');
      throw Exception('Failed to download template: $e');
    }
  }

  // Get external storage directory (helper function)
  static Future<Directory?> getExternalStorageDirectory() async {
    try {
      // For mobile
      final directory = await getApplicationDocumentsDirectory();
      return directory;
    } catch (e) {
      // For web or other platforms
      return null;
    }
  }

  // Get Filter Options for Teacher Filters
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

      if (result is Map<String, dynamic>) {
        return result;
      }

      // Fallback
      return {
        'success': false,
        'data': {'kelas': [], 'gender_options': []},
      };
    } catch (e) {
      print('Error getting filter options: $e');
      rethrow;
    }
  }

  // Get Guru by User ID
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

      if (result is Map<String, dynamic> &&
          result['data'] is List &&
          (result['data'] as List).isNotEmpty) {
        return result['data'][0];
      }

      return null;
    } catch (e) {
      print('Error getting guru by user id: $e');
      return null;
    }
  }

  // Get Teachers with Pagination & Filters (Recommended)
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
  }) async {
    // Build query parameters
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

    // Build query string
    String queryString = Uri(queryParameters: queryParams).query;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teacher?$queryString'),
        headers: await ApiService.getHeaders(),
      );

      print('GET /teacher?$queryString - Status: ${response.statusCode}');

      final result = _handleResponse(response);

      if (result is Map<String, dynamic>) {
        return result;
      }

      // Fallback untuk backward compatibility
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
      print('Error getting paginated teachers: $e');
      rethrow;
    }
  }

  // Existing methods tetap dipertahankan...
  Future<List<dynamic>> getTeacher() async {
    final result = await ApiService().get('/teacher');

    // Handle new pagination format
    if (result is Map<String, dynamic>) {
      return result['data'] ?? [];
    }

    // Handle old format (List)
    return result is List ? result : [];
  }

  Future<dynamic> getTeacherById(String id, {String? academicYearId}) async {
    String url = '/teacher/$id';
    if (academicYearId != null) {
      url += '?academic_year_id=$academicYearId';
    }
    return await ApiService().get(url);
  }

  // Add teacher with new structure
  // Required fields: nama, email, jenis_kelamin ("L" or "P")
  // Optional fields: nip, subject_ids (List<String>), class_ids (List<String>),
  //                  wali_kelas_id (String), status_kepegawaian ("tetap" or "tidak_tetap")
  Future<dynamic> addTeacher(Map<String, dynamic> data) async {
    return await ApiService().post('/teacher', data);
  }

  // Update teacher with new structure
  // All fields same as addTeacher
  // Note: id parameter is guru.id (not user_id)
  Future<void> updateTeacher(String id, Map<String, dynamic> data) async {
    await ApiService().put('/teacher/$id', data);
  }

  Future<void> deleteTeacher(String id) async {
    await ApiService().delete('/teacher/$id');
  }

  Future<List<dynamic>> getSubjectByTeacher(String guruId) async {
    try {
      // Correct endpoint matches index.js: /api/guru/:id/mata-pelajaran
      final result = await ApiService().get('/teacher/$guruId/subjects');

      if (result is List) {
        return result;
      }

      // Handle wrapped response if any
      if (result is Map<String, dynamic> && result['data'] != null) {
        return result['data'] is List ? result['data'] : [];
      }

      return [];
    } catch (e) {
      print('Error getting mata pelajaran by guru: $e');
      return [];
    }
  }

  // Get Classes by Teacher (Teaching + Homeroom)
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
      print('Error getting classes by teacher: $e');
      return [];
    }
  }

  // Get Subjects by Teacher with Pagination & Filters (Recommended)
  static Future<Map<String, dynamic>> getSubjectsByTeacherPaginated({
    required String teacherId,
    int page = 1,
    int limit = 10,
    String? search,
    List<String>? subjectIds,
    String? academicYearId,
  }) async {
    // Build query parameters
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

    // Build query string
    String queryString = Uri(queryParameters: queryParams).query;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teacher/$teacherId/subjects?$queryString'),
        headers: await ApiService.getHeaders(),
      );

      print(
        'GET /teacher/$teacherId/subjects?$queryString - Status: ${response.statusCode}',
      );
      if (kDebugMode && response.statusCode != 200) {
        print('Response body (Error): ${response.body}');
      }
      if (kDebugMode) {
        print(
          'Response body: ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}',
        );
      }

      final result = _handleResponse(response);

      if (result is Map<String, dynamic>) {
        return result;
      }

      // Fallback untuk backward compatibility
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
      print('Error getting paginated subjects by teacher: $e');
      rethrow;
    }
  }

  Future<dynamic> addSubjectToTeacher(
    String teacherId,
    String subjectId,
  ) async {
    try {
      final result = await ApiService().post('/teacher/$teacherId/subjects', {
        'subject_id': subjectId,
      });
      return result;
    } catch (e) {
      print('Error adding mata pelajaran to guru: $e');
      rethrow;
    }
  }

  Future<void> removeSubjectFromTeacher(
    String teacherId,
    String subjectId,
  ) async {
    try {
      await ApiService().delete('/teacher/$teacherId/subjects/$subjectId');
    } catch (e) {
      print('Error removing mata pelajaran from guru: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> importTeachersFromExcel(File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/teacher/import'),
      );

      // Add authorization header
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      request.headers['Authorization'] = 'Bearer $token';
      // Add file
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
        return json.decode(responseData);
      } else {
        throw Exception('Failed to import teachers: $responseData');
      }
    } catch (e) {
      throw Exception('Failed to import teachers: $e');
    }
  }

  // Download teacher template
  Future<void> downloadTeacherTemplate() async {
    try {
      final response = await ApiService().get('/teacher/template');

      // Handle response untuk download file
      // Implementasi download file sesuai kebutuhan
    } catch (e) {
      throw Exception('Failed to download template: $e');
    }
  }
}
