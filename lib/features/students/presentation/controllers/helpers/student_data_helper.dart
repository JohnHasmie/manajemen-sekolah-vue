import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/filter_options_service.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/students/presentation/controllers/admin_student_controller.dart';

/// Helper class for student data loading operations.
/// Handles loading students, loading more students, loading filter options,
/// and parsing filter options.
class StudentDataHelper {
  /// Loads the first page of students and the class list.
  /// Returns a [StudentLoadResult] — the screen applies it with setState.
  ///
  /// [cacheKeyArgs] encapsulates all current filter/search state so the
  /// controller can decide whether to read/write cache without holding
  /// a reference to the screen's state fields.
  static Future<StudentLoadResult> loadData({
    required Ref ref,
    required bool resetPage,
    required bool useCache,
    required int currentPage,
    required int perPage,
    required List<String> selectedClassIds,
    required String? selectedGradeLevel,
    required String? selectedGenderFilter,
    required String? selectedGuardian,
    required String? selectedStatusFilter,
    required String searchText,
    required String? Function() buildCacheKey,
  }) async {
    try {
      if (resetPage) {
        // ─── Step 1: Try cache — return early on hit ───
        if (useCache) {
          final cacheKey = buildCacheKey();
          if (cacheKey != null) {
            try {
              final cached = await LocalCacheService.load(
                cacheKey,
                ttl: const Duration(hours: 3),
              );
              if (cached != null) {
                final cachedData = Map<String, dynamic>.from(cached);
                AppLogger.info('student', 'Students loaded from cache');
                return StudentLoadResult(
                  students: List<dynamic>.from(cachedData['students'] ?? []),
                  classList: List<dynamic>.from(cachedData['classList'] ?? []),
                  hasMoreData:
                      cachedData['pagination']?['has_next_page'] ?? false,
                  isLoading: false,
                );
              }
            } catch (e) {
              AppLogger.error('student', 'Student cache load failed: $e');
            }
          }
        }
      }

      // ─── Step 2: Fetch fresh data from API ───
      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final response = await getIt<ApiStudentService>().getStudentPaginated(
        page: resetPage ? 1 : currentPage,
        limit: perPage,
        classId: selectedClassIds.isNotEmpty ? selectedClassIds.first : null,
        gradeLevel: selectedGradeLevel,
        gender: selectedGenderFilter,
        academicYearId: selectedYearId,
        guardianName: selectedGuardian,
        status: selectedStatusFilter,
        search: searchText.trim().isEmpty ? null : searchText.trim(),
        useCache: useCache,
      );

      final classData = await getIt<ApiClassService>().getClass();

      // ─── Step 3: Save to cache (non-blocking, only default view) ───
      final cacheKey = buildCacheKey();
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'students': response['data'] ?? [],
          'classList': classData,
          'pagination': response['pagination'],
        });
      }

      return StudentLoadResult(
        students: response['data'] ?? [],
        classList: classData,
        hasMoreData: response['pagination']?['has_next_page'] ?? false,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.error('student', 'Load students/class error: $e');
      return StudentLoadResult(
        students: const [],
        classList: const [],
        hasMoreData: false,
        isLoading: false,
        errorMessage: ErrorUtils.getFriendlyMessage(e),
      );
    }
  }

  /// Loads the next page of students for infinite scroll.
  /// Returns a [StudentLoadMoreResult] — screen appends to its list via
  /// setState.
  static Future<StudentLoadMoreResult?> loadMoreData({
    required Ref ref,
    required int nextPage,
    required int perPage,
    required List<String> selectedClassIds,
    required String? selectedGradeLevel,
    required String? selectedGenderFilter,
    required String? selectedGuardian,
    required String? selectedStatusFilter,
    required String searchText,
  }) async {
    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final response = await getIt<ApiStudentService>().getStudentPaginated(
        page: nextPage,
        limit: perPage,
        classId: selectedClassIds.isNotEmpty ? selectedClassIds.first : null,
        gradeLevel: selectedGradeLevel,
        gender: selectedGenderFilter,
        academicYearId: selectedYearId,
        guardianName: selectedGuardian,
        status: selectedStatusFilter,
        search: searchText.trim().isEmpty ? null : searchText.trim(),
      );

      final itemCount = (response['data'] ?? []).length;
      AppLogger.info(
        'student',
        'Loaded more data: Page $nextPage, items: $itemCount',
      );

      return StudentLoadMoreResult(
        additionalStudents: response['data'] ?? [],
        hasMoreData: response['pagination']?['has_next_page'] ?? false,
      );
    } catch (e) {
      AppLogger.error('student', 'Load more students error: $e');
      return null;
    }
  }

  /// Loads filter options (grade levels + classes) via consolidated endpoint.
  /// Returns [FilterOptionsResult] — screen applies via setState.
  static Future<FilterOptionsResult?> loadFilterOptions() async {
    try {
      final data = await FilterOptionsService.getFilterOptions(
        role: 'admin',
      );

      final gradeCount = (data['grade_levels'] as List?)?.length ?? 0;
      final classCount = (data['classes'] as List?)?.length ?? 0;
      AppLogger.info(
        'student',
        'Filter options loaded: $gradeCount grades, $classCount classes',
      );

      return FilterOptionsResult(
        gradeLevels: List<String>.from(
          (data['grade_levels'] as List?)?.map((e) => e.toString()) ?? [],
        ),
        availableClass: data['classes'] ?? [],
      );
    } catch (e) {
      AppLogger.error('student', 'Error loading filter options: $e');
      return null;
    }
  }
}
