import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

mixin ParentActivityDataLoadingMixin
    on ConsumerState<ParentClassActivityScreen> {
  Future<void> loadUserData({bool useCache = true}) async {
    try {
      final prefs = PreferencesService();
      final userData = json.decode(prefs.getString('user') ?? '{}');

      setState(() {
        (this as dynamic)._parentName =
            userData['name']?.toString() ?? 'Wali Murid';
      });

      await loadStudentsForParent(useCache: useCache);
    } catch (e) {
      AppLogger.error('class_activity', 'Error load user data: $e');
      setState(() => (this as dynamic)._isLoading = false);
      if (mounted) {
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> loadStudentsForParent({bool useCache = true}) async {
    final state = this as dynamic;
    bool hadCacheHit = false;

    // Try cache for instant display
    if (useCache) {
      final cached = await LocalCacheService.load(state._studentsCacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          state._studentList = cached;
          state._isLoading = false;
        });
        if (state._studentList.length == 1 &&
            state._selectedStudentId == null) {
          state._selectedStudentId = state._studentList[0]['id'];
          await loadActivities(useCache: true);
        }
        AppLogger.debug(
          'class_activity',
          'ParentStudents: from cache (${cached.length})',
        );
        hadCacheHit = true;
        // Don't return — continue fetching fresh data from API
      }
    }

    // Show skeleton only if list is still empty (no cache hit)
    if (!hadCacheHit && mounted) {
      setState(() => (this as dynamic)._isLoading = true);
    }

    try {
      final prefs = PreferencesService();
      final userData = json.decode(prefs.getString('user') ?? '{}');
      final userId = userData['id']?.toString() ?? '';
      final guardianEmail = userData['email']?.toString();

      final allStudents = await getIt<ApiStudentService>().getStudent(
        academicYearId: widget.academicYearId,
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

      final parentState = this as dynamic;
      await LocalCacheService.save(
        parentState._studentsCacheKey,
        filteredStudents,
      );

      setState(() {
        (this as dynamic)._studentList = filteredStudents;
      });

      if ((this as dynamic)._studentList.isNotEmpty) {
        if ((this as dynamic)._studentList.length == 1) {
          (this as dynamic)._selectedStudentId =
              (this as dynamic)._studentList[0]['id'];
          // Only load activities from API if we didn't already trigger it from cache
          if (!hadCacheHit) {
            await loadActivities(useCache: useCache);
          } else {
            // Cache already showed activities; now silently refresh them from API
            await loadActivities(useCache: false);
          }
        }
      } else {
        setState(() => (this as dynamic)._isLoading = false);
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error load students for parent: $e');
      if (!mounted) return;
      if ((this as dynamic)._studentList.isEmpty) {
        setState(() => (this as dynamic)._isLoading = false);
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> loadActivities({bool useCache = true}) async {
    final state = this as dynamic;
    if (state._selectedStudentId == null) return;

    final cacheKey = state.buildActivitiesCacheKey();

    // Try cache for instant display
    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          state._activityList = cached;
          state._hasFreshData = false;
          state._isLoading = false;
        });
        AppLogger.debug(
          'class_activity',
          'ParentActivities: from cache (${cached.length})',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && state._studentList.isNotEmpty) {
            checkAndShowTour();
          }
        });
        // Don't return — continue fetching fresh data from API
      }
    }

    // Show skeleton only if list is still empty (no cache hit)
    if (state._activityList.isEmpty && mounted) {
      setState(() => (this as dynamic)._isLoading = true);
    }

    try {
      final selectedStudent = state._studentList.firstWhere(
        (s) => s['id'] == state._selectedStudentId,
        orElse: () => {},
      );

      final classId =
          selectedStudent['class_id'] ?? selectedStudent['class']?['id'];

      if (selectedStudent.isNotEmpty && classId != null) {
        final activities = await getIt<ApiClassActivityService>()
            .getActivityByClass(
              classId,
              studentId: state._selectedStudentId,
              academicYearId: widget.academicYearId,
            );

        if (!mounted) return;

        await LocalCacheService.save(cacheKey, activities);

        setState(() {
          state._activityList = activities;
          state._hasFreshData = true;
          state._isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          state._activityList = [];
          state._hasFreshData = true;
          state._isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error load activities: $e');
      if (!mounted) return;
      if (state._activityList.isEmpty) {
        setState(() => (this as dynamic)._isLoading = false);
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (this as dynamic)._studentList.isNotEmpty) {
          checkAndShowTour();
        }
      });
    }
  }

  Future<void> forceRefresh() async {
    await LocalCacheService.clearStartingWith('parent_activity_');
    await LocalCacheService.clearStartingWith('tour_parent_class_activity_');
    loadUserData(useCache: false);
  }

  Future<void> flushMarkReadSilently(List<String> ids) async {
    try {
      await getIt<ApiClassActivityService>().markAsRead(ids);
    } catch (e) {
      AppLogger.error('class_activity', 'Error silent auto-marking read: $e');
    }
  }

  void checkAndShowTour();
}
