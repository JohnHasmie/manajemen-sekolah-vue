/// filter_options_service.dart - Centralized filter options with caching.
///
/// Consolidates 7 individual `/feature/filter-options` API calls into a single
/// `GET /filter-options` call. The response is cached with a 6-hour TTL and
/// scoped by school + academic year. Feature pages read from the cache instead
/// of making their own network requests.
///
/// Cache invalidation happens via [CacheInvalidationService] — any mutation
/// that affects filter data (e.g., adding a class, teacher, subject) clears
/// the `filter_options_` prefix.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Provides cached, consolidated filter options for all feature pages.
///
/// Usage:
/// ```dart
/// final options = await FilterOptionsService.getFilterOptions(
///   role: 'admin',
///   academicYearId: '...',
/// );
/// final classes = options['classes'] as List;
/// final subjects = options['subjects'] as List;
/// ```
class FilterOptionsService {
  static const Duration _ttl = Duration(hours: 6);

  /// Returns the full filter options map. Tries cache first, falls back to API.
  static Future<Map<String, dynamic>> getFilterOptions({
    required String role,
    String? academicYearId,
  }) async {
    final cacheKey = _buildCacheKey(role, academicYearId);

    // 1. Try cache
    final cached = await LocalCacheService.load(cacheKey, ttl: _ttl);
    if (cached is Map<String, dynamic>) {
      return cached;
    }

    // 2. Fetch from consolidated endpoint
    return _fetchAndCache(role, academicYearId, cacheKey);
  }

  /// Force-refresh: skips cache and fetches fresh data from API.
  static Future<Map<String, dynamic>> refreshFilterOptions({
    required String role,
    String? academicYearId,
  }) async {
    final cacheKey = _buildCacheKey(role, academicYearId);
    return _fetchAndCache(role, academicYearId, cacheKey);
  }

  /// Convenience getters for individual filter categories.
  /// These all call [getFilterOptions] internally (cached).

  static Future<List<dynamic>> getClasses({
    required String role,
    String? academicYearId,
  }) async {
    final data = await getFilterOptions(
      role: role,
      academicYearId: academicYearId,
    );
    return data['classes'] as List<dynamic>? ?? [];
  }

  static Future<List<dynamic>> getSubjects({
    required String role,
    String? academicYearId,
  }) async {
    final data = await getFilterOptions(
      role: role,
      academicYearId: academicYearId,
    );
    return data['subjects'] as List<dynamic>? ?? [];
  }

  static Future<List<dynamic>> getTeachers({
    required String role,
    String? academicYearId,
  }) async {
    final data = await getFilterOptions(
      role: role,
      academicYearId: academicYearId,
    );
    return data['teachers'] as List<dynamic>? ?? [];
  }

  static Future<List<dynamic>> getDays({
    required String role,
    String? academicYearId,
  }) async {
    final data = await getFilterOptions(
      role: role,
      academicYearId: academicYearId,
    );
    return data['days'] as List<dynamic>? ?? [];
  }

  static Future<List<dynamic>> getSemesters({
    required String role,
    String? academicYearId,
  }) async {
    final data = await getFilterOptions(
      role: role,
      academicYearId: academicYearId,
    );
    return data['semesters'] as List<dynamic>? ?? [];
  }

  static Future<List<dynamic>> getAcademicYears({
    required String role,
    String? academicYearId,
  }) async {
    final data = await getFilterOptions(
      role: role,
      academicYearId: academicYearId,
    );
    return data['academic_years'] as List<dynamic>? ?? [];
  }

  static Future<List<dynamic>> getGradeLevels({
    required String role,
    String? academicYearId,
  }) async {
    final data = await getFilterOptions(
      role: role,
      academicYearId: academicYearId,
    );
    return data['grade_levels'] as List<dynamic>? ?? [];
  }

  static Future<List<dynamic>> getGenderOptions({
    required String role,
    String? academicYearId,
  }) async {
    final data = await getFilterOptions(
      role: role,
      academicYearId: academicYearId,
    );
    return data['gender_options'] as List<dynamic>? ?? [];
  }

  static Future<List<dynamic>> getEmploymentStatusOptions({
    required String role,
    String? academicYearId,
  }) async {
    final data = await getFilterOptions(
      role: role,
      academicYearId: academicYearId,
    );
    return data['employment_status_options'] as List<dynamic>? ?? [];
  }

  static Future<List<dynamic>> getAnnouncementRoles({
    required String role,
    String? academicYearId,
  }) async {
    final data = await getFilterOptions(
      role: role,
      academicYearId: academicYearId,
    );
    return data['announcement_roles'] as List<dynamic>? ?? [];
  }

  /// Invalidate all cached filter options (called after mutations).
  static Future<void> invalidateCache() async {
    await LocalCacheService.clearStartingWith('filter_options_');
  }

  // ── Private helpers ──

  static String _buildCacheKey(String role, String? academicYearId) {
    final yearPart = academicYearId ?? 'current';
    return 'filter_options_${role}_$yearPart';
  }

  static Future<Map<String, dynamic>> _fetchAndCache(
    String role,
    String? academicYearId,
    String cacheKey,
  ) async {
    try {
      final queryParams = <String, dynamic>{'role': role};
      if (academicYearId != null && academicYearId.isNotEmpty) {
        queryParams['academic_year_id'] = academicYearId;
      }

      final response = await dioClient.get(
        '/filter-options',
        queryParameters: queryParams,
      );

      final result = response.data;
      if (result is Map<String, dynamic> && result['success'] == true) {
        final data = Map<String, dynamic>.from(result['data'] ?? {});

        // Save to cache (fire-and-forget)
        LocalCacheService.save(cacheKey, data);

        return data;
      }
      return {};
    } catch (e) {
      AppLogger.error(
        'filter_options_service',
        'Error fetching filter options: $e',
      );
      return {};
    }
  }
}
