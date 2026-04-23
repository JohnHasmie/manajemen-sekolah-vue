import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';

/// Mixin for student data loading with caching.
mixin DataLoadingMixin {
  bool get isLoading;
  set isLoading(bool value);

  List<dynamic> get students;
  set students(List<dynamic> value);

  String get errorMessage;
  set errorMessage(String value);

  Map<String, dynamic> get classData;

  /// The currently selected academic year ID from the dashboard.
  /// Implementors should resolve from academicYearRiverpod.
  String? get academicYearId;

  void setState(VoidCallback fn);

  String buildStudentsCacheKey() {
    final classId = classData['id']?.toString() ?? '';
    return 'recommendation_students_$classId';
  }

  Future<void> forceRefresh() async {
    await LocalCacheService.invalidate(buildStudentsCacheKey());
    await LocalCacheService.clearStartingWith('tour_recommendation_student_');
    loadStudents(useCache: false);
  }

  Future<void> loadStudents({bool useCache = true}) async {
    final cacheKey = buildStudentsCacheKey();

    if (useCache && await _tryLoadFromCache(cacheKey)) {
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final studentList = await getIt<ApiClassService>().getStudentsByClassId(
        classData['id'].toString(),
        academicYearId: academicYearId,
      );

      // Only save to cache when we actually have data. `_tryLoadFromCache`
      // treats an empty cached list as a miss anyway, so persisting []
      // accomplishes nothing except wasting disk writes. More importantly,
      // it prevents us from ever "locking in" a bad transient-failure
      // response for future sessions.
      if (studentList.isNotEmpty) {
        await LocalCacheService.save(cacheKey, studentList);
      }

      // Deduplicate by student ID — safety net in case the API returns
      // duplicate entries (e.g., from multiple student_classes pivot rows).
      final seen = <String>{};
      final deduped = studentList.where((s) {
        final id = (s['id'] ?? s['student_id'])?.toString() ?? '';
        return id.isNotEmpty && seen.add(id);
      }).toList();

      setState(() {
        students = deduped;
        isLoading = false;
        errorMessage = '';
      });
    } catch (e) {
      AppLogger.error('recommendation', 'loadStudents failed: $e');
      if (students.isEmpty) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  Future<bool> _tryLoadFromCache(String cacheKey) async {
    final cached = await LocalCacheService.load(cacheKey);
    if (cached != null && cached is List && cached.isNotEmpty) {
      setState(() {
        students = cached;
        isLoading = false;
        errorMessage = '';
      });
      AppLogger.debug(
        'recommendation',
        'RecommendationStudents: from cache (${cached.length})',
      );
      return true;
    }
    return false;
  }
}
