/// api_subject_services.dart - Manages subjects (mata pelajaran), materials, and AI-generated content.
/// Like Laravel's SubjectController + MaterialController / Vue's subject store module.
///
/// This is one of the largest service files. It handles:
/// - Subject CRUD with pagination, caching, and Excel import/export
/// - Curriculum material hierarchy: Bab (chapter) > Sub-Bab (sub-chapter) > Content
/// - Material progress tracking (checked/generated state per teacher)
/// - AI-powered material generation via KamillLabs Edu AI microservice
/// - RPP (lesson plan) generation, editing, and field-level regeneration
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for subject, material, and AI content management API calls.
/// Like a combined Laravel controller handling subjects, materials, and AI endpoints.
/// Uses two different base URLs: main API for CRUD, AI API for generation.
///
/// In Vue terms, this is a large Pinia store combining subject state management
/// with AI generation actions and curriculum material tree operations.
class ApiSubjectService {
  /// Base URL from central config.
  static String get baseUrl => ApiService.baseUrl;

  /// Parses JSON response and throws on non-2xx status.
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

  /// Fetches filter dropdown options for subject listing, with 24-hour cache.
  /// Like a Laravel endpoint returning distinct filter values for Vue selects.
  /// Cache is scoped by school_id to prevent cross-school data leaks.
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

  /// Fetches subjects with server-side pagination, filters, and local caching.
  /// Like `Subject::filter($request)->paginate()` in Laravel.
  /// Cache is scoped by school_id with 30-minute TTL.
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

  /// Legacy method to fetch all subjects as a flat list.
  /// Kept for backward compatibility -- new code should use [getSubjectsPaginated].
  /// Note: this is an instance method (not static) unlike most others.
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

  /// Creates a new subject. Invalidates subject cache.
  /// Like `Subject::create($data)` in Laravel.
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

  /// Attaches a class to a subject (many-to-many pivot).
  /// Like `$subject->classes()->attach($classId)` in Laravel.
  static Future<void> attachClass(String subjectId, String classId) async {
    await ApiService().post('/subject-class', {
      'subject_id': subjectId,
      'class_id': classId,
    });
    await LocalCacheService.clearStartingWith('subject_'); // Invalidate cache
  }

  /// Detaches a class from a subject (removes pivot record).
  /// Like `$subject->classes()->detach($classId)` in Laravel.
  static Future<void> detachClass(String subjectId, String classId) async {
    await ApiService().delete(
      '/subject-class?subject_id=$subjectId&class_id=$classId',
    );
    await LocalCacheService.clearStartingWith('subject_'); // Invalidate cache
  }

  /// Fetches the master list of all available subjects (system-wide, not school-specific).
  /// Like `MasterSubject::all()` in Laravel -- used for template/reference data.
  static Future<List<dynamic>> getAllMasterSubjects() async {
    final response = await http.get(
      Uri.parse('$baseUrl/master-subjects'),
      headers: await ApiService.getHeaders(),
    );
    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  /// Fetches content materials for a specific sub-chapter (sub-bab).
  /// Part of the material hierarchy: Subject > Bab > Sub-Bab > Content.
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

  /// Fetches chapters (bab) for a subject. Top level of the material hierarchy.
  /// Like `Chapter::where('subject_id', $id)->get()` in Laravel.
  static Future<List<dynamic>> getBabMateri({String? subjectId}) async {
    String url = '$baseUrl/bab-material?';
    if (subjectId != null) url += 'subject_id=$subjectId&';

    final response = await http.get(
      Uri.parse(url),
      headers: await ApiService.getHeaders(),
    ).timeout(const Duration(seconds: 30));

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  /// Fetches sub-chapters (sub-bab) for a given chapter.
  /// Like `SubChapter::where('chapter_id', $babId)->get()` in Laravel.
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
    ).timeout(const Duration(seconds: 30));

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

  static Future<List<dynamic>> getRPPByTeacher(String teacherId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/rpp?teacher_id=$teacherId'),
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
  // The methods below call a separate AI microservice (KamillLabs Edu AI),
  // not the main Laravel backend. Similar to having a second API_BASE_URL
  // in your .env file for an external service.

  /// Base URL for the AI microservice. Separate from the main Laravel API.
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

  // ==================== RPP REGENERATION METHODS ====================
  // These methods handle AI-powered RPP (lesson plan) field regeneration.
  // Each field can be regenerated up to 2 times (limit enforced server-side).

  /// Regenerate a specific RPP field (Section 5.6)
  /// POST /api/lesson-plans/{id}/regen/{field}
  /// Max 2 regenerations per field
  static Future<http.Response> regenRppFieldRaw(
    String rppId,
    String field, {
    String? additionalText,
  }) async {
    final body = <String, dynamic>{};
    if (additionalText != null && additionalText.trim().isNotEmpty) {
      body['additional_text'] = additionalText.trim();
    }
    final url = '$_aiBaseUrl/lesson-plans/$rppId/regen/$field';
    if (kDebugMode) {
      print('🔄 Regen RPP field URL: $url');
      print('🔄 Regen RPP body: ${json.encode(body)}');
    }
    final response = await http
        .post(
          Uri.parse(url),
          headers: await _getAiHeaders(),
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 60));
    if (kDebugMode) {
      print('🔄 Regen RPP response: ${response.statusCode} - ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
    }
    return response;
  }

  /// Get RPP regen limits per field (Section 5.7)
  /// GET /api/lesson-plans/{id}/regen-limits
  static Future<dynamic> getRppRegenLimits(String rppId) async {
    if (kDebugMode) print('🔄 Regen limits URL: $_aiBaseUrl/lesson-plans/$rppId/regen-limits');
    final response = await http.get(
      Uri.parse('$_aiBaseUrl/lesson-plans/$rppId/regen-limits'),
      headers: await _getAiHeaders(),
    );
    if (kDebugMode) print('🔄 Regen limits response: ${response.statusCode}');
    if (response.body.trimLeft().startsWith('<!DOCTYPE') || response.body.trimLeft().startsWith('<html')) {
      throw Exception('Server AI tidak tersedia (${response.statusCode})');
    }
    return _handleResponse(response);
  }

  /// Update RPP fields / auto-save (Section 5.5)
  /// PATCH /api/lesson-plans/{id}
  static Future<dynamic> updateRppFields(
    String rppId,
    Map<String, dynamic> fields,
  ) async {
    final response = await http
        .patch(
          Uri.parse('$_aiBaseUrl/lesson-plans/$rppId'),
          headers: await _getAiHeaders(),
          body: json.encode(fields),
        )
        .timeout(const Duration(seconds: 30));
    return _handleResponse(response);
  }

  /// Get RPP detail from AI API (Section 5.4)
  /// GET /api/lesson-plans/{id}
  static Future<dynamic> getRppDetail(String rppId) async {
    final response = await http.get(
      Uri.parse('$_aiBaseUrl/lesson-plans/$rppId'),
      headers: await _getAiHeaders(),
    );
    return _handleResponse(response);
  }

  // ==================== MATERI PROGRESS METHODS ====================
  // These methods track which chapters/sub-chapters a teacher has covered
  // and which ones have been AI-generated. Like a todo/checklist system.

  /// Fetches material progress (checked/generated state) for a teacher + subject combo.
  /// Like `MaterialProgress::where('teacher_id', ...)->where('subject_id', ...)->get()`.
  static Future<List<dynamic>> getMateriProgress({
    required String teacherId,
    required String subjectId,
    String? classId,
  }) async {
    String url =
        '$baseUrl/material-progress?teacher_id=$teacherId&subject_id=$subjectId';
    if (classId != null) url += '&class_id=$classId';

    final response = await http.get(
      Uri.parse(url),
      headers: await ApiService.getHeaders(),
    ).timeout(const Duration(seconds: 30));

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  /// Saves or toggles the checked state for a single material progress item.
  /// Like `MaterialProgress::updateOrCreate()` in Laravel.
  static Future<dynamic> saveMateriProgress(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/material-progress'),
      headers: await ApiService.getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  /// Batch-saves multiple material progress items at once.
  /// Remaps frontend keys (guru_id, bab_id) to backend keys (teacher_id, chapter_id).
  /// Like a Laravel batch upsert with key remapping middleware.
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

  /// Marks specific materials as AI-generated (after RPP/activity generation).
  /// Prevents accidental re-generation. Like setting a `generated_at` timestamp.
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

  /// Resets the generated status to allow re-generation.
  /// Like clearing the `generated_at` flag so the AI can regenerate content.
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
