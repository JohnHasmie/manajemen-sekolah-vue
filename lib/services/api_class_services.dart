import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/local_cache_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClassService {
  static String get baseUrl => ApiService.baseUrl;

  static dynamic _handleResponse(http.Response response) {
    final responseBody = json.decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    } else {
      throw Exception(
        responseBody['error'] ??
            'Request failed with status: ${response.statusCode}',
      );
    }
  }

  static Future<Map<String, dynamic>> importClassesFromExcel(File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/class/import'),
      );

      final headers = await ApiService.getHeaders();
      request.headers.addAll(headers);

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: file.path.split('/').last,
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _clearClassCache();
        return json.decode(responseBody);
      } else {
        throw Exception(
          'Import failed with status: ${response.statusCode}. Response: $responseBody',
        );
      }
    } catch (e) {
      throw Exception('Import error: $e');
    }
  }

  static Future<String> downloadTemplate() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/class/template'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/template_import_kelas.xlsx';
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

  static Future<Map<String, dynamic>> getClassFilterOptions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/class/filter-options'),
        headers: await ApiService.getHeaders(),
      );

      final result = _handleResponse(response);

      if (result is Map<String, dynamic>) {
        return result;
      }

      return {
        'success': false,
        'data': {'grade_levels': [], 'wali_kelas': []},
      };
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getClassPaginated({
    int page = 1,
    int limit = 10,
    String? gradeLevel,
    String? waliclassId,
    String? search,
    String? academicYearId,
    String? hasHomeroomTeacher,
    bool useCache = true,
  }) async {
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (hasHomeroomTeacher != null && hasHomeroomTeacher.isNotEmpty) {
      queryParams['has_homeroom_teacher'] = hasHomeroomTeacher;
    }

    if (gradeLevel != null && gradeLevel.isNotEmpty) {
      queryParams['grade_level'] = gradeLevel;
    }
    if (waliclassId != null && waliclassId.isNotEmpty) {
      queryParams['homeroom_teacher_id'] = waliclassId;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }

    String queryString = Uri(queryParameters: queryParams).query;

    // Get school_id context for cache key
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    String schoolId = 'global';
    if (userJson != null) {
      try {
        final user = json.decode(userJson);
        schoolId = user['school_id']?.toString() ?? 'global';
      } catch (_) {}
    }

    final cacheKey = 'class_${schoolId}_paginated_$queryString';

    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null) {
        if (kDebugMode) print('📦 Using cached classes for $cacheKey');
        return cached;
      }
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/class?$queryString'),
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

  static Future<void> _clearClassCache() async {
    await LocalCacheService.clearStartingWith('class_');
    if (kDebugMode) print('🧹 Class cache cleared due to changes');
  }

  static Future<List<dynamic>> getClass({String? academicYearId}) async {
    try {
      String url = '/class';
      if (academicYearId != null) {
        url += '?academic_year_id=$academicYearId';
      }

      final result = await ApiService().get(url);

      if (result is Map<String, dynamic>) {
        return result['data'] ?? [];
      }

      return result is List ? result : [];
    } catch (e) {
      return [];
    }
  }

  static Future<dynamic> getClassById(String id) async {
    try {
      final result = await ApiService().get('/class/$id');
      return result;
    } catch (e) {
      throw Exception('Gagal mengambil data kelas: $e');
    }
  }

  static Future<dynamic> addClass(Map<String, dynamic> data) async {
    try {
      if (data['name'] == null || data['name'].toString().isEmpty) {
        throw Exception('Nama kelas harus diisi');
      }

      if (data['grade_level'] == null) {
        throw Exception('Grade level harus dipilih');
      }

      final result = await ApiService().post('/class', data);
      await _clearClassCache();
      return result;
    } catch (e) {
      throw Exception('Gagal menambah kelas: $e');
    }
  }

  static Future<dynamic> updateClass(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      if (data['name'] == null || data['name'].toString().isEmpty) {
        throw Exception('Nama kelas harus diisi');
      }

      if (data['grade_level'] == null) {
        throw Exception('Grade level harus dipilih');
      }

      final result = await ApiService().put('/class/$id', data);
      await _clearClassCache();
      return result;
    } catch (e) {
      throw Exception('Gagal mengupdate kelas: $e');
    }
  }

  static Future<void> deleteClass(String id) async {
    try {
      await ApiService().delete('/class/$id');
      await _clearClassCache();
    } catch (e) {
      throw Exception('Gagal menghapus kelas: $e');
    }
  }

  static Future<List<dynamic>> getStudentsByClassId(String classId) async {
    try {
      final result = await ApiService().get('/student/class/$classId');

      if (result is Map<String, dynamic>) {
        if (result.containsKey('data')) {
          return result['data'] ?? [];
        }
        return [];
      }

      return result is List ? result : [];
    } catch (e) {
      return [];
    }
  }

  static Future<dynamic> promoteStudents(Map<String, dynamic> data) async {
    try {
      final result = await ApiService().post('/promotion/promote', data);
      await _clearClassCache();
      return result;
    } catch (e) {
      throw Exception('Gagal melakukan proses kenaikan kelas: $e');
    }
  }
}
