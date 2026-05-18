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
  // Access public fields on the state class
  ParentClassActivityScreenState get _state =>
      this as ParentClassActivityScreenState;

  Future<void> loadUserData({bool useCache = true}) async {
    try {
      await loadStudentsForParent(useCache: useCache);
    } catch (e) {
      AppLogger.error('class_activity', 'Error load user data: $e');
      setState(() => _state.isLoading = false);
      if (mounted) {
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> loadStudentsForParent({bool useCache = true}) async {
    bool hadCacheHit = false;
    final cacheKey = _state.studentsCacheKey;

    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _state.studentList.clear();
          _state.studentList.addAll(cached);
          _state.isLoading = false;
        });
        if (_state.studentList.length == 1 &&
            _state.selectedStudentId == null) {
          _state.selectedStudentId = _state.studentList[0]['id'];
          await loadActivities(useCache: true);
        }
        hadCacheHit = true;
      }
    }

    if (!hadCacheHit && mounted) {
      setState(() => _state.isLoading = true);
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

      await LocalCacheService.save(cacheKey, filteredStudents);

      setState(() {
        _state.studentList.clear();
        _state.studentList.addAll(filteredStudents);
      });

      if (_state.studentList.isNotEmpty) {
        // Always auto-pick the first child as default — the chip
        // selector in the screen lets the parent switch in-place,
        // so there's no point making them tap a picker first. Only
        // skip auto-pick if a previous selection survived (e.g.
        // parent navigated back).
        _state.selectedStudentId ??= _state.studentList[0]['id'];
        if (!hadCacheHit) {
          await loadActivities(useCache: useCache);
        } else {
          await loadActivities(useCache: false);
        }
      } else {
        setState(() => _state.isLoading = false);
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error load students for parent: $e');
      if (!mounted) return;
      if (_state.studentList.isEmpty) {
        setState(() => _state.isLoading = false);
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> loadActivities({bool useCache = true}) async {
    if (_state.selectedStudentId == null) return;

    final cacheKey = _state.buildActivitiesCacheKey();

    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _state.activityList = cached;
          _state.hasFreshData = false;
          _state.isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {});
      }
    }

    if (_state.activityList.isEmpty && mounted) {
      setState(() => _state.isLoading = true);
    }

    try {
      final selectedStudent = _state.studentList.firstWhere(
        (s) => s['id'] == _state.selectedStudentId,
        orElse: () => {},
      );

      final classId =
          selectedStudent['class_id'] ?? selectedStudent['class']?['id'];

      if (selectedStudent.isNotEmpty && classId != null) {
        final activities = await getIt<ApiClassActivityService>()
            .getActivityByClass(
              classId,
              studentId: _state.selectedStudentId,
              academicYearId: widget.academicYearId,
            );

        if (!mounted) return;

        await LocalCacheService.save(cacheKey, activities);

        setState(() {
          _state.activityList = activities;
          _state.hasFreshData = true;
          _state.isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _state.activityList = [];
          _state.hasFreshData = true;
          _state.isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error load activities: $e');
      if (!mounted) return;
      if (_state.activityList.isEmpty) {
        setState(() => _state.isLoading = false);
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {});
    }
  }

  Future<void> forceRefresh() async {
    await LocalCacheService.clearStartingWith('parent_activity_');
    loadUserData(useCache: false);
  }

  Future<void> flushMarkReadSilently(List<String> ids) async {
    try {
      await getIt<ApiClassActivityService>().markAsRead(ids);
    } catch (e) {
      AppLogger.error('class_activity', 'Error silent auto-marking read: $e');
    }
  }
}
