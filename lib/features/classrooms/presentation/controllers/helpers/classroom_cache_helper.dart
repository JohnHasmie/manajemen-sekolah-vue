import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';

/// Encapsulates cache key building and cache management logic.
class ClassroomCacheHelper {
  final Ref ref;

  const ClassroomCacheHelper(this.ref);

  /// Builds the cache key for the unfiltered, page-1 class list.
  ///
  /// Returns `null` when filters/search/pagination are active — only
  /// caches the clean first-page view.
  String? buildClassCacheKey({
    required int currentPage,
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
    required String searchText,
  }) {
    if (currentPage != 1) return null;
    if (selectedGradeFilter != null ||
        selectedHomeroomFilter != null ||
        searchText.trim().isNotEmpty) {
      return null;
    }

    final academicYearProvider = ref.read(academicYearRiverpod);
    final yearId =
        academicYearProvider.selectedAcademicYear?['id']?.toString() ??
        'default';
    return 'class_list_$yearId';
  }

  /// Clears all classroom-related caches.
  Future<void> clearAllClassroomCaches({
    required int currentPage,
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
    required String searchText,
  }) async {
    final cacheKey = buildClassCacheKey(
      currentPage: 1,
      selectedGradeFilter: selectedGradeFilter,
      selectedHomeroomFilter: selectedHomeroomFilter,
      searchText: searchText,
    );
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await LocalCacheService.clearStartingWith('tour_class_management_');
    await LocalCacheService.invalidate('school_settings');
    await LocalCacheService.invalidate('teachers_all_list');
  }
}
