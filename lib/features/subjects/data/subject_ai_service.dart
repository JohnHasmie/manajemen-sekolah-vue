/// AI-powered content generation via KamillLabs Edu AI
/// microservice.
/// Handles material generation, lesson plan (RPP) management,
/// and field-level regeneration.
library;

import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/config/ai_config.dart';
import 'package:manajemensekolah/core/services/secure_storage_service.dart';
import 'package:manajemensekolah/core/router/app_router.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Manages AI-powered generation via separate microservice.
/// Uses a dedicated Dio instance (_aiDio) with:
/// - AI microservice base URL
/// - Auth header injection (Bearer token only)
/// - validateStatus: (_) => true — callers inspect status codes
class SubjectAiService {
  /// Base URL for the AI microservice.
  /// Resolved centrally via [AiConfig] from env / dart-define / fallback.
  String get _aiBaseUrl => AiConfig.baseUrl;

  /// Lazy-initialized Dio for KamillLabs AI API calls.
  /// Does NOT throw on non-2xx so callers can check statusCode
  /// themselves.
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
              // Don't throw on non-2xx
              validateStatus: (_) => true,
            ),
          )
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) async {
                final secureStorage = SecureStorageService();
                final token = await secureStorage.getToken();
                if (token != null) {
                  options.headers['Authorization'] = 'Bearer $token';
                }
                handler.next(options);
              },
              onResponse: (response, handler) async {
                if (response.statusCode == 401) {
                  AppLogger.error('ai', 'AI API returned 401. Forcing logout.');
                  try {
                    await SecureStorageService().clearAll();
                    await PreferencesService().clear();
                    appRouter.go('/login');
                  } catch (_) {}
                }
                handler.next(response);
              },
            ),
          );
    return _aiDioInstance!;
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

  /// Generate a lesson plan via kamiledu-ai backend.
  /// POST /lesson-plans/generate
  /// Returns generated lesson plan data (201) or job info (202).
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

  /// Generates material. Returns raw Response so callers can
  /// inspect statusCode (202, 429, etc.).
  Future<Response<dynamic>> generateMaterialRaw(
    Map<String, dynamic> data,
  ) async {
    final response = await _aiDio.post(
      '/generated-materials/generate',
      data: data,
    );
    return response;
  }

  /// Generates material and parses response. Throws on non-2xx.
  Future<dynamic> generateMaterial(Map<String, dynamic> data) async {
    final response = await generateMaterialRaw(data);
    return _handleAiResponse(response);
  }

  /// Poll AI job status from KamillLabs Edu AI.
  /// Returns raw Response so callers can inspect statusCode.
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

  /// Get generated material by ID from KamillLabs Edu AI.
  /// Pass [classId] to get class-specific quiz variants.
  Future<dynamic> getGeneratedMaterial(
    String materialId, {
    String? classId,
  }) async {
    AppLogger.debug(
      'subject',
      'Getting material: $_aiBaseUrl/generated-materials/$materialId '
          '(classId=$classId)',
    );
    final params = <String, dynamic>{};
    if (classId != null) params['class_id'] = classId;
    final response = await _aiDio.get(
      '/generated-materials/$materialId',
      queryParameters: params,
    );
    AppLogger.debug('subject', 'Get material response: ${response.statusCode}');
    return _handleAiResponse(response);
  }

  /// Clone shared quizzes to a specific class.
  /// POST /generated-materials/{id}/clone-quiz
  Future<dynamic> cloneQuizForClass(String materialId, String classId) async {
    final response = await _aiDio.post(
      '/generated-materials/$materialId/clone-quiz',
      data: {'class_id': classId},
    );
    return _handleAiResponse(response);
  }

  /// Check cache for generated material.
  ///
  /// [teacherId] is optional: when omitted, the backend performs a
  /// teacher-agnostic lookup scoped by (chapter_id, sub_chapter_id) and
  /// returns the most recently generated material for that sub-chapter.
  /// This path exists so the re-open flow works even when the client's
  /// teacher_id drifts between mounts (teacherProfileId lazy-loads from
  /// Riverpod; the pre-load fallback resolves to a different UUID).
  /// The backend requires at least one of [teacherId] or [subChapterId]
  /// to be present.
  Future<dynamic> checkMaterialCache({
    String? teacherId,
    required String chapterId,
    String? subChapterId,
  }) async {
    final queryParams = <String, dynamic>{
      if (teacherId != null) 'teacher_id': teacherId,
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

  /// List generated materials with filters (fallback when
  /// check-cache fails)
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

  /// Regenerate ONLY material content (keeps quiz + refs).
  Future<dynamic> regenerateMaterialContent(String materialId) async {
    final response = await _aiDio.post(
      '/generated-materials/$materialId/regenerate-material',
    );
    return _handleAiResponse(response);
  }

  /// Regenerate quiz for generated material. Returns raw
  /// Response for 202 handling.
  Future<Response<dynamic>> regenerateQuizRaw(String materialId) async {
    return await _aiDio.post(
      '/generated-materials/$materialId/regenerate-quiz',
    );
  }

  /// Regenerate references for generated material. Returns raw
  /// Response for 202 handling.
  Future<Response<dynamic>> regenerateReferencesRaw(String materialId) async {
    return await _aiDio.post(
      '/generated-materials/$materialId/regenerate-reference',
    );
  }

  /// Regenerate a specific RPP field (Section 5.6)
  /// POST /api/lesson-plans/{id}/regen/{field}
  /// Max 2 regenerations per field.
  /// Returns raw Dio Response so callers can inspect statusCode
  /// (200, 202, 429).
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
}
