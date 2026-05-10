// Mixin for main data loading in TeacherMaterialScreen.
//
// Extracted from material_data_mixin.dart to keep that file under 400 lines.
// Contains loadData and all its sub-methods for resolving classes, profiles, etc.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// Mixin providing main data loading logic for [TeacherMaterialScreenState].
///
/// Handles the loadData flow and all its sub-methods for resolving classes,
/// picking initial selections, and applying state.
mixin MaterialDataLoadMixin on ConsumerState<TeacherMaterialScreen> {
  // ── Fields that must be accessible from the main State ──

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
  bool get isLoading;
  set isLoading(bool v);
  bool get isLoadingBab;
  set isLoadingBab(bool v);
  bool get isLoadingOverview;
  set isLoadingOverview(bool v);
  String? get teacherProfileId;
  set teacherProfileId(String? v);

  // Callback that the main state provides
  void loadContentProgress(String subjectId);
  void checkAndShowTour();
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

  // Error state accessor for inline error display
  String? get materialErrorMessage;
  set materialErrorMessage(String? v);

  /// Build cache key for content data.
  String? buildContentCacheKey() {
    final teacherId = Teacher.fromJson(widget.teacher).id;
    if (teacherId.isEmpty) return null;
    return 'materi_data_$teacherId';
  }

  /// Main data loader.
  Future<void> loadData({bool useCache = true}) async {
    try {
      if (!mounted) return;
      final teacherId = Teacher.fromJson(widget.teacher).id;

      if (_handleEmbeddedMode(teacherId)) return;

      if (teacherId.isEmpty) {
        if (!mounted) return;
        // Reset BOTH gates — the overview gate defaults to true on the
        // screen state, so without resetting it here the body stays on
        // the skeleton forever when the teacher payload is malformed.
        setState(() {
          isLoading = false;
          isLoadingOverview = false;
        });
        SnackBarUtils.showInfo(context, 'Error: ID guru tidak valid');
        return;
      }

      final resolved = await _resolveClassList(teacherId, useCache);
      final sel = _pickInitialClass(resolved);

      if (_handleOverviewMode(teacherId, resolved)) {
        return;
      }

      final cached = await _trySubjectsCache(
        teacherId,
        resolved,
        sel,
        useCache,
      );
      if (cached) return;

      if (subjectList.isEmpty && mounted) {
        setState(() => isLoading = true);
      }

      final classes = await resolveClassesAndProfile(
        teacherId,
        resolved,
        useCache,
      );
      if (!mounted) return;

      final sel2 = _pickInitialClass(classes);
      _applyClassState(classes, sel2);

      await fetchRemoteData(teacherId, classes, sel2, useCache);
    } catch (e) {
      _handleLoadError(e);
    }
  }

  // ── loadData sub-methods ──

  /// Deep-link fast path: when the screen was pushed with both
  /// `initialClassId` and `initialSubjectId` (from a Jadwal session
  /// detail card OR from the Materi overview hub tapping a card),
  /// jump straight to the chapter content view instead of going
  /// through the full overview → subjects → resolve chain.
  ///
  /// Without this, `selectedSubject` stays null until the async
  /// `_resolveClassList → _trySubjectsCache → fetchRemoteData →
  /// applySubjectList` chain completes, and during that window the
  /// header renders the overview title ("Bab & Sub-Bab") and the
  /// body shows the skeleton loader. This race used to be guarded
  /// behind `widget.embedded == true`, but the embedded flag was
  /// dropped when we converted both call-sites to push as full
  /// `MaterialPageRoute`s.
  ///
  /// Returns true if handled (caller should return).
  bool _handleEmbeddedMode(String? teacherId) {
    if (widget.initialSubjectId == null) return false;
    if (widget.initialClassId == null) return false;

    final tp = ref.read(teacherRiverpod);
    teacherProfileId = tp.teacherId ?? teacherId;
    setState(() {
      selectedSubject = widget.initialSubjectId;
      selectedClassId = widget.initialClassId;
      selectedClassName = widget.initialClassName;
      isLoading = false;
    });
    loadChapterContent(widget.initialSubjectId!);
    return true;
  }

  /// Resolves class list from Riverpod provider or cache.
  Future<List<dynamic>> _resolveClassList(
    String teacherId,
    bool useCache,
  ) async {
    final tp = ref.read(teacherRiverpod);
    if (tp.isLoaded && tp.teacherId != null) {
      teacherProfileId = tp.teacherId;
    }

    if (tp.isLoaded && tp.allClasses.isNotEmpty) {
      return tp.allClasses;
    }

    final cacheKey = buildContentCacheKey();
    if (useCache && cacheKey != null) {
      try {
        final cached = await LocalCacheService.load(
          cacheKey,
          ttl: const Duration(hours: 3),
        );
        if (cached != null) {
          final d = Map<String, dynamic>.from(cached);
          teacherProfileId ??= d['teacherProfileId']?.toString();
          return List<dynamic>.from(d['classes'] ?? []);
        }
      } catch (_) {}
    }
    return [];
  }

  /// Picks the initial class/className from a class list.
  ({String? id, String? name}) _pickInitialClass(List<dynamic> classes) {
    if (widget.initialClassId != null &&
        classes.any((c) => c['id'] == widget.initialClassId)) {
      return (id: widget.initialClassId, name: widget.initialClassName);
    }
    if (classes.isNotEmpty) {
      return (
        id: classes[0]['id']?.toString(),
        name: (classes[0]['name'] ?? classes[0]['nama'])?.toString(),
      );
    }
    return (id: null, name: null);
  }

  /// Shows overview when no subject/class was pre-selected.
  /// Returns true if handled.
  bool _handleOverviewMode(String teacherId, List<dynamic> classes) {
    if (widget.initialClassId != null) return false;
    if (widget.initialSubjectId != null) return false;

    if (mounted) {
      setState(() {
        classList = classes;
        isLoading = false;
      });
    }
    loadOverviewAndSchedules(teacherId, classes);
    return true;
  }

  /// Tries to load subjects from cache.
  /// Returns true if cache hit (caller should return).
  Future<bool> _trySubjectsCache(
    String teacherId,
    List<dynamic> classes,
    ({String? id, String? name}) sel,
    bool useCache,
  ) async {
    if (!useCache || subjectList.isNotEmpty) return false;

    final classKey = sel.id ?? 'no_class';
    final ck = CacheKeyBuilder.custom('materi_subjects', teacherId, classKey);
    try {
      final cached = await LocalCacheService.load(
        ck,
        ttl: const Duration(hours: 6),
      );
      if (cached != null && mounted) {
        final subjects = List<dynamic>.from(cached);
        if (subjects.isNotEmpty) {
          setState(() {
            classList = classes;
            selectedClassId = sel.id;
            selectedClassName = sel.name;
            isLoading = false;
          });
          return true;
        }
      }
    } catch (e) {
      AppLogger.error('material', 'Subject cache load error: $e');
    }
    return false;
  }

  /// Applies class selection state.
  void _applyClassState(
    List<dynamic> classes,
    ({String? id, String? name}) sel,
  ) {
    if (mounted) {
      setState(() {
        classList = classes;
        selectedClassId = sel.id;
        selectedClassName = sel.name;
      });
    }

    final cacheKey = buildContentCacheKey();
    if (cacheKey != null && classes.isNotEmpty) {
      LocalCacheService.save(cacheKey, {
        'classes': classes,
        'teacherProfileId': teacherProfileId,
      });
    }
  }

  /// Handles loadData catch block.
  void _handleLoadError(Object e) {
    AppLogger.error('material', 'Error loading TeacherMaterialScreen data: $e');
    if (!mounted) return;
    setState(() {
      isLoading = false;
      isLoadingBab = false;
      materialErrorMessage = ErrorUtils.getFriendlyMessage(e);
    });
  }
}
