// Mixin that holds all data-loading logic for TeacherMaterialScreen.
//
// Extracted from teacher_material_screen.dart (~750 lines → ~400 lines)
// to keep the main screen file under 500 lines.
//
// Manages: subject list, class list, chapter content, overview summary,
// schedules, teacher profile resolution, and multi-layer caching.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// Mixin providing data-loading methods for [TeacherMaterialScreenState].
///
/// Depends on state fields declared in the main State class.
/// Uses [WidgetRef] for Riverpod reads and [getIt] for services.
mixin MaterialDataMixin on ConsumerState<TeacherMaterialScreen> {
  // ── Fields that must be accessible from the main State ──
  // These are declared in TeacherMaterialScreenState and
  // accessed here via the abstract getters/setters below.

  // Getters the main state must expose
  String? get selectedSubject;
  set selectedSubject(String? v);
  String? get selectedClassId;
  set selectedClassId(String? v);
  String? get selectedClassName;
  set selectedClassName(String? v);
  List<dynamic> get subjectList;
  set subjectList(List<dynamic> v);
  List<dynamic> get classList;
  set classList(List<dynamic> v);
  List<dynamic> get chapterMaterialList;
  set chapterMaterialList(List<dynamic> v);
  List<dynamic> get subChapterMaterialList;
  set subChapterMaterialList(List<dynamic> v);
  List<dynamic> get schedules;
  set schedules(List<dynamic> v);
  List<dynamic> get overviewSummary;
  set overviewSummary(List<dynamic> v);
  bool get isLoading;
  set isLoading(bool v);
  bool get isLoadingBab;
  set isLoadingBab(bool v);
  bool get isLoadingProgress;
  set isLoadingProgress(bool v);
  bool get isLoadingOverview;
  set isLoadingOverview(bool v);
  String? get materialErrorMessage;
  set materialErrorMessage(String? v);
  String? get teacherProfileId;
  set teacherProfileId(String? v);
  Map<String, bool> get expandedChapter;
  Map<String, bool> get checkedChapter;
  Map<String, bool> get checkedSubChapter;
  Map<String, bool> get generatedChapter;
  Map<String, bool> get generatedSubChapter;
  Map<String, bool> get usedChapter;
  Map<String, bool> get usedSubChapter;

  // Homeroom view state
  bool get isHomeroomView;
  set isHomeroomView(bool v);

  // Callback that the main state provides
  void applyProgressToMaps(List<dynamic> progress);
  void loadContentProgress(String subjectId);
  void autoSelectCurrentSchedule(List<dynamic> classes, List<dynamic> subjects);
  Future<void> loadChapterContent(
    String subjectId, {
    bool useCache,
    String? search,
  });
  Future<List<dynamic>> resolveClassesAndProfile(
    String teacherId,
    List<dynamic> initial,
    bool useCache,
  );
  Future<void> fetchRemoteData(
    String teacherId,
    List<dynamic> classes,
    ({String? id, String? name}) sel,
    bool useCache,
  );
  void loadOverviewAndSchedules(
    String teacherId,
    List<dynamic> classes, {
    String? search,
  });
  void resetChapterMaps(List<dynamic> chapters, List<dynamic> subChapters);
  Future<List<dynamic>> getSubjectsForClass(String classId);

  // ── Cache keys ──

  String? buildContentCacheKey() {
    final teacherId = Teacher.fromJson(widget.teacher).id;
    if (teacherId.isEmpty) return null;
    return 'materi_data_$teacherId';
  }

  String buildProgressCacheKey(String subjectId) {
    final teacherId = Teacher.fromJson(widget.teacher).id;
    final cid = selectedClassId ?? 'no_class';
    return CacheKeyBuilder.custom(
      'materi_progress',
      teacherId,
      '${subjectId}_$cid',
    );
  }

  // ── View preference ──

  Future<void> loadViewPref(ValueChanged<bool> setListView) async {
    try {
      final c = await LocalCacheService.load('materi_view_preference');
      if (c is Map && mounted) {
        setListView(c['is_list_view'] ?? false);
      }
    } catch (_) {}
  }

  // ── Apply subject list + auto-select first ──

  void applySubjectList(List<dynamic> subjects) {
    setState(() {
      subjectList = subjects;
      chapterMaterialList = [];
      subChapterMaterialList = [];
      isLoading = false;

      if (widget.initialSubjectId != null &&
          subjects.any((mp) => mp['id'] == widget.initialSubjectId)) {
        selectedSubject = widget.initialSubjectId;
      } else if (subjects.isNotEmpty) {
        selectedSubject = subjects[0]['id'];
      } else {
        selectedSubject = null;
      }
    });

    if (selectedSubject != null) {
      loadChapterContent(selectedSubject!);
    }
  }

  // ── Load subjects filtered by class ──

  Future<void> loadSubjectsForClass(
    String classId, {
    bool useCache = true,
  }) async {
    final teacherId = Teacher.fromJson(widget.teacher).id;
    if (teacherId.isEmpty) return;

    final cacheKey = CacheKeyBuilder.custom(
      'materi_subjects',
      teacherId,
      classId,
    );

    if (useCache) {
      try {
        final cached = await LocalCacheService.load(
          cacheKey,
          ttl: const Duration(hours: 6),
        );
        if (cached != null && mounted) {
          final subjects = List<dynamic>.from(cached);
          if (subjects.isNotEmpty) {
            applySubjectList(subjects);
            AppLogger.info(
              'material',
              'Loaded subjects for class $classId from cache',
            );
            return;
          }
        }
      } catch (e) {
        AppLogger.error('material', 'Subject cache error: $e');
      }
    }

    try {
      final subjects = await getIt<ApiTeacherService>().getSubjectByTeacher(
        teacherId,
        classId: classId,
      );
      if (!mounted) return;
      applySubjectList(subjects);
      if (subjects.isNotEmpty) {
        await LocalCacheService.save(cacheKey, subjects);
      }
    } catch (e) {
      AppLogger.error('material', 'Error loading subjects for class: $e');
    }
  }

  // ── Force refresh (clear all caches) ──

  Future<void> forceRefresh() async {
    await LocalCacheService.clearStartingWith('materi_');
    await LocalCacheService.clearStartingWith('teacher_classes_');
    await LocalCacheService.clearStartingWith('teacher_profile_');
    setState(() {
      isLoading = true;
      subjectList.clear();
      classList.clear();
    });
    loadData(useCache: false);
  }

  /// Main data loader (delegated to MaterialDataLoadMixin).
  Future<void> loadData({bool useCache = true});
}
