/// class_activity_metadata_helper.dart - Metadata operations for class
/// activities (schedules, students, filters, health check).
library;

import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Helper class for metadata operations: schedules, students, filters,
/// summary, and health checks.
class MetadataHelper {
  /// Fetches activities grouped by class+subject with pagination.
  /// When [includeContext] is true, the backend also returns
  /// `homeroom_classes`, `schedules`, and `class_list` in a single call.
  /// Results are cached with a 5-minute TTL when [includeContext] is true.
  /// Returns {'data': [...], 'pagination': {...}} or
  /// {'data': [], 'pagination': null}.
  /// Returns the cache key for teacher activity summary, or null if not cacheable.
  static String? buildSummaryCacheKey({
    String? teacherId,
    String? classId,
    String? subjectId,
    String? search,
    String? dateFilter,
    int page = 1,
    bool includeContext = false,
  }) {
    final isCacheable = includeContext &&
        page == 1 &&
        classId == null &&
        subjectId == null &&
        (search == null || search.isEmpty) &&
        dateFilter == null;
    return isCacheable ? 'activity_teacher_summary_$teacherId' : null;
  }

  /// Loads cached summary data if available. Returns null on miss.
  static Future<Map<String, dynamic>?> loadCachedSummary(
    String cacheKey,
  ) async {
    final cached = await LocalCacheService.load(
      cacheKey,
      ttl: const Duration(minutes: 5),
    );
    if (cached != null && cached is Map) {
      AppLogger.debug(
        'class_activity',
        'Teacher activity summary loaded from cache',
      );
      return Map<String, dynamic>.from(cached);
    }
    return null;
  }

  Future<Map<String, dynamic>> getTeacherActivitySummary({
    String? teacherId,
    String? academicYearId,
    String? classId,
    String? subjectId,
    String? search,
    String? dateFilter,
    int page = 1,
    int perPage = 20,
    bool includeContext = false,
    String? view,
  }) async {
    final cacheKey = buildSummaryCacheKey(
      teacherId: teacherId,
      classId: classId,
      subjectId: subjectId,
      search: search,
      dateFilter: dateFilter,
      page: page,
      includeContext: includeContext,
    );
    final useCache = cacheKey != null;

    try {
      final params = <String, dynamic>{'page': page, 'per_page': perPage};
      if (teacherId != null) params['teacher_id'] = teacherId;
      if (academicYearId != null) {
        params['academic_year_id'] = academicYearId;
      }
      if (classId != null) params['class_id'] = classId;
      if (subjectId != null) params['subject_id'] = subjectId;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (dateFilter != null) params['date_filter'] = dateFilter;
      if (includeContext) params['include_context'] = '1';
      // Tells the backend to group by (class, subject, teacher) and emit
      // teacher_id/teacher_name on each card so the homeroom teacher can
      // see who recorded each activity. 'mengajar' (or omitted) keeps the
      // legacy (class, subject) shape.
      if (view != null) params['view'] = view;

      final response = await dioClient.get(
        '/class-activities/teacher-summary',
        queryParameters: params,
      );

      final result = response.data;
      if (result is Map<String, dynamic>) {
        final parsed = <String, dynamic>{
          'data': (result['data'] as List?) ?? [],
          'pagination': result['pagination'],
        };
        // Pass through context fields when present
        if (result.containsKey('homeroom_classes')) {
          parsed['homeroom_classes'] = result['homeroom_classes'];
        }
        if (result.containsKey('schedules')) {
          parsed['schedules'] = result['schedules'];
        }
        if (result.containsKey('class_list')) {
          parsed['class_list'] = result['class_list'];
        }

        if (useCache) {
          await LocalCacheService.save(cacheKey, parsed);
        }
        return parsed;
      }
      return {'data': [], 'pagination': null};
    } catch (e) {
      AppLogger.error(
        'class_activity',
        'Error getting teacher activity summary: $e',
      );
      return {'data': [], 'pagination': null};
    }
  }

  /// Clears the cached teacher activity summary so the next load is fresh.
  static Future<void> clearSummaryCache(String teacherId) async {
    await LocalCacheService.clearStartingWith(
      'activity_teacher_summary_$teacherId',
    );
  }

  /// Fetches the teacher's schedule to populate form dropdowns.
  /// Like loading relationship data for a Laravel form.
  /// Used to show which class/subject/day options are available when
  /// creating activities.
  Future<List<dynamic>> getScheduleForForm({
    required String teacherId,
    String? day,
    String? academicYear,
  }) async {
    try {
      final params = <String, String>{};
      if (day != null && day != 'Semua Hari') params['day'] = day;
      if (academicYear != null) params['academic_year'] = academicYear;

      String url = '/schedule/teacher/$teacherId';
      if (params.isNotEmpty) {
        final qs = Uri(queryParameters: params).query;
        url += '?$qs';
      }

      final response = await dioClient.get(url);
      return _extractData(response.data);
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }

  /// Fetches students belonging to a specific class.
  /// Like `Student::where('class_id', $classId)->get()` in Laravel.
  /// Used to select which students an activity targets.
  Future<List<dynamic>> getStudentsByClass(String classId) async {
    try {
      final response = await dioClient.get('/student/class/$classId');

      AppLogger.debug(
        'class_activity',
        'API Response Status: ${response.statusCode}',
      );
      AppLogger.debug('class_activity', 'API Response Body: ${response.data}');

      return _extractData(response.data);
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }

  /// Tests API connectivity by hitting the health endpoint.
  /// Like Laravel's `/api/health` route. Useful for debugging connection
  /// issues.
  Future<dynamic> testConnection() async {
    try {
      final response = await dioClient.get('/health');
      return response.data;
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }

  /// Fetches filter dropdown options for the activity list screen.
  /// Like a Laravel endpoint returning distinct values for filter selects.
  /// Similar to a Vue composable that loads filter metadata on mount.
  Future<Map<String, dynamic>> getActivityFilterOptions({
    String? teacherId,
    String? classId,
    String? date,
    String? month,
    String? year,
    String? subjectId,
  }) async {
    try {
      final params = <String, String>{};
      _addIfNotEmpty(params, 'teacher_id', teacherId);
      _addIfNotEmpty(params, 'class_id', classId);
      _addIfNotEmpty(params, 'date', date);
      _addIfNotEmpty(params, 'month', month);
      _addIfNotEmpty(params, 'year', year);
      _addIfNotEmpty(params, 'subject_id', subjectId);

      String url = '/class-activity/filter-options';
      if (params.isNotEmpty) {
        final qs = Uri(queryParameters: params).query;
        url += '?$qs';
      }

      final response = await dioClient.get(url);
      final result = response.data;

      if (result is Map<String, dynamic>) return result;

      return {'success': false};
    } catch (e) {
      AppLogger.error('class_activity', e);
      rethrow;
    }
  }

  /// Helper: Adds parameter to map only if value is not null/empty.
  void _addIfNotEmpty(Map<String, String> map, String key, String? value) {
    if (value != null && value.isNotEmpty) {
      map[key] = value;
    }
  }

  /// Helper: Extracts data list from response (handles various formats).
  List<dynamic> _extractData(dynamic result) {
    if (result is List) {
      return result;
    } else if (result is Map && result.containsKey('data')) {
      return result['data'] ?? [];
    } else {
      return [];
    }
  }
}
