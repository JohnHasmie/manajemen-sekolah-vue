import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/local_cache_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiSubjectService {
  // static const String baseUrl = ApiService.baseUrl;
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

  // Get Filter Options for Subject Filters
  static Future<Map<String, dynamic>> getSubjectFilterOptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      String schoolId = 'global';
      if (userJson != null) {
        final user = json.decode(userJson);
        schoolId = user['school_id']?.toString() ?? 'global';
      }

      String cacheKey = 'subject_filters_$schoolId';

      // 1. Try cache
      final cachedData = await LocalCacheService.load(
        cacheKey,
        ttl: Duration(hours: 24),
      );
      if (cachedData != null) return cachedData;

      final response = await http.get(
        Uri.parse('$baseUrl/subject/filter-options'),
        headers: await ApiService.getHeaders(),
      );

      final result = _handleResponse(response);

      if (result is Map<String, dynamic>) {
        await LocalCacheService.save(cacheKey, result);
        return result;
      }

      // Fallback
      return {
        'success': false,
        'data': {'status_options': []},
      };
    } catch (e) {
      print('Error getting filter options: $e');
      rethrow;
    }
  }

  // Get Subjects with Pagination & Filters (Recommended)
  static Future<Map<String, dynamic>> getSubjectsPaginated({
    int page = 1,
    int limit = 10,
    String? status, // 'active', 'inactive', 'all'
    String? search,
    String? gradeLevel,
    List<String>? subjectIds,
  }) async {
    // Build query parameters
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (status != null && status.isNotEmpty && status != 'all') {
      queryParams['status'] = status;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (gradeLevel != null && gradeLevel.isNotEmpty) {
      queryParams['grade_level'] = gradeLevel;
    }

    if (subjectIds != null && subjectIds.isNotEmpty) {
      queryParams['subject_ids'] = subjectIds.join(',');
    }

    // Build query string
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

    String cacheKey = 'subject_${schoolId}_$queryString';

    try {
      // 1. Coba ambil dari cache
      final cachedData = await LocalCacheService.load(
        cacheKey,
        ttl: Duration(minutes: 30),
      );
      if (cachedData != null) {
        if (kDebugMode) {
          print('✅ Loading subjects from CACHE: $cacheKey');
        }
        return cachedData;
      }

      // 2. Jika tidak ada di cache, ambil dari API
      if (kDebugMode) {
        print('🌐 Fetching subjects from API for School: $schoolId');
      }
      final response = await http.get(
        Uri.parse('$baseUrl/subject?$queryString'),
        headers: await ApiService.getHeaders(),
      );

      print('GET /subject?$queryString - Status: ${response.statusCode}');

      final result = _handleResponse(response);

      if (result is Map<String, dynamic>) {
        await LocalCacheService.save(cacheKey, result); // Save to cache
        return result;
      }

      // Fallback untuk backward compatibility
      final fallbackResult = {
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

      await LocalCacheService.save(
        cacheKey,
        fallbackResult,
      ); // Save fallback to cache
      return fallbackResult;
    } catch (e) {
      print('Error getting paginated subjects: $e');
      rethrow;
    }
  }

  // Legacy method (keep for backward compatibility)
  // Now handles paginated response from backend
  Future<List<dynamic>> getSubject({String? status}) async {
    String url = '/subject';
    if (status != null && status.isNotEmpty && status != 'all') {
      url += '?status=$status';
    }
    final result = await ApiService().get(url);

    // Handle new pagination format
    if (result is Map<String, dynamic>) {
      return result['data'] ?? [];
    }

    // Handle old format (List)
    return result is List ? result : [];
  }

  static Future<dynamic> addSubject(Map<String, dynamic> data) async {
    final response = await ApiService().post('/subject', data);
    await LocalCacheService.clearStartingWith('subject_'); // Invalidate cache
    return response;
  }

  static Future<void> updateSubject(
    String id,
    Map<String, dynamic> data,
  ) async {
    await ApiService().put('/subject/$id', data);
    await LocalCacheService.clearStartingWith('subject_'); // Invalidate cache
  }

  static Future<void> deleteSubject(String id) async {
    await ApiService().delete('/subject/$id');
    await LocalCacheService.clearStartingWith('subject_'); // Invalidate cache
  }

  static Future<void> attachClass(String subjectId, String classId) async {
    await ApiService().post('/subject-class', {
      'subject_id': subjectId,
      'class_id': classId,
    });
    await LocalCacheService.clearStartingWith('subject_'); // Invalidate cache
  }

  static Future<void> detachClass(String subjectId, String classId) async {
    await ApiService().delete(
      '/subject-class?subject_id=$subjectId&class_id=$classId',
    );
    await LocalCacheService.clearStartingWith('subject_'); // Invalidate cache
  }

  static Future<List<dynamic>> getAllMasterSubjects() async {
    final response = await http.get(
      Uri.parse('$baseUrl/master-subjects'),
      headers: await ApiService.getHeaders(),
    );
    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  static Future<List<dynamic>> getContentMateri({
    required String subBabId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/content-material?sub_chapter_id=$subBabId'),
      headers: await ApiService.getHeaders(),
    );

    final result = _handleResponse(response);
    if (result is List) return result;
    if (result is Map && result['data'] is List) return result['data'];
    return [];
  }

  static Future<List<dynamic>> getBabMateri({String? subjectId}) async {
    String url = '$baseUrl/bab-material?';
    if (subjectId != null) url += 'subject_id=$subjectId&';

    final response = await http.get(
      Uri.parse(url),
      headers: await ApiService.getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  // Sub Bab Materi
  static Future<List<dynamic>> getSubBabMateri({required String babId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/sub-bab-material?chapter_id=$babId'),
      headers: await ApiService.getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  // Tambah Bab Materi
  static Future<dynamic> addBabMateri(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bab-material'),
      headers: await ApiService.getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  // Tambah Sub Bab Materi
  static Future<dynamic> addSubBabMateri(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sub-bab-material'),
      headers: await ApiService.getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  // Tambah Konten Materi
  static Future<dynamic> addContentMateri(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/content-material'),
      headers: await ApiService.getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  // Update Bab Materi
  static Future<void> updateBabMateri(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/bab-material/$id'),
      headers: await ApiService.getHeaders(),
      body: json.encode(data),
    );

    _handleResponse(response);
  }

  // Update Sub Bab Materi
  static Future<void> updateSubBabMateri(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/sub-bab-material/$id'),
      headers: await ApiService.getHeaders(),
      body: json.encode(data),
    );

    _handleResponse(response);
  }

  // Update Konten Materi
  static Future<void> updateContentMateri(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/content-material/$id'),
      headers: await ApiService.getHeaders(),
      body: json.encode(data),
    );

    _handleResponse(response);
  }

  // Delete Bab Materi
  static Future<void> deleteBabMateri(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/bab-material/$id'),
      headers: await ApiService.getHeaders(),
    );

    _handleResponse(response);
  }

  // Delete Sub Bab Materi
  static Future<void> deleteSubBabMateri(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/sub-bab-material/$id'),
      headers: await ApiService.getHeaders(),
    );

    _handleResponse(response);
  }

  // Delete Konten Materi
  static Future<void> deleteContentMateri(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/content-material/$id'),
      headers: await ApiService.getHeaders(),
    );

    _handleResponse(response);
  }

  // Materi
  static Future<List<dynamic>> getMateri({
    String? teacherId,
    String? subjectId,
  }) async {
    String url = '$baseUrl/materials?';
    if (teacherId != null) url += 'teacher_id=$teacherId&';
    if (subjectId != null) url += 'subject_id=$subjectId&';

    final response = await http.get(
      Uri.parse(url),
      headers: await ApiService.getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  static Future<dynamic> addMateri(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/materials'),
      headers: await ApiService.getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<dynamic> saveRPP(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rpp'),
      headers: await ApiService.getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<List<dynamic>> getRPPByTeacher(String guruId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/rpp?teacher_id=$guruId'),
      headers: await ApiService.getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  static Future<Map<String, dynamic>> importSubjectFromExcel(File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/subject/import'),
      );

      // Add headers
      final headers = await ApiService.getHeaders();
      request.headers.addAll(headers);

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: file.path.split('/').last,
        ),
      );

      // Send request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('Import Response Status: ${response.statusCode}');
      print('Import Response Body: $responseBody');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await LocalCacheService.clearStartingWith(
          'subject_',
        ); // Invalidate cache
        return json.decode(responseBody);
      } else {
        throw Exception(
          'Import failed with status: ${response.statusCode}. Response: $responseBody',
        );
      }
    } catch (e) {
      print('Import error details: $e');
      throw Exception('Import error: $e');
    }
  }

  static Future<String> downloadTemplate() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/subject/template'),
        headers: await ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        // Save file locally
        final directory = await getExternalStorageDirectory();
        final filePath = '${directory?.path}/template_import_kelas.xlsx';
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

  // ==================== GENERATE MATERI OLEH AI ====================
  static const String _aiBaseUrl = 'https://edu-ai-api.kamillabs.com/api';

  /// Headers khusus untuk KamillLabs AI API (tanpa X-School-ID)
  static Future<Map<String, String>> _getAiHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> generateMaterialRaw(
      Map<String, dynamic> data) async {
    final response = await http
        .post(
          Uri.parse('$_aiBaseUrl/generated-materials/generate'),
          headers: await _getAiHeaders(),
          body: json.encode(data),
        )
        .timeout(const Duration(seconds: 60));
    return response;
  }

  static Future<dynamic> generateMaterial(Map<String, dynamic> data) async {
    final response = await generateMaterialRaw(data);
    return _handleResponse(response);
  }

  /// Poll AI job status from KamillLabs Edu AI
  static Future<http.Response> pollAiJob(String jobId, String token) async {
    final response = await http
        .get(
          Uri.parse('$_aiBaseUrl/ai-jobs/$jobId'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 15));
    return response;
  }

  /// Get generated material by ID from KamillLabs Edu AI
  static Future<dynamic> getGeneratedMaterial(String materialId) async {
    if (kDebugMode) {
      print('🔍 Getting material: $_aiBaseUrl/generated-materials/$materialId');
    }
    final response = await http.get(
      Uri.parse('$_aiBaseUrl/generated-materials/$materialId'),
      headers: await _getAiHeaders(),
    );
    if (kDebugMode) {
      print('🔍 Get material response: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
    }
    return _handleResponse(response);
  }

  /// Check cache for generated material
  static Future<dynamic> checkMaterialCache({
    required String teacherId,
    required String chapterId,
    String? subChapterId,
  }) async {
    String url =
        '$_aiBaseUrl/generated-materials/check-cache?teacher_id=$teacherId&chapter_id=$chapterId';
    if (subChapterId != null) url += '&sub_chapter_id=$subChapterId';
    if (kDebugMode) {
      print('🔍 Check cache URL: $url');
    }
    final response = await http.get(
      Uri.parse(url),
      headers: await _getAiHeaders(),
    );
    if (kDebugMode) {
      print('🔍 Check cache response: ${response.statusCode} - ${response.body}');
    }
    return _handleResponse(response);
  }

  /// List generated materials with filters (fallback when check-cache fails)
  static Future<dynamic> listGeneratedMaterials({
    required String teacherId,
    String? subjectId,
    String? chapterId,
  }) async {
    String url =
        '$_aiBaseUrl/generated-materials?teacher_id=$teacherId';
    if (subjectId != null) url += '&subject_id=$subjectId';
    if (chapterId != null) url += '&chapter_id=$chapterId';
    if (kDebugMode) {
      print('🔍 List materials URL: $url');
    }
    final response = await http.get(
      Uri.parse(url),
      headers: await _getAiHeaders(),
    );
    if (kDebugMode) {
      print('🔍 List materials response: ${response.statusCode}');
    }
    return _handleResponse(response);
  }

  /// Regenerate quiz for generated material
  static Future<dynamic> regenerateQuiz(String materialId) async {
    final response = await http.post(
      Uri.parse('$_aiBaseUrl/generated-materials/$materialId/regenerate-quiz'),
      headers: await _getAiHeaders(),
    );
    return _handleResponse(response);
  }

  /// Regenerate references for generated material
  static Future<dynamic> regenerateReferences(String materialId) async {
    final response = await http.post(
      Uri.parse(
          '$_aiBaseUrl/generated-materials/$materialId/regenerate-reference'),
      headers: await _getAiHeaders(),
    );
    return _handleResponse(response);
  }

  // ==================== MATERI PROGRESS METHODS ====================

  // Get Materi Progress (checked state) for a teacher and subject
  static Future<List<dynamic>> getMateriProgress({
    required String guruId,
    required String mataPelajaranId,
    String? classId,
  }) async {
    String url =
        '$baseUrl/material-progress?teacher_id=$guruId&subject_id=$mataPelajaranId';
    if (classId != null) url += '&class_id=$classId';

    final response = await http.get(
      Uri.parse(url),
      headers: await ApiService.getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  // Save or Update single materi progress (toggle checked state)
  static Future<dynamic> saveMateriProgress(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/material-progress'),
      headers: await ApiService.getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  // Batch save materi progress (for saving multiple checkboxes at once)
  static Future<dynamic> batchSaveMateriProgress(
    Map<String, dynamic> data,
  ) async {
    // Remap keys to match backend expectations
    final requestData = {
      'teacher_id': data['guru_id'],
      'subject_id': data['mata_pelajaran_id'],
      'class_id': data['class_id'],
      'progress_items': (data['progress_items'] as List).map((item) {
        return {
          'chapter_id': item['bab_id'],
          'sub_chapter_id': item['sub_bab_id'],
          'is_checked': item['is_checked'],
          'is_generated': item['is_generated'] ?? false,
        };
      }).toList(),
    };

    final response = await http.post(
      Uri.parse('$baseUrl/material-progress/batch'),
      headers: await ApiService.getHeaders(),
      body: json.encode(requestData),
    );

    return _handleResponse(response);
  }

  // Mark materi as generated (after RPP/activity generation)
  static Future<dynamic> markMateriGenerated(Map<String, dynamic> data) async {
    // Remap keys
    final requestData = {
      'teacher_id': data['teacher_id'],
      'subject_id': data['subject_id'],
      'class_id': data['class_id'],
      'items': (data['items'] as List).map((item) {
        return {
          'chapter_id': item['bab_id'],
          'sub_chapter_id': item['sub_bab_id'],
        };
      }).toList(),
    };

    final response = await http.post(
      Uri.parse('$baseUrl/material-progress/mark-generated'),
      headers: await ApiService.getHeaders(),
      body: json.encode(requestData),
    );

    return _handleResponse(response);
  }

  // Reset generated status (to allow regeneration)
  static Future<dynamic> resetMateriGenerated(Map<String, dynamic> data) async {
    // Remap keys
    final requestData = {
      'teacher_id': data['teacher_id'],
      'subject_id': data['subject_id'],
      'class_id': data['class_id'],
      'items': (data['items'] as List).map((item) {
        return {
          'chapter_id': item['bab_id'],
          'sub_chapter_id': item['sub_bab_id'],
        };
      }).toList(),
    };

    final response = await http.post(
      Uri.parse('$baseUrl/material-progress/reset-generated'),
      headers: await ApiService.getHeaders(),
      body: json.encode(requestData),
    );

    return _handleResponse(response);
  }
}
