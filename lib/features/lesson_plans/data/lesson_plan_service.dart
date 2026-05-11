import 'dart:io';
import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/config/ai_config.dart';
import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/cache_invalidation_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

class LessonPlanService {
  // ── Backend query-parameter keys ─────────────────────────────────────────
  // The server uses these exact strings. English snake_case is used wherever
  // the backend accepts it. The keys below are Indonesian because the server
  // contract uses them and a backend change is not currently possible.
  static const _kFilterSubjectId =
      'mataPelajaranId'; // subject filter on RPP endpoint
  static const _kAcademicYear =
      'tahun_ajaran'; // free-text year e.g. "2023/2024"
  static const _kDateRangeStart = 'tanggalStart';
  static const _kDateRangeEnd = 'tanggalEnd';
  // ─────────────────────────────────────────────────────────────────────────
  /// Fetches RPP (lesson plans) with optional filters.
  static Future<List<dynamic>> getLessonPlans({
    String? teacherId,
    String? status,
    String? search,
    String? academicYearId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (teacherId != null) queryParams['teacher_id'] = teacherId;
    if (status != null) queryParams['status'] = status;
    if (search != null) queryParams['search'] = search;
    if (academicYearId != null) {
      queryParams['academic_year_id'] = academicYearId;
    }

    final response = await dioClient.get(
      ApiEndpoints.lessonPlans,
      queryParameters: queryParams,
    );

    final result = response.data;

    if (result is Map && result.containsKey('data')) {
      return result['data'] is List ? result['data'] : [];
    }

    return result is List ? result : [];
  }

  /// Get a single RPP by its ID.
  static Future<Map<String, dynamic>> getLessonPlanById(String id) async {
    final response = await dioClient.get('/rpp/$id');
    final result = response.data;
    if (result is Map<String, dynamic>) {
      // Unwrap { success, data } envelope if present
      final data = result['data'];
      if (data is Map<String, dynamic>) return data;
      return result;
    }
    return {};
  }

  // Get RPP with pagination & filters (recommended)
  static Future<Map<String, dynamic>> getLessonPlansPaginated({
    int page = 1,
    int limit = 10,
    String? teacherId,
    String? status,
    String? search,
    String? subjectId,
    String? classId,
    String? semester,
    String? academicYear,
    String? dateStart,
    String? dateEnd,
    String? academicYearId,
    String? filterSubjectId,
    String? date,
    // Format axis filter — multi-select. Sent as comma-separated to
    // the backend's `formats` query param (matches the new
    // `LessonPlan::scopeOfFormat` scope). Empty list ↔ no filter.
    List<String>? formats,
    // AI vs Manual filter. Accepts 'ai', 'manual', or null = no filter.
    String? method,
  }) async {
    final Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (teacherId != null && teacherId.isNotEmpty) {
      queryParams['teacher_id'] = teacherId;
    }
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (subjectId != null && subjectId.isNotEmpty) {
      queryParams['subject_id'] = subjectId;
    }
    if (filterSubjectId != null && filterSubjectId.isNotEmpty) {
      queryParams[_kFilterSubjectId] = filterSubjectId;
    }
    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }
    if (date != null && date.isNotEmpty) queryParams['date'] = date;
    if (dateStart != null && dateStart.isNotEmpty) {
      queryParams[_kDateRangeStart] = dateStart;
    }
    if (dateEnd != null && dateEnd.isNotEmpty) {
      queryParams[_kDateRangeEnd] = dateEnd;
    }
    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }
    if (semester != null && semester.isNotEmpty) {
      queryParams['semester'] = semester;
    }
    if (academicYear != null && academicYear.isNotEmpty) {
      queryParams[_kAcademicYear] = academicYear;
    }
    if (formats != null && formats.isNotEmpty) {
      queryParams['formats'] = formats.join(',');
    }
    if (method != null && method.isNotEmpty) {
      queryParams['method'] = method;
    }

    final response = await dioClient.get(
      ApiEndpoints.lessonPlans,
      queryParameters: queryParams,
    );

    final result = response.data;

    if (result is Map<String, dynamic>) return result;

    // fallback
    return {
      'success': true,
      'data': result is List ? result : [],
      'pagination': {
        'total_items': result is List ? result.length : 0,
        'total_pages': 1,
        'current_page': page,
        'per_page': limit,
        'has_next_page': false,
        'has_prev_page': false,
      },
    };
  }

  /// Fetches RPP summary grouped by subject with status counts, plus
  /// the KPI aggregates the list-screen overlap card needs.
  ///
  /// Returns a record with both pieces:
  ///   • `groups` — list of `{ subject_id, subject_name, total, statuses }`
  ///     used by the existing summary view.
  ///   • `kpi`    — `{ weekly, monthly, open, ai, approved, rejected, total }`
  ///     used by the brand header KPI overlay. Server-computed, so the
  ///     counts don't shift when the visible page paginates.
  ///
  /// Older callers can still grab `groups` with [getLessonPlanSummary]
  /// for backwards-compatibility.
  static Future<({List<Map<String, dynamic>> groups, Map<String, int> kpi})>
  getLessonPlanSummaryWithKpi({
    String? teacherId,
    String? academicYearId,
    String? status,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{};
    if (teacherId != null) queryParams['teacher_id'] = teacherId;
    if (academicYearId != null) {
      queryParams['academic_year_id'] = academicYearId;
    }
    if (status != null) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await dioClient.get(
      '/rpp/summary',
      queryParameters: queryParams,
    );
    final result = response.data;
    final groups = <Map<String, dynamic>>[];
    final kpi = <String, int>{};
    if (result is Map<String, dynamic>) {
      final data = result['data'];
      if (data is List) {
        groups.addAll(data.cast<Map<String, dynamic>>());
      }
      final raw = result['kpi'];
      if (raw is Map) {
        for (final entry in raw.entries) {
          final v = entry.value;
          if (v is int) {
            kpi[entry.key.toString()] = v;
          } else if (v is num) {
            kpi[entry.key.toString()] = v.toInt();
          } else if (v is String) {
            kpi[entry.key.toString()] = int.tryParse(v) ?? 0;
          }
        }
      }
    }
    return (groups: groups, kpi: kpi);
  }

  /// Backwards-compat — returns just the per-subject groups.
  static Future<List<Map<String, dynamic>>> getLessonPlanSummary({
    String? teacherId,
    String? academicYearId,
    String? status,
    String? search,
  }) async {
    final result = await getLessonPlanSummaryWithKpi(
      teacherId: teacherId,
      academicYearId: academicYearId,
      status: status,
      search: search,
    );
    return result.groups;
  }

  static Future<dynamic> createLessonPlan(Map<String, dynamic> data) async {
    final response = await dioClient.post(ApiEndpoints.lessonPlans, data: data);
    await CacheInvalidationService.onLessonPlanChanged();
    return response.data;
  }

  static Future<dynamic> updateLessonPlan(
    String lessonPlanId,
    Map<String, dynamic> data,
  ) async {
    final response = await dioClient.put('/rpp/$lessonPlanId', data: data);
    await CacheInvalidationService.onLessonPlanChanged();
    return response.data;
  }

  static Future<dynamic> updateLessonPlanStatus(
    String lessonPlanId,
    String status, {
    String? catatan,
  }) async {
    final response = await dioClient.put(
      '/rpp/$lessonPlanId/status',
      data: {'status': status, 'catatan': catatan},
    );
    await CacheInvalidationService.onLessonPlanChanged();
    return response.data;
  }

  static Future<dynamic> deleteLessonPlan(String lessonPlanId) async {
    final response = await dioClient.delete('/rpp/$lessonPlanId');
    await CacheInvalidationService.onLessonPlanChanged();
    return response.data;
  }

  /// Upload a PDF/DOCX file to the RPP storage area.
  ///
  /// Returns the upload metadata: {file_path, file_url, file_name,
  /// file_size, file_mime}. The caller then passes file_path/file_name/
  /// file_size/file_mime to [createLessonPlan] together with
  /// `format: 'file'` to materialize the lesson_plans row.
  static Future<Map<String, dynamic>> uploadLessonPlanFile(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await dioClient.post(
        ApiEndpoints.uploadLessonPlan,
        data: formData,
      );

      AppLogger.debug('api', 'Upload Response Status: ${response.statusCode}');
      AppLogger.debug('api', 'Upload Response Data: ${response.data}');

      // Don't invalidate cache here — the lesson_plans row hasn't been
      // created yet. Cache invalidation happens in createLessonPlan().
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw Exception('Unexpected upload response shape: $data');
    } catch (e) {
      AppLogger.error('api', 'Upload error details: $e');
      throw Exception('Upload error: $e');
    }
  }

  /// Create a `format=file` lesson plan from a previously uploaded file.
  /// Convenience wrapper that combines upload metadata + classroom
  /// metadata into the create payload.
  static Future<dynamic> createFileFormatLessonPlan({
    required String teacherId,
    required String subjectId,
    String? classId,
    required String title,
    required Map<String, dynamic> uploadResponse,
    String? semester,
    String? academicYear,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'teacher_id': teacherId,
      'subject_id': subjectId,
      'class_id': classId,
      'title': title,
      'format': 'file',
      'file_path': uploadResponse['file_path'],
      'file_name': uploadResponse['file_name'],
      'file_size': uploadResponse['file_size'],
      'file_mime': uploadResponse['file_mime'],
      'status': 'draft',
    };
    if (semester != null && semester.isNotEmpty) body['semester'] = semester;
    if (academicYear != null && academicYear.isNotEmpty) {
      body['academic_year'] = academicYear;
    }
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;

    return createLessonPlan(body);
  }

  /// Generate an AI lesson plan with format dispatch.
  ///
  /// `format` is one of `k13` / `rpp_1_halaman` / `modul_ajar`. The
  /// `file` format is rejected at the backend Form Request — uploads
  /// use [uploadLessonPlanFile] + [createFileFormatLessonPlan].
  ///
  /// **Important**: this endpoint lives on the AI backend (kamiledu-ai),
  /// NOT the core Laravel backend that `dioClient` is configured for.
  /// We build a one-off Dio instance with `AiConfig.baseUrl` + the
  /// teacher's bearer token — same pattern as the legacy
  /// `GenerateLessonPlanApiMixin.callAiGenerationApi`.
  ///
  /// Returns the response body (Map). Caller is responsible for
  /// async-mode polling when the AI backend returns 202 Accepted.
  static Future<Map<String, dynamic>> generateLessonPlan({
    required String teacherId,
    required String subjectId,
    required String classId,
    required String chapterId,
    String? subChapterId,
    String? timeAllocation,
    String format = 'k13',
    String? extraContext,
  }) async {
    final body = <String, dynamic>{
      'teacher_id': teacherId,
      'subject_id': subjectId,
      'class_id': classId,
      'chapter_id': chapterId,
      'format': format,
    };
    if (subChapterId != null && subChapterId.isNotEmpty) {
      body['sub_chapter_id'] = subChapterId;
    }
    if (timeAllocation != null && timeAllocation.isNotEmpty) {
      body['time_allocation'] = timeAllocation;
    }
    if (extraContext != null && extraContext.isNotEmpty) {
      body['extra_context'] = extraContext;
    }

    final token = PreferencesService().getString('token') ?? '';
    final aiDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 120),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        validateStatus: (_) => true,
      ),
    );

    final response = await aiDio.post(
      '${AiConfig.baseUrl}/lesson-plans/generate',
      data: body,
    );

    AppLogger.debug(
      'lesson_plan',
      '🤖 generate ${response.statusCode}: ${response.data}',
    );

    final data = response.data;
    final result = data is Map<String, dynamic>
        ? data
        : <String, dynamic>{'raw': data};

    // 429 — rate limit. Surface the backend's message.
    if (response.statusCode == 429) {
      throw Exception(
        result['message']?.toString() ??
            'Batas pembuatan RPP harian/bulanan telah tercapai.',
      );
    }

    // 202 — async mode. The AI backend has dispatched a queue job.
    // The response carries `job_id` + `poll_url`. Caller should
    // either poll (production) or surface the pending state. For
    // the sync-style setup sheet flow we treat this as success and
    // return the response so the UI can show "RPP sedang diproses…".
    if (response.statusCode == 202) {
      return result;
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(result['message']?.toString() ?? 'Gagal generate RPP');
    }

    await CacheInvalidationService.onLessonPlanChanged();
    return result;
  }
}
