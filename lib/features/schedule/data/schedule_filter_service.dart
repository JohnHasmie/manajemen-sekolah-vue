/// schedule_filter_service.dart - Fetch and filter teaching schedules
/// with pagination, search, and various filter options.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Service for fetching and filtering teaching schedules.
class ScheduleFilterService {
  /// Fetches filter dropdown options (teachers, classes, days, semesters).
  /// Like a Laravel endpoint that returns distinct values for Vue filters.
  Future<Map<String, dynamic>> getScheduleFilterOptions({
    String? academicYearId,
  }) async {
    try {
      String url = '/teaching-schedule/filter-options';
      if (academicYearId != null) {
        url += '?academic_year_id=$academicYearId';
      }

      final response = await dioClient.get(url);
      final result = response.data;

      if (result is Map<String, dynamic>) {
        return result;
      }

      // Fallback
      return {
        'success': false,
        'data': {'teachers': [], 'classes': [], 'days': [], 'semesters': []},
      };
    } catch (e) {
      AppLogger.error('schedule', 'Error getting filter options: $e');
      rethrow;
    }
  }

  /// Fetches teaching schedules with pagination, filters, and caching.
  /// Cache TTL is 30 minutes. Set [skipCache] to true for fresh data.
  /// Like `TeachingSchedule::filter($request)->paginate()` in Laravel.
  Future<Map<String, dynamic>> getSchedulesPaginated({
    int page = 1,
    int limit = 10,
    String? teacherId,
    String? classId,
    String? dayId,
    String? semesterId,
    String? academicYearId,
    String? search,
    String? lessonHourId,
    String? hourNumber,
    bool skipCache = false,
  }) async {
    final queryParams = _buildQueryParams(
      page: page,
      limit: limit,
      teacherId: teacherId,
      classId: classId,
      dayId: dayId,
      semesterId: semesterId,
      academicYearId: academicYearId,
      search: search,
      lessonHourId: lessonHourId,
      hourNumber: hourNumber,
    );

    final queryString = Uri(queryParameters: queryParams).query;
    final cacheKey = 'schedule_paginated?$queryString';

    try {
      if (!skipCache) {
        final cachedData = await LocalCacheService.load(
          cacheKey,
          ttl: const Duration(minutes: 30),
        );
        if (cachedData != null) {
          AppLogger.debug(
            'schedule',
            'Returning cached schedule data for $cacheKey',
          );
          return cachedData;
        }
      } else {
        AppLogger.debug(
          'schedule',
          'Skipping cache for $cacheKey (skipCache=true)',
        );
      }

      final response = await dioClient.get('/teaching-schedule?$queryString');

      AppLogger.debug(
        'schedule',
        'GET /teaching-schedule?$queryString - '
            'Status: ${response.statusCode}',
      );

      final result = response.data;

      if (result is Map<String, dynamic>) {
        await LocalCacheService.save(cacheKey, result);
        return result;
      }

      final fallbackResult = _buildFallbackResult(result, limit);
      await LocalCacheService.save(cacheKey, fallbackResult);
      return fallbackResult;
    } catch (e) {
      AppLogger.error('schedule', 'Error getting paginated schedules: $e');
      rethrow;
    }
  }

  /// Legacy method to fetch schedules as a flat list.
  /// Use [getSchedulesPaginated] instead.
  Future<List<dynamic>> getSchedule({
    String? teacherId,
    String? classId,
    String? dayId,
    String? semesterId,
    String? academicYear,
  }) async {
    String url = '/teaching-schedule?';
    if (teacherId != null) url += 'teacher_id=$teacherId&';
    if (classId != null) url += 'class_id=$classId&';
    if (dayId != null) url += 'day_id=$dayId&';
    if (semesterId != null) url += 'semester_id=$semesterId&';
    if (academicYear != null) url += 'academic_year_id=$academicYear&';

    final response = await dioClient.get(url);
    final result = response.data;
    return result is List ? result : [];
  }

  /// Fetches schedules with server-side text-based filters.
  /// Like a Laravel endpoint with `where('day', $day)` using names.
  Future<List<dynamic>> getFilteredSchedule({
    required String teacherId,
    String? day,
    String? semester,
    String? academicYear,
  }) async {
    try {
      String url = '/teaching-schedule/filtered?';
      url += 'teacher_id=$teacherId&limit=100&';

      if (day != null && day != 'Semua Hari') {
        url += 'day=$day&';
      }

      if (semester != null && semester != 'Semua Semester') {
        url += 'semester=$semester&';
      }

      if (academicYear != null) {
        url += 'academic_year_id=$academicYear&';
      }

      final response = await dioClient.get(url);
      final result = response.data;

      if (result is Map<String, dynamic> && result.containsKey('data')) {
        return result['data'] is List ? result['data'] : [];
      }

      return result is List ? result : [];
    } catch (e) {
      AppLogger.error('schedule', 'Error loading filtered schedule: $e');
      return [];
    }
  }

  /// Builds query parameters for pagination request.
  static Map<String, dynamic> _buildQueryParams({
    required int page,
    required int limit,
    String? teacherId,
    String? classId,
    String? dayId,
    String? semesterId,
    String? academicYearId,
    String? search,
    String? lessonHourId,
    String? hourNumber,
  }) {
    final params = {'page': page.toString(), 'limit': limit.toString()};

    if (teacherId != null && teacherId.isNotEmpty) {
      params['teacher_id'] = teacherId;
    }
    if (classId != null && classId.isNotEmpty) {
      params['class_id'] = classId;
    }
    if (dayId != null && dayId.isNotEmpty) {
      params['day_id'] = dayId;
    }
    if (semesterId != null && semesterId.isNotEmpty) {
      params['semester_id'] = semesterId;
    }
    if (academicYearId != null && academicYearId.isNotEmpty) {
      params['academic_year_id'] = academicYearId;
    }
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }
    if (lessonHourId != null && lessonHourId.isNotEmpty) {
      params['lesson_hour_id'] = lessonHourId;
    }
    if (hourNumber != null && hourNumber.isNotEmpty) {
      params['hour_number'] = hourNumber;
    }

    return params;
  }

  /// Builds a fallback result for backward compatibility.
  static Map<String, dynamic> _buildFallbackResult(dynamic result, int limit) {
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
