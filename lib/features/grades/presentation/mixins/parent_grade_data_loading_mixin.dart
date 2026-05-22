import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/mixins/pagination_mixin.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/grades/data/grade_service.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Mixin for data loading and caching logic.
///
/// Handles student list and grade list loading with cache support.
mixin ParentGradeDataLoadingMixin
    on ConsumerState<ParentGradeScreen>, PaginationMixin<ParentGradeScreen> {
  // State vars expected from ParentGradeScreenState
  List<dynamic> get gradeList;
  set gradeList(List<dynamic> value);

  List<dynamic> get studentList;
  set studentList(List<dynamic> value);

  String? get selectedStudentId;
  set selectedStudentId(String? value);

  bool get isLoading;
  set isLoading(bool value);

  String? get academicYearId;

  /// Get cache key for students list.
  String get studentsCacheKey =>
      'parent_grade_students_${academicYearId ?? 'default'}';

  /// Build cache key for grades list.
  String buildGradesCacheKey() {
    final yearId = academicYearId ?? 'default';
    // Include the active grade-type filter in the cache key so two
    // filter states (e.g. "all" vs "Tugas") don't collide and pollute
    // each other's view. Reading the filter via `as dynamic` keeps the
    // mixin loosely coupled to ParentGradeFilterMixin (which hasn't been
    // mixed in at this point in the inheritance chain).
    final type = (this as dynamic).selectedGradeTypeFilter as String?;
    final typeKey = (type == null || type.isEmpty) ? 'all' : type;
    return 'parent_grade_list_${selectedStudentId}_${yearId}_$typeKey';
  }

  /// Load user data (students) with optional cache.
  Future<void> loadUserData({bool useCache = true}) async {
    try {
      await loadStudentsForParent(useCache: useCache);
    } catch (e) {
      AppLogger.error('grades', e);
      setState(() => isLoading = false);
      if (mounted) {
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  /// Load students for parent from cache or API.
  Future<void> loadStudentsForParent({bool useCache = true}) async {
    bool hadCacheHit = false;

    // Try cache for instant display
    if (useCache) {
      final cached = await LocalCacheService.load(
        studentsCacheKey,
        ttl: const Duration(hours: 6),
      );
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          studentList = cached;
          isLoading = false;
        });
        // Auto-pick the first child as default — the chip selector
        // in the screen lets the parent switch in-place.
        if (studentList.isNotEmpty && selectedStudentId == null) {
          selectedStudentId = studentList[0]['id'];
          await loadGrades(useCache: true);
        }
        AppLogger.debug(
          'grades',
          'ParentGradeStudents: from cache (${cached.length})',
        );
        hadCacheHit = true;
        // Don't return — continue fetching fresh data from API
      }
    }

    // Show skeleton only if list is still empty (no cache hit)
    if (!hadCacheHit && studentList.isEmpty && mounted) {
      setState(() => isLoading = true);
    }

    try {
      final prefs = PreferencesService();
      final userData = json.decode(prefs.getString('user') ?? '{}');
      final userId = userData['id']?.toString() ?? '';
      final guardianEmail = userData['email']?.toString();

      final allStudents = await getIt<ApiStudentService>().getStudent(
        academicYearId: academicYearId,
        userId: userId,
        guardianEmail: guardianEmail,
      );

      final filteredStudents = allStudents.where((student) {
        final model = Student.fromJson(student as Map<String, dynamic>);
        return model.guardianEmail == userData['email'] ||
            model.guardianName == userData['name'] ||
            student['user_id'].toString() == userId ||
            student['parent_id'].toString() == userId ||
            student['wali_id'].toString() == userId ||
            (userData['student_id'] != null &&
                model.id == userData['student_id'].toString()) ||
            (userData['siswa_id'] != null &&
                model.id == userData['siswa_id'].toString());
      }).toList();

      if (!mounted) return;

      LocalCacheService.save(studentsCacheKey, filteredStudents);

      setState(() {
        studentList = filteredStudents;
      });

      if (studentList.isNotEmpty) {
        // Always auto-pick the first child if nothing is selected;
        // the chip selector handles in-place switching.
        selectedStudentId ??= studentList[0]['id'];
        if (!hadCacheHit) {
          await loadGrades(useCache: useCache);
        } else {
          await loadGrades(useCache: false);
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      AppLogger.error('grades', e);
      if (!mounted) return;
      if (studentList.isEmpty) {
        setState(() => isLoading = false);
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  /// Load grades for selected student.
  Future<void> loadGrades({bool useCache = true}) async {
    if (selectedStudentId == null) return;

    final cacheKey = buildGradesCacheKey();

    bool hadCacheHit = false;

    // Try cache for instant display only if useCache is true.
    // When useCache=false (e.g. after applying a filter), skip cache
    // entirely to ensure fresh filtered data is loaded from API.
    if (useCache) {
      final cached = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(hours: 3),
      );
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          gradeList = List<dynamic>.from(cached);
          isLoading = false;
        });
        AppLogger.debug(
          'grades',
          'ParentGrades: from cache (${cached.length})',
        );
        resetPagination();
        endPaginationReset();
        hasMoreData = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {});
        hadCacheHit = true;
        // Return early when cache hit and useCache=true to avoid
        // redundant API call. API fetch only happens below on manual refresh.
        return;
      }
    }

    // Reset pagination and load page 1
    if (!hadCacheHit) resetPagination();
    if (!hadCacheHit && gradeList.isEmpty && mounted) {
      setState(() => isLoading = true);
    }

    try {
      await loadPage(1);
      if (!mounted) return;
      setState(() => isLoading = false);
      if (gradeList.isNotEmpty) {
        LocalCacheService.save(cacheKey, gradeList);
      }
    } catch (e) {
      AppLogger.error('grades', e);
      if (!mounted) return;
      if (gradeList.isEmpty) {
        setState(() => isLoading = false);
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      endPaginationReset();
      WidgetsBinding.instance.addPostFrameCallback((_) {});
    }
  }

  /// PaginationMixin contract — load one page.
  @override
  Future<void> loadPage(int page) async {
    try {
      final result = await GradeService.getGradesPaginated(
        studentId: selectedStudentId,
        academicYearId: academicYearId,
        gradeType: (this as dynamic)
            .selectedGradeTypeFilter, // From ParentGradeFilterMixin
        page: page,
      );
      final newItems = List<dynamic>.from(result['data'] ?? []);
      if (mounted) {
        setState(() {
          if (page == 1) {
            gradeList = newItems;
          } else {
            gradeList = [...gradeList, ...newItems];
          }
        });
        updatePaginationFromMeta(result['pagination'] as Map<String, dynamic>?);
      }
    } catch (e) {
      AppLogger.error('grades', 'loadPage($page) error: $e');
      if (page == 1) rethrow;
    }
  }

  /// Force refresh: clear cache and reload.
  Future<void> forceRefresh() async {
    await LocalCacheService.clearStartingWith('parent_grade_');
    await loadUserData(useCache: false);
  }
}
