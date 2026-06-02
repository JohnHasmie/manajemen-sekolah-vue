/// query_helper.dart - Student query operations (pagination, stats, filters).
library;

import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Helper for complex student queries.
class QueryHelper {
  /// Builds query parameters from filter options.
  static String _buildQueryString(Map<String, dynamic> params) {
    return Uri(queryParameters: params).query;
  }

  /// Fetches filter dropdown options.
  static Future<Map<String, dynamic>> getFilterOptions() async {
    try {
      final response = await dioClient.get('/student/filter-options');

      final result = response.data;

      if (result is Map<String, dynamic>) {
        return result;
      }

      return {
        'success': false,
        'data': {
          'grade_levels': [],
          'kelas': [],
          // Backend canonical: `male` / `female` (was `L` / `P`).
          'gender_options': [
            {'value': 'male', 'label': 'Laki-laki'},
            {'value': 'female', 'label': 'Perempuan'},
          ],
          'status_options': [
            {'value': 'active', 'label': 'Aktif'},
            {'value': 'inactive', 'label': 'Tidak Aktif'},
          ],
        },
      };
    } catch (e) {
      AppLogger.error('student', e);
      rethrow;
    }
  }

  /// Fetches paginated student list with optional filters and caching.
  static Future<Map<String, dynamic>> getPaginated({
    int page = 1,
    int limit = 10,
    String? classId,
    String? gradeLevel,
    String? gender,
    String? search,
    String? academicYearId,
    String? guardianName,
    String? status,
    bool useCache = true,
  }) async {
    final Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }
    if (gradeLevel != null && gradeLevel.isNotEmpty) {
      queryParams['grade_level'] = gradeLevel;
    }
    if (gender != null && gender.isNotEmpty) {
      queryParams['gender'] = gender;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }
    if (guardianName != null && guardianName.isNotEmpty) {
      queryParams['guardian_name'] = guardianName;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final String queryString = _buildQueryString(queryParams);
    final cacheKey = CacheKeyBuilder.custom(
      'student',
      'paginated',
      queryString,
    );

    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null) {
        AppLogger.debug('student', 'Using cached students for $cacheKey');
        return cached;
      }
    }

    try {
      final response = await dioClient.get('/student?$queryString');

      final result = response.data;

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

  /// Fetches aggregated student statistics.
  static Future<Map<String, dynamic>> getStats({
    String? classId,
    String? gender,
    String? search,
    String? academicYearId,
    String? status,
  }) async {
    final Map<String, dynamic> queryParams = {};
    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }
    if (gender != null && gender.isNotEmpty) {
      queryParams['gender'] = gender;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final String queryString = _buildQueryString(queryParams);

    try {
      final response = await dioClient.get('/student/stats?$queryString');

      final result = response.data;
      return result['data'] ?? {};
    } catch (e) {
      AppLogger.error('student', e);
      return {};
    }
  }
}
