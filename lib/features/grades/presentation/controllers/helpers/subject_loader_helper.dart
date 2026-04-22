import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/teacher_grade_state.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/helpers/cache_helper.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/helpers/sorting_helper.dart';

/// Helper for loading subjects with caching and sorting.
class SubjectLoaderHelper {
  /// Loads subjects from cache or API.
  static Future<TeacherGradeState> loadSubjects({
    required TeacherGradeState currentState,
    required Ref ref,
    required dynamic teacherId,
    required String teacherRole,
    bool useCache = true,
  }) async {
    if (currentState.selectedClass == null) return currentState;

    // 1. Cache
    if (useCache) {
      final cacheKey = CacheHelper.buildSubjectCacheKey(
        currentState.selectedClass!,
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
          final cachedSubjects = List<dynamic>.from(
            cachedData['subjects'] ?? [],
          );
          if (cachedSubjects.isNotEmpty) {
            return currentState.copyWith(
              subjectList: cachedSubjects,
              isLoading: false,
            );
          }
        }
      }
    }

    // 2. API
    try {
      final academicYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();
      final classId = currentState.selectedClass!['id'].toString();

      // Get teacher's schedules first
      final mySchedules = await getIt<ApiScheduleService>()
          .getSchedulesPaginated(
            limit: 100,
            teacherId: teacherId,
            classId: classId,
            academicYearId: academicYearId,
          );
      final myData = mySchedules['data'] ?? [];
      final mySubjectIds = <String>{};
      for (final item in myData) {
        final s = item['subject'] ?? item['mata_pelajaran'];
        if (s != null) mySubjectIds.add(s['id'].toString());
      }

      final isTeacher =
          teacherRole.contains('guru') || teacherRole.contains('teacher');
      final isAdmin = !isTeacher;
      final isHomeroom = currentState.selectedClass!['is_homeroom'] == true;

      List<dynamic> subjects = [];

      if (isHomeroom || isAdmin) {
        final response = await dioClient.get('/class/$classId/subjects');
        final allSubjects = response.data is List ? response.data as List : [];
        final uniqueSubjects = <String, Map<String, dynamic>>{};
        for (final s in allSubjects) {
          final sid = s['id'].toString();
          final smap = Map<String, dynamic>.from(s);
          smap['can_edit'] = isAdmin || mySubjectIds.contains(sid);
          uniqueSubjects[sid] = smap;
        }
        subjects = uniqueSubjects.values.toList();
      } else {
        final uniqueSubjects = <String, Map<String, dynamic>>{};
        for (final item in myData) {
          final s = item['subject'] ?? item['mata_pelajaran'];
          if (s != null) {
            final sid = s['id'].toString();
            final smap = Map<String, dynamic>.from(s);
            smap['can_edit'] = true;
            uniqueSubjects[sid] = smap;
          }
        }
        subjects = uniqueSubjects.values.toList();
      }

      SortingHelper.sortSubjectsByTodaySchedule(
        subjects,
        classId,
        currentState.todaySchedules,
      );

      // Save to cache
      final cacheKey = CacheHelper.buildSubjectCacheKey(
        currentState.selectedClass!,
        ref,
        teacherId,
      );
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {'subjects': subjects});
      }

      return currentState.copyWith(subjectList: subjects, isLoading: false);
    } catch (e) {
      AppLogger.error('grades', e);
      return currentState.copyWith(isLoading: false);
    }
  }
}
