/// api_schedule_services.dart - Manages teaching schedules (jadwal mengajar) with caching.
/// Like Laravel's TeachingScheduleController / Vue's schedule store module.
///
/// Handles CRUD for teaching schedules, lesson hours, semesters, academic years,
/// conflict detection, Excel import/export, and schedule filtering by teacher/class/day.
/// Uses [LocalCacheService] with 30-minute TTL for paginated schedule data.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Service for teaching schedule (jadwal mengajar) API calls with caching.
/// Like a comprehensive Laravel Resource Controller with additional actions for
/// conflicts, import/export, and filtered views. Uses local cache for performance.
///
/// In Vue terms, this is like a large Pinia store that manages schedule state,
/// with computed getters for filtered/cached data and actions for CRUD + import/export.
class ApiScheduleService {
  /// Clears all schedule-related cache entries.
  /// Called after any mutation to ensure fresh data on next load.
  /// Like Laravel's `Cache::tags('schedules')->flush()`.
  Future<void> invalidateCache() async {
    await LocalCacheService.clearStartingWith('schedule_');
    AppLogger.debug(
      'schedule',
      'DEBUG: Schedule cache invalidated (persistent)',
    );
  }

  /// Fetches the list of school days (hari). Like `Day::all()` in Laravel.
  Future<List<dynamic>> getDays() async {
    final response = await dioClient.get('/day');

    final result = response.data;
    return result is List ? result : [];
  }

  /// Fetches the list of semesters. Like `Semester::all()` in Laravel.
  Future<List<dynamic>> getSemester() async {
    final response = await dioClient.get('/semester');

    final result = response.data;
    return result is List ? result : [];
  }

  /// Fetches academic years. Like `AcademicYear::all()` in Laravel.
  Future<List<dynamic>> getAcademicYear() async {
    final response = await dioClient.get('/academic-year');

    final result = response.data;
    return result is List ? result : [];
  }

  /// Fetches lesson hour slots (jam pelajaran). Like `LessonHour::all()` in Laravel.
  Future<List<dynamic>> getJamPelajaran() async {
    final response = await dioClient.get('/lesson-hour');

    final result = response.data;
    return result is List ? result : [];
  }

  /// Creates a new lesson hour slot. Like `LessonHour::create($data)` in Laravel.
  Future<dynamic> addJamPelajaran(Map<String, dynamic> data) async {
    final response = await dioClient.post('/lesson-hour', data: data);
    return response.data;
  }

  /// Fetches filter dropdown options (teachers, classes, days, semesters) for schedule listing.
  /// Like a Laravel endpoint that returns distinct values for Vue filter selects.
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
      AppLogger.error('schedule', 'Error getting schedule filter options: $e');
      rethrow;
    }
  }

  /// Fetches teaching schedules with server-side pagination, filters, and local caching.
  /// Like `TeachingSchedule::filter($request)->paginate()` in Laravel.
  /// Cache TTL is 30 minutes. Set [skipCache] to true to force fresh data.
  /// Similar to a Vuex action with localStorage caching for offline support.
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
    // Build query parameters
    final Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (teacherId != null && teacherId.isNotEmpty) {
      queryParams['teacher_id'] = teacherId;
    }
    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }
    if (dayId != null && dayId.isNotEmpty) {
      queryParams['day_id'] = dayId;
    }
    if (semesterId != null && semesterId.isNotEmpty) {
      queryParams['semester_id'] = semesterId;
    }
    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (lessonHourId != null && lessonHourId.isNotEmpty) {
      queryParams['lesson_hour_id'] = lessonHourId;
    }
    if (hourNumber != null && hourNumber.isNotEmpty) {
      queryParams['hour_number'] = hourNumber;
    }

    // Build query string
    final String queryString = Uri(queryParameters: queryParams).query;
    final cacheKey = 'schedule_paginated?$queryString';

    try {
      // 1. Try Load from Cache (skip if explicitly requested)
      if (!skipCache) {
        final cachedData = await LocalCacheService.load(
          cacheKey,
          ttl: const Duration(minutes: 30),
        );
        if (cachedData != null) {
          AppLogger.debug(
            'schedule',
            'DEBUG: Returning cached schedule data for $cacheKey',
          );
          return cachedData;
        }
      } else {
        AppLogger.debug(
          'schedule',
          'DEBUG: Skipping cache for $cacheKey (skipCache=true)',
        );
      }

      // 2. Fetch from API
      final response = await dioClient.get('/teaching-schedule?$queryString');

      AppLogger.debug(
        'schedule',
        'GET /teaching-schedule?$queryString - Status: ${response.statusCode}',
      );

      final result = response.data;

      if (result is Map<String, dynamic>) {
        // 3. Save to Cache
        await LocalCacheService.save(cacheKey, result);
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

      // Cache fallback result
      await LocalCacheService.save(cacheKey, fallbackResult);

      return fallbackResult;
    } catch (e) {
      AppLogger.error('schedule', 'Error getting paginated schedules: $e');
      rethrow;
    }
  }

  /// Legacy method to fetch schedules as a flat list. Use [getSchedulesPaginated] instead.
  /// Like a deprecated Laravel route kept for backward compatibility.
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

  /// Creates a new teaching schedule entry. Invalidates cache after mutation.
  /// Like `TeachingSchedule::create($data)` in Laravel.
  Future<dynamic> addSchedule(Map<String, dynamic> data) async {
    AppLogger.debug('schedule', 'DEBUG: addSchedule request body: $data');

    final response = await dioClient.post('/teaching-schedule', data: data);

    AppLogger.debug(
      'schedule',
      'DEBUG: addSchedule response: ${response.statusCode} - ${response.data}',
    );

    // Always invalidate cache after POST, even if response is an error
    // (backend may have saved the data despite returning 500)
    await invalidateCache();

    return response.data;
  }

  /// Updates an existing schedule entry. Invalidates cache.
  /// Like `TeachingSchedule::find($id)->update($data)` in Laravel.
  Future<void> updateSchedule(String id, Map<String, dynamic> data) async {
    await dioClient.put('/teaching-schedule/$id', data: data);
    await invalidateCache();
  }

  /// Deletes a schedule entry. Invalidates cache.
  /// Like `TeachingSchedule::find($id)->delete()` in Laravel.
  Future<void> deleteSchedule(String id) async {
    await dioClient.delete('/teaching-schedule/$id');
    await invalidateCache(); // Invalidate cache on delete
  }

  /// Fetches lesson hours filtered by day, semester, class, and academic year.
  /// Like `LessonHour::where(...)->get()` in Laravel with multiple scopes.
  Future<List<dynamic>> getJamPelajaranByFilter({
    String? dayId,
    String? semesterId,
    String? classId,
    String? academicYear,
  }) async {
    String url = '/lesson-hour-filter?';
    if (dayId != null) url += 'day_id=$dayId&';
    if (semesterId != null) url += 'semester_id=$semesterId&';
    if (classId != null) url += 'class_id=$classId&';
    if (academicYear != null) url += 'academic_year_id=$academicYear&';

    final response = await dioClient.get(url);

    final result = response.data;
    return result is List ? result : [];
  }

  /// Fetches all schedules without pagination (for exports or full-view displays).
  /// Like `TeachingSchedule::all()` in Laravel. Use sparingly for large datasets.
  Future<Map<String, dynamic>> getAllSchedules({
    String? semesterId,
    String? academicYearId,
  }) async {
    final queryParameters = {
      if (semesterId != null) 'semester_id': semesterId,
      if (academicYearId != null) 'academic_year_id': academicYearId,
    };

    String url = '/teaching-schedule/all';
    if (queryParameters.isNotEmpty) {
      final qs = Uri(queryParameters: queryParameters).query;
      url += '?$qs';
    }

    AppLogger.debug(
      'schedule',
      'DEBUG: Calling getAllSchedules with URL: $url',
    );
    final response = await dioClient.get(url);

    AppLogger.debug(
      'schedule',
      'DEBUG: getAllSchedules Response Status: ${response.statusCode}',
    );
    final dynamic data = response.data;

    if (data is List) {
      AppLogger.debug(
        'schedule',
        'DEBUG: getAllSchedules received List, wrapping in data object. Count: ${data.length}',
      );
      return {'data': data};
    } else if (data is Map<String, dynamic>) {
      AppLogger.debug(
        'schedule',
        'DEBUG: getAllSchedules received Map. Data count: ${(data['data'] as List?)?.length ?? 0}',
      );
      return data;
    }

    AppLogger.debug(
      'schedule',
      'DEBUG: getAllSchedules received unexpected type: ${data.runtimeType}',
    );
    return {'data': []};
  }

  /// Checks for schedule conflicts before creating/updating a schedule.
  /// Like a Laravel validation rule that queries for overlapping time slots.
  /// Returns a list of conflicting schedules (empty if no conflicts).
  /// [excludeScheduleId] - Exclude the current schedule when editing.
  Future<List<dynamic>> getConflictingSchedules({
    required List<String> daysIds,
    required String classId,
    required String teacherId, // Added parameter
    required String semesterId,
    required String academicYearId,
    required String lessonHourId,
    String? excludeScheduleId, // For edit, exclude the schedule being edited
  }) async {
    try {
      String url = '/teaching-schedule/conflicts?';
      url += 'days_ids=${daysIds.join(',')}&';
      url += 'class_id=$classId&';
      url += 'teacher_id=$teacherId&'; // Added to URL
      url += 'semester_id=$semesterId&';
      url += 'academic_year_id=$academicYearId&';
      url += 'lesson_hour_id=$lessonHourId&';

      if (excludeScheduleId != null) {
        url += 'exclude_id=$excludeScheduleId&';
      }

      final response = await dioClient.get(url);

      final result = response.data;
      return result is List ? result : [];
    } catch (e) {
      AppLogger.error('schedule', 'Error checking conflicts: $e');
      return [];
    }
  }

  /// Fetches schedules for a specific teacher with optional filters.
  /// Like `TeachingSchedule::where('teacher_id', $id)->get()` in Laravel.
  Future<List<dynamic>> getScheduleByTeacher({
    required String teacherId,
    String? dayId,
    String? semesterId,
    String? academicYear,
  }) async {
    try {
      String url = '/teaching-schedule/teacher/$teacherId?';
      if (dayId != null && dayId.isNotEmpty) url += 'day_id=$dayId&';
      if (semesterId != null) url += 'semester_id=$semesterId&';
      if (academicYear != null) url += 'academic_year_id=$academicYear&';

      final response = await dioClient.get(url);

      final result = response.data;
      return result is List ? result : [];
    } catch (e) {
      AppLogger.error('schedule', 'Error loading schedule by guru: $e');
      return [];
    }
  }

  /// Fetches schedules for the currently authenticated user.
  /// Like `auth()->user()->teachingSchedules` in Laravel.
  Future<List<dynamic>> getCurrentUserSchedule({
    String? dayId,
    String? semesterId,
    String? academicYear,
  }) async {
    try {
      String url = '/teaching-schedule/current?';
      if (dayId != null && dayId.isNotEmpty) url += 'day_id=$dayId&';
      if (semesterId != null) url += 'semester_id=$semesterId&';
      if (academicYear != null) url += 'academic_year_id=$academicYear&';

      final response = await dioClient.get(url);

      final result = response.data;
      return result is List ? result : [];
    } catch (e) {
      AppLogger.error('schedule', 'Error loading current user schedule: $e');
      return [];
    }
  }

  /// Fetches schedules with server-side text-based filters (day name, semester name).
  /// Like a Laravel endpoint with `where('day', $day)` using display names instead of IDs.
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

  /// Downloads the Excel import template for teaching schedules.
  /// Like Laravel's file download response. Returns the local file path.
  Future<String> downloadScheduleTemplate() async {
    try {
      final response = await dioClient.get<List<int>>(
        '/teaching-schedule/template',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data ?? [];
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/template_import_jadwal_mengajar.xlsx';
      final file = File(filePath);

      await file.writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      throw Exception('Failed to download template: $e');
    }
  }

  /// Imports schedules from an Excel file via multipart upload. Invalidates cache.
  /// Like Laravel's `Excel::import()` with Maatwebsite package.
  Future<Map<String, dynamic>> importSchedulesFromExcel(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await dioClient.post(
        '/teaching-schedule/import',
        data: formData,
      );

      AppLogger.debug(
        'schedule',
        'Import Schedule Response Status: ${response.statusCode}',
      );
      AppLogger.debug(
        'schedule',
        'Import Schedule Response Body: ${response.data}',
      );

      await invalidateCache(); // Force refresh data after import
      return response.data;
    } catch (e) {
      AppLogger.error('schedule', 'Import schedule error details: $e');
      throw Exception('Import error: $e');
    }
  }

  /// Debug endpoint to preview Excel file parsing without importing.
  /// Like a Laravel debug/test route. Useful during development.
  Future<Map<String, dynamic>> debugExcelSchedule(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await dioClient.post(
        '/debug/excel-teaching-schedule',
        data: formData,
      );

      return response.data;
    } catch (e) {
      throw Exception('Debug error: $e');
    }
  }

  /// Exports schedules to an Excel file with optional filters.
  /// Like Laravel's `Excel::download()` -- saves the file locally and returns the path.
  Future<String> exportSchedules({
    String? teacherId,
    String? classId,
    String? dayId,
    String? semesterId,
    String? academicYearId,
  }) async {
    try {
      String url = '/teaching-schedule/export?';
      if (teacherId != null) url += 'teacher_id=$teacherId&';
      if (classId != null) url += 'class_id=$classId&';
      if (dayId != null) url += 'day_id=$dayId&';
      if (semesterId != null) url += 'semester_id=$semesterId&';
      if (academicYearId != null) url += 'academic_year_id=$academicYearId&';

      final response = await dioClient.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data ?? [];
      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/jadwal_mengajar_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);

      await file.writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      throw Exception('Failed to export schedules: $e');
    }
  }

  /// Gets the current semester based on the server date (Ganjil/Genap).
  /// Like a Laravel helper that determines the active semester from today's date.
  Future<Map<String, dynamic>> getDateBasedSemester() async {
    try {
      final response = await dioClient.get('/semester/current-date-based');

      final result = response.data;
      return result is Map<String, dynamic> ? result : {};
    } catch (e) {
      AppLogger.error('schedule', 'Error getting date based semester: $e');
      return {};
    }
  }
}
