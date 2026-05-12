import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/class_activity/exports/class_activity_export_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/admin_class_activity_screen.dart';

/// Mixin providing data loading methods for class activities.
mixin ClassActivityDataMixin on ConsumerState<AdminClassActivityScreen> {
  List<dynamic> get teacherList;
  set teacherList(List<dynamic> value);

  List<dynamic> get subjectList;
  set subjectList(List<dynamic> value);

  List<dynamic> get activityList;
  set activityList(List<dynamic> value);

  bool get isLoading;
  set isLoading(bool value);

  String? get selectedTeacherId;
  set selectedTeacherId(String? value);

  String? get selectedTeacherName;
  set selectedTeacherName(String? value);

  String? get selectedSubjectId;
  set selectedSubjectId(String? value);

  String? get selectedSubjectName;
  set selectedSubjectName(String? value);

  bool get showTeacherList;
  set showTeacherList(bool value);

  bool get showSubjectList;
  set showSubjectList(bool value);

  String? get errorMessage;
  set errorMessage(String? value);

  TextEditingController get searchController;

  Future<void> forceRefresh() async {
    if (showTeacherList) {
      final cacheKey = buildTeacherCacheKey();
      if (cacheKey != null) await LocalCacheService.invalidate(cacheKey);
      await loadTeachers(useCache: false);
    } else if (showSubjectList) {
      final cacheKey = buildSubjectCacheKey();
      if (cacheKey != null) await LocalCacheService.invalidate(cacheKey);
      await loadSubjectsByTeacher(
        selectedTeacherId!,
        selectedTeacherName!,
        useCache: false,
      );
    } else {
      final cacheKey = buildActivityCacheKey();
      if (cacheKey != null) await LocalCacheService.invalidate(cacheKey);
      await loadActivitiesBySubject(
        selectedSubjectId!,
        selectedSubjectName!,
        useCache: false,
      );
    }
  }

  String? buildTeacherCacheKey() {
    if (searchController.text.trim().isNotEmpty) return null;
    return 'class_activity_teachers';
  }

  String? buildSubjectCacheKey() {
    if (selectedTeacherId == null) return null;
    if (searchController.text.trim().isNotEmpty) return null;
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return 'class_activity_subjects_${selectedTeacherId}_$yearId';
  }

  String? buildActivityCacheKey() {
    if (selectedTeacherId == null || selectedSubjectId == null) return null;
    if (searchController.text.trim().isNotEmpty) return null;
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return 'class_activity_list_${selectedTeacherId}_'
        '${selectedSubjectId}_$yearId';
  }

  Future<void> loadTeachers({bool useCache = true}) async {
    try {
      errorMessage = null;

      // Try cache for instant display
      if (useCache) {
        final cacheKey = buildTeacherCacheKey();
        if (cacheKey != null) {
          final cached = await LocalCacheService.load(cacheKey);
          if (cached != null && cached['data'] != null && mounted) {
            final cachedList = cached['data'] as List<dynamic>;
            if (cachedList.isNotEmpty) {
              setState(() {
                teacherList = cachedList;
                isLoading = false;
              });
              AppLogger.info(
                'class_activity',
                'Class activity teachers loaded from cache',
              );
              // Don't return — continue fetching fresh data from API
            }
          }
        }
      }

      // Show skeleton only if list is still empty (no cache hit)
      if (teacherList.isEmpty && mounted) {
        setState(() {
          isLoading = true;
        });
      }

      // Fetch fresh from API
      final apiTeacherService = getIt<ApiTeacherService>();
      final teachers = await apiTeacherService.getTeacher();

      if (!mounted) return;

      setState(() {
        teacherList = teachers;
        isLoading = false;
      });

      // Save to cache
      final cacheKey = buildTeacherCacheKey();
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {'data': teachers});
      }

      // Trigger tour after teachers are loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {});
    } catch (e) {
      if (mounted) {
        if (teacherList.isEmpty) {
          setState(() {
            isLoading = false;
            errorMessage = ErrorUtils.getFriendlyMessage(e);
          });
        } else {
          setState(() {
            isLoading = false;
          });
        }
        showErrorSnackBar(
          '${AppLocalizations.failedToLoad.tr}: '
          '${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  Future<void> exportActivities() async {
    if (activityList.isEmpty) {
      SnackBarUtils.showWarning(context, AppLocalizations.noDataToExport.tr);
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await ExcelClassActivityService.exportClassActivitiesToExcel(
        activities: activityList,
        context: context,
      );
    } catch (e) {
      AppLogger.error('class_activity', e);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> loadSubjectsByTeacher(
    String teacherId,
    String teacherName, {
    bool useCache = true,
  }) async {
    try {
      errorMessage = null;
      selectedTeacherId = teacherId;
      selectedTeacherName = teacherName;
      showTeacherList = false;
      showSubjectList = true;

      // Try cache for instant display
      if (useCache) {
        final cacheKey = buildSubjectCacheKey();
        if (cacheKey != null) {
          final cached = await LocalCacheService.load(cacheKey);
          if (cached != null && cached['data'] != null && mounted) {
            final cachedList = cached['data'] as List<dynamic>;
            if (cachedList.isNotEmpty) {
              setState(() {
                subjectList = cachedList;
                isLoading = false;
              });
              AppLogger.info(
                'class_activity',
                'Class activity subjects loaded from cache',
              );
              // Don't return — continue fetching fresh data from API
            }
          }
        }
      }

      // Show skeleton only if list is still empty (no cache hit)
      if (subjectList.isEmpty && mounted) {
        setState(() {
          isLoading = true;
        });
      }

      // Fetch fresh from API
      final academicYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      final response = await getIt<ApiTeacherService>()
          .getSubjectsByTeacherPaginated(
            teacherId: teacherId,
            academicYearId: academicYearId,
          );

      if (!mounted) return;

      setState(() {
        subjectList = response['data'] ?? [];
        isLoading = false;
      });

      // Save to cache
      final cacheKey = buildSubjectCacheKey();
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {'data': response['data'] ?? []});
      }
    } catch (e) {
      if (mounted) {
        if (subjectList.isEmpty) {
          setState(() {
            isLoading = false;
            errorMessage = ErrorUtils.getFriendlyMessage(e);
          });
        } else {
          setState(() {
            isLoading = false;
          });
        }
        showErrorSnackBar(
          '${AppLocalizations.failedToLoad.tr}: '
          '${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  Future<void> loadActivitiesBySubject(
    String subjectId,
    String subjectName, {
    bool useCache = true,
  }) async {
    try {
      errorMessage = null;
      selectedSubjectId = subjectId;
      selectedSubjectName = subjectName;
      showSubjectList = false;

      // Try cache for instant display
      if (useCache) {
        final cacheKey = buildActivityCacheKey();
        if (cacheKey != null) {
          final cached = await LocalCacheService.load(cacheKey);
          if (cached != null && cached['data'] != null && mounted) {
            final cachedList = cached['data'] as List<dynamic>;
            if (cachedList.isNotEmpty) {
              setState(() {
                activityList = cachedList;
                isLoading = false;
              });
              AppLogger.info(
                'class_activity',
                'Class activities loaded from cache',
              );
              // Don't return — continue fetching fresh data from API
            }
          }
        }
      }

      // Show skeleton only if list is still empty (no cache hit)
      if (activityList.isEmpty && mounted) {
        setState(() {
          isLoading = true;
        });
      }

      // Fetch fresh from API
      final academicYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      final response = await getIt<ApiClassActivityService>()
          .getClassActivityPaginated(
            teacherId: selectedTeacherId,
            subjectId: subjectId,
            academicYearId: academicYearId,
          );

      if (!mounted) return;

      setState(() {
        activityList = response['data'] ?? [];
        isLoading = false;
      });

      // Save to cache
      final cacheKey = buildActivityCacheKey();
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {'data': response['data'] ?? []});
      }
    } catch (e) {
      if (mounted) {
        if (activityList.isEmpty) {
          setState(() {
            isLoading = false;
            errorMessage = ErrorUtils.getFriendlyMessage(e);
          });
        } else {
          setState(() {
            isLoading = false;
          });
        }
        showErrorSnackBar(
          '${AppLocalizations.failedToLoad.tr}: '
          '${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  void showErrorSnackBar(String message) {
    SnackBarUtils.showError(context, message);
  }
}
