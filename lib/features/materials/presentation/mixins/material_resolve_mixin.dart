// Mixin for resolving classes, teacher profile, and
// fetching remote data in TeacherMaterialScreen.
//
// Extracted from material_data_mixin.dart to keep
// each file under 400 lines.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/material_data_mixin.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';

/// Mixin for class/profile resolution and remote
/// data fetching. Must be applied with
/// [MaterialDataMixin].
mixin MaterialResolveMixin
    on ConsumerState<TeacherMaterialScreen>, MaterialDataMixin {
  // ── Class + profile resolution ──

  /// Resolves classes and teacher profile from
  /// cache then API as needed.
  @override
  Future<List<dynamic>> resolveClassesAndProfile(
    String teacherId,
    List<dynamic> initial,
    bool useCache,
  ) async {
    var classes = List<dynamic>.from(initial);
    if (classes.isNotEmpty && teacherProfileId != null) {
      return classes;
    }

    classes = await _tryCacheForClassesAndProfile(
      teacherId,
      classes,
      classes.isEmpty,
      teacherProfileId == null,
      useCache,
    );

    return _fetchMissingClassesAndProfile(teacherId, classes);
  }

  Future<List<dynamic>> _tryCacheForClassesAndProfile(
    String teacherId,
    List<dynamic> classes,
    bool needClasses,
    bool needProfile,
    bool useCache,
  ) async {
    if (!useCache) return classes;

    if (needClasses) {
      final ck = CacheKeyBuilder.custom('teacher_classes', teacherId);
      try {
        final cc = await LocalCacheService.load(
          ck,
          ttl: const Duration(hours: 3),
        );
        if (cc != null && cc is List) {
          classes = List<dynamic>.from(cc);
          sortClassesByName(classes);
        }
      } catch (_) {}
    }

    if (needProfile) {
      final pk = CacheKeyBuilder.teacherProfile(teacherId);
      try {
        final cp = await LocalCacheService.load(
          pk,
          ttl: const Duration(hours: 6),
        );
        if (cp != null && cp is Map) {
          teacherProfileId = cp['id']?.toString();
        }
      } catch (_) {}
    }

    return classes;
  }

  Future<List<dynamic>> _fetchMissingClassesAndProfile(
    String teacherId,
    List<dynamic> classes,
  ) async {
    final needClasses = classes.isEmpty;
    final needProfile = teacherProfileId == null;
    if (!needClasses && !needProfile) return classes;

    final classesCK = CacheKeyBuilder.custom('teacher_classes', teacherId);
    final profileCK = CacheKeyBuilder.teacherProfile(teacherId);
    final api = getIt<ApiTeacherService>();

    final futures = <Future<dynamic>>[
      if (needClasses) api.getTeacherClasses(teacherId),
      if (needProfile) api.getTeacherById(teacherId),
    ];
    final results = await Future.wait(futures);
    if (!mounted) return classes;

    var idx = 0;
    if (needClasses) {
      classes = results[idx++] as List<dynamic>;
      sortClassesByName(classes);
      await LocalCacheService.save(classesCK, classes);
    }
    if (needProfile && idx < results.length) {
      _applyTeacherProfile(results[idx], profileCK);
    }
    return classes;
  }

  /// Sorts classes by name in place.
  void sortClassesByName(List<dynamic> classes) {
    classes.sort((a, b) {
      final na = (a['name'] ?? a['nama'] ?? '').toString();
      final nb = (b['name'] ?? b['nama'] ?? '').toString();
      return na.compareTo(nb);
    });
  }

  void _applyTeacherProfile(dynamic result, String cacheKey) {
    try {
      if (result is Map<String, dynamic>) {
        final pd = result['data'] ?? result;
        teacherProfileId = pd['id']?.toString();
        LocalCacheService.save(cacheKey, pd);
      }
    } catch (e) {
      AppLogger.debug('material', 'Could not resolve teacher profile: $e');
    }
  }

  // ── Remote data fetch ──

  /// Fetches subjects, schedules, and overview.
  @override
  Future<void> fetchRemoteData(
    String teacherId,
    List<dynamic> classes,
    ({String? id, String? name}) sel,
    bool useCache,
  ) async {
    final ayId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
    final api = getIt<ApiTeacherService>();

    final results = await Future.wait([
      api.getSubjectByTeacher(teacherId, classId: sel.id),
      getIt<ApiSubjectService>().getMaterials(teacherId: teacherId),
      getIt<ApiScheduleService>().getScheduleByTeacher(
        teacherId: teacherId,
        academicYear: ayId,
      ),
      getIt<ApiSubjectService>().getMaterialTeacherSummary(
        teacherId: teacherId,
        academicYearId: ayId,
      ),
    ]);
    if (!mounted) return;

    _applyRemoteResults(teacherId, classes, sel, results);
  }

  void _applyRemoteResults(
    String teacherId,
    List<dynamic> classes,
    ({String? id, String? name}) sel,
    List<dynamic> results,
  ) {
    final subjects = results[0] as List<dynamic>;
    schedules = (results[2] as List<dynamic>?) ?? [];
    overviewSummary = (results[3] as List<dynamic>?) ?? [];
    isLoadingOverview = false;
    materialErrorMessage = null;

    if (subjects.isEmpty) {
      setState(() {
        isLoading = false;
        subjectList = [];
      });
      return;
    }

    setState(() => isLoading = false);
    applySubjectList(subjects);
    autoSelectCurrentSchedule(classes, subjects);

    final classKey = sel.id ?? 'no_class';
    LocalCacheService.save(
      CacheKeyBuilder.custom('materi_subjects', teacherId, classKey),
      subjects,
    );
  }

  // ── Background overview + schedules ──

  @override
  Future<void> loadOverviewAndSchedules(
    String teacherId,
    List<dynamic> classes, {
    String? search,
  }) async {
    try {
      final ayId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();
      // Single API call — schedules are piggy-backed in the response
      final result =
          await getIt<ApiSubjectService>().getMaterialTeacherSummaryWithSchedules(
        teacherId: teacherId,
        academicYearId: ayId,
        view: isHomeroomView ? 'wali_kelas' : 'mengajar',
        search: search,
      );
      if (!mounted) return;
      setState(() {
        overviewSummary =
            (result['data'] as List<dynamic>?) ?? [];
        schedules =
            (result['schedules'] as List<dynamic>?) ?? [];
        isLoadingOverview = false;
      });
    } catch (e) {
      AppLogger.error('material', 'Error loading overview: $e');
      if (mounted) {
        setState(() => isLoadingOverview = false);
      }
    }
  }

  /// Resets all chapter/sub-chapter tracking maps.
  @override
  void resetChapterMaps(List<dynamic> chapters, List<dynamic> subChapters) {
    expandedChapter.clear();
    checkedChapter.clear();
    checkedSubChapter.clear();
    generatedChapter.clear();
    generatedSubChapter.clear();
    usedChapter.clear();
    usedSubChapter.clear();

    for (final ch in chapters) {
      final id = ch['id'].toString();
      expandedChapter[id] = false;
      checkedChapter[id] = false;
      generatedChapter[id] = false;
      usedChapter[id] = false;
    }
    for (final sc in subChapters) {
      checkedSubChapter[sc['id'].toString()] = false;
    }
  }

  /// Fetches subjects for a class (filter sheet).
  @override
  Future<List<dynamic>> getSubjectsForClass(String classId) async {
    try {
      return await getIt<ApiTeacherService>().getSubjectByTeacher(
        Teacher.fromJson(widget.teacher).id,
        classId: classId,
      );
    } catch (_) {
      return [];
    }
  }
}
