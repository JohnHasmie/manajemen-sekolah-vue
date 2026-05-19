/// Subject CRUD operations with caching and filtering.
library;

import 'dart:convert';

import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/cache_invalidation_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Manages subject CRUD operations with pagination,
/// filtering, and caching. Like Laravel's SubjectController
/// for read/write operations.
class SubjectCrudService {
  /// Fetches filter dropdown options for subject listing,
  /// with 24-hour cache. Cache is scoped by school_id to
  /// prevent cross-school data leaks.
  Future<Map<String, dynamic>> getSubjectFilterOptions() async {
    try {
      final prefs = PreferencesService();
      final userJson = prefs.getString('user');
      String schoolId = 'global';
      if (userJson != null) {
        final user = json.decode(userJson);
        schoolId = user['school_id']?.toString() ?? 'global';
      }

      final String cacheKey = CacheKeyBuilder.subjectFilters(schoolId);

      // 1. Try cache
      final cachedData = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cachedData != null) return cachedData;

      final response = await dioClient.get('/subject/filter-options');

      final result = response.data;

      if (result is Map<String, dynamic>) {
        await LocalCacheService.save(cacheKey, result);
        return result;
      }

      return {
        'success': false,
        'data': {'status_options': []},
      };
    } catch (e) {
      AppLogger.error('subject', e);
      rethrow;
    }
  }

  /// Fetches subjects with server-side pagination, filters,
  /// and local caching. Cache is scoped by school_id with
  /// 30-minute TTL.
  Future<Map<String, dynamic>> getSubjectsPaginated({
    int page = 1,
    int limit = 10,
    String? status,
    String? search,
    String? gradeLevel,
    List<String>? subjectIds,
    String? academicYearId,
  }) async {
    final queryString = _buildSubjectQueryString(
      page,
      limit,
      status,
      search,
      gradeLevel,
      subjectIds,
      academicYearId,
    );
    final schoolId = _getSchoolIdForCache();
    final cacheKey = CacheKeyBuilder.custom('subject', schoolId, queryString);

    try {
      return await _getSubjectsWithCache(
        cacheKey,
        queryString,
        schoolId,
        limit,
      );
    } catch (e) {
      AppLogger.error('subject', e);
      rethrow;
    }
  }

  /// Builds query string for subject pagination request.
  String _buildSubjectQueryString(
    int page,
    int limit,
    String? status,
    String? search,
    String? gradeLevel,
    List<String>? subjectIds, [
    String? academicYearId,
  ]) {
    final queryParams = <String, dynamic>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (status != null && status.isNotEmpty && status != 'all') {
      queryParams['status'] = status;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (gradeLevel != null && gradeLevel.isNotEmpty) {
      queryParams['grade_level'] = gradeLevel;
    }
    if (subjectIds != null && subjectIds.isNotEmpty) {
      queryParams['subject_ids'] = subjectIds.join(',');
    }
    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }

    return Uri(queryParameters: queryParams).query;
  }

  /// Gets school ID from user preferences for cache scope.
  String _getSchoolIdForCache() {
    final prefs = PreferencesService();
    final userJson = prefs.getString('user');
    String schoolId = 'global';
    if (userJson != null) {
      try {
        final user = json.decode(userJson);
        schoolId = user['school_id']?.toString() ?? 'global';
      } catch (_) {}
    }
    return schoolId;
  }

  /// Fetches subjects with cache-first logic.
  Future<Map<String, dynamic>> _getSubjectsWithCache(
    String cacheKey,
    String queryString,
    String schoolId,
    int limit,
  ) async {
    // Try cache first
    final cachedData = await LocalCacheService.load(
      cacheKey,
      ttl: const Duration(minutes: 30),
    );
    if (cachedData != null) {
      AppLogger.info('subject', 'Loading subjects from CACHE: $cacheKey');
      return cachedData;
    }

    return await _fetchAndCacheSubjects(cacheKey, queryString, schoolId, limit);
  }

  /// Fetches subjects from API and caches result.
  Future<Map<String, dynamic>> _fetchAndCacheSubjects(
    String cacheKey,
    String queryString,
    String schoolId,
    int limit,
  ) async {
    AppLogger.debug(
      'subject',
      'Fetching subjects from API for School: $schoolId',
    );
    final response = await dioClient.get('/subject?$queryString');

    AppLogger.debug(
      'subject',
      'GET /subject?$queryString - Status: ${response.statusCode}',
    );

    final result = response.data;

    if (result is Map<String, dynamic>) {
      await LocalCacheService.save(cacheKey, result);
      return result;
    }

    return await _buildAndCacheFallback(cacheKey, result, limit);
  }

  /// Builds fallback response and caches it.
  Future<Map<String, dynamic>> _buildAndCacheFallback(
    String cacheKey,
    dynamic result,
    int limit,
  ) async {
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

    await LocalCacheService.save(cacheKey, fallbackResult);
    return fallbackResult;
  }

  /// Fetches all subjects as a flat list. Legacy method for
  /// backward compatibility.
  Future<List<dynamic>> getSubject({String? status}) async {
    String url = '/subject';
    if (status != null && status.isNotEmpty && status != 'all') {
      url += '?status=$status';
    }
    final result = await ApiService().get(url);

    if (result is Map<String, dynamic>) {
      return result['data'] ?? [];
    }

    return result is List ? result : [];
  }

  /// Creates a new subject. Invalidates cache.
  Future<dynamic> addSubject(Map<String, dynamic> data) async {
    final response = await ApiService().post('/subject', data);
    await CacheInvalidationService.onSubjectChanged();
    return response;
  }

  /// Updates a subject. Invalidates cache.
  Future<void> updateSubject(String id, Map<String, dynamic> data) async {
    await ApiService().put('/subject/$id', data);
    await CacheInvalidationService.onSubjectChanged();
  }

  /// Deletes a subject. Invalidates cache.
  Future<void> deleteSubject(String id) async {
    await ApiService().delete('/subject/$id');
    await CacheInvalidationService.onSubjectChanged();
  }

  /// Attaches a class to a subject (many-to-many pivot).
  Future<void> attachClass(String subjectId, String classId) async {
    await ApiService().post('/subject-class', {
      'subject_id': subjectId,
      'class_id': classId,
    });
    await CacheInvalidationService.onSubjectChanged();
  }

  /// Detaches a class from a subject.
  Future<void> detachClass(String subjectId, String classId) async {
    await ApiService().delete(
      '/subject-class?subject_id=$subjectId&class_id=$classId',
    );
    await CacheInvalidationService.onSubjectChanged();
  }

  /// Attaches multiple classes to a subject in a single round-trip.
  /// Used by the Frame E multi-select Tambah Kelas sheet on the Mata
  /// Pelajaran detail screen.
  ///
  /// Returns the backend payload `{ attached_count, skipped_count }`
  /// so the caller can show an accurate toast (e.g. "3 ditambahkan,
  /// 1 dilewati karena sudah terdaftar").
  Future<Map<String, dynamic>> bulkAttachClasses(
    String subjectId,
    List<String> classIds,
  ) async {
    final response = await ApiService().post(
      '/subject/$subjectId/classes/bulk-attach',
      {'class_ids': classIds},
    );
    await CacheInvalidationService.onSubjectChanged();
    if (response is Map<String, dynamic>) return response;
    return <String, dynamic>{};
  }

  /// Fetches the master list of all available subjects.
  /// System-wide reference data, not school-specific.
  Future<List<dynamic>> getAllMasterSubjects() async {
    final response = await dioClient.get('/master-subjects');
    final result = response.data;
    return result is List ? result : [];
  }
}
