/// api_student_services.dart - Manages student (siswa) CRUD with caching.
/// Like Laravel's StudentController / Vue's student store module.
///
/// Handles paginated listing with filters, CRUD operations, stats,
/// Excel import with error handling, template download, guardian lookups,
/// and student-by-class queries. Uses cache with manual invalidation.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/cache_invalidation_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/students/data/helpers/template_helper.dart';
import 'package:manajemensekolah/features/students/data/helpers/query_helper.dart';
import 'package:manajemensekolah/features/students/data/helpers/guardian_helper.dart';

/// Service for student (siswa) management API calls with local caching.
/// Like a Laravel Resource Controller + Repository pattern.
/// Facade that delegates to specialized helpers.
///
/// Key patterns:
/// - Laravel validation error parsing (422 with 'errors' map)
/// - Excel import with row-level error extraction
class ApiStudentService {
  /// Imports students from an Excel file via multipart upload.
  /// Handles row-level errors by stripping "Row N:" prefixes.
  /// Clears student cache after successful import.
  Future<Map<String, dynamic>> importStudentsFromExcel(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await dioClient.post('/students/import', data: formData);

      AppLogger.debug(
        'student',
        'Import Response Status: ${response.statusCode}',
      );
      AppLogger.debug('student', 'Import Response Body: ${response.data}');

      final body = response.data;

      // Check for specific import result structure
      if (body is Map && body['results'] != null) {
        final results = body['results'];
        if (results['failed'] is int && results['failed'] > 0) {
          // Handle failures
          final List<dynamic> errors = results['errors'] ?? [];
          String errorMsg = errors.isNotEmpty
              ? errors.first.toString()
              : 'Import failed';

          // Strip "Row N: " prefix for cleaner UI messages
          final rowPrefixRegex = RegExp(r'^Row \d+: ');
          if (errorMsg.startsWith(rowPrefixRegex)) {
            errorMsg = errorMsg.replaceFirst(rowPrefixRegex, '');
          }

          throw Exception(errorMsg);
        }
      }

      // Clear cache after successful import
      await _clearStudentCache();

      return body;
    } catch (e) {
      AppLogger.error('student', e);
      throw Exception('Import error: $e');
    }
  }

  /// Downloads the student Excel import template.
  Future<String> downloadTemplate() async {
    return TemplateHelper.downloadTemplate();
  }

  /// Gets external storage directory path.
  Future<Directory?> getExternalStorageDirectory() async {
    return TemplateHelper.getExternalStorageDirectory();
  }

  /// Fetches the parent/guardian user account for a student.
  Future<Map<String, dynamic>?> getParentUser(String studentId) async {
    return GuardianHelper.getParentUser(studentId);
  }

  /// Fetches students with optional filters.
  Future<List<dynamic>> getStudent({
    String? academicYearId,
    String? userId,
    String? guardianEmail,
  }) async {
    String url = '/student';
    final List<String> queryParams = [];

    if (academicYearId != null) {
      queryParams.add('academic_year_id=$academicYearId');
    }
    if (userId != null) {
      queryParams.add('user_id=$userId');
    }
    if (guardianEmail != null) {
      queryParams.add('guardian_email=$guardianEmail');
    }

    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join('&')}';
    }

    final response = await dioClient.get(url);

    final result = response.data;
    if (result is Map<String, dynamic> && result.containsKey('data')) {
      return result['data'];
    }
    return result;
  }

  /// Fetches a single student by UUID.
  Future<dynamic> getStudentById(String id) async {
    final response = await dioClient.get('/student/$id');
    final result = response.data;
    if (result is Map<String, dynamic> && result.containsKey('data')) {
      return result['data'];
    }
    return result;
  }

  /// Fetches filter dropdown options.
  Future<Map<String, dynamic>> getStudentFilterOptions() async {
    return QueryHelper.getFilterOptions();
  }

  /// Fetches paginated students with filters and caching.
  Future<Map<String, dynamic>> getStudentPaginated({
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
    return QueryHelper.getPaginated(
      page: page,
      limit: limit,
      classId: classId,
      gradeLevel: gradeLevel,
      gender: gender,
      search: search,
      academicYearId: academicYearId,
      guardianName: guardianName,
      status: status,
      useCache: useCache,
    );
  }

  /// Fetches aggregated student statistics.
  Future<Map<String, dynamic>> getStudentStats({
    String? classId,
    String? gender,
    String? search,
    String? academicYearId,
    String? status,
  }) async {
    return QueryHelper.getStats(
      classId: classId,
      gender: gender,
      search: search,
      academicYearId: academicYearId,
      status: status,
    );
  }

  /// Clears all student-related cache entries.
  /// Called after any mutation operation.
  Future<void> _clearStudentCache() async {
    await CacheInvalidationService.onStudentChanged();
  }

  /// Creates a new student record and clears cache.
  Future<dynamic> addStudent(Map<String, dynamic> data) async {
    final response = await dioClient.post('/student', data: data);
    final result = response.data;
    await _clearStudentCache();
    return result;
  }

  /// Updates a student record and clears cache.
  Future<void> updateStudent(String id, Map<String, dynamic> data) async {
    AppLogger.debug('student', 'Updating student ID: $id with data: $data');
    try {
      await dioClient.put('/student/$id', data: data);
      await _clearStudentCache();
    } catch (e) {
      AppLogger.error('student', 'Update student failed for ID $id: $e');
      rethrow;
    }
  }

  /// Deletes a student and clears cache.
  Future<void> deleteStudent(String id) async {
    await dioClient.delete('/student/$id');
    await _clearStudentCache();
  }

  /// Fetches students belonging to a specific class.
  Future<List<dynamic>> getStudentByClass(
    String classId, {
    String? academicYearId,
  }) async {
    try {
      String url = '/student/class/$classId';
      if (academicYearId != null) {
        url += '?academic_year_id=$academicYearId';
      }
      final response = await dioClient.get(url);

      final result = response.data;
      if (result is Map<String, dynamic>) {
        return (result['data'] as List?) ?? [];
      }
      return result is List ? result : [];
    } catch (e) {
      AppLogger.error('student', e);
      return [];
    }
  }

  /// Searches guardian names for autocomplete suggestions.
  Future<List<String>> getGuardians(String query) async {
    return GuardianHelper.getGuardians(query);
  }
}
