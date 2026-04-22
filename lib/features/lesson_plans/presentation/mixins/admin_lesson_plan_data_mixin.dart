import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';
import 'package:manajemensekolah/features/lesson_plans/exports/lesson_plan_export_service.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/admin_lesson_plan_screen.dart';

mixin AdminLessonPlanDataMixin on ConsumerState<AdminLessonPlanScreen> {
  // Abstract getters and setters for state fields
  List<dynamic> get lessonPlanList;
  set lessonPlanList(List<dynamic> v);

  List<dynamic> get teacherList;
  set teacherList(List<dynamic> v);

  bool get isLoading;
  set isLoading(bool v);

  String? get errorMessage;
  set errorMessage(String? v);

  int get currentPage;
  set currentPage(int v);

  int get perPage;

  bool get isLoadingMore;
  set isLoadingMore(bool v);

  bool get hasMoreData;
  set hasMoreData(bool v);

  String? get selectedTeacherId;

  String? get selectedStatusFilter;

  TextEditingController get searchController;

  bool get showTeacherList;

  // Cache key methods
  String? buildTeacherCacheKey() {
    if (currentPage != 1) return null;
    if (searchController.text.trim().isNotEmpty) return null;
    return 'rpp_teacher_list';
  }

  String? buildLessonPlanCacheKey() {
    if (currentPage != 1) return null;
    if (selectedStatusFilter != null ||
        searchController.text.trim().isNotEmpty) {
      return null;
    }
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return 'rpp_list_${selectedTeacherId}_$yearId';
  }

  // Force refresh method
  Future<void> forceRefresh() async {
    await LocalCacheService.clearStartingWith('tour_rpp_screen_');
    if (showTeacherList && widget.teacherId == null) {
      final cacheKey = buildTeacherCacheKey();
      if (cacheKey != null) await LocalCacheService.invalidate(cacheKey);
      loadTeachersPaginated(reset: true, useCache: false);
    } else {
      final cacheKey = buildLessonPlanCacheKey();
      if (cacheKey != null) await LocalCacheService.invalidate(cacheKey);
      loadLessonPlansPaginated(reset: true, useCache: false);
    }
  }

  // Export to Excel method
  Future<void> exportToExcel() async {
    await ExcelLessonPlanService.exportLessonPlansToExcel(
      lessonPlanList: lessonPlanList,
      context: context,
    );
  }

  // Load lesson plans by teacher
  Future<void> loadLessonPlansByTeacher() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      await loadLessonPlansPaginated(reset: true, useCache: false);
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  // Load all lesson plans
  Future<void> loadAllLessonPlans() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      await loadLessonPlansPaginated(reset: true, useCache: false);
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  // Load teachers paginated
  Future<void> loadTeachersPaginated({
    bool reset = false,
    bool useCache = true,
  }) async {
    try {
      if (reset) {
        currentPage = 1;
        hasMoreData = true;
      }

      // Step 1: Try cache for instant display (only on reset/first load)
      if (useCache && reset) {
        final cacheKey = buildTeacherCacheKey();
        if (cacheKey != null) {
          final cached = await LocalCacheService.load(cacheKey);
          if (cached != null && cached['data'] != null && mounted) {
            final cachedList = cached['data'] as List<dynamic>;
            if (cachedList.isNotEmpty) {
              setState(() {
                teacherList = cachedList;
                hasMoreData = cached['hasMoreData'] ?? true;
                isLoading = false;
              });
              AppLogger.info('lesson_plan', 'Teacher list loaded from cache');
              return;
            }
          }
        }
      }

      // Show skeleton only if list is empty
      if (reset && teacherList.isEmpty && mounted) {
        setState(() {
          isLoading = true;
          errorMessage = null;
        });
      } else if (!reset) {
        setState(() {
          isLoadingMore = true;
        });
      }

      // Step 2: Fetch fresh from API
      final result = await getIt<ApiTeacherService>().getTeachersPaginated(
        page: currentPage,
        limit: perPage,
        search: searchController.text.isNotEmpty ? searchController.text : null,
      );

      if (result['success'] == true || result['data'] != null) {
        final List<dynamic> data = result['data'] ?? [];
        final pagination = result['pagination'] ?? {};

        if (mounted) {
          setState(() {
            if (reset) {
              teacherList = data;
            } else {
              teacherList.addAll(data);
            }

            hasMoreData =
                pagination['has_next_page'] ?? (data.length == perPage);
            isLoading = false;
            isLoadingMore = false;
          });

          // Step 3: Save to cache (only page 1 default view, non-blocking)
          if (reset) {
            final cacheKey = buildTeacherCacheKey();
            if (cacheKey != null) {
              LocalCacheService.save(cacheKey, {
                'data': data,
                'hasMoreData': hasMoreData,
              });
            }
          }
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
            isLoadingMore = false;
            if (teacherList.isEmpty) {
              errorMessage = 'Failed to load teachers';
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          isLoadingMore = false;
          if (teacherList.isEmpty) {
            errorMessage = ErrorUtils.getFriendlyMessage(e);
          }
        });
      }
    }
  }

  // Load lesson plans paginated
  Future<void> loadLessonPlansPaginated({
    bool reset = false,
    bool useCache = true,
  }) async {
    try {
      if (reset) {
        currentPage = 1;
        hasMoreData = true;
      }

      // Step 1: Try cache for instant display (only on reset/first load)
      if (useCache && reset) {
        final cacheKey = buildLessonPlanCacheKey();
        if (cacheKey != null) {
          final cached = await LocalCacheService.load(cacheKey);
          if (cached != null && cached['data'] != null && mounted) {
            final cachedList = cached['data'] as List<dynamic>;
            if (cachedList.isNotEmpty) {
              setState(() {
                lessonPlanList = cachedList;
                hasMoreData = cached['hasMoreData'] ?? true;
                isLoading = false;
              });
              AppLogger.info('lesson_plan', 'RPP list loaded from cache');
              return;
            }
          }
        }
      }

      // Show skeleton only if list is empty
      if (reset && lessonPlanList.isEmpty && mounted) {
        setState(() {
          isLoading = true;
          errorMessage = null;
        });
      } else if (!reset) {
        setState(() {
          isLoadingMore = true;
        });
      }

      // Step 2: Fetch fresh from API
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final result = await LessonPlanService.getLessonPlansPaginated(
        page: currentPage,
        limit: perPage,
        teacherId: selectedTeacherId,
        status: selectedStatusFilter,
        search: searchController.text.isNotEmpty ? searchController.text : null,
        academicYearId: academicYearId,
      );

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        final pagination = result['pagination'] ?? {};

        if (mounted) {
          setState(() {
            if (reset) {
              lessonPlanList = data;
            } else {
              lessonPlanList.addAll(data);
            }

            hasMoreData =
                pagination['has_next_page'] ?? (data.length == perPage);
            isLoading = false;
            isLoadingMore = false;
          });

          // Step 3: Save to cache (only page 1 default view, non-blocking)
          if (reset) {
            final cacheKey = buildLessonPlanCacheKey();
            if (cacheKey != null) {
              LocalCacheService.save(cacheKey, {
                'data': data,
                'hasMoreData': hasMoreData,
              });
            }
          }
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
            isLoadingMore = false;
            if (lessonPlanList.isEmpty) {
              errorMessage = 'Failed to load RPP';
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          isLoadingMore = false;
          if (lessonPlanList.isEmpty) {
            errorMessage = ErrorUtils.getFriendlyMessage(e);
          }
        });
      }
    }
  }
}
