import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart'
    as classroom_service;
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart'
    as teacher_service;
import 'package:manajemensekolah/features/grades/presentation/controllers/teacher_grade_state.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/helpers/cache_helper.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/helpers/sorting_helper.dart';

/// Helper for loading classes with caching and sorting.
class ClassLoaderHelper {
  /// Loads classes from cache, provider, or API.
  static Future<TeacherGradeState> loadClasses({
    required TeacherGradeState currentState,
    required Ref ref,
    required dynamic teacherId,
    required String teacherRole,
    bool resetPage = true,
    bool useCache = true,
  }) async {
    final isTeacher =
        teacherRole.contains('guru') || teacherRole.contains('teacher');

    final int page = resetPage ? 1 : currentState.currentPage;
    final List<dynamic> classList = resetPage
        ? []
        : List.from(currentState.classList);

    if (resetPage) {
      // 1. Try TeacherProvider
      if (isTeacher && useCache) {
        final teacherProvider = ref.read(teacherRiverpod);
        if (teacherProvider.isLoaded && teacherProvider.allClasses.isNotEmpty) {
          final List<dynamic> providerClasses = List.from(
            teacherProvider.allClasses,
          );
          SortingHelper.sortClassesByTodaySchedule(
            providerClasses,
            currentState.todaySchedules,
          );
          return currentState.copyWith(
            classList: providerClasses,
            hasMoreData: false,
            isLoading: false,
          );
        }
      }

      // 2. Try Cache
      if (useCache) {
        final cacheKey = CacheHelper.buildClassCacheKey(
          page,
          currentState.searchQuery,
          ref,
          teacherId,
        );
        if (cacheKey != null) {
          final cached = await LocalCacheService.load(
            cacheKey,
            ttl: const Duration(hours: 3),
          );
          if (cached != null) {
            final cachedData = Map<String, dynamic>.from(cached);
            final cachedClasses = List<dynamic>.from(
              cachedData['classes'] ?? [],
            );
            if (cachedClasses.isNotEmpty) {
              return currentState.copyWith(
                classList: cachedClasses,
                hasMoreData: cachedData['hasMoreData'] ?? false,
                isLoading: false,
              );
            }
          }
        }
      }
    }

    // 3. API
    try {
      final academicYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();
      List<dynamic> loadedClasses = [];
      bool hasMore = false;

      if (isTeacher) {
        loadedClasses = await getIt<teacher_service.ApiTeacherService>()
            .getTeacherClasses(teacherId, academicYearId: academicYearId);
        hasMore = false;
      } else {
        final response = await getIt<classroom_service.ApiClassService>()
            .getClassPaginated(
              page: page,
              limit: 20,
              academicYearId: academicYearId,
              search: currentState.searchQuery,
            );
        loadedClasses = response['data'] ?? [];
        hasMore = response['pagination']?['has_next_page'] ?? false;
      }

      SortingHelper.sortClassesByTodaySchedule(
        loadedClasses,
        currentState.todaySchedules,
      );

      final newList = resetPage
          ? loadedClasses
          : [...classList, ...loadedClasses];

      // Save to cache
      if (resetPage) {
        final cacheKey = CacheHelper.buildClassCacheKey(
          1,
          currentState.searchQuery,
          ref,
          teacherId,
        );
        if (cacheKey != null) {
          LocalCacheService.save(cacheKey, {
            'classes': loadedClasses,
            'hasMoreData': hasMore,
          });
        }
      }

      return currentState.copyWith(
        classList: newList,
        hasMoreData: hasMore,
        isLoading: false,
        isLoadingMore: false,
        currentPage: page,
      );
    } catch (e) {
      AppLogger.error('grades', e);
      return currentState.copyWith(isLoading: false, isLoadingMore: false);
    }
  }
}
