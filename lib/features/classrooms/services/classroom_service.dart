/// api_class_services.dart - Manages school class (kelas) CRUD with caching.
/// Like Laravel's ClassController / Vue's class store module.
///
/// Handles class listing (paginated with filters), creation, update, deletion,
/// Excel import/template download, student listing by class, and student promotion.
/// Uses [LocalCacheService] for offline-first caching with school-scoped keys.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Service for class (kelas) management API calls with local caching.
/// Like a Laravel Resource Controller + Repository pattern with a cache layer.
/// In Vue terms, think of this as a Pinia store with persistent cache.
///
/// Key patterns:
/// - School-scoped cache keys (prefix: `class_{schoolId}_`) to avoid data leaking
/// - Cache invalidation on any mutation (create/update/delete/import)
/// - Fallback pagination structure for backward compatibility
class ApiClassService {
  /// Base URL from central config. Like `config('app.url')` in Laravel.
  static String get baseUrl => ApiService.baseUrl;

  /// Imports classes from an Excel file via multipart upload.
  /// Like Laravel's `Excel::import()` with Maatwebsite. Clears cache after success.
  /// Similar to a Vue file upload action that triggers a backend import job.
  static Future<Map<String, dynamic>> importClassesFromExcel(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await dioClient.post('/class/import', data: formData);

      await _clearClassCache();
      return response.data;
    } catch (e) {
      throw Exception('Import error: $e');
    }
  }

  /// Downloads the Excel import template to the device's documents directory.
  /// Like Laravel's file download response. Returns the local file path.
  static Future<String> downloadTemplate() async {
    try {
      final response = await dioClient.get<List<int>>(
        '/class/template',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data ?? [];
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/template_import_kelas.xlsx';
      final file = File(filePath);

      await file.writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      throw Exception('Failed to download template: $e');
    }
  }

  /// Fetches filter dropdown options (grade levels, homeroom teachers) for class listing.
  /// Like a Laravel endpoint returning distinct filter values for a Vue filter component.
  static Future<Map<String, dynamic>> getClassFilterOptions() async {
    try {
      final response = await dioClient.get('/class/filter-options');

      final result = response.data;

      if (result is Map<String, dynamic>) {
        return result;
      }

      return {
        'success': false,
        'data': {'grade_levels': [], 'wali_kelas': []},
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches classes with server-side pagination, filters, and local caching.
  /// Like `SchoolClass::filter($request)->paginate()` in Laravel.
  /// Cache is scoped by school_id to prevent cross-school data leaks.
  /// Set [useCache] to false to force a fresh API call (like cache-busting).
  static Future<Map<String, dynamic>> getClassPaginated({
    int page = 1,
    int limit = 10,
    String? gradeLevel,
    String? waliclassId,
    String? search,
    String? academicYearId,
    String? hasHomeroomTeacher,
    bool useCache = true,
  }) async {
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (hasHomeroomTeacher != null && hasHomeroomTeacher.isNotEmpty) {
      queryParams['has_homeroom_teacher'] = hasHomeroomTeacher;
    }

    if (gradeLevel != null && gradeLevel.isNotEmpty) {
      queryParams['grade_level'] = gradeLevel;
    }
    if (waliclassId != null && waliclassId.isNotEmpty) {
      queryParams['homeroom_teacher_id'] = waliclassId;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }

    String queryString = Uri(queryParameters: queryParams).query;

    // Get school_id context for cache key
    final prefs = PreferencesService();
    final userJson = prefs.getString('user');
    String schoolId = 'global';
    if (userJson != null) {
      try {
        final user = json.decode(userJson);
        schoolId = user['school_id']?.toString() ?? 'global';
      } catch (_) {}
    }

    final cacheKey = 'class_${schoolId}_paginated_$queryString';

    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null) {
        AppLogger.debug('classroom', 'Using cached classes for $cacheKey');
        return cached;
      }
    }

    try {
      final response = await dioClient.get('/class?$queryString');

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

  /// Invalidates all class-related cache entries.
  /// Called after any mutation (create/update/delete/import) to ensure fresh data.
  /// Like Laravel's `Cache::tags('classes')->flush()`.
  static Future<void> _clearClassCache() async {
    await LocalCacheService.clearStartingWith('class_');
    AppLogger.info('classroom', 'Class cache cleared due to changes');
  }

  /// Legacy method to fetch all classes as a flat list.
  /// Like `SchoolClass::all()` in Laravel. New code should use [getClassPaginated].
  static Future<List<dynamic>> getClass({String? academicYearId}) async {
    try {
      String url = '/class';
      if (academicYearId != null) {
        url += '?academic_year_id=$academicYearId';
      }

      final result = await ApiService().get(url);

      if (result is Map<String, dynamic>) {
        return result['data'] ?? [];
      }

      return result is List ? result : [];
    } catch (e) {
      return [];
    }
  }

  /// Fetches a single class by its UUID. Like `SchoolClass::findOrFail($id)` in Laravel.
  static Future<dynamic> getClassById(String id) async {
    try {
      final result = await ApiService().get('/class/$id');
      return result;
    } catch (e) {
      throw Exception('Gagal mengambil data kelas: $e');
    }
  }

  /// Creates a new class with validation. Clears cache after success.
  /// Like `SchoolClass::create()` in Laravel with form request validation.
  static Future<dynamic> addClass(Map<String, dynamic> data) async {
    try {
      if (data['name'] == null || data['name'].toString().isEmpty) {
        throw Exception('Nama kelas harus diisi');
      }

      if (data['grade_level'] == null) {
        throw Exception('Grade level harus dipilih');
      }

      final result = await ApiService().post('/class', data);
      await _clearClassCache();
      return result;
    } catch (e) {
      throw Exception('Gagal menambah kelas: $e');
    }
  }

  /// Updates an existing class by ID. Clears cache after success.
  /// Like `SchoolClass::find($id)->update($data)` in Laravel.
  static Future<dynamic> updateClass(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      if (data['name'] == null || data['name'].toString().isEmpty) {
        throw Exception('Nama kelas harus diisi');
      }

      if (data['grade_level'] == null) {
        throw Exception('Grade level harus dipilih');
      }

      final result = await ApiService().put('/class/$id', data);
      await _clearClassCache();
      return result;
    } catch (e) {
      throw Exception('Gagal mengupdate kelas: $e');
    }
  }

  /// Deletes a class by ID. Clears cache after success.
  /// Like `SchoolClass::find($id)->delete()` in Laravel.
  static Future<void> deleteClass(String id) async {
    try {
      await ApiService().delete('/class/$id');
      await _clearClassCache();
    } catch (e) {
      throw Exception('Gagal menghapus kelas: $e');
    }
  }

  /// Fetches all students in a given class.
  /// Like `Student::where('class_id', $classId)->get()` in Laravel.
  static Future<List<dynamic>> getStudentsByClassId(String classId) async {
    try {
      final result = await ApiService().get('/student/class/$classId');

      if (result is Map<String, dynamic>) {
        if (result.containsKey('data')) {
          return result['data'] ?? [];
        }
        return [];
      }

      return result is List ? result : [];
    } catch (e) {
      return [];
    }
  }

  /// Promotes students to the next class/grade level. Clears cache after success.
  /// Like a Laravel job that batch-processes student promotions at year-end.
  static Future<dynamic> promoteStudents(Map<String, dynamic> data) async {
    try {
      final result = await ApiService().post('/promotion/promote', data);
      await _clearClassCache();
      return result;
    } catch (e) {
      throw Exception('Gagal melakukan proses kenaikan kelas: $e');
    }
  }
}
