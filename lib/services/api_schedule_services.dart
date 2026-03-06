import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/local_cache_service.dart';
import 'package:path_provider/path_provider.dart';

class ApiScheduleService {
  static String get baseUrl => ApiService.baseUrl;

  // Clear cache
  static Future<void> invalidateCache() async {
    await LocalCacheService.clearStartingWith('schedule_');
    if (kDebugMode) {
      print('DEBUG: Schedule cache invalidated (persistent)');
    }
  }

  static Future<Map<String, String>> _getHeaders() => ApiService.getHeaders();

  static dynamic _handleResponse(http.Response response) {
    final responseBody = json.decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    } else {
      throw Exception(
        'Status: ${response.statusCode}, Body: ${json.encode(responseBody)}',
      );
    }
  }

  // Get Hari
  static Future<List<dynamic>> getHari() async {
    final response = await http.get(
      Uri.parse('$baseUrl/day'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  // Get Semester
  static Future<List<dynamic>> getSemester() async {
    final response = await http.get(
      Uri.parse('$baseUrl/semester'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  // Get Academic Year
  static Future<List<dynamic>> getAcademicYear() async {
    final response = await http.get(
      Uri.parse('$baseUrl/academic-year'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  // Get Jam Pelajaran
  static Future<List<dynamic>> getJamPelajaran() async {
    final response = await http.get(
      Uri.parse('$baseUrl/lesson-hour'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  // Add Jam Pelajaran
  static Future<dynamic> addJamPelajaran(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/lesson-hour'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  // Get Filter Options for Teaching Schedule Filters
  static Future<Map<String, dynamic>> getScheduleFilterOptions({
    String? academicYearId,
  }) async {
    try {
      String url = '$baseUrl/teaching-schedule/filter-options';
      if (academicYearId != null) {
        url += '?academic_year_id=$academicYearId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);

      if (result is Map<String, dynamic>) {
        return result;
      }

      // Fallback
      return {
        'success': false,
        'data': {'teachers': [], 'classes': [], 'days': [], 'semesters': []},
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting schedule filter options: $e');
      }
      rethrow;
    }
  }

  // Get Teaching Schedules with Pagination & Filters (Recommended)
  static Future<Map<String, dynamic>> getSchedulesPaginated({
    int page = 1,
    int limit = 10,
    String? guruId,
    String? classId,
    String? hariId,
    String? semesterId,
    String? tahunAjaran,
    String? search,
    String? jamPelajaranId,
    String? hourNumber,
  }) async {
    // Build query parameters
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (guruId != null && guruId.isNotEmpty) {
      queryParams['teacher_id'] = guruId;
    }
    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }
    if (hariId != null && hariId.isNotEmpty) {
      queryParams['day_id'] = hariId;
    }
    if (semesterId != null && semesterId.isNotEmpty) {
      queryParams['semester_id'] = semesterId;
    }
    if (tahunAjaran != null && tahunAjaran.isNotEmpty) {
      queryParams['academic_year_id'] = tahunAjaran;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (jamPelajaranId != null && jamPelajaranId.isNotEmpty) {
      queryParams['lesson_hour_id'] = jamPelajaranId;
    }
    if (hourNumber != null && hourNumber.isNotEmpty) {
      queryParams['hour_number'] = hourNumber;
    }

    // Build query string
    String queryString = Uri(queryParameters: queryParams).query;
    final cacheKey = 'schedule_paginated?$queryString';

    try {
      // 1. Try Load from Cache
      final cachedData = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(minutes: 30),
      );
      if (cachedData != null) {
        if (kDebugMode) {
          print('DEBUG: Returning cached schedule data for $cacheKey');
        }
        return cachedData;
      }

      // 2. Fetch from API
      final response = await http.get(
        Uri.parse('$baseUrl/teaching-schedule?$queryString'),
        headers: await _getHeaders(),
      );

      if (kDebugMode) {
        print(
          'GET /teaching-schedule?$queryString - Status: ${response.statusCode}',
        );
      }

      final result = _handleResponse(response);

      if (result is Map<String, dynamic>) {
        // 3. Save to Cache
        await LocalCacheService.save(cacheKey, result);
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

      // Cache fallback result
      await LocalCacheService.save(cacheKey, fallbackResult);

      return fallbackResult;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting paginated schedules: $e');
      }
      rethrow;
    }
  }

  // Jadwal Mengajar dengan struktur baru (Legacy - use getSchedulesPaginated instead)
  static Future<List<dynamic>> getSchedule({
    String? teacherId,
    String? classId,
    String? dayId,
    String? semesterId,
    String? academicYear,
  }) async {
    String url = '$baseUrl/teaching-schedule?';
    if (teacherId != null) url += 'teacher_id=$teacherId&';
    if (classId != null) url += 'class_id=$classId&';
    if (dayId != null) url += 'day_id=$dayId&';
    if (semesterId != null) url += 'semester_id=$semesterId&';
    if (academicYear != null) url += 'academic_year_id=$academicYear&';

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  static Future<dynamic> addSchedule(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teaching-schedule'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    final result = _handleResponse(response);
    await invalidateCache(); // Invalidate cache on add
    return result;
  }

  static Future<void> updateSchedule(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/teaching-schedule/$id'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    _handleResponse(response);
    await invalidateCache(); // Invalidate cache on update
  }

  static Future<void> deleteSchedule(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/teaching-schedule/$id'),
      headers: await _getHeaders(),
    );

    _handleResponse(response);
    await invalidateCache(); // Invalidate cache on delete
  }

  // Tambahkan method untuk mendapatkan jam pelajaran berdasarkan filter
  static Future<List<dynamic>> getJamPelajaranByFilter({
    String? hariId,
    String? semesterId,
    String? classId,
    String? academicYear,
  }) async {
    String url = '$baseUrl/lesson-hour-filter?';
    if (hariId != null) url += 'day_id=$hariId&';
    if (semesterId != null) url += 'semester_id=$semesterId&';
    if (classId != null) url += 'class_id=$classId&';
    if (academicYear != null) url += 'academic_year_id=$academicYear&';

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  // Get All Schedules (No Pagination)
  static Future<Map<String, dynamic>> getAllSchedules({
    String? semesterId,
    String? tahunAjaran,
  }) async {
    final queryParameters = {
      if (semesterId != null) 'semester_id': semesterId,
      if (tahunAjaran != null) 'academic_year_id': tahunAjaran,
    };

    final uri = Uri.parse(
      '$baseUrl/teaching-schedule/all',
    ).replace(queryParameters: queryParameters);

    print('DEBUG: Calling getAllSchedules with URI: $uri');
    final response = await http.get(uri, headers: await _getHeaders());

    print('DEBUG: getAllSchedules Response Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final dynamic data = json.decode(response.body);

      if (data is List) {
        print(
          'DEBUG: getAllSchedules received List, wrapping in data object. Count: ${data.length}',
        );
        return {'data': data};
      } else if (data is Map<String, dynamic>) {
        print(
          'DEBUG: getAllSchedules received Map. Data count: ${(data['data'] as List?)?.length ?? 0}',
        );
        return data;
      }

      print(
        'DEBUG: getAllSchedules received unexpected type: ${data.runtimeType}',
      );
      return {'data': []};
    } else {
      print('DEBUG: getAllSchedules Error: ${response.body}');
      throw Exception('Failed to load all schedules');
    }
  }

  static Future<List<dynamic>> getConflictingSchedules({
    required List<String> days_ids,
    required String classId,
    required String teacherId, // Added parameter
    required String semesterId,
    required String tahunAjaran,
    required String jamPelajaranId,
    String? excludeScheduleId, // Untuk edit, exclude jadwal yang sedang diedit
  }) async {
    try {
      String url = '$baseUrl/teaching-schedule/conflicts?';
      url += 'days_ids=${days_ids.join(',')}&';
      url += 'class_id=$classId&';
      url += 'teacher_id=$teacherId&'; // Added to URL
      url += 'semester_id=$semesterId&';
      url += 'academic_year_id=$tahunAjaran&';
      url += 'lesson_hour_id=$jamPelajaranId&';

      if (excludeScheduleId != null) {
        url += 'exclude_id=$excludeScheduleId&';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      return result is List ? result : [];
    } catch (e) {
      if (kDebugMode) {
        print('Error checking conflicts: $e');
      }
      return [];
    }
  }

  // Di class ApiScheduleService, tambahkan method berikut:

  // Get Jadwal Mengajar by Guru ID
  static Future<List<dynamic>> getScheduleByTeacher({
    required String teacherId,
    String? dayId,
    String? semesterId,
    String? academicYear,
  }) async {
    try {
      String url = '$baseUrl/teaching-schedule/teacher/$teacherId?';
      if (dayId != null && dayId.isNotEmpty) url += 'day_id=$dayId&';
      if (semesterId != null) url += 'semester_id=$semesterId&';
      if (academicYear != null) url += 'academic_year_id=$academicYear&';

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      return result is List ? result : [];
    } catch (e) {
      if (kDebugMode) {
        print('Error loading schedule by guru: $e');
      }
      return [];
    }
  }

  // Get Jadwal Mengajar for Current User
  static Future<List<dynamic>> getCurrentUserSchedule({
    String? dayId,
    String? semesterId,
    String? academicYear,
  }) async {
    try {
      String url = '$baseUrl/teaching-schedule/current?';
      if (dayId != null && dayId.isNotEmpty) url += 'day_id=$dayId&';
      if (semesterId != null) url += 'semester_id=$semesterId&';
      if (academicYear != null) url += 'academic_year_id=$academicYear&';

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      return result is List ? result : [];
    } catch (e) {
      if (kDebugMode) {
        print('Error loading current user schedule: $e');
      }
      return [];
    }
  }

  // Tambahkan method ini di ApiScheduleService
  static Future<List<dynamic>> getFilteredSchedule({
    required String teacherId,
    String? day,
    String? semester,
    String? academicYear,
  }) async {
    try {
      String url = '$baseUrl/teaching-schedule/filtered?';
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

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);

      if (result is Map<String, dynamic> && result.containsKey('data')) {
        return result['data'] is List ? result['data'] : [];
      }

      return result is List ? result : [];
    } catch (e) {
      if (kDebugMode) {
        print('Error loading filtered schedule: $e');
      }
      return [];
    }
  }

  // Tambahkan method berikut di class ApiScheduleService

  // Download template jadwal mengajar
  static Future<String> downloadScheduleTemplate() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teaching-schedule/template'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        // Get directory
        final directory = await getApplicationDocumentsDirectory();
        final filePath =
            '${directory.path}/template_import_jadwal_mengajar.xlsx';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      } else {
        throw Exception('Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to download template: $e');
    }
  }

  // Import jadwal mengajar dari Excel
  static Future<Map<String, dynamic>> importSchedulesFromExcel(
    File file,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/teaching-schedule/import'),
      );

      // Add headers
      request.headers.addAll(await _getHeaders());

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

      print('Import Schedule Response Status: ${response.statusCode}');
      print('Import Schedule Response Body: $responseBody');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await invalidateCache(); // Force refresh data after import
        return json.decode(responseBody);
      } else {
        throw Exception(
          'Import failed with status: ${response.statusCode}. Response: $responseBody',
        );
      }
    } catch (e) {
      print('Import schedule error details: $e');
      throw Exception('Import error: $e');
    }
  }

  // Debug Excel untuk jadwal mengajar
  static Future<Map<String, dynamic>> debugExcelSchedule(File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/debug/excel-teaching-schedule'),
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

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(responseBody);
      } else {
        throw Exception('Debug failed with status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Debug error: $e');
    }
  }

  // Export jadwal mengajar ke Excel
  static Future<String> exportSchedules({
    String? guruId,
    String? classId,
    String? hariId,
    String? semesterId,
    String? tahunAjaran,
  }) async {
    try {
      String url = '$baseUrl/teaching-schedule/export?';
      if (guruId != null) url += 'teacher_id=$guruId&';
      if (classId != null) url += 'class_id=$classId&';
      if (hariId != null) url += 'day_id=$hariId&';
      if (semesterId != null) url += 'semester_id=$semesterId&';
      if (tahunAjaran != null) url += 'academic_year_id=$tahunAjaran&';

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        // Get directory
        final directory = await getApplicationDocumentsDirectory();
        final filePath =
            '${directory.path}/jadwal_mengajar_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      } else {
        throw Exception('Export failed with status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to export schedules: $e');
    }
  }

  // Get current semester based on server date (Ganjil/Genap)
  static Future<Map<String, dynamic>> getDateBasedSemester() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/semester/current-date-based'),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      return result is Map<String, dynamic> ? result : {};
    } catch (e) {
      if (kDebugMode) {
        print('Error getting date based semester: $e');
      }
      return {};
    }
  }
}
