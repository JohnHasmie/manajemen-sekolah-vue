import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';

/// Helper class for student cache operations.
/// Handles cache key building, cache invalidation, and cache management.
class StudentCacheHelper {
  /// Returns the cache key for the current first-page default view, or null
  /// if any filter/search is active (those results are not cached).
  /// Only caches page-1, no-filter views — like HTTP cache-control: max-age.
  static String? buildStudentCacheKey({
    required Ref ref,
    required int currentPage,
    required List<String> selectedClassIds,
    required String? selectedGradeLevel,
    required String? selectedGenderFilter,
    required String? selectedGuardian,
    required String? selectedStatusFilter,
    required String searchText,
  }) {
    if (currentPage != 1) return null;
    if (selectedClassIds.isNotEmpty ||
        selectedGradeLevel != null ||
        selectedGenderFilter != null ||
        selectedGuardian != null ||
        selectedStatusFilter != null ||
        searchText.trim().isNotEmpty) {
      return null;
    }
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return CacheKeyBuilder.custom('student_list', yearId);
  }

  /// Force-refresh: clears relevant caches then triggers a full reload.
  /// The screen passes current filter state so buildStudentCacheKey can find
  /// the right key.
  static Future<void> forceRefreshCaches({
    required Ref ref,
    required int currentPage,
    required List<String> selectedClassIds,
    required String? selectedGradeLevel,
    required String? selectedGenderFilter,
    required String? selectedGuardian,
    required String? selectedStatusFilter,
    required String searchText,
  }) async {
    final cacheKey = buildStudentCacheKey(
      ref: ref,
      currentPage: currentPage,
      selectedClassIds: selectedClassIds,
      selectedGradeLevel: selectedGradeLevel,
      selectedGenderFilter: selectedGenderFilter,
      selectedGuardian: selectedGuardian,
      selectedStatusFilter: selectedStatusFilter,
      searchText: searchText,
    );
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await LocalCacheService.invalidate(
      CacheKeyBuilder.custom('student', 'filter_options'),
    );
  }
}
