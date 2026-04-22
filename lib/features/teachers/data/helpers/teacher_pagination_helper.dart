/// teacher_pagination_helper.dart - Paginated teacher listing & stats.
/// Manages cached pagination and aggregate statistics.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Handles paginated teacher listing and statistics.
/// Like Laravel's filter().paginate() with local caching.
class TeacherPaginationHelper {
  /// Fetches teachers with server-side pagination, filters, and cache.
  /// Like `Teacher::filter($request)->paginate()` in Laravel.
  /// Supports classId, gender, employmentStatus, teachingClassId,
  /// search, academicYearId, teacherId filters.
  /// Uses local cache unless useCache=false.
  /// Returns pagination structure with data, pagination metadata.
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
    bool useCache = true,
  }) async {
    final Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    _addIfNotEmpty(queryParams, 'homeroom_class_id', classId);
    _addIfNotEmpty(queryParams, 'gender', gender);
    _addIfNotEmpty(queryParams, 'employment_status', employmentStatus);
    _addIfNotEmpty(queryParams, 'teaching_class_id', teachingClassId);
    _addIfNotEmpty(queryParams, 'search', search);
    _addIfNotEmpty(queryParams, 'academic_year_id', academicYearId);
    _addIfNotEmpty(queryParams, 'teacher_id', teacherId);

    final String queryString = Uri(queryParameters: queryParams).query;
    final cacheKey = CacheKeyBuilder.custom(
      'teacher',
      'paginated',
      queryString,
    );

    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null) {
        AppLogger.debug('teacher', 'Using cached teachers for $cacheKey');
        return cached;
      }
    }

    try {
      final response = await dioClient.get('/teacher?$queryString');
      final result = response.data;

      if (result is Map<String, dynamic>) {
        await LocalCacheService.save(cacheKey, result);
        return result;
      }

      final fallback = _buildFallbackPagination(result, limit);
      await LocalCacheService.save(cacheKey, fallback);
      return fallback;
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches aggregated teacher statistics.
  /// Like a Laravel aggregate query endpoint.
  /// Supports gender, employmentStatus, name, employeeNumber,
  /// academicYearId filters.
  /// Returns data map or empty map on error.
  static Future<Map<String, dynamic>> getTeacherStats({
    String? gender,
    String? employmentStatus,
    String? name,
    String? employeeNumber,
    String? academicYearId,
  }) async {
    final Map<String, dynamic> queryParams = {};

    _addIfNotEmpty(queryParams, 'gender', gender);
    _addIfNotEmpty(queryParams, 'employment_status', employmentStatus);
    _addIfNotEmpty(queryParams, 'name', name);
    _addIfNotEmpty(queryParams, 'employee_number', employeeNumber);
    _addIfNotEmpty(queryParams, 'academic_year_id', academicYearId);

    final String queryString = Uri(queryParameters: queryParams).query;

    try {
      final response = await dioClient.get('/teacher/stats?$queryString');
      final result = response.data;
      return result['data'] ?? {};
    } catch (e) {
      AppLogger.error('teacher', e);
      return {};
    }
  }

  /// Helper: Adds parameter to map if value is not null/empty.
  static void _addIfNotEmpty(
    Map<String, dynamic> params,
    String key,
    String? value,
  ) {
    if (value != null && value.isNotEmpty) {
      params[key] = value;
    }
  }

  /// Builds fallback pagination structure when API returns non-standard.
  static Map<String, dynamic> _buildFallbackPagination(
    dynamic result,
    int limit,
  ) {
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
  }
}
