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

import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Service for subject, material, and AI content management API calls.
/// Like a combined Laravel controller handling subjects, materials, and AI endpoints.
/// Uses two different base URLs: main API for CRUD, AI API for generation.
///
/// In Vue terms, this is a large Pinia store combining subject state management
/// with AI generation actions and curriculum material tree operations.
class ApiSubjectService {
  /// Fetches filter dropdown options for subject listing, with 24-hour cache.
  /// Like a Laravel endpoint returning distinct filter values for Vue selects.
  /// Cache is scoped by school_id to prevent cross-school data leaks.
  Future<Map<String, dynamic>> getSubjectFilterOptions() async {
    try {
      final prefs = PreferencesService();
      final userJson = prefs.getString('user');
      String schoolId = 'global';
      if (userJson != null) {
        final user = json.decode(userJson);
        schoolId = user['school_id']?.toString() ?? 'global';
      }

      final String cacheKey = CacheKeyBuilder.subjectFilters(schoolId);

      // 1. Try cache
      final cachedData = await LocalCacheService.load(
        cacheKey,
        ttl: Duration(hours: 24),
      );
      if (cachedData != null) return cachedData;

      final response = await dioClient.get('/subject/filter-options');

      final result = response.data;

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
      AppLogger.error('subject', e);
      rethrow;
    }
  }

  /// Fetches subjects with server-side pagination, filters, and local caching.
  /// Like `Subject::filter($request)->paginate()` in Laravel.
  /// Cache is scoped by school_id with 30-minute TTL.
  Future<Map<String, dynamic>> getSubjectsPaginated({
    int page = 1,
    int limit = 10,
    String? status, // 'active', 'inactive', 'all'
    String? search,
    String? gradeLevel,
    List<String>? subjectIds,
  }) async {
    // Build query parameters
    final Map<String, dynamic> queryParams = {
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
    final String queryString = Uri(queryParameters: queryParams).query;

    // Get school_id context for cache key
    final prefs = PreferencesService();
    final userJson = prefs.getString('user');
    String schoolId = 'global';
    if (userJson != null) {
      try {
        final user = json.decode(userJson);
        schoolId = user['school_id']?.toString() ?? 'global';
      } catch (_) {}
    }

    final String cacheKey = CacheKeyBuilder.custom(
      'subject',
      schoolId,
      queryString,
    );

    try {
      // 1. Try to get from cache
      final cachedData = await LocalCacheService.load(
        cacheKey,
        ttl: Duration(minutes: 30),
      );
      if (cachedData != null) {
        AppLogger.info('subject', 'Loading subjects from CACHE: $cacheKey');
        return cachedData;
      }

      // 2. If not in cache, fetch from API
      AppLogger.debug(
        'subject',
        'Fetching subjects from API for School: $schoolId',
      );
      final response = await dioClient.get('/subject?$queryString');

      AppLogger.debug(
        'subject',
        'GET /subject?$queryString - Status: ${response.statusCode}',
      );

      final result = response.data;

      if (result is Map<String, dynamic>) {
        await LocalCacheService.save(cacheKey, result); // Save to cache
        return result;
      }

      // Fallback for backward compatibility
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
      AppLogger.error('subject', e);
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
  Future<dynamic> addSubject(Map<String, dynamic> data) async {
    final response = await ApiService().post('/subject', data);
    await LocalCacheService.clearStartingWith('subject_'); // Invalidate cache
    return response;
  }

  Future<void> updateSubject(String id, Map<String, dynamic> data) async {
    await ApiService().put('/subject/$id', data);
    await LocalCacheService.clearStartingWith('subject_'); // Invalidate cache
  }

  Future<void> deleteSubject(String id) async {
    await ApiService().delete('/subject/$id');
    await LocalCacheService.clearStartingWith('subject_'); // Invalidate cache
  }

  /// Attaches a class to a subject (many-to-many pivot).
  /// Like `$subject->classes()->attach($classId)` in Laravel.
  Future<void> attachClass(String subjectId, String classId) async {
    await ApiService().post('/subject-class', {
      'subject_id': subjectId,
      'class_id': classId,
    });
    await LocalCacheService.clearStartingWith('subject_'); // Invalidate cache
  }

  /// Detaches a class from a subject (removes pivot record).
  /// Like `$subject->classes()->detach($classId)` in Laravel.
  Future<void> detachClass(String subjectId, String classId) async {
    await ApiService().delete(
      '/subject-class?subject_id=$subjectId&class_id=$classId',
    );
    await LocalCacheService.clearStartingWith('subject_'); // Invalidate cache
  }

  /// Fetches the master list of all available subjects (system-wide, not school-specific).
  /// Like `MasterSubject::all()` in Laravel -- used for template/reference data.
  Future<List<dynamic>> getAllMasterSubjects() async {
    final response = await dioClient.get('/master-subjects');
    final result = response.data;
    return result is List ? result : [];
  }

  /// Fetches content materials for a specific sub-chapter.
  /// Part of the material hierarchy: Subject > Chapter > SubChapter > Content.
  Future<List<dynamic>> getContentMaterials({
    required String subChapterId,
  }) async {
    final response = await dioClient.get(
      '/content-material?sub_chapter_id=$subChapterId',
    );

    final result = response.data;
    if (result is List) return result;
    if (result is Map && result['data'] is List) return result['data'];
    return [];
  }

  /// Fetches chapters for a subject. Top level of the material hierarchy.
  /// Like `Chapter::where('subject_id', $id)->get()` in Laravel.
  Future<List<dynamic>> getChapterMaterials({String? subjectId}) async {
    String url = '/bab-material?';
    if (subjectId != null) url += 'subject_id=$subjectId&';

    final response = await dioClient.get(url);

    final result = response.data;
    return result is List ? result : [];
  }

  /// Fetches sub-chapters for a given chapter.
  /// Like `SubChapter::where('chapter_id', $chapterId)->get()` in Laravel.
  Future<List<dynamic>> getSubChapterMaterials({
    required String chapterId,
  }) async {
    final response = await dioClient.get(
      '/sub-bab-material?chapter_id=$chapterId',
    );

    final result = response.data;
    return result is List ? result : [];
  }

  // Add Chapter Material
  Future<dynamic> addChapterMaterial(Map<String, dynamic> data) async {
    final response = await dioClient.post('/bab-material', data: data);
    return response.data;
  }

  // Add Sub-Chapter Material
  Future<dynamic> addSubChapterMaterial(Map<String, dynamic> data) async {
    final response = await dioClient.post('/sub-bab-material', data: data);
    return response.data;
  }

  // Add Content Material
  Future<dynamic> addContentMaterial(Map<String, dynamic> data) async {
    final response = await dioClient.post('/content-material', data: data);
    return response.data;
  }

  // Update Chapter Material
  Future<void> updateChapterMaterial(
    String id,
    Map<String, dynamic> data,
  ) async {
    await dioClient.put('/bab-material/$id', data: data);
  }

  // Update Sub-Chapter Material
  Future<void> updateSubChapterMaterial(
    String id,
    Map<String, dynamic> data,
  ) async {
    await dioClient.put('/sub-bab-material/$id', data: data);
  }

  // Update Content Material
  Future<void> updateContentMaterial(
    String id,
    Map<String, dynamic> data,
  ) async {
    await dioClient.put('/content-material/$id', data: data);
  }

  // Delete Chapter Material
  Future<void> deleteChapterMaterial(String id) async {
    await dioClient.delete('/bab-material/$id');
  }

  // Delete Sub-Chapter Material
  Future<void> deleteSubChapterMaterial(String id) async {
    await dioClient.delete('/sub-bab-material/$id');
  }

  // Delete Content Material
  Future<void> deleteContentMaterial(String id) async {
    await dioClient.delete('/content-material/$id');
  }

  // Materi
  Future<List<dynamic>> getMaterials({
    String? teacherId,
    String? subjectId,
  }) async {
    String url = '/materials?';
    if (teacherId != null) url += 'teacher_id=$teacherId&';
    if (subjectId != null) url += 'subject_id=$subjectId&';

    final response = await dioClient.get(url);

    final result = response.data;
    return result is List ? result : [];
  }

  Future<dynamic> addMaterial(Map<String, dynamic> data) async {
    final response = await dioClient.post('/materials', data: data);
    return response.data;
  }

  Future<dynamic> saveRPP(Map<String, dynamic> data) async {
    final response = await dioClient.post('/rpp', data: data);
    return response.data;
  }

  Future<List<dynamic>> getLessonPlansByTeacher(String teacherId) async {
    final response = await dioClient.get('/rpp?teacher_id=$teacherId');

    final result = response.data;
    return result is List ? result : [];
  }

  Future<Map<String, dynamic>> importSubjectFromExcel(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await dioClient.post('/subject/import', data: formData);

      AppLogger.debug(
        'subject',
        'Import Response Status: ${response.statusCode}',
      );
      AppLogger.debug('subject', 'Import Response Body: ${response.data}');

      await LocalCacheService.clearStartingWith('subject_'); // Invalidate cache
      return response.data;
    } catch (e) {
      AppLogger.error('subject', e);
      throw Exception('Import error: $e');
    }
  }

  Future<String> downloadTemplate() async {
    try {
      final response = await dioClient.get<List<int>>(
        '/subject/template',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data ?? [];

      // Save file locally
      final directory = await getExternalStorageDirectory();
      final filePath = '${directory?.path}/template_import_kelas.xlsx';
      final file = File(filePath);

      await file.writeAsBytes(bytes);

      AppLogger.info('subject', 'Template downloaded to: $filePath');
      return filePath;
    } catch (e) {
      AppLogger.error('subject', e);
      throw Exception('Failed to download template: $e');
    }
  }

  // ==================== GENERATE MATERI OLEH AI ====================
  // The methods below call a separate AI microservice (KamillLabs Edu AI),
  // not the main Laravel backend. Similar to having a second API_BASE_URL
  // in your .env file for an external service.
  //
  // Uses a dedicated Dio instance (_aiDio) with:
  // - AI microservice base URL
  // - Auth header injection (Bearer token only, no X-School-ID)
  // - validateStatus: (_) => true — so callers can inspect non-2xx status
  //   codes without Dio throwing (matching the old http package behavior).

  /// Base URL for the AI microservice. Separate from the main Laravel API.
  final String _aiBaseUrl = 'https://edu-ai-api.kamillabs.com/api';

  /// Lazy-initialized Dio instance for KamillLabs AI API calls.
  /// Like a second Axios instance in Vue pointing to a different base URL.
  /// Does NOT throw on non-2xx so callers can check statusCode themselves.
  Dio? _aiDioInstance;
  Dio get _aiDio {
    _aiDioInstance ??=
        Dio(
            BaseOptions(
              baseUrl: _aiBaseUrl,
              connectTimeout: const Duration(seconds: 60),
              receiveTimeout: const Duration(seconds: 60),
              sendTimeout: const Duration(seconds: 60),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              // Don't throw on non-2xx — callers inspect statusCode directly
              validateStatus: (_) => true,
            ),
          )
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) async {
                final prefs = PreferencesService();
                final token = prefs.getString('token');
                if (token != null) {
                  options.headers['Authorization'] = 'Bearer $token';
                }
                handler.next(options);
              },
            ),
          );
    return _aiDioInstance!;
  }

  /// Generate a lesson plan via kamiledu-ai backend.
  /// POST /lesson-plans/generate
  /// Returns the generated lesson plan data (sync 201) or job info (async 202).
  Future<dynamic> generateLessonPlanViaAI({
    required String teacherId,
    required String subjectId,
    required String classId,
    required String chapterId,
    String? subChapterId,
    String? timeAllocation,
  }) async {
    final response = await _aiDio.post(
      '/lesson-plans/generate',
      data: {
        'teacher_id': teacherId,
        'subject_id': subjectId,
        'class_id': classId,
        'chapter_id': chapterId,
        if (subChapterId != null) 'sub_chapter_id': subChapterId,
        if (timeAllocation != null) 'time_allocation': timeAllocation,
      },
    );
    return response.data;
  }

  /// Returns a raw Dio Response so callers can inspect statusCode (202, 429, etc.).
  Future<Response<dynamic>> generateMaterialRaw(
    Map<String, dynamic> data,
  ) async {
    final response = await _aiDio.post(
      '/generated-materials/generate',
      data: data,
    );
    return response;
  }

  /// Parses Dio AI response and throws on non-2xx status.
  dynamic _handleAiResponse(Response<dynamic> response) {
    final responseBody = response.data;

    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      return responseBody;
    } else {
      throw Exception(
        responseBody is Map
            ? (responseBody['error'] ??
                  'Request failed with status: ${response.statusCode}')
            : 'Request failed with status: ${response.statusCode}',
      );
    }
  }

  Future<dynamic> generateMaterial(Map<String, dynamic> data) async {
    final response = await generateMaterialRaw(data);
    return _handleAiResponse(response);
  }

  /// Poll AI job status from KamillLabs Edu AI.
  /// Returns raw Dio Response so callers can inspect statusCode.
  Future<Response<dynamic>> pollAiJob(String jobId, String token) async {
    final response = await _aiDio.get(
      '/ai-jobs/$jobId',
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    return response;
  }

  /// Get generated material by ID from KamillLabs Edu AI
  Future<dynamic> getGeneratedMaterial(String materialId) async {
    AppLogger.debug(
      'subject',
      'Getting material: $_aiBaseUrl/generated-materials/$materialId',
    );
    final response = await _aiDio.get('/generated-materials/$materialId');
    AppLogger.debug('subject', 'Get material response: ${response.statusCode}');
    return _handleAiResponse(response);
  }

  /// Check cache for generated material
  Future<dynamic> checkMaterialCache({
    required String teacherId,
    required String chapterId,
    String? subChapterId,
  }) async {
    final queryParams = <String, dynamic>{
      'teacher_id': teacherId,
      'chapter_id': chapterId,
      if (subChapterId != null) 'sub_chapter_id': subChapterId,
    };
    AppLogger.debug('subject', 'Check cache params: $queryParams');
    final response = await _aiDio.get(
      '/generated-materials/check-cache',
      queryParameters: queryParams,
    );
    AppLogger.debug(
      'subject',
      'Check cache response: ${response.statusCode} - ${response.data}',
    );
    return _handleAiResponse(response);
  }

  /// List generated materials with filters (fallback when check-cache fails)
  Future<dynamic> listGeneratedMaterials({
    required String teacherId,
    String? subjectId,
    String? chapterId,
  }) async {
    final queryParams = <String, dynamic>{
      'teacher_id': teacherId,
      if (subjectId != null) 'subject_id': subjectId,
      if (chapterId != null) 'chapter_id': chapterId,
    };
    AppLogger.debug('subject', 'List materials params: $queryParams');
    final response = await _aiDio.get(
      '/generated-materials',
      queryParameters: queryParams,
    );
    AppLogger.debug(
      'subject',
      'List materials response: ${response.statusCode}',
    );
    return _handleAiResponse(response);
  }

  /// Regenerate quiz for generated material
  Future<dynamic> regenerateQuiz(String materialId) async {
    final response = await _aiDio.post(
      '/generated-materials/$materialId/regenerate-quiz',
    );
    return _handleAiResponse(response);
  }

  /// Regenerate references for generated material
  Future<dynamic> regenerateReferences(String materialId) async {
    final response = await _aiDio.post(
      '/generated-materials/$materialId/regenerate-reference',
    );
    return _handleAiResponse(response);
  }

  // ==================== RPP REGENERATION METHODS ====================
  // These methods handle AI-powered RPP (lesson plan) field regeneration.
  // Each field can be regenerated up to 2 times (limit enforced server-side).

  /// Regenerate a specific RPP field (Section 5.6)
  /// POST /api/lesson-plans/{id}/regen/{field}
  /// Max 2 regenerations per field.
  /// Returns raw Dio Response so callers can inspect statusCode (200, 202, 429).
  Future<Response<dynamic>> regenLessonPlanFieldRaw(
    String lessonPlanId,
    String field, {
    String? additionalText,
  }) async {
    final body = <String, dynamic>{};
    if (additionalText != null && additionalText.trim().isNotEmpty) {
      body['additional_text'] = additionalText.trim();
    }
    AppLogger.debug(
      'subject',
      'Regen RPP field: /lesson-plans/$lessonPlanId/regen/$field',
    );
    AppLogger.debug('subject', 'Regen RPP body: $body');
    final response = await _aiDio.post(
      '/lesson-plans/$lessonPlanId/regen/$field',
      data: body,
    );
    AppLogger.debug('subject', 'Regen RPP response: ${response.statusCode}');
    return response;
  }

  /// Get RPP regen limits per field (Section 5.7)
  /// GET /api/lesson-plans/{id}/regen-limits
  Future<dynamic> getLessonPlanRegenLimits(String lessonPlanId) async {
    AppLogger.debug(
      'subject',
      'Regen limits: /lesson-plans/$lessonPlanId/regen-limits',
    );
    final response = await _aiDio.get(
      '/lesson-plans/$lessonPlanId/regen-limits',
    );
    AppLogger.debug('subject', 'Regen limits response: ${response.statusCode}');
    // Check for HTML error page from proxy/CDN
    if (response.data is String) {
      final bodyStr = response.data as String;
      if (bodyStr.trimLeft().startsWith('<!DOCTYPE') ||
          bodyStr.trimLeft().startsWith('<html')) {
        throw Exception('Server AI tidak tersedia (${response.statusCode})');
      }
    }
    return _handleAiResponse(response);
  }

  /// Update RPP fields / auto-save (Section 5.5)
  /// PATCH /api/lesson-plans/{id}
  Future<dynamic> updateLessonPlanFields(
    String lessonPlanId,
    Map<String, dynamic> fields,
  ) async {
    final response = await _aiDio.patch(
      '/lesson-plans/$lessonPlanId',
      data: fields,
      options: Options(sendTimeout: const Duration(seconds: 30)),
    );
    return _handleAiResponse(response);
  }

  /// Get RPP detail from AI API (Section 5.4)
  /// GET /api/lesson-plans/{id}
  Future<dynamic> getLessonPlanDetail(String lessonPlanId) async {
    final response = await _aiDio.get('/lesson-plans/$lessonPlanId');
    return _handleAiResponse(response);
  }

  // ==================== MATERI PROGRESS METHODS ====================
  // These methods track which chapters/sub-chapters a teacher has covered
  // and which ones have been AI-generated. Like a todo/checklist system.

  /// Fetches material progress (checked/generated state) for a teacher + subject combo.
  /// Like `MaterialProgress::where('teacher_id', ...)->where('subject_id', ...)->get()`.
  Future<List<dynamic>> getMaterialProgress({
    required String teacherId,
    required String subjectId,
    String? classId,
  }) async {
    String url =
        '/material-progress?teacher_id=$teacherId&subject_id=$subjectId';
    if (classId != null) url += '&class_id=$classId';

    final response = await dioClient.get(url);

    final result = response.data;
    return result is List ? result : [];
  }

  /// Saves or toggles the checked state for a single material progress item.
  /// Like `MaterialProgress::updateOrCreate()` in Laravel.
  Future<dynamic> saveMateriProgress(Map<String, dynamic> data) async {
    final response = await dioClient.post('/material-progress', data: data);
    return response.data;
  }

  /// Batch-saves multiple material progress items at once.
  /// Remaps frontend keys (guru_id, bab_id) to backend keys (teacher_id, chapter_id).
  /// Like a Laravel batch upsert with key remapping middleware.
  Future<dynamic> batchSaveMateriProgress(Map<String, dynamic> data) async {
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

    final response = await dioClient.post(
      '/material-progress/batch',
      data: requestData,
    );
    return response.data;
  }

  /// Marks specific materials as AI-generated (after RPP/activity generation).
  /// Prevents accidental re-generation. Like setting a `generated_at` timestamp.
  Future<dynamic> markMaterialGenerated(Map<String, dynamic> data) async {
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

    final response = await dioClient.post(
      '/material-progress/mark-generated',
      data: requestData,
    );
    return response.data;
  }

  /// Resets the generated status to allow re-generation.
  /// Like clearing the `generated_at` flag so the AI can regenerate content.
  Future<dynamic> resetMaterialGenerated(Map<String, dynamic> data) async {
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

    final response = await dioClient.post(
      '/material-progress/reset-generated',
      data: requestData,
    );
    return response.data;
  }

  Future<Directory?> getExternalStorageDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory;
    } catch (e) {
      return null;
    }
  }
}
