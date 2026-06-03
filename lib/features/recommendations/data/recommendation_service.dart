/// api_recommendation_services.dart - Interfaces with the AI recommendation
/// engine.
/// Like a Laravel service that calls an external AI microservice / Vue's AI store module.
///
/// This service communicates with a separate AI API (KamillLabs Edu AI), not
/// the main
/// Laravel backend. It handles AI-powered teaching recommendations: generating
/// them
/// (async via job polling), listing, updating status, and getting class
/// summaries.
///
/// Key patterns:
/// - Async job processing: generate returns 202 with a job_id, then poll until
/// done
/// - Rate limiting: 429 responses throw [RateLimitException]
/// - Separate auth headers (no X-School-ID, only Bearer token)
/// - Uses its own Dio instance (_aiDio) instead of dioClient, because the AI
/// API
///   has a different base URL and does not need X-School-ID headers.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:manajemensekolah/core/config/ai_config.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Service for AI-powered teaching recommendation API calls.
/// Talks to a separate microservice (KamillLabs Edu AI), not the main Laravel
/// backend.
/// Like a Laravel service class that uses `Http::baseUrl()` to call an external
/// API,
/// or a Vue composable that wraps a dedicated Axios instance for an AI service.
///
/// Key difference from other services: uses [_aiBaseUrl] instead of the global
/// dioClient,
/// and has its own auth interceptor without X-School-ID.
class ApiRecommendationService {
  /// Base URL for the AI microservice. Separate from the main Laravel API.
  /// Like having a second `API_BASE_URL` in your Laravel `.env` file.
  String get _aiBaseUrl => AiConfig.baseUrl;

  /// Lazily-initialized Dio instance dedicated to the AI microservice.
  /// Configured with Bearer-token-only auth (no X-School-ID).
  Dio? _aiDioInstance;

  /// Returns the AI-specific Dio instance, creating it on first call.
  /// Like a Laravel Http::withOptions() macro for the AI service.
  Dio get _aiDio {
    _aiDioInstance ??=
        Dio(
            BaseOptions(
              baseUrl: _aiBaseUrl,
              connectTimeout: const Duration(seconds: 60),
              receiveTimeout: const Duration(seconds: 60),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ),
          )
          ..interceptors.addAll([
            _AiAuthInterceptor(),
            if (kDebugMode) _AiLoggingInterceptor(),
          ]);
    return _aiDioInstance!;
  }

  // ==================== RECOMMENDATIONS ====================

  /// Generate recommendations for a class
  /// Returns 202 with job_id for async processing, or 200 with data
  Future<Map<String, dynamic>> generateForClass({
    required String teacherId,
    required String classId,
    required String subjectId,
    String? triggerSource,
    bool forceRegenerate = false,
    bool? includeOnTrack,
    String? academicYearId,
  }) async {
    final requestData = {
      'teacher_id': teacherId,
      'class_id': classId,
      'subject_id': subjectId,
      if (triggerSource != null) 'trigger_source': triggerSource,
      if (forceRegenerate) 'force_regenerate': true,
      if (includeOnTrack != null) 'include_on_track': includeOnTrack,
      if (academicYearId != null) 'academic_year_id': academicYearId,
    };

    // Use validateStatus to accept 202 and 429 without throwing
    final response = await _aiDio.post(
      '/recommendations/generate',
      data: requestData,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );

    AppLogger.debug(
      'recommendation',
      'Generate recommendations: ${response.statusCode}',
    );
    AppLogger.info('recommendation', 'Request body sent: $requestData');
    AppLogger.debug('recommendation', 'Response body: ${response.data}');

    final body = response.data;

    if (response.statusCode == 202) {
      // Async processing - return job info
      return {
        'async': true,
        'job_id': body['data']?['job_id'] ?? body['job_id'],
        'poll_url': body['data']?['poll_url'] ?? body['poll_url'],
        'message': body['message'] ?? 'Processing...',
      };
    } else if (response.statusCode == 429) {
      throw RateLimitException(body['message'] ?? 'Rate limit exceeded', body);
    }

    return {'async': false, 'data': body};
  }

  /// Generate recommendations for a single student
  Future<Map<String, dynamic>> generateForStudent({
    required String teacherId,
    required String classId,
    required String subjectId,
    required String studentId,
    bool forceRegenerate = false,
  }) async {
    final response = await _aiDio.post(
      '/recommendations/generate-student',
      data: {
        'teacher_id': teacherId,
        'class_id': classId,
        'subject_id': subjectId,
        'student_id': studentId,
        if (forceRegenerate) 'force_regenerate': true,
      },
      options: Options(validateStatus: (s) => s != null && s < 500),
    );

    AppLogger.debug(
      'recommendation',
      'Generate student recommendation: ${response.statusCode}',
    );

    final body = response.data;

    if (response.statusCode == 202) {
      return {
        'async': true,
        'job_id': body['data']?['job_id'] ?? body['job_id'],
        'poll_url': body['data']?['poll_url'] ?? body['poll_url'],
        'message': body['message'] ?? 'Processing...',
      };
    } else if (response.statusCode == 429) {
      throw RateLimitException(body['message'] ?? 'Rate limit exceeded', body);
    }

    return {'async': false, 'data': body};
  }

  /// List recommendations with filters (paginated).
  ///
  /// Pass exactly one of:
  ///  - [teacherId] — guru view: only the teacher's own authored recs.
  ///  - [homeroomClassId] — wali kelas view: every rec in a homeroom
  ///    class regardless of authoring teacher. Backend uses this to
  ///    switch the scope and 403s if the caller isn't the wali kelas.
  Future<Map<String, dynamic>> getRecommendations({
    String? teacherId,
    String? homeroomClassId,
    String? classId,
    String? studentId,
    String? subjectId,
    String? status,
    String? priority,
    String? category,
    String? academicYearId,
    int page = 1,
    int perPage = 15,
  }) async {
    final params = <String, dynamic>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (academicYearId != null) 'academic_year_id': academicYearId,
    };
    // The backend requires teacher_id XOR homeroom_class_id. Prefer the
    // homeroom scope when both are supplied — the homeroom scope is the
    // cross-teacher view and is what the wali-kelas caller actually wants.
    if (homeroomClassId != null && homeroomClassId.isNotEmpty) {
      params['homeroom_class_id'] = homeroomClassId;
    } else if (teacherId != null && teacherId.isNotEmpty) {
      params['teacher_id'] = teacherId;
    }
    if (classId != null) params['class_id'] = classId;
    if (studentId != null) params['student_id'] = studentId;
    if (subjectId != null) params['subject_id'] = subjectId;
    if (status != null) params['status'] = status;
    if (priority != null) params['priority'] = priority;
    if (category != null) params['category'] = category;

    final response = await _aiDio.get(
      '/recommendations',
      queryParameters: params,
      options: Options(receiveTimeout: const Duration(seconds: 30)),
    );

    AppLogger.debug(
      'recommendation',
      'List recommendations: ${response.statusCode} - '
          'URL: ${response.requestOptions.uri}',
    );
    AppLogger.debug('recommendation', 'Response body: ${response.data}');

    final body = response.data;
    return {'success': true, 'data': body['data'] ?? [], 'meta': body['meta']};
  }

  /// Get recommendation detail
  Future<Map<String, dynamic>> getRecommendationDetail(
    String recommendationId,
  ) async {
    final response = await _aiDio.get(
      '/recommendations/$recommendationId',
      options: Options(receiveTimeout: const Duration(seconds: 30)),
    );

    AppLogger.debug(
      'recommendation',
      'Recommendation detail: ${response.statusCode}',
    );

    return response.data;
  }

  /// Update recommendation status.
  ///
  /// [teacherId] names the teacher performing the update. The backend
  /// runs a two-stage check: (1) `EnsureTeacherOwnership` middleware
  /// verifies this teacher id belongs to the authenticated user; (2) the
  /// action allows the update only if that teacher is either the rec's
  /// author OR the wali kelas of the rec's class.
  Future<Map<String, dynamic>> updateStatus({
    required String recommendationId,
    required String status, // pending, in_progress, completed, dismissed
    required String teacherId,
    String? teacherNotes,
  }) async {
    final response = await _aiDio.patch(
      '/recommendations/$recommendationId/status',
      data: {
        'status': status,
        'teacher_id': teacherId,
        if (teacherNotes != null) 'teacher_notes': teacherNotes,
      },
      options: Options(receiveTimeout: const Duration(seconds: 30)),
    );

    AppLogger.debug('recommendation', 'Update status: ${response.statusCode}');

    return response.data;
  }

  // ==================== SHARE-TO-PARENT ====================

  /// Bagikan ke Wali — fan out a recommendation to one or more parents.
  ///
  /// Backend rejects (422) if the rec is still `pending` or
  /// `dismissed`. Returns the updated recommendation with
  /// `share_recipients` eager-loaded so the card can refresh
  /// in-place without another round-trip.
  Future<Map<String, dynamic>> shareRecommendation({
    required String recommendationId,
    required String teacherId,
    required List<Map<String, dynamic>> parents,
    String? message,
    String? tone,
    bool channelPush = true,
    bool channelWhatsapp = false,
  }) async {
    final response = await _aiDio.post(
      '/recommendations/$recommendationId/share',
      data: {
        'teacher_id': teacherId,
        'parents': parents,
        if (message != null) 'message': message,
        if (tone != null) 'tone': tone,
        'channels': {'push': channelPush, 'whatsapp': channelWhatsapp},
      },
      options: Options(validateStatus: (s) => s != null && s < 500),
    );

    AppLogger.debug(
      'recommendation',
      'Share rec $recommendationId: ${response.statusCode}',
    );

    if (response.statusCode == 403 || response.statusCode == 422) {
      throw Exception(
        response.data?['message']?.toString() ??
            'Gagal membagikan rekomendasi.',
      );
    }
    return response.data as Map<String, dynamic>;
  }

  /// Riwayat Pengiriman — per-recipient timeline with sent/read/replied stamps.
  Future<Map<String, dynamic>> getShareStatus(String recommendationId) async {
    final response = await _aiDio.get(
      '/recommendations/$recommendationId/share-status',
    );
    return response.data as Map<String, dynamic>;
  }

  /// Ingatkan Ulang — re-stamp sent_at for one recipient + bump resend.
  Future<Map<String, dynamic>> remindRecipient({
    required String recommendationId,
    required String recipientId,
  }) async {
    final response = await _aiDio.post(
      '/recommendations/$recommendationId/share/$recipientId/remind',
    );
    return response.data as Map<String, dynamic>;
  }

  /// Tarik Pesan — flag a recipient as revoked.
  Future<Map<String, dynamic>> revokeRecipient({
    required String recommendationId,
    required String recipientId,
    String? reason,
  }) async {
    final response = await _aiDio.post(
      '/recommendations/$recommendationId/share/$recipientId/revoke',
      data: {if (reason != null) 'reason': reason},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Edit & Kirim Ulang — patch the rec's shared_message/tone and
  /// re-stamp this recipient's sent_at without losing read state.
  Future<Map<String, dynamic>> editAndResendRecipient({
    required String recommendationId,
    required String recipientId,
    String? message,
    String? tone,
  }) async {
    final response = await _aiDio.patch(
      '/recommendations/$recommendationId/share/$recipientId',
      data: {
        if (message != null) 'message': message,
        if (tone != null) 'tone': tone,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Parent app: flip read_at on the recipient row when the parent
  /// opens the rec card. Idempotent — backend no-ops when read_at is
  /// already set.
  Future<void> markRecommendationRead({
    required String recommendationId,
    required String parentUserId,
  }) async {
    await _aiDio.post(
      '/recommendations/$recommendationId/share/mark-read',
      data: {'parent_user_id': parentUserId},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
  }

  /// Fetch one recommendation by id. Returns the hydrated JSON map
  /// (with `student`, `class_`, `subject`, etc. eager-loaded by the
  /// backend repository). Throws on non-2xx — callers handle UX.
  ///
  /// Used by the teacher dashboard priority inbox to resolve a bare
  /// `recommendation_id` from `target_params` into the full
  /// `(student, classData)` shape that `LearningRecommendationResultScreen`
  /// requires.
  Future<Map<String, dynamic>> getRecommendationById(String id) async {
    final response = await _aiDio.get('/recommendations/$id');
    final body = response.data;
    if (body is Map<String, dynamic> && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    throw Exception('Unexpected response shape for /recommendations/$id');
  }

  /// Teacher app: flip `teacher_seen_at` on every share recipient of
  /// the rec the wali kelas just opened. Drives Signal E (parent
  /// reply unread) on the priority inbox — once seen, the dashboard
  /// stops surfacing the same reply on every refresh.
  ///
  /// Fire-and-forget by design: the call is made on rec-detail open
  /// and a failure should never block the screen from rendering. We
  /// swallow non-2xx responses and log them via Dio's interceptor
  /// stack; the inbox auto-corrects on the next composer run anyway.
  Future<void> markRecommendationSharesSeenByTeacher({
    required String recommendationId,
  }) async {
    try {
      await _aiDio.post(
        '/recommendations/$recommendationId/mark-shares-seen',
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
    } catch (_) {
      // Transparent — the inbox will re-fire next refresh if it
      // matters. No UI affordance / snackbar.
    }
  }

  /// Parent reply — stamps replied_at + reply_text on the recipient row.
  Future<Map<String, dynamic>> replyToRecommendation({
    required String recommendationId,
    required String parentUserId,
    required String replyText,
  }) async {
    final response = await _aiDio.post(
      '/recommendations/$recommendationId/share/reply',
      data: {'parent_user_id': parentUserId, 'reply_text': replyText},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Parent inbox — recommendations shared with the authenticated wali.
  ///
  /// Cached locally for **5 minutes** (`useCache: true` by default) so
  /// the screen feels instant on tab-switches and quick re-opens.
  /// Pass `useCache: false` from a pull-to-refresh / reply / tandai
  /// selesai handler to force a fresh fetch — the screen invalidates
  /// the cache and re-saves with the updated rows.
  Future<List<dynamic>> getParentInbox({
    required String parentUserId,
    String? studentId,
    bool unreadOnly = false,
    bool useCache = true,
  }) async {
    final cacheKey = _parentInboxCacheKey(
      parentUserId: parentUserId,
      studentId: studentId,
      unreadOnly: unreadOnly,
    );

    if (useCache) {
      final cached = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(minutes: 5),
      );
      if (cached is List) return cached;
    }

    final response = await _aiDio.get(
      '/recommendations/parent-inbox',
      queryParameters: {
        'parent_user_id': parentUserId,
        if (studentId != null) 'student_id': studentId,
        if (unreadOnly) 'unread_only': 'true',
      },
    );
    final rows = (response.data?['data'] as List?) ?? const <dynamic>[];
    // Best-effort cache write — failures are logged but don't sink
    // the response.
    await LocalCacheService.save(cacheKey, rows);
    return rows;
  }

  /// Invalidate every cached `getParentInbox` variant for a given
  /// parent (Semua / per-child / unread-only). Called from the screen
  /// after reply / tandai selesai so the next fetch is fresh.
  Future<void> invalidateParentInboxCache({
    required String parentUserId,
  }) async {
    await LocalCacheService.clearStartingWith('parent_inbox_$parentUserId');
    await LocalCacheService.clearStartingWith('parent_summary_$parentUserId');
  }

  String _parentInboxCacheKey({
    required String parentUserId,
    String? studentId,
    required bool unreadOnly,
  }) {
    return 'parent_inbox_${parentUserId}_${studentId ?? 'all'}'
        '_${unreadOnly ? 'u' : 'a'}';
  }

  /// Per-child summary used by the parent multi-child hub (Frame A).
  /// Returns `{ children: [...], totals: {...} }` — one card per child
  /// with counts for total / unread / replied / completed / high
  /// priority + the most recent send timestamp.
  ///
  /// Cached for 5 minutes so the multi-child hub doesn't re-fetch on
  /// every back-navigation.
  Future<Map<String, dynamic>> getParentSummary({
    required String parentUserId,
    bool useCache = true,
  }) async {
    final cacheKey = 'parent_summary_${parentUserId}_v1';

    if (useCache) {
      final cached = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(minutes: 5),
      );
      if (cached is Map) return Map<String, dynamic>.from(cached);
    }

    final response = await _aiDio.get(
      '/recommendations/parent-summary',
      queryParameters: {'parent_user_id': parentUserId},
    );
    final data = response.data?['data'];
    final result = data is Map<String, dynamic>
        ? data
        : <String, dynamic>{'children': const [], 'totals': const {}};
    await LocalCacheService.save(cacheKey, result);
    return result;
  }

  /// Parent confirmation that a shared rec was applied at home —
  /// stamps `parent_completed_at` on the recipient row and (when
  /// [notifyTeacher] is true) flips the rec's status to `completed`
  /// so the wali kelas's hub also reflects it.
  Future<Map<String, dynamic>> markRecommendationCompletedByParent({
    required String recommendationId,
    required String parentUserId,
    String? note,
    bool notifyTeacher = true,
  }) async {
    final response = await _aiDio.post(
      '/recommendations/$recommendationId/share/mark-completed-by-parent',
      data: {
        'parent_user_id': parentUserId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'notify_teacher': notifyTeacher,
      },
    );
    final body = response.data;
    if (body is Map<String, dynamic>) return body;
    return <String, dynamic>{};
  }

  // ==================== CLASS SUMMARY ====================

  /// Get class summary (aggregated recommendations by category/priority/status)
  Future<Map<String, dynamic>> getClassSummary(
    String classId, {
    String? academicYearId,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (academicYearId != null) {
        params['academic_year_id'] = academicYearId;
      }
      final response = await _aiDio.get(
        '/recommendations/class/$classId/summary',
        queryParameters: params.isNotEmpty ? params : null,
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );

      AppLogger.debug(
        'recommendation',
        'Class summary: ${response.statusCode} - ${response.data}',
      );

      return response.data;
    } catch (e) {
      AppLogger.error('recommendation', e);
      // Return empty summary on error (class may have no recommendations yet)
      return {
        'success': true,
        'data': {
          'total_recommendations': 0,
          'by_status': {},
          'by_priority': {},
          'by_category': {},
        },
      };
    }
  }

  /// Get per-student recommendation status counts for a class.
  /// Returns a Map keyed by student_id with { total, pending, completed }
  /// counts.
  /// Paginates through all pages (backend max per_page is 50).
  ///
  /// Pass [homeroomClassId] (not [teacherId]) when the caller is the wali
  /// kelas — the counts then cover recs from ALL authoring teachers in
  /// that homeroom, which is what the wali-kelas dashboard wants to show.
  Future<Map<String, Map<String, int>>> getStudentStatusCounts({
    required String classId,
    String? teacherId,
    String? homeroomClassId,
    String? academicYearId,
  }) async {
    try {
      final allData = <dynamic>[];
      int page = 1;
      const perPage = 50;

      // Fetch all pages
      while (true) {
        final result = await getRecommendations(
          classId: classId,
          teacherId: teacherId,
          homeroomClassId: homeroomClassId,
          academicYearId: academicYearId,
          perPage: perPage,
          page: page,
        );

        final data = result['data'] as List? ?? [];
        allData.addAll(data);

        // Check if there are more pages
        final meta = result['meta'] as Map?;
        final lastPage = meta?['last_page'] ?? 1;
        if (page >=
            (lastPage is int
                ? lastPage
                : int.tryParse(lastPage.toString()) ?? 1)) {
          break;
        }
        page++;
      }

      final counts = <String, Map<String, int>>{};

      for (final rec in allData) {
        final studentId = rec['student_id']?.toString() ?? '';
        if (studentId.isEmpty) continue;

        final status = rec['status']?.toString().toLowerCase() ?? 'pending';
        counts.putIfAbsent(
          studentId,
          () => {'total': 0, 'pending': 0, 'completed': 0},
        );
        counts[studentId]!['total'] = (counts[studentId]!['total'] ?? 0) + 1;
        if (status == 'completed') {
          counts[studentId]!['completed'] =
              (counts[studentId]!['completed'] ?? 0) + 1;
        } else {
          counts[studentId]!['pending'] =
              (counts[studentId]!['pending'] ?? 0) + 1;
        }
      }

      return counts;
    } catch (e) {
      AppLogger.error('recommendation', 'getStudentStatusCounts error: $e');
      return {};
    }
  }

  // ==================== AI JOB POLLING ====================

  /// Poll an AI job until completion
  /// Returns the completed job data or throws on failure
  Future<Map<String, dynamic>> pollJobUntilComplete(
    String jobId, {
    Duration interval = const Duration(seconds: 5),
    int maxAttempts = 60,
    void Function(String status, int attempt)? onProgress,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _aiDio.get(
          '/ai-jobs/$jobId',
          options: Options(receiveTimeout: const Duration(seconds: 15)),
        );

        AppLogger.debug(
          'recommendation',
          'Poll attempt $attempt: ${response.statusCode} - ${response.data}',
        );

        if (response.statusCode == 200) {
          final body = response.data;
          final data = body['data'] ?? body;
          final status = data['status']?.toString().toLowerCase() ?? '';

          AppLogger.error(
            'recommendation',
            'Job $jobId: status=$status, '
                'progress=${data['progress'] ?? 'N/A'}, '
                'error=${data['error'] ?? 'none'}',
          );

          onProgress?.call(status, attempt);

          if (status == 'completed' || status == 'done') {
            return data;
          } else if (status == 'failed' || status == 'error') {
            throw Exception(data['error'] ?? 'AI job failed');
          }
          // still processing - wait and retry
        }
      } catch (e) {
        if (e is DioException) {
          AppLogger.error(
            'recommendation',
            '️ Poll error: ${e.response?.statusCode ?? 'N/A'} - ${e.message}',
          );
          // Don't rethrow DioException for polling - just retry
        } else {
          // Rethrow non-Dio exceptions (e.g., job failed)
          rethrow;
        }
      }

      if (attempt < maxAttempts) {
        await Future.delayed(interval);
      }
    }

    throw TimeoutException('AI job timed out after $maxAttempts attempts');
  }
}

/// Auth interceptor for the AI microservice.
/// Only injects Bearer token (no X-School-ID), since the AI service
/// doesn't use multi-tenant school headers.
class _AiAuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final prefs = PreferencesService();
      final token = prefs.getString('token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Continue without auth if SharedPreferences fails
    }
    handler.next(options);
  }
}

/// Debug logging interceptor for AI API calls.
class _AiLoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.debug('recommendation', 'AI ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.error(
      'recommendation',
      'AI Error ${err.response?.statusCode ?? 'N/A'} '
          '${err.requestOptions.uri}: ${err.message}',
    );
    // Dump the raw response body for 500-class errors. The AI service
    // renders Throwable as JSON in APP_DEBUG=true (see
    // edu_ai_api/bootstrap/app.php), and the body carries the exact
    // exception class + file:line + trace — without this log line
    // it's invisible because Dio throws on the status before the
    // caller can read it.
    final code = err.response?.statusCode ?? 0;
    if (code >= 500 && err.response?.data != null) {
      AppLogger.error('recommendation', 'AI 500 body: ${err.response!.data}');
    }
    handler.next(err);
  }
}

/// Custom exception for HTTP 429 (Too Many Requests) responses.
/// Like Laravel's `ThrottleRequestsException` -- carries the response body
/// so the UI can display retry information or cooldown timers.
class RateLimitException implements Exception {
  final String message;
  final Map<String, dynamic>? body;

  RateLimitException(this.message, [this.body]);

  @override
  String toString() => message;
}
