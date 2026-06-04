import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/classrooms/data/'
    'classroom_service.dart';
import 'package:manajemensekolah/features/settings/data/'
    'settings_service.dart';
import 'package:manajemensekolah/features/teachers/data/'
    'teacher_service.dart';

/// Result object returned by data loading operations.
class ClassLoadResult {
  final List<dynamic> classes;
  final bool hasMoreData;
  final bool isLoading;
  final String? errorMessage;

  const ClassLoadResult({
    required this.classes,
    required this.hasMoreData,
    this.isLoading = false,
    this.errorMessage,
  });
}

/// Result returned by school settings load.
class SchoolSettingsResult {
  final String? jenjang;
  final List<String> gradeLevels;

  const SchoolSettingsResult({
    required this.jenjang,
    required this.gradeLevels,
  });
}

/// Encapsulates data loading and API operations.
class ClassroomDataService {
  final Function(String?) _generateGradeLevels;

  ClassroomDataService({required Function(String?) generateGradeLevels})
    : _generateGradeLevels = generateGradeLevels;

  /// Loads school settings with cache-first strategy.
  ///
  /// Pass [forceRefresh] to bypass the cache and re-read the live
  /// `education_level` from the API — used when opening the add/edit form so
  /// the "tingkat" dropdown is always constrained to the school's current
  /// jenjang instead of a possibly-stale cached blob.
  Future<SchoolSettingsResult> loadSchoolSettings({
    bool forceRefresh = false,
  }) async {
    const cacheKey = 'school_settings';

    try {
      final cached = forceRefresh
          ? null
          : await LocalCacheService.load(
              cacheKey,
              ttl: const Duration(hours: 24),
            );
      if (cached != null) {
        // Backend rename: `schools.jenjang` → `schools.education_level`.
        final jenjang =
            (cached['education_level'] ?? cached['jenjang']) as String?;
        AppLogger.info('classroom', 'School settings loaded from cache');
        return SchoolSettingsResult(
          jenjang: jenjang,
          gradeLevels: _generateGradeLevels(jenjang),
        );
      }
    } catch (e) {
      AppLogger.error('classroom', 'School settings cache load failed: $e');
    }

    try {
      final settings = await getIt<ApiSettingsService>().getSchoolSettings();
      final jenjang =
          (settings['education_level'] ?? settings['jenjang']) as String?;
      LocalCacheService.save(cacheKey, settings);
      return SchoolSettingsResult(
        jenjang: jenjang,
        gradeLevels: _generateGradeLevels(jenjang),
      );
    } catch (e) {
      AppLogger.error('classroom', 'Error loading school settings: $e');
      return SchoolSettingsResult(
        jenjang: null,
        gradeLevels: _generateGradeLevels(null),
      );
    }
  }

  /// Loads the full teacher list with cache-first strategy.
  Future<List<dynamic>> fetchTeachers() async {
    const cacheKey = 'teachers_all_list';

    try {
      final cached = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(hours: 6),
      );
      if (cached != null) {
        final teachers = List<dynamic>.from(cached);
        AppLogger.info(
          'classroom',
          'Teachers list loaded from cache (${teachers.length})',
        );
        return teachers;
      }
    } catch (e) {
      AppLogger.error('classroom', 'Teachers list cache load failed: $e');
    }

    final response = await getIt<ApiTeacherService>().getTeachersPaginated(
      limit: 1000,
    );
    final teachers = List<dynamic>.from(response['data'] ?? []);
    LocalCacheService.save(cacheKey, teachers);
    AppLogger.info(
      'classroom',
      'Loaded ${teachers.length} teachers for wali kelas selection',
    );
    return teachers;
  }

  /// Loads paginated class list from cache then API.
  Future<ClassLoadResult> loadData({
    required int currentPage,
    required int perPage,
    required List<dynamic> existingClasses,
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
    required String searchText,
    required String? selectedYearId,
    required String? cacheKey,
    required bool resetPage,
    required bool useCache,
  }) async {
    try {
      if (resetPage && useCache && cacheKey != null) {
        try {
          final cached = await LocalCacheService.load(
            cacheKey,
            ttl: const Duration(hours: 3),
          );
          if (cached != null) {
            final cachedData = Map<String, dynamic>.from(cached);
            AppLogger.info('classroom', 'Classes loaded from cache');
            return ClassLoadResult(
              classes: List<dynamic>.from(cachedData['classes'] ?? []),
              hasMoreData: cachedData['pagination']?['has_next_page'] ?? false,
              isLoading: false,
            );
          }
        } catch (e) {
          AppLogger.error('classroom', 'Class cache load failed: $e');
        }
      }

      final int page = resetPage ? 1 : currentPage;

      final response = await getIt<ApiClassService>().getClassPaginated(
        page: page,
        limit: perPage,
        gradeLevel: selectedGradeFilter,
        hasHomeroomTeacher: selectedHomeroomFilter,
        academicYearId: selectedYearId,
        search: searchText.trim().isEmpty ? null : searchText.trim(),
        useCache: useCache,
      );

      if (cacheKey != null && resetPage) {
        LocalCacheService.save(cacheKey, {
          'classes': response['data'] ?? [],
          'pagination': response['pagination'],
        });
      }

      return ClassLoadResult(
        classes: List<dynamic>.from(response['data'] ?? []),
        hasMoreData: response['pagination']?['has_next_page'] ?? false,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.error('classroom', 'Load classes error: $e');
      return ClassLoadResult(
        classes: resetPage ? [] : existingClasses,
        hasMoreData: false,
        isLoading: false,
        errorMessage: existingClasses.isEmpty
            ? ErrorUtils.getFriendlyMessage(e)
            : null,
      );
    }
  }

  /// Loads the next page of classes.
  Future<ClassLoadResult> loadMoreData({
    required int nextPage,
    required int perPage,
    required List<dynamic> existingClasses,
    required String? selectedGradeFilter,
    required String? selectedHomeroomFilter,
    required String searchText,
    required String? selectedYearId,
  }) async {
    try {
      final response = await getIt<ApiClassService>().getClassPaginated(
        page: nextPage,
        limit: perPage,
        gradeLevel: selectedGradeFilter,
        hasHomeroomTeacher: selectedHomeroomFilter,
        academicYearId: selectedYearId,
        search: searchText.trim().isEmpty ? null : searchText.trim(),
      );

      final newItems = List<dynamic>.from(response['data'] ?? []);
      AppLogger.info(
        'classroom',
        'Loaded more data: Page $nextPage, New items: ${newItems.length}',
      );

      return ClassLoadResult(
        classes: [...existingClasses, ...newItems],
        hasMoreData: response['pagination']?['has_next_page'] ?? false,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.error('classroom', 'Error loading more data: $e');
      return ClassLoadResult(
        classes: existingClasses,
        hasMoreData: true,
        isLoading: false,
        errorMessage: ErrorUtils.getFriendlyMessage(e),
      );
    }
  }

  /// Deletes a class via the API.
  Future<void> deleteClass(String classId) async {
    await getIt<ApiClassService>().deleteClass(classId);
  }
}
