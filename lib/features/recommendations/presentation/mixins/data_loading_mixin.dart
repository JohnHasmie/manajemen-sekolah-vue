import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/recommendations/data/recommendation_service.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_class_screen.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// Mixin for data loading operations in
/// [LearningRecommendationClassScreen].
mixin DataLoadingMixin on ConsumerState<LearningRecommendationClassScreen> {
  // Summary data per class ID
  final Map<String, Map<String, dynamic>> classSummaries = {};
  final Map<String, bool> loadingSummaries = {};

  // Recommendation history per class (grouped by date)
  final Map<String, List<Map<String, dynamic>>> classHistory = {};
  final Map<String, bool> loadingHistory = {};

  // Subjects per class (from teaching schedule)
  List<dynamic> teacherSchedules = [];
  bool schedulesLoaded = false;

  // Teacher profile ID (resolved from user_id)
  String? teacherProfileId;

  // Initial loading state for skeleton display
  bool isInitialLoading = true;
  String? initialErrorMessage;

  /// Get the effective teacher ID for API calls
  String get effectiveTeacherId =>
      teacherProfileId ?? Teacher.fromJson(widget.teacher).id;

  /// Whether we're currently in Wali Kelas scope. The state class owns
  /// this flag — mixins read it to decide whether to query recs by
  /// `teacher_id` (mengajar) or `homeroom_class_id` (wali kelas).
  bool get isHomeroomView;

  /// Loads all data in parallel: teacher profile, schedules, and
  /// per-class summaries + histories.
  ///
  /// Uses the currently-hydrated class roster from `teacherRiverpod`
  /// matching the active scope ([isHomeroomView]). Falls back to
  /// `widget.classes` when the provider hasn't loaded yet (deep link).
  Future<void> loadAllData({bool useCache = true}) async {
    if (mounted && isInitialLoading) {
      setState(() {
        initialErrorMessage = null;
      });
    }

    try {
      await resolveTeacherProfileId(useCache: useCache);
      // Pick the class list matching the active role. In mengajar mode
      // this is the full teaching roster; in wali kelas mode it's only
      // the perwalian classes. Falling back to widget.classes keeps
      // deep-linked screens working when the provider hasn't hydrated.
      final provider = ref.read(teacherRiverpod);
      final scopedClasses = isHomeroomView
          ? provider.homeroomClasses
          : provider.allClasses;
      final classes = scopedClasses.isNotEmpty
          ? scopedClasses
          : widget.classes;

      // Fire all loads concurrently
      final futures = <Future>[];
      futures.add(loadTeacherSchedules(useCache: useCache));
      for (final cls in classes) {
        final classId = cls['id']?.toString();
        if (classId == null) continue;
        futures.add(loadClassSummary(classId, useCache: useCache));
        futures.add(loadClassHistory(classId, useCache: useCache));
      }
      await Future.wait(futures);
    } catch (e) {
      if (mounted) {
        setState(() => initialErrorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => isInitialLoading = false);
      }
    }
  }

  Future<void> resolveTeacherProfileId({bool useCache = true}) async {
    final userId = Teacher.fromJson(widget.teacher).id;
    if (userId.isEmpty) return;
    final cacheKey = 'recommendation_teacher_profile_$userId';

    // Try cache
    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null && cached is String && cached.isNotEmpty) {
        teacherProfileId = cached;
        return;
      }
    }

    try {
      final apiTeacherService = getIt<ApiTeacherService>();
      final profileData = await apiTeacherService.getTeacherById(userId);
      if (profileData != null) {
        teacherProfileId = profileData['id']?.toString();
        if (teacherProfileId != null) {
          await LocalCacheService.save(cacheKey, teacherProfileId);
        }
      }
    } catch (e) {
      AppLogger.debug(
        'recommendation',
        'Could not resolve teacher profile ID: $e',
      );
    }
  }

  Future<void> loadClassSummary(String classId, {bool useCache = true}) async {
    if (!mounted) return;
    final cacheKey = 'recommendation_summary_$classId';

    // Try cache — return early
    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null && cached is Map) {
        if (mounted) {
          setState(() {
            classSummaries[classId] = Map<String, dynamic>.from(cached);
            loadingSummaries[classId] = false;
          });
        }
        AppLogger.debug('recommendation', 'ClassSummary $classId: from cache');
        return;
      }
    }

    if (mounted) {
      setState(() => loadingSummaries[classId] = true);
    }

    try {
      final ayId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();
      final summary = await getIt<ApiRecommendationService>().getClassSummary(
        classId,
        academicYearId: ayId,
      );
      if (mounted) {
        setState(() {
          classSummaries[classId] = summary['data'] ?? {};
          loadingSummaries[classId] = false;
        });
      }
      await LocalCacheService.save(cacheKey, summary['data'] ?? {});
    } catch (e) {
      AppLogger.error('recommendation', e);
      if (mounted) {
        setState(() => loadingSummaries[classId] = false);
      }
    }
  }

  Future<void> loadClassHistory(String classId, {bool useCache = true}) async {
    if (!mounted) return;
    // Segment the cache by scope — wali kelas data (cross-teacher) must
    // not leak into the mengajar cache when the user flips roles.
    final scopeTag = isHomeroomView ? 'wali' : 'mengajar';
    final cacheKey = 'recommendation_history_${classId}_${effectiveTeacherId}_$scopeTag';

    // Try cache — return early
    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            classHistory[classId] = List<Map<String, dynamic>>.from(
              cached.map((e) => Map<String, dynamic>.from(e)),
            );
            loadingHistory[classId] = false;
          });
        }
        AppLogger.debug('recommendation', 'ClassHistory $classId: from cache');
        return;
      }
    }

    if (mounted) {
      setState(() => loadingHistory[classId] = true);
    }

    try {
      // In wali kelas mode, scope by homeroom_class_id so we pick up
      // recommendations from ALL teachers in that homeroom — the whole
      // point of the Wali Kelas tab. In mengajar mode, scope by teacher
      // so we only see the current teacher's own authored recs.
      final ayId2 = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();
      final result = await getIt<ApiRecommendationService>().getRecommendations(
        teacherId: isHomeroomView ? null : effectiveTeacherId,
        homeroomClassId: isHomeroomView ? classId : null,
        classId: classId,
        academicYearId: ayId2,
        perPage: 50,
      );

      if (!mounted) return;

      final recommendations = (result['data'] as List?) ?? [];
      final grouped = <String, Map<String, dynamic>>{};

      for (final rec in recommendations) {
        final createdAt = rec['created_at']?.toString() ?? '';
        if (createdAt.isEmpty) continue;

        final dateKey = createdAt.length >= 10
            ? createdAt.substring(0, 10)
            : createdAt;
        final triggerSource = rec['trigger_source']?.toString() ?? 'on_demand';
        final groupKey = '${dateKey}_$triggerSource';

        if (!grouped.containsKey(groupKey)) {
          grouped[groupKey] = {
            'date': dateKey,
            'trigger_source': triggerSource,
            'count': 0,
            'by_status': <String, int>{},
            'by_priority': <String, int>{},
            'by_category': <String, int>{},
          };
        }

        final group = grouped[groupKey]!;
        group['count'] = (group['count'] as int) + 1;

        final status = rec['status']?.toString() ?? 'pending';
        final statusMap = group['by_status'] as Map<String, int>;
        statusMap[status] = (statusMap[status] ?? 0) + 1;

        final priority = rec['priority']?.toString() ?? 'medium';
        final priorityMap = group['by_priority'] as Map<String, int>;
        priorityMap[priority] = (priorityMap[priority] ?? 0) + 1;

        final category = rec['category']?.toString() ?? '';
        if (category.isNotEmpty) {
          final catMap = group['by_category'] as Map<String, int>;
          catMap[category] = (catMap[category] ?? 0) + 1;
        }
      }

      final history = grouped.values.toList()
        ..sort((a, b) {
          final dateCompare = (b['date'] as String).compareTo(
            a['date'] as String,
          );
          if (dateCompare != 0) return dateCompare;
          return (a['trigger_source'] as String).compareTo(
            b['trigger_source'] as String,
          );
        });

      setState(() {
        classHistory[classId] = history;
        loadingHistory[classId] = false;
      });

      // Save grouped history to cache
      await LocalCacheService.save(cacheKey, history);
    } catch (e) {
      AppLogger.error('recommendation', e);
      if (mounted && !classHistory.containsKey(classId)) {
        setState(() {
          classHistory[classId] = [];
          loadingHistory[classId] = false;
        });
      }
    }
  }

  Future<void> loadTeacherSchedules({bool useCache = true}) async {
    final teacherIdForSchedule = Teacher.fromJson(widget.teacher).id;
    if (teacherIdForSchedule.isEmpty) return;
    final cacheKey = 'recommendation_schedules_$teacherIdForSchedule';

    // Try cache — return early
    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            teacherSchedules = List<dynamic>.from(cached);
            schedulesLoaded = true;
          });
        }
        AppLogger.debug('recommendation', 'TeacherSchedules: from cache');
        return;
      }
    }

    try {
      final schedules = await getIt<ApiScheduleService>().getScheduleByTeacher(
        teacherId: teacherIdForSchedule,
      );
      if (mounted) {
        setState(() {
          teacherSchedules = schedules;
          schedulesLoaded = true;
        });
      }
      await LocalCacheService.save(cacheKey, schedules);
    } catch (e) {
      AppLogger.error('recommendation', e);
      if (mounted) setState(() => schedulesLoaded = true);
    }
  }

  List<Map<String, String>> getSubjectsForClass(String classId) {
    final seen = <String>{};
    final subjects = <Map<String, String>>[];

    for (final schedule in teacherSchedules) {
      final model =
          Schedule.fromJson(schedule as Map<String, dynamic>);
      if (model.classId != classId) continue;

      final subjectId = model.subjectId;
      final subjectName = model.subjectName ?? 'Mata Pelajaran';

      if (subjectId != null && seen.add(subjectId)) {
        subjects.add({'id': subjectId, 'name': subjectName});
      }
    }

    return subjects;
  }
}
