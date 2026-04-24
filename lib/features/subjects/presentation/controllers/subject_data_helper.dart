/// Helper for subject data extraction, caching, and pagination.
/// Handles cache key building, filter option extraction, and data merging.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';

/// Result types — plain objects returned by helper methods.
class SubjectLoadResult {
  final List<dynamic> subjects;
  final bool hasMoreData;
  final bool isLoading;
  final String? errorMessage;

  /// Extracted filter options from the loaded data.
  final List<String> availableClassNames;
  final List<String> availableGradeLevels;

  const SubjectLoadResult({
    required this.subjects,
    required this.hasMoreData,
    required this.isLoading,
    required this.availableClassNames,
    required this.availableGradeLevels,
    this.errorMessage,
  });

  /// Convenience constructor for error-only results.
  SubjectLoadResult.failure(String message)
    : subjects = const [],
      hasMoreData = false,
      isLoading = false,
      availableClassNames = const [],
      availableGradeLevels = const [],
      errorMessage = message;
}

class SubjectLoadMoreResult {
  final List<dynamic> additionalSubjects;
  final bool hasMoreData;
  final List<String> availableClassNames;
  final List<String> availableGradeLevels;
  final String? errorMessage;

  const SubjectLoadMoreResult({
    required this.additionalSubjects,
    required this.hasMoreData,
    required this.availableClassNames,
    required this.availableGradeLevels,
    this.errorMessage,
  });
}

class SubjectFilterOptionsResult {
  final bool success;

  const SubjectFilterOptionsResult({required this.success});
}

/// Pure data helper — no state management, pure functions and API calls.
class SubjectDataHelper {
  /// Builds the local-cache key for the default first-page subject list.
  /// Returns null when any filter or search term is active.
  static String? buildSubjectCacheKey(
    Ref ref, {
    required int currentPage,
    required String? selectedStatusFilter,
    required String? selectedGradeLevelFilter,
    required String? selectedClassesStatusFilter,
    required String? selectedClassNameFilter,
    required String searchText,
  }) {
    if (currentPage != 1) return null;
    if (selectedStatusFilter != null ||
        selectedGradeLevelFilter != null ||
        selectedClassesStatusFilter != null ||
        selectedClassNameFilter != null ||
        searchText.trim().isNotEmpty) {
      return null;
    }

    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return CacheKeyBuilder.custom('subject_list', yearId);
  }

  /// Extracts unique class names and grade levels from a subject list.
  /// Returns `(classNames, gradeLevels)` sorted appropriately.
  static ({List<String> classNames, List<String> gradeLevels})
  extractFilterOptions(List<dynamic> subjects) {
    final Set<String> classNamesSet = {};
    final Set<String> gradeLevelsSet = {};

    for (final subject in subjects) {
      final model = Subject.fromJson(subject as Map<String, dynamic>);
      classNamesSet.addAll(model.classNameList);

      // grade_levels not in Subject model — still raw
      final gradeLevels =
          (subject['class_grade_levels'] ?? subject['kelas_grade_levels'])
              ?.toString() ??
          '';
      if (gradeLevels.isNotEmpty) {
        gradeLevelsSet.addAll(
          gradeLevels
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty),
        );
      }
    }

    return (
      classNames: classNamesSet.toList()..sort(),
      gradeLevels: gradeLevelsSet.toList()
        ..sort((a, b) {
          final aInt = int.tryParse(a) ?? 0;
          final bInt = int.tryParse(b) ?? 0;
          return aInt.compareTo(bInt);
        }),
    );
  }

  /// Loads the first page of subjects. Cache-first: tries local cache,
  /// then falls back to API.
  static Future<SubjectLoadResult> loadSubjects({
    required String? selectedStatusFilter,
    required String? selectedGradeLevelFilter,
    required String? selectedClassesStatusFilter,
    required String? selectedClassNameFilter,
    required String searchText,
    required int perPage,
    required Ref ref,
    bool useCache = true,
  }) async {
    SubjectLoadResult? cacheResult;

    try {
      // Step 1: Try cache for instant display
      if (useCache) {
        final cacheKey = buildSubjectCacheKey(
          ref,
          currentPage: 1,
          selectedStatusFilter: selectedStatusFilter,
          selectedGradeLevelFilter: selectedGradeLevelFilter,
          selectedClassesStatusFilter: selectedClassesStatusFilter,
          selectedClassNameFilter: selectedClassNameFilter,
          searchText: searchText,
        );

        if (cacheKey != null) {
          try {
            final cached = await LocalCacheService.load(
              cacheKey,
              ttl: const Duration(hours: 3),
            );
            if (cached != null) {
              final cachedData = Map<String, dynamic>.from(cached);
              final subjects = List<dynamic>.from(cachedData['subjects'] ?? []);
              if (subjects.isNotEmpty) {
                AppLogger.info('subject', 'Subjects loaded from cache');
                final options = extractFilterOptions(subjects);
                cacheResult = SubjectLoadResult(
                  subjects: subjects,
                  hasMoreData:
                      cachedData['pagination']?['has_next_page'] ?? false,
                  isLoading: false,
                  availableClassNames: options.classNames,
                  availableGradeLevels: options.gradeLevels,
                );
                return cacheResult;
              }
            }
          } catch (e) {
            AppLogger.error('subject', 'Subject cache load failed: $e');
          }
        }
      }

      // Step 2: Fetch fresh data from API
      final ayId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();
      final response = await getIt<ApiSubjectService>().getSubjectsPaginated(
        page: 1,
        limit: perPage,
        status: selectedStatusFilter,
        gradeLevel: selectedGradeLevelFilter,
        search: searchText.trim().isEmpty ? null : searchText.trim(),
        academicYearId: ayId,
      );

      final data = List<dynamic>.from(response['data'] ?? []);
      AppLogger.info('subject', 'Subjects received: ${data.length} items');

      final options = extractFilterOptions(data);

      // Step 3: Persist to cache (only default view)
      final cacheKey = buildSubjectCacheKey(
        ref,
        currentPage: 1,
        selectedStatusFilter: selectedStatusFilter,
        selectedGradeLevelFilter: selectedGradeLevelFilter,
        selectedClassesStatusFilter: selectedClassesStatusFilter,
        selectedClassNameFilter: selectedClassNameFilter,
        searchText: searchText,
      );
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'subjects': data,
          'pagination': response['pagination'],
        });
      }

      return SubjectLoadResult(
        subjects: data,
        hasMoreData: response['pagination']?['has_next_page'] ?? false,
        isLoading: false,
        availableClassNames: options.classNames,
        availableGradeLevels: options.gradeLevels,
      );
    } catch (error) {
      AppLogger.error('subject', 'Load subjects error: $error');
      if (cacheResult != null) {
        return SubjectLoadResult(
          subjects: cacheResult.subjects,
          hasMoreData: cacheResult.hasMoreData,
          isLoading: false,
          availableClassNames: cacheResult.availableClassNames,
          availableGradeLevels: cacheResult.availableGradeLevels,
          errorMessage: ErrorUtils.getFriendlyMessage(error),
        );
      }
      return SubjectLoadResult.failure(ErrorUtils.getFriendlyMessage(error));
    }
  }

  /// Loads the next page and merges filter options with existing sets.
  static Future<SubjectLoadMoreResult> loadMoreSubjects({
    required int nextPage,
    required int perPage,
    required String? selectedStatusFilter,
    required String? selectedGradeLevelFilter,
    required String searchText,
    required List<String> existingClassNames,
    required List<String> existingGradeLevels,
    String? academicYearId,
  }) async {
    try {
      final response = await getIt<ApiSubjectService>().getSubjectsPaginated(
        page: nextPage,
        limit: perPage,
        status: selectedStatusFilter,
        gradeLevel: selectedGradeLevelFilter,
        search: searchText.trim().isEmpty ? null : searchText.trim(),
        academicYearId: academicYearId,
      );

      final data = List<dynamic>.from(response['data'] ?? []);

      // Merge new filter option values into the existing sets
      final classNamesSet = Set<String>.from(existingClassNames);
      final gradeLevelsSet = Set<String>.from(existingGradeLevels);

      for (final subject in data) {
        final model = Subject.fromJson(subject as Map<String, dynamic>);
        classNamesSet.addAll(model.classNameList);

        final classGradeLevels =
            subject['kelas_grade_levels']?.toString() ?? '';
        if (classGradeLevels.isNotEmpty) {
          gradeLevelsSet.addAll(
            classGradeLevels
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty),
          );
        }
      }

      AppLogger.info(
        'subject',
        'Loaded more subjects: Page $nextPage, Count: ${data.length}',
      );

      return SubjectLoadMoreResult(
        additionalSubjects: data,
        hasMoreData: response['pagination']?['has_next_page'] ?? false,
        availableClassNames: classNamesSet.toList()..sort(),
        availableGradeLevels: gradeLevelsSet.toList()
          ..sort((a, b) {
            final aInt = int.tryParse(a) ?? 0;
            final bInt = int.tryParse(b) ?? 0;
            return aInt.compareTo(bInt);
          }),
      );
    } catch (e) {
      AppLogger.error('subject', 'Error loading more subjects: $e');
      return SubjectLoadMoreResult(
        additionalSubjects: const [],
        hasMoreData: true,
        availableClassNames: existingClassNames,
        availableGradeLevels: existingGradeLevels,
        errorMessage: ErrorUtils.getFriendlyMessage(e),
      );
    }
  }

  /// Invalidates the subject cache for a given filter combination.
  static Future<void> invalidateSubjectCache(
    Ref ref, {
    required String? selectedStatusFilter,
    required String? selectedGradeLevelFilter,
    required String? selectedClassesStatusFilter,
    required String? selectedClassNameFilter,
    required String searchText,
  }) async {
    final cacheKey = buildSubjectCacheKey(
      ref,
      currentPage: 1,
      selectedStatusFilter: selectedStatusFilter,
      selectedGradeLevelFilter: selectedGradeLevelFilter,
      selectedClassesStatusFilter: selectedClassesStatusFilter,
      selectedClassNameFilter: selectedClassNameFilter,
      searchText: searchText,
    );
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
  }

  /// Loads filter options from the API (currently placeholder).
  static Future<SubjectFilterOptionsResult> loadFilterOptions() async {
    try {
      final response = await getIt<ApiSubjectService>()
          .getSubjectFilterOptions();
      if (response['success'] == true && response['data'] != null) {
        AppLogger.info('subject', 'Filter options loaded');
      }
      return const SubjectFilterOptionsResult(success: true);
    } catch (e) {
      AppLogger.error('subject', 'Error loading filter options: $e');
      return const SubjectFilterOptionsResult(success: false);
    }
  }

  /// Loads master subjects (predefined templates).
  static Future<List<dynamic>> loadMasterSubjects() async {
    try {
      final data = await getIt<ApiSubjectService>().getAllMasterSubjects();
      AppLogger.info('subject', 'Master Subjects Loaded: ${data.length} items');
      return data;
    } catch (e) {
      AppLogger.error('subject', 'Error loading master subjects: $e');
      return const [];
    }
  }
}
