// Teaching material (materi) management screen for teachers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
// Like `pages/teacher/Material/Index.vue` in a Vue app.
//
// A large screen that lets teachers browse subjects, chapters (bab), and
// sub-chapters (sub-bab) in a tree structure. Teachers can check items
// and generate AI materials or navigate to class activities. Includes
// progress tracking (generated/used status per chapter).
//
// Contains two widget classes:
// - [TeacherMaterialScreen] -- the main material browser with subject/chapter tree
// - [SubBabDetailPage] -- detail view for a sub-chapter's content
//
// In Laravel terms, combines MaterialController@index, @show, and
// ChapterController with progress tracking.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';

import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/embedded_activity_list_screen.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/sub_chapter_detail_screen.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_content_list.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_tour_helper.dart';

/// Teaching material browser with subject, chapter, and sub-chapter navigation.
///
/// This is a StatefulWidget with complex local state for managing the chapter
/// tree, checkboxes, progress tracking, and AI generation flow. In Vue terms,
/// it is like a page component with deeply nested reactive data.
///
/// Props (like Vue props): [teacher], optional initial* for deep linking.
class TeacherMaterialScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final String? initialClassId;
  final String? initialClassName;

  final bool embedded;

  const TeacherMaterialScreen({
    super.key,
    required this.teacher,
    this.initialSubjectId,
    this.initialSubjectName,
    this.initialClassId,
    this.initialClassName,
    this.embedded = false,
  });

  @override
  TeacherMaterialScreenState createState() => TeacherMaterialScreenState();
}

/// State for [TeacherMaterialScreen].
///
/// Like a Vue page component with `data() { return {...} }`. Manages:
/// - Subject/class selection dropdowns
/// - Chapter (bab) and sub-chapter (sub-bab) tree with expand/collapse
/// - Checkbox state for selecting items to generate AI content
/// - Progress tracking (generated, used status) per chapter
///
/// `setState()` is like Vue's reactivity -- triggers UI rebuild.
class TeacherMaterialScreenState extends ConsumerState<TeacherMaterialScreen> {
  String? _selectedSubject;
  String? _selectedClassId;
  String? _selectedClassName;
  List<dynamic> _subjectList = [];
  List<dynamic> _classList = [];
  List<dynamic> _chapterMaterialList = [];
  List<dynamic> _subChapterMaterialList = [];

  // Schedule data (for auto-select current lesson)
  List<dynamic> _schedules = [];

  // Overview summary data (init screen before filter)
  List<dynamic> _overviewSummary = [];
  bool _isLoadingOverview = true;

  // View toggle (card ↔ list) for overview
  bool _isListView = false;


  // Search dan Filter
  final TextEditingController _searchController = TextEditingController();


  // State for expanded/collapsed
  final Map<String, bool> _expandedChapter = {};

  // State for checkboxes
  final Map<String, bool> _checkedChapter = {};
  final Map<String, bool> _checkedSubChapter = {};

  // State for generated (previously generated)
  final Map<String, bool> _generatedChapter = {};
  final Map<String, bool> _generatedSubChapter = {};

  // State for used (already used in class activity) - Blue Check
  final Map<String, bool> _usedChapter = {};
  final Map<String, bool> _usedSubChapter = {};

  // Teacher profile ID (from teachers table, not user ID)
  String? _teacherProfileId;

  // Get checked chapters that have not been generated yet
  List<Map<String, dynamic>> _getCheckedNotGeneratedChapters() {
    return _chapterMaterialList
        .where((chapter) {
          final hasSubChapters = _subChapterMaterialList.any(
            (sb) => sb['bab_id'].toString() == chapter['id'].toString(),
          );

          return _checkedChapter[chapter['id']] == true &&
              _generatedChapter[chapter['id']] != true &&
              _usedChapter[chapter['id']] != true && // Exclude used
              !hasSubChapters; // Only include if it has NO sub-chapters
        })
        .toList()
        .cast<Map<String, dynamic>>();
  }

  // Get checked sub-chapters that have not been generated yet
  List<Map<String, dynamic>> _getCheckedNotGeneratedSubChapters() {
    return _subChapterMaterialList
        .where(
          (subChapter) =>
              _checkedSubChapter[subChapter['id']] == true &&
              _generatedSubChapter[subChapter['id']] != true &&
              _usedSubChapter[subChapter['id']] != true, // Exclude used
        )
        .toList()
        .cast<Map<String, dynamic>>();
  }

  /// Shows a summary bottom sheet of checked materials with a single
  /// "Generate Kegiatan Kelas" button — no multi-step dialog flow.
  void _showGenerateSheet(LanguageProvider lp) {
    final checkedChapters = _getCheckedNotGeneratedChapters();
    final checkedSubChapters = _getCheckedNotGeneratedSubChapters();
    final totalChecked = checkedChapters.length + checkedSubChapters.length;
    final p = _getPrimaryColor();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: ColorUtils.slate300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: p.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.auto_awesome, size: 18, color: p)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lp.getTranslatedText({'en': 'Generate Class Activity', 'id': 'Generate Kegiatan Kelas'}), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ColorUtils.slate800)),
                Text(_getSelectedSubjectName(), style: TextStyle(fontSize: 12, color: p, fontWeight: FontWeight.w500)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),
          // Checked items summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: ColorUtils.slate50, borderRadius: BorderRadius.circular(12)),
              child: totalChecked == 0
                  ? Column(children: [
                      Icon(Icons.info_outline, size: 32, color: ColorUtils.slate400),
                      const SizedBox(height: 8),
                      Text(lp.getTranslatedText({'en': 'No chapters selected yet', 'id': 'Belum ada bab yang dipilih'}), style: TextStyle(fontSize: 13, color: ColorUtils.slate500), textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text(lp.getTranslatedText({'en': 'Check chapters/sub-chapters first, then generate', 'id': 'Centang bab/sub-bab terlebih dahulu'}), style: TextStyle(fontSize: 11, color: ColorUtils.slate400), textAlign: TextAlign.center),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.check_circle_outline, size: 16, color: ColorUtils.success600),
                        const SizedBox(width: 6),
                        Text('$totalChecked ${lp.getTranslatedText({'en': 'items ready to generate', 'id': 'materi siap di-generate'})}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColorUtils.slate700)),
                      ]),
                      const SizedBox(height: 8),
                      ...checkedChapters.take(3).map((c) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(children: [
                          Icon(Icons.folder_outlined, size: 14, color: ColorUtils.slate400),
                          const SizedBox(width: 6),
                          Expanded(child: Text(c['judul_bab'] ?? '-', style: TextStyle(fontSize: 12, color: ColorUtils.slate600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                      )),
                      ...checkedSubChapters.take(3).map((s) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(children: [
                          Icon(Icons.description_outlined, size: 14, color: ColorUtils.slate400),
                          const SizedBox(width: 6),
                          Expanded(child: Text(s['judul_sub_bab'] ?? '-', style: TextStyle(fontSize: 12, color: ColorUtils.slate600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                      )),
                      if (totalChecked > 6)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('+${totalChecked - 6} ${lp.getTranslatedText({'en': 'more', 'id': 'lainnya'})}', style: TextStyle(fontSize: 11, color: ColorUtils.slate400)),
                        ),
                    ]),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
              onPressed: totalChecked > 0 ? () {
                Navigator.pop(ctx);
                _openGenerateActivitySheet();
              } : null,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                totalChecked > 0
                    ? lp.getTranslatedText({'en': 'Generate $totalChecked Items', 'id': 'Generate $totalChecked Materi'})
                    : lp.getTranslatedText({'en': 'Select Materials First', 'id': 'Pilih Materi Dulu'}),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, disabledBackgroundColor: ColorUtils.slate200, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            )),
          ),
        ]),
      ),
    );
  }

  /// Opens the activity creation flow in a DraggableScrollableSheet
  /// instead of navigating to a full page.
  void _openGenerateActivitySheet() {
    final checkedChapters = _getCheckedNotGeneratedChapters();
    final checkedSubChapters = _getCheckedNotGeneratedSubChapters();

    String? selectedChapterId;
    String? selectedSubChapterId;
    final List<Map<String, dynamic>> additionalMaterials = [];

    if (checkedSubChapters.isNotEmpty) {
      selectedSubChapterId = checkedSubChapters.first['id']?.toString();
      selectedChapterId = checkedSubChapters.first['bab_id']?.toString();
      for (var sub in checkedSubChapters) {
        additionalMaterials.add({'chapter_id': sub['bab_id'], 'sub_chapter_id': sub['id']});
      }
    } else if (checkedChapters.isNotEmpty) {
      selectedChapterId = checkedChapters.first['id']?.toString();
    }

    final List<Map<String, dynamic>> materialsToMark = [];
    for (var c in checkedChapters) { materialsToMark.add({'bab_id': c['id'], 'sub_bab_id': null}); }
    for (var s in checkedSubChapters) { materialsToMark.add({'bab_id': s['bab_id'], 'sub_bab_id': s['id']}); }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.96, expand: false,
        builder: (ctx, sc) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: EmbeddedActivityListScreen(
            teacherId: widget.teacher['id']?.toString() ?? '',
            teacherName: widget.teacher['nama']?.toString() ?? widget.teacher['name']?.toString() ?? '',
            classId: _selectedClassId ?? widget.initialClassId ?? '',
            className: _selectedClassName ?? widget.initialClassName ?? '',
            subjectId: _selectedSubject ?? '',
            subjectName: _getSelectedSubjectName(),
            initialChapterId: selectedChapterId,
            initialSubChapterId: selectedSubChapterId,
            initialAdditionalMaterials: additionalMaterials,
            materialsToMarkAsGenerated: materialsToMark,
            autoShowActivityDialog: true,
            showScaffold: true,
          ),
        ),
      ),
    ).then((_) {
      if (mounted && _selectedSubject != null) _loadChapterContent(_selectedSubject!);
    });
  }

  bool _isLoading = false;
  bool _isLoadingBab = false;
  // True while waiting for progress data — keeps skeleton visible so checkboxes
  // never flash from unchecked → checked on first render.
  bool _isLoadingProgress = false;

  // Tour properties
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();

  /// Like Vue's `mounted()` -- resolves teacher profile, loads subjects and
  /// chapters, applies initial selections if deep-linked, and shows tour.
  @override
  void initState() {
    super.initState();

    AppLogger.debug('material', 'Teacher data received: ${widget.teacher}');
    AppLogger.debug('material', 'Teacher ID: ${widget.teacher['id']}');

    _loadViewPref();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadViewPref() async {
    try {
      final c = await LocalCacheService.load('materi_view_preference');
      if (c is Map && mounted) setState(() => _isListView = c['is_list_view'] ?? false);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _buildContentCacheKey() {
    final teacherId = widget.teacher['id']?.toString() ?? '';
    if (teacherId.isEmpty) return null;
    return 'materi_data_$teacherId';
  }

  /// Cache key for progress data (checked/generated/used) per teacher+subject+class.
  String _buildProgressCacheKey(String subjectId) {
    final teacherId = widget.teacher['id']?.toString() ?? '';
    final classId = _selectedClassId ?? 'no_class';
    return CacheKeyBuilder.custom('materi_progress', teacherId, '${subjectId}_$classId');
  }

  /// Applies a list of progress API items into the in-memory checkbox maps.
  /// Call this inside a setState block. Like a Vue computed setter that
  /// pushes server state into reactive data.
  void _applyProgressToMaps(List<dynamic> progress) {
    for (var item in progress) {
      final chapterId = item['bab_id'];
      final subChapterId = item['sub_bab_id'];
      final isChecked = item['is_checked'] == 1 || item['is_checked'] == true;
      final isGenerated = item['is_generated'] == 1 || item['is_generated'] == true;
      final isUsed = item['is_used'] == 1 || item['is_used'] == true;

      if (subChapterId != null) {
        _checkedSubChapter[subChapterId.toString()] = isChecked;
        _generatedSubChapter[subChapterId.toString()] = isGenerated;
        _usedSubChapter[subChapterId.toString()] = isUsed;
      } else if (chapterId != null) {
        _checkedChapter[chapterId.toString()] = isChecked;
        _generatedChapter[chapterId.toString()] = isGenerated;
        _usedChapter[chapterId.toString()] = isUsed;
      }
    }

    // Recalculate chapter checked state from sub-chapters
    for (var chapter in _chapterMaterialList) {
      final chapterId = chapter['id'].toString();
      final subs = _subChapterMaterialList
          .where((sb) => sb['bab_id'].toString() == chapterId)
          .toList();
      if (subs.isNotEmpty) {
        _checkedChapter[chapterId] =
            subs.every((sb) => _checkedSubChapter[sb['id'].toString()] == true);
      }
    }
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('materi_');
    await LocalCacheService.clearStartingWith('tour_materi_');
    await LocalCacheService.clearStartingWith('teacher_classes_');
    await LocalCacheService.clearStartingWith('teacher_profile_');
    setState(() {
      _isLoading = true;
      _subjectList.clear();
      _classList.clear();
    });
    _loadData(useCache: false);
  }

  /// Load subjects filtered by classId — cache per class
  Future<void> _loadSubjectsForClass(
    String classId, {
    bool useCache = true,
  }) async {
    final String? teacherId = widget.teacher['id'];
    if (teacherId == null) return;

    final cacheKey = CacheKeyBuilder.custom(
      'materi_subjects',
      teacherId,
      classId,
    );

    // Try cache first
    if (useCache) {
      try {
        final cached = await LocalCacheService.load(
          cacheKey,
          ttl: const Duration(hours: 6),
        );
        if (cached != null && mounted) {
          final subjects = List<dynamic>.from(cached);
          if (subjects.isNotEmpty) {
            _applySubjectList(subjects);
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

    // Fetch from API with classId filter
    try {
      final apiTeacherService = getIt<ApiTeacherService>();
      final subjects = await apiTeacherService.getSubjectByTeacher(
        teacherId,
        classId: classId,
      );
      if (!mounted) return;

      _applySubjectList(subjects);

      // Save to cache
      if (subjects.isNotEmpty) {
        await LocalCacheService.save(cacheKey, subjects);
      }
    } catch (e) {
      AppLogger.error('material', 'Error loading subjects for class: $e');
    }
  }

  /// Apply subject list to state and auto-select first subject
  void _applySubjectList(List<dynamic> subjects) {
    setState(() {
      _subjectList = subjects;
      _chapterMaterialList = [];
      _subChapterMaterialList = [];
      _isLoading = false;

      if (widget.initialSubjectId != null &&
          subjects.any((mp) => mp['id'] == widget.initialSubjectId)) {
        _selectedSubject = widget.initialSubjectId;
      } else if (subjects.isNotEmpty) {
        _selectedSubject = subjects[0]['id'];
      } else {
        _selectedSubject = null;
      }
    });

    if (_selectedSubject != null) {
      _loadChapterContent(_selectedSubject!);
    }
  }

  /// Main data loader -- fetches subjects for the selected class.
  /// Like `axios.get('/api/subjects?classId=...')` in Vue.
  /// Uses a multi-layer cache: TeacherProvider -> LocalCacheService -> API.
  Future<void> _loadData({bool useCache = true}) async {
    try {
      if (!mounted) return;

      final String? teacherId = widget.teacher['id'];
      AppLogger.debug('material', 'Loading data for teacher ID: $teacherId');

      // ─── Fast path for embedded mode (opened from schedule card) ───
      // Skip class list, subject list, and teacher profile resolution.
      // Only load chapters and progress for the given subject.
      if (widget.embedded &&
          widget.initialSubjectId != null &&
          widget.initialClassId != null) {
        final teacherProvider = ref.read(teacherRiverpod);
        _teacherProfileId = teacherProvider.teacherId ?? teacherId;

        setState(() {
          _selectedSubject = widget.initialSubjectId;
          _selectedClassId = widget.initialClassId;
          _selectedClassName = widget.initialClassName;
          _isLoading = false;
        });
        _loadChapterContent(widget.initialSubjectId!);
        return;
      }

      if (teacherId == null || teacherId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        SnackBarUtils.showInfo(context, 'Error: ID guru tidak valid');
        return;
      }

      final cacheKey = _buildContentCacheKey();

      // ─── Step 1: Try TeacherProvider (populated by Dashboard) ───
      final teacherProvider = ref.read(teacherRiverpod);

      // Resolve teacher profile ID from provider (skip /api/teacher/{id})
      if (teacherProvider.isLoaded && teacherProvider.teacherId != null) {
        _teacherProfileId = teacherProvider.teacherId;
        AppLogger.debug(
          'material',
          'TeacherProvider: profileId=$_teacherProfileId',
        );
      }

      List<dynamic>? providerClassList;
      if (teacherProvider.isLoaded && teacherProvider.allClasses.isNotEmpty) {
        providerClassList = teacherProvider.allClasses;
        AppLogger.debug(
          'material',
          'Using TeacherProvider classList (${providerClassList.length} classes)',
        );
      }

      // ─── Step 2: Resolve classList early (for subject filtering) ───
      List<dynamic> resolvedClasses = providerClassList ?? [];

      // If no provider classes, try loading from cache or will be fetched later
      if (resolvedClasses.isEmpty && useCache && cacheKey != null) {
        try {
          final cached = await LocalCacheService.load(
            cacheKey,
            ttl: const Duration(hours: 3),
          );
          if (cached != null) {
            final cachedData = Map<String, dynamic>.from(cached);
            resolvedClasses = List<dynamic>.from(cachedData['classes'] ?? []);
            _teacherProfileId ??= cachedData['teacherProfileId']?.toString();
          }
        } catch (_) {}
      }

      // Determine selected class
      String? selectedClassId;
      String? selectedClassName;
      if (widget.initialClassId != null &&
          resolvedClasses.any((c) => c['id'] == widget.initialClassId)) {
        selectedClassId = widget.initialClassId;
        selectedClassName = widget.initialClassName;
      } else if (resolvedClasses.isNotEmpty) {
        selectedClassId = resolvedClasses[0]['id'];
        selectedClassName =
            resolvedClasses[0]['name'] ?? resolvedClasses[0]['nama'];
      }

      // ─── Step 3: If no initial selection, show overview and stop ───
      if (widget.initialClassId == null && widget.initialSubjectId == null) {
        if (mounted) {
          setState(() {
            _classList = resolvedClasses;
            _isLoading = false;
          });
        }
        // Load overview + schedules in background
        _loadOverviewAndSchedules(teacherId, resolvedClasses);
        return;
      }

      // ─── Step 3b: Try subjects cache (per class) → return early if hit ───
      final effectiveClassKey = selectedClassId ?? 'no_class';
      if (useCache && _subjectList.isEmpty) {
        final subjectCacheKey = CacheKeyBuilder.custom(
          'materi_subjects',
          teacherId,
          effectiveClassKey,
        );
        try {
          final cachedSubjects = await LocalCacheService.load(
            subjectCacheKey,
            ttl: const Duration(hours: 6),
          );
          if (cachedSubjects != null && mounted) {
            final subjects = List<dynamic>.from(cachedSubjects);
            if (subjects.isNotEmpty) {
              setState(() {
                _classList = resolvedClasses;
                _selectedClassId = selectedClassId;
                _selectedClassName = selectedClassName;
                _isLoading = false;
              });

              _applySubjectList(subjects);

              AppLogger.info(
                'material',
                'Loaded from cache (classes + subjects for $selectedClassId) — skipping API',
              );
              return; // ✅ Cache hit — no API calls needed
            }
          }
        } catch (e) {
          AppLogger.error('material', 'Subject cache load error: $e');
        }
      }

      // ─── Step 3: No cache — show skeleton and fetch from API ───
      if (_subjectList.isEmpty && mounted) {
        setState(() => _isLoading = true);
      }

      final ApiTeacherService apiTeacherService = getIt<ApiTeacherService>();

      // ─── Step 4: No cache — fetch from API ───
      // Parallelize getTeacherClasses + getTeacherById when both needed
      List<dynamic> classes = resolvedClasses;
      final bool needClasses = classes.isEmpty;
      final bool needProfile = _teacherProfileId == null;

      if (needClasses || needProfile) {
        // Try dedicated caches first before hitting API
        final classesCacheKey = CacheKeyBuilder.custom(
          'teacher_classes',
          teacherId,
        );
        final profileCacheKey = CacheKeyBuilder.teacherProfile(teacherId);

        if (needClasses && useCache) {
          try {
            final cachedClasses = await LocalCacheService.load(
              classesCacheKey,
              ttl: const Duration(hours: 3),
            );
            if (cachedClasses != null && cachedClasses is List) {
              classes = List<dynamic>.from(cachedClasses);
              classes.sort((a, b) {
                final String nameA = (a['name'] ?? a['nama'] ?? '').toString();
                final String nameB = (b['name'] ?? b['nama'] ?? '').toString();
                return nameA.compareTo(nameB);
              });
              AppLogger.debug(
                'material',
                'TeacherClasses: from cache (${classes.length})',
              );
            }
          } catch (_) {}
        }

        if (needProfile && useCache) {
          try {
            final cachedProfile = await LocalCacheService.load(
              profileCacheKey,
              ttl: const Duration(hours: 6),
            );
            if (cachedProfile != null && cachedProfile is Map) {
              _teacherProfileId = cachedProfile['id']?.toString();
              AppLogger.debug(
                'material',
                'TeacherProfile: from cache (id=$_teacherProfileId)',
              );
            }
          } catch (_) {}
        }

        // Only fetch from API what's still missing
        final bool stillNeedClasses = classes.isEmpty;
        final bool stillNeedProfile = _teacherProfileId == null;

        if (stillNeedClasses || stillNeedProfile) {
          final List<Future> teacherFutures = [];
          if (stillNeedClasses) {
            teacherFutures.add(
              getIt<ApiTeacherService>().getTeacherClasses(teacherId),
            );
          }
          if (stillNeedProfile) {
            teacherFutures.add(apiTeacherService.getTeacherById(teacherId));
          }

          final results = await Future.wait(teacherFutures);
          if (!mounted) return;

          int idx = 0;
          if (stillNeedClasses) {
            classes = results[idx] as List<dynamic>;
            idx++;
            classes.sort((a, b) {
              final String nameA = (a['name'] ?? a['nama'] ?? '').toString();
              final String nameB = (b['name'] ?? b['nama'] ?? '').toString();
              return nameA.compareTo(nameB);
            });
            // Save classes to dedicated cache
            await LocalCacheService.save(classesCacheKey, classes);
          }
          if (stillNeedProfile && idx < results.length) {
            try {
              final teacherProfile = results[idx];
              if (teacherProfile is Map<String, dynamic>) {
                final profileData = teacherProfile['data'] ?? teacherProfile;
                _teacherProfileId = profileData['id']?.toString();
                // Save profile to dedicated cache
                await LocalCacheService.save(profileCacheKey, profileData);
              }
            } catch (e) {
              AppLogger.debug(
                'material',
                'Could not resolve teacher profile ID: $e',
              );
            }
          }
        }
      }

      // Determine selected class for subject filtering
      if (selectedClassId == null && classes.isNotEmpty) {
        if (widget.initialClassId != null &&
            classes.any((c) => c['id'] == widget.initialClassId)) {
          selectedClassId = widget.initialClassId;
          selectedClassName = widget.initialClassName;
        } else {
          selectedClassId = classes[0]['id'];
          selectedClassName = classes[0]['name'] ?? classes[0]['nama'];
        }
      }

      // ─── Show classes immediately while subjects are loading ───
      if (mounted) {
        setState(() {
          _classList = classes;
          _selectedClassId = selectedClassId;
          _selectedClassName = selectedClassName;
        });
      }

      // Save classes cache early (regardless of subjects result)
      if (cacheKey != null && classes.isNotEmpty) {
        // Don't await — save in background
        LocalCacheService.save(cacheKey, {
          'classes': classes,
          'teacherProfileId': _teacherProfileId,
        });
      }

      // Fetch subjects + schedules + materi + overview in parallel
      final academicYearId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();
      final List<Future> futures = [
        apiTeacherService.getSubjectByTeacher(
          teacherId,
          classId: selectedClassId,
        ),
        getIt<ApiSubjectService>().getMaterials(teacherId: teacherId),
        getIt<ApiScheduleService>().getScheduleByTeacher(teacherId: teacherId, academicYear: academicYearId),
        getIt<ApiSubjectService>().getMaterialTeacherSummary(teacherId: teacherId, academicYearId: academicYearId),
      ];

      final results = await Future.wait(futures);
      if (!mounted) return;

      final subject = results[0] as List<dynamic>;
      _schedules = (results[2] as List<dynamic>?) ?? [];
      _overviewSummary = (results[3] as List<dynamic>?) ?? [];
      _isLoadingOverview = false;

      AppLogger.debug(
        'material',
        'Mata pelajaran found: ${subject.length} (class: $selectedClassId)',
      );
      AppLogger.debug('material', 'Classes found: ${classes.length}');

      if (subject.isEmpty) {
        setState(() {
          _isLoading = false;
          _subjectList = [];
        });
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _applySubjectList(subject);

      // Auto-select current schedule's class+subject if teacher is currently teaching
      _autoSelectCurrentSchedule(classes, subject);

      // Save subjects cache in background
      if (subject.isNotEmpty) {
        LocalCacheService.save(
          CacheKeyBuilder.custom(
            'materi_subjects',
            teacherId,
            effectiveClassKey,
          ),
          subject,
        );
      }
      AppLogger.info('material', 'Saved materi data to cache');
    } catch (e) {
      AppLogger.error('material', 'Error loading TeacherMaterialScreen data: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isLoadingBab = false;
      });
      SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
    }
  }

  /// Loads overview summary + schedules in background (called when no initial selection).
  Future<void> _loadOverviewAndSchedules(String teacherId, List<dynamic> classes) async {
    try {
      final academicYearId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();
      final results = await Future.wait([
        getIt<ApiSubjectService>().getMaterialTeacherSummary(teacherId: teacherId, academicYearId: academicYearId),
        getIt<ApiScheduleService>().getScheduleByTeacher(teacherId: teacherId, academicYear: academicYearId),
      ]);
      if (!mounted) return;
      setState(() {
        _overviewSummary = (results[0] as List<dynamic>?) ?? [];
        _schedules = (results[1] as List<dynamic>?) ?? [];
        _isLoadingOverview = false;
      });
    } catch (e) {
      AppLogger.error('material', 'Error loading overview: $e');
      if (mounted) setState(() => _isLoadingOverview = false);
    }
  }

  /// Auto-detects the teacher's current schedule and selects that class+subject.
  /// Same pattern as ClassActivityScreen._autoOpenCurrentSchedule().
  void _autoSelectCurrentSchedule(List<dynamic> classes, List<dynamic> subjects) {
    if (_schedules.isEmpty || widget.initialClassId != null) return;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    const wd = {1: 'senin', 2: 'selasa', 3: 'rabu', 4: 'kamis', 5: 'jumat', 6: 'sabtu'};
    final today = wd[now.weekday] ?? '';

    for (final s in _schedules) {
      final dn = (s['hari_nama'] ?? s['day_name'] ?? '').toString().toLowerCase();
      if (!dn.contains(today)) continue;
      final st = (s['jam_mulai'] ?? s['start_time'])?.toString();
      final et = (s['jam_selesai'] ?? s['end_time'])?.toString();
      if (st == null || et == null) continue;
      int toM(String t) { final p = t.replaceAll('.', ':').split(':'); return p.length < 2 ? 0 : (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0); }
      if (nowMin >= toM(st) && nowMin < toM(et)) {
        final cid = (s['class_id'] ?? s['kelas_id'])?.toString();
        final sid = (s['subject_id'] ?? s['mata_pelajaran_id'])?.toString();
        if (cid != null && sid != null) {
          // Check if this class+subject exists in our lists
          final classMatch = classes.any((c) => c['id']?.toString() == cid);
          final subjectMatch = subjects.any((sub) => (sub['id'] ?? sub['mata_pelajaran_id'])?.toString() == sid);
          if (classMatch && subjectMatch) {
            final cn = classes.firstWhere((c) => c['id']?.toString() == cid)['name'] ?? classes.firstWhere((c) => c['id']?.toString() == cid)['nama'] ?? '';
            if (cid != _selectedClassId?.toString()) {
              // Different class than currently selected — switch
              setState(() {
                _selectedClassId = cid;
                _selectedClassName = cn;
                _selectedSubject = sid;
                _chapterMaterialList = [];
                _subChapterMaterialList = [];
                _isLoadingBab = true;
              });
              _loadChapterContent(sid);
            } else if (sid != _selectedSubject?.toString()) {
              // Same class, different subject — switch subject
              setState(() {
                _selectedSubject = sid;
                _chapterMaterialList = [];
                _subChapterMaterialList = [];
                _isLoadingBab = true;
              });
              _loadChapterContent(sid);
            }
            return;
          }
        }
      }
    }
  }

  /// Loads chapters (bab) and sub-chapters (sub-bab) for a subject.
  /// Like `axios.get('/api/subjects/{id}/chapters')` in Vue.
  /// Also loads progress data to mark generated/used chapters.
  Future<void> _loadChapterContent(
    String subjectId, {
    bool useCache = true,
  }) async {
    final chapterCacheKey = CacheKeyBuilder.custom(
      'materi_bab',
      widget.teacher['id'].toString(),
      subjectId,
    );

    // Show skeleton if list is empty
    if (_chapterMaterialList.isEmpty && mounted) {
      setState(() => _isLoadingBab = true);
    }

    // Step 1: Try cache → return early if hit
    if (useCache && _chapterMaterialList.isEmpty) {
      try {
        final cached = await LocalCacheService.load(
          chapterCacheKey,
          ttl: const Duration(hours: 3),
        );
        if (cached != null && mounted) {
          final cachedData = Map<String, dynamic>.from(cached);
          final cachedChapters = List<dynamic>.from(
            cachedData['chapterMaterials'] ??
                cachedData['chapterMaterials'] ??
                [],
          );
          final cachedSubChapters = List<dynamic>.from(
            cachedData['subChapterMaterials'] ??
                cachedData['subChapterMaterials'] ??
                [],
          );

          if (cachedChapters.isNotEmpty) {
            // Try to load cached progress so checkboxes render correctly on first frame
            List<dynamic> cachedProgress = [];
            try {
              final progressCacheKey = _buildProgressCacheKey(subjectId);
              final cachedProgressData = await LocalCacheService.load(
                progressCacheKey,
                ttl: const Duration(minutes: 30),
              );
              if (cachedProgressData != null) {
                cachedProgress = List<dynamic>.from(cachedProgressData);
              }
            } catch (_) {}

            setState(() {
              _chapterMaterialList = cachedChapters;
              _subChapterMaterialList = cachedSubChapters;
              _isLoadingBab = false;
              _expandedChapter.clear();
              _checkedChapter.clear();
              _checkedSubChapter.clear();
              _generatedChapter.clear();
              _generatedSubChapter.clear();
              _usedChapter.clear();
              _usedSubChapter.clear();
              for (var chapter in cachedChapters) {
                _expandedChapter[chapter['id'].toString()] = false;
                _checkedChapter[chapter['id'].toString()] = false;
                _generatedChapter[chapter['id'].toString()] = false;
                _usedChapter[chapter['id'].toString()] = false;
              }
              for (var sc in cachedSubChapters) {
                _checkedSubChapter[sc['id'].toString()] = false;
              }
              // Apply cached progress in same frame — no checkbox flicker
              if (cachedProgress.isNotEmpty) {
                _applyProgressToMaps(cachedProgress);
                _isLoadingProgress = false;
              } else {
                // No cached progress yet — keep skeleton until API responds
                _isLoadingProgress = true;
              }
            });
            // Refresh progress from API in background (short TTL — user-specific state)
            _loadContentProgress(subjectId);
            // Trigger tour check
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _checkAndShowTour();
            });
            AppLogger.info(
              'material',
              'Loaded bab materi from cache — skipping API',
            );
            return; // ✅ Cache hit — no API calls for bab-material
          }
        }
      } catch (e) {
        AppLogger.error('material', 'Bab cache load error: $e');
      }
    }

    // Step 2: No cache — fetch fresh from API
    try {
      final subject = _subjectList.firstWhere(
        (s) => s['id'] == subjectId,
        orElse: () => null,
      );
      // Fall back to subject's own id if master subject_id is missing
      final masterSubjectId =
          subject?['subject_id']?.toString() ??
          subject?['id']?.toString() ??
          subjectId;

      final chapterMaterials = await getIt<ApiSubjectService>()
          .getChapterMaterials(subjectId: masterSubjectId);
      if (!mounted) return;

      // Extract sub-chapters directly from getChapterMaterials response
      // (backend already includes sub_chapters nested in each chapter)
      final allSubChapters = <dynamic>[];
      for (var chapter in chapterMaterials) {
        final subChapters = chapter['sub_chapters'];
        if (subChapters is List) {
          allSubChapters.addAll(subChapters);
        }
      }

      setState(() {
        _chapterMaterialList = chapterMaterials;
        _subChapterMaterialList = List.from(allSubChapters);
        _isLoadingBab = false;
        // Keep skeleton until _loadContentProgress finishes
        _isLoadingProgress = true;

        _expandedChapter.clear();
        _checkedChapter.clear();
        _checkedSubChapter.clear();
        _generatedChapter.clear();
        _generatedSubChapter.clear();
        _usedChapter.clear();
        _usedSubChapter.clear();

        for (var chapter in chapterMaterials) {
          _expandedChapter[chapter['id'].toString()] = false;
          _checkedChapter[chapter['id'].toString()] = false;
          _generatedChapter[chapter['id'].toString()] = false;
          _usedChapter[chapter['id'].toString()] = false;
        }

        for (var sc in _subChapterMaterialList) {
          _checkedSubChapter[sc['id'].toString()] = false;
        }
      });

      // Save to cache (non-blocking)
      LocalCacheService.save(chapterCacheKey, {
        'chapterMaterials': chapterMaterials,
        'subChapterMaterials': allSubChapters,
      });

      // Load fresh progress from API and cache the result
      _loadContentProgress(subjectId);

      // Trigger tour
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndShowTour();
        }
      });
    } catch (e) {
      AppLogger.error('material', 'Error loading bab and sub-bab: $e');
      if (!mounted) return;
      setState(() => _isLoadingBab = false);
      if (_chapterMaterialList.isEmpty) {
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  // Handle checkbox change on sub-chapter
  void _handleSubChapterCheck(
    String subChapterId,
    String chapterId,
    bool? value,
  ) {
    // Prevent unchecking if already generated (Purple) or Used (Blue)
    if ((_generatedSubChapter[subChapterId] == true ||
            _usedSubChapter[subChapterId] == true) &&
        value == false) {
      return;
    }

    setState(() {
      _checkedSubChapter[subChapterId] = value ?? false;

      // Check if all sub-chapters in this chapter are checked
      final subChaptersForThisChapter = _subChapterMaterialList.where((sb) {
        return sb['bab_id'].toString() == chapterId.toString();
      }).toList();

      if (subChaptersForThisChapter.isNotEmpty) {
        // Check if every sub-chapter is checked
        final allChecked = subChaptersForThisChapter.every((sb) {
          final sbId = sb['id'].toString();
          return _checkedSubChapter[sbId] == true;
        });

        // Update chapter checkbox status
        _checkedChapter[chapterId] = allChecked;

        AppLogger.debug(
          'material',
          'SubChapter check changed: $subChapterId -> $value',
        );
        AppLogger.debug(
          'material',
          'Chapter $chapterId auto-check status: $allChecked',
        );
      }
    });

    // Save to database
    _saveProgress(chapterId, subChapterId, value ?? false);
  }

  // Handle checkbox change on chapter
  void _handleChapterCheck(String chapterId, bool? value) {
    final subs = _subChapterMaterialList.where((sc) => sc['bab_id'].toString() == chapterId).toList();

    if (subs.isEmpty) {
      // No sub-chapters: toggle chapter directly
      if ((_generatedChapter[chapterId] == true || _usedChapter[chapterId] == true) && value == false) return;
      setState(() => _checkedChapter[chapterId] = value ?? false);
      _saveChapterAndSubChaptersProgress(chapterId, value ?? false);
      return;
    }

    // Has sub-chapters: find next unchecked sub-chapter and check it
    final uncheckedSubs = subs.where((sc) {
      final scId = sc['id'].toString();
      return _checkedSubChapter[scId] != true;
    }).toList();

    if (uncheckedSubs.isNotEmpty) {
      // Check the next unchecked sub-chapter
      final nextSub = uncheckedSubs.first;
      final nextSubId = nextSub['id'].toString();
      _handleSubChapterCheck(nextSubId, chapterId, true);
    } else {
      // All sub-chapters are checked — uncheck all (except generated/used)
      if (_generatedChapter[chapterId] == true || _usedChapter[chapterId] == true) return;
      setState(() {
        _checkedChapter[chapterId] = false;
        for (var sc in subs) {
          final scId = sc['id'].toString();
          if (_generatedSubChapter[scId] != true && _usedSubChapter[scId] != true) {
            _checkedSubChapter[scId] = false;
          }
        }
      });
      _saveChapterAndSubChaptersProgress(chapterId, false);
    }
  }

  // Load materi progress from database, cache the result for instant re-render
  Future<void> _loadContentProgress(String subjectId) async {
    try {
      final String? teacherId = widget.teacher['id'];
      if (teacherId == null) return;

      final progress = await getIt<ApiSubjectService>().getMaterialProgress(
        teacherId: teacherId,
        subjectId: subjectId,
        classId: _selectedClassId,
      );
      if (!mounted) return;

      if (kDebugMode) {
        AppLogger.debug('material', '=== LOADING MATERI PROGRESS ===');
        AppLogger.debug('material', 'Teacher ID: $teacherId');
        AppLogger.debug('material', 'Subject ID: $subjectId');
        AppLogger.debug('material', 'API Response Items: ${progress.length}');
        if (progress.isNotEmpty) {
          AppLogger.debug('material', 'First item sample: ${progress.first}');
        }
      }

      // Cache fresh progress so next load shows correct state instantly
      LocalCacheService.save(_buildProgressCacheKey(subjectId), progress);

      setState(() {
        _applyProgressToMaps(progress);
        _isLoadingProgress = false;
      });
    } catch (e) {
      AppLogger.error('material', 'Error loading progress: $e');
      if (mounted) setState(() => _isLoadingProgress = false);
    }
  }

  /// Serialises the current in-memory checkbox/generated/used maps back into
  /// the same list-of-items format the API returns, then saves to cache.
  /// Called after every successful save so switching subjects is always instant
  /// with correct state — no API round-trip needed.
  void _writeProgressToCache(String subjectId) {
    final List<Map<String, dynamic>> snapshot = [];

    for (var chapter in _chapterMaterialList) {
      final chapterId = chapter['id'].toString();
      final subs = _subChapterMaterialList
          .where((sb) => sb['bab_id'].toString() == chapterId)
          .toList();

      if (subs.isEmpty) {
        // Leaf chapter — store its own state
        snapshot.add({
          'bab_id': chapterId,
          'sub_bab_id': null,
          'is_checked': _checkedChapter[chapterId] == true ? 1 : 0,
          'is_generated': _generatedChapter[chapterId] == true ? 1 : 0,
          'is_used': _usedChapter[chapterId] == true ? 1 : 0,
        });
      } else {
        // Chapter with sub-chapters — store each sub-chapter's state
        for (var sc in subs) {
          final scId = sc['id'].toString();
          snapshot.add({
            'bab_id': chapterId,
            'sub_bab_id': scId,
            'is_checked': _checkedSubChapter[scId] == true ? 1 : 0,
            'is_generated': _generatedSubChapter[scId] == true ? 1 : 0,
            'is_used': _usedSubChapter[scId] == true ? 1 : 0,
          });
        }
      }
    }

    LocalCacheService.save(_buildProgressCacheKey(subjectId), snapshot);
  }

  // Save single progress to database
  Future<void> _saveProgress(
    String chapterId,
    String? subChapterId,
    bool isChecked,
  ) async {
    try {
      final String? teacherId = widget.teacher['id'];
      if (teacherId == null || _selectedSubject == null) return;

      await getIt<ApiSubjectService>().saveMateriProgress({
        'teacher_id': teacherId,
        'subject_id': _selectedSubject,
        'class_id': _selectedClassId,
        'chapter_id': chapterId,
        'sub_chapter_id': subChapterId,
        'is_checked': isChecked ? 1 : 0,
      });

      // Write current in-memory state to cache — next subject switch is instant
      _writeProgressToCache(_selectedSubject!);

      AppLogger.info(
        'material',
        'Progress saved: chapter=$chapterId, subChapter=$subChapterId, checked=$isChecked',
      );
    } catch (e) {
      AppLogger.error('material', 'Error saving progress: $e');
    }
  }

  // Save chapter and all its sub-chapters progress to database
  Future<void> _saveChapterAndSubChaptersProgress(
    String chapterId,
    bool isChecked,
  ) async {
    try {
      final String? teacherId = widget.teacher['id'];
      if (teacherId == null || _selectedSubject == null) return;

      // Prepare batch items
      final List<Map<String, dynamic>> progressItems = [];

      // Debug sub-chapter count
      final subChaptersForThisChapter = _subChapterMaterialList
          .where((sb) => sb['bab_id'].toString() == chapterId.toString())
          .toList();

      AppLogger.debug(
        'material',
        'Found ${subChaptersForThisChapter.length} sub-chapters for chapter $chapterId',
      );

      // Add chapter itself ONLY if it has NO sub-chapters
      // If it has sub-chapters, its status is derived and shouldn't be saved explicitly
      if (subChaptersForThisChapter.isEmpty) {
        progressItems.add({
          'bab_id': chapterId,
          'sub_bab_id': null,
          'is_checked': isChecked ? 1 : 0,
        });
      }

      // Add all sub-chapters of this chapter
      for (var sc in subChaptersForThisChapter) {
        // Respect locks: If unchecking, don't include if Generated or Used
        if (isChecked == false) {
          final isGenerated = _generatedSubChapter[sc['id']] == true;
          final isUsed = _usedSubChapter[sc['id']] == true;
          if (isGenerated || isUsed) continue;
        }

        progressItems.add({
          'bab_id': chapterId,
          'sub_bab_id': sc['id'],
          'is_checked': isChecked ? 1 : 0,
        });
      }

      // Batch save
      await getIt<ApiSubjectService>().batchSaveMateriProgress({
        'guru_id': teacherId,
        'mata_pelajaran_id': _selectedSubject,
        'class_id': _selectedClassId,
        'progress_items': progressItems,
      });

      // Write current in-memory state to cache — next subject switch is instant
      _writeProgressToCache(_selectedSubject!);

      AppLogger.info(
        'material',
        'Batch progress saved: ${progressItems.length} items',
      );
    } catch (e) {
      AppLogger.error('material', 'Error batch saving progress: $e');
    }
  }

  // Navigate to sub-chapter detail page
  void _navigateToSubChapterDetail(
    Map<String, dynamic> subChapter,
    Map<String, dynamic> bab,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92, minChildSize: 0.5, maxChildSize: 0.96, expand: false,
        builder: (ctx, sc) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: SubBabDetailPage(
            teacherId: _teacherProfileId ?? widget.teacher['id'],
            subjectId: _selectedSubject ?? '',
            classId: _selectedClassId,
            className: _selectedClassName,
            subChapter: subChapter,
            chapter: bab,
            checked: _checkedSubChapter[subChapter['id'].toString()] ?? false,
            onCheckChanged: (value) {
              _handleSubChapterCheck(
                subChapter['id'].toString(),
                bab['id'].toString(),
                value,
              );
            },
            onGenerated: () {
              if (mounted) {
                setState(() {
                  _generatedSubChapter[subChapter['id'].toString()] = true;
                });
              }
            },
          ),
        ),
      ),
    );
  }

  List<dynamic> _getFilteredChapterContent() {
    final searchTerm = _searchController.text.toLowerCase();

    if (searchTerm.isEmpty) {
      return _chapterMaterialList;
    }

    return _chapterMaterialList.where((chapter) {
      final matchesChapter =
          (chapter['judul_bab']?.toString().toLowerCase().contains(
            searchTerm,
          ) ??
          false);

      // Also search in related sub-chapters
      final subChapterMatches = _subChapterMaterialList
          .where((sc) => sc['bab_id'] == chapter['id'])
          .any(
            (sc) =>
                sc['judul_sub_bab']?.toString().toLowerCase().contains(
                  searchTerm,
                ) ??
                false,
          );

      return matchesChapter || subChapterMatches;
    }).toList();
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }

  bool get _hasActiveFilter => _selectedClassId != null || _selectedSubject != null;

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final p = _getPrimaryColor();

    // ── Embedded mode (opened from schedule card) ──
    if (widget.embedded) {
      return Scaffold(
        backgroundColor: ColorUtils.slate50,
        appBar: AppBar(
          backgroundColor: p,
          foregroundColor: Colors.white,
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
          title: Text(
            '${languageProvider.getTranslatedText({'en': 'Material', 'id': 'Materi'})} — ${widget.initialSubjectName ?? ''} ${widget.initialClassName ?? ''}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          elevation: 0,
        ),
        body: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Column(children: [
            AppSpacing.v8,
            Expanded(child: _buildContent(languageProvider)),
          ]),
        ),
      );
    }

    // ── Main screen ──
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(children: [
          _buildHeader(languageProvider),
          if (_hasActiveFilter) _buildFilterChips(languageProvider),
          Expanded(child: _buildContent(languageProvider)),
        ]),
        floatingActionButton: _selectedSubject != null ? FloatingActionButton.extended(
          onPressed: () => _showGenerateSheet(languageProvider),
          backgroundColor: p,
          icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          label: Text(languageProvider.getTranslatedText({'en': 'Generate', 'id': 'Generate'}), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ) : null,
      ),
    );
  }

  Widget _buildHeader(LanguageProvider lp) {
    final p = _getPrimaryColor();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + AppSpacing.lg, left: AppSpacing.lg, right: AppSpacing.lg, bottom: AppSpacing.lg),
      decoration: BoxDecoration(gradient: _getCardGradient()),
      child: Column(children: [
        // Top row: back + title + generate + overflow
        Row(children: [
          GestureDetector(
            onTap: () => AppNavigator.pop(context),
            child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.arrow_back, color: Colors.white, size: 20)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lp.getTranslatedText({'en': 'Teaching Materials', 'id': 'Materi Pembelajaran'}), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Text(lp.getTranslatedText({'en': 'Browse chapters and sub-chapters', 'id': 'Jelajahi bab dan sub-bab materi'}), style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
          ])),
          // Toggle view button (card ↔ list)
          if (!_hasActiveFilter) GestureDetector(
            onTap: () { setState(() => _isListView = !_isListView); LocalCacheService.save('materi_view_preference', {'is_list_view': _isListView}); },
            child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: Icon(_isListView ? Icons.grid_view_rounded : Icons.view_list_rounded, color: Colors.white, size: 18)),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        // Search + filter row
        Row(children: [
          Expanded(child: Container(
            key: _searchKey,
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _searchController, textAlignVertical: TextAlignVertical.center,
                style: TextStyle(color: ColorUtils.slate800, fontSize: 13),
                decoration: InputDecoration(isDense: true, hintText: lp.getTranslatedText({'en': 'Search chapters...', 'id': 'Cari bab...'}), hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
              )),
              Container(margin: const EdgeInsets.only(right: 4), child: IconButton(icon: Icon(Icons.search, color: p, size: 20), onPressed: () => FocusScope.of(context).unfocus())),
            ]),
          )),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            key: _filterKey,
            onTap: () => _showFilterDialog(lp),
            child: Container(
              height: 48, width: 48,
              decoration: BoxDecoration(color: _hasActiveFilter ? Colors.white : Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
              child: Stack(alignment: Alignment.center, children: [
                Icon(Icons.tune, color: _hasActiveFilter ? p : Colors.white, size: 20),
                if (_hasActiveFilter) Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: ColorUtils.error600, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)))),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }

  void _showFilterDialog(LanguageProvider lp) {
    String? tClassId = _selectedClassId;
    String? tSubjectId = _selectedSubject;
    List<dynamic> tSubjectList = List.from(_subjectList);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: ColorUtils.slate300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: _getPrimaryColor().withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.tune_rounded, size: 18, color: _getPrimaryColor())),
                const SizedBox(width: 12),
                Expanded(child: Text(lp.getTranslatedText({'en': 'Filter Materials', 'id': 'Filter Materi'}), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ColorUtils.slate800))),
                if (tClassId != null || tSubjectId != null)
                  TextButton(onPressed: () => setSS(() { tClassId = null; tSubjectId = null; tSubjectList = []; }), child: Text('Reset', style: TextStyle(color: _getPrimaryColor(), fontSize: 13))),
              ]),
            ),
            const SizedBox(height: 16),
            // Class chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lp.getTranslatedText({'en': 'Class', 'id': 'Kelas'}), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColorUtils.slate700)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: _classList.map((c) {
                  final isSelected = tClassId == c['id']?.toString();
                  return _buildSheetChip(c['name'] ?? c['nama'] ?? '-', isSelected, () async {
                    setSS(() { tClassId = isSelected ? null : c['id']?.toString(); tSubjectId = null; tSubjectList = []; });
                    if (tClassId != null) {
                      try {
                        final subjects = await _getSubjectsForClass(tClassId!);
                        setSS(() => tSubjectList = subjects);
                      } catch (_) {}
                    }
                  });
                }).toList()),
              ]),
            ),
            if (tClassId != null && tSubjectList.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lp.getTranslatedText({'en': 'Subject', 'id': 'Mata Pelajaran'}), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColorUtils.slate700)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: tSubjectList.map((s) {
                    final isSelected = tSubjectId == (s['id'] ?? s['mata_pelajaran_id'])?.toString();
                    return _buildSheetChip(s['nama'] ?? s['name'] ?? '-', isSelected, () => setSS(() => tSubjectId = isSelected ? null : (s['id'] ?? s['mata_pelajaran_id'])?.toString()));
                  }).toList()),
                ]),
              ),
            ],
            if (tClassId != null && tSubjectList.isEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(lp.getTranslatedText({'en': 'Loading subjects...', 'id': 'Memuat mapel...'}), style: TextStyle(color: ColorUtils.slate500, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _applyFilter(tClassId, tSubjectId, tSubjectList);
                },
                style: ElevatedButton.styleFrom(backgroundColor: _getPrimaryColor(), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: Text(lp.getTranslatedText({'en': 'Apply Filter', 'id': 'Terapkan Filter'}), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              )),
            ),
          ]),
        ),
      ),
    );
  }

  Future<List<dynamic>> _getSubjectsForClass(String classId) async {
    try {
      final result = await getIt<ApiTeacherService>().getSubjectByTeacher(
        widget.teacher['id']?.toString() ?? '',
        classId: classId,
      );
      return result;
    } catch (_) {
      return [];
    }
  }

  void _applyFilter(String? classId, String? subjectId, List<dynamic> subjectList) {
    setState(() {
      if (classId != _selectedClassId) {
        _selectedClassId = classId;
        final selectedClass = _classList.firstWhere((c) => c['id'] == classId, orElse: () => {});
        _selectedClassName = selectedClass['name'] ?? selectedClass['nama'];
        _subjectList = subjectList;
        _chapterMaterialList = [];
        _subChapterMaterialList = [];
        if (subjectId == null) {
          _selectedSubject = null;
        }
      }
      if (subjectId != _selectedSubject) {
        _selectedSubject = subjectId;
        _chapterMaterialList = [];
        _subChapterMaterialList = [];
        _isLoadingBab = true;
        if (subjectId != null) {
          _loadChapterContent(subjectId);
        }
      }
      _searchController.clear();
    });
    if (classId != null && subjectId == null && subjectList.isEmpty) {
      _loadSubjectsForClass(classId);
    }
  }

  Widget _buildSheetChip(String label, bool isSelected, VoidCallback onTap) {
    final p = _getPrimaryColor();
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? p.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? p : ColorUtils.slate300, width: isSelected ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: isSelected ? p : ColorUtils.slate600, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  Widget _buildFilterChips(LanguageProvider lp) {
    final p = _getPrimaryColor();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Icon(Icons.filter_alt_outlined, size: 14, color: p),
        const SizedBox(width: 6),
        Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          if (_selectedClassId != null) _buildFilterTag(_selectedClassName ?? '-', () {
            setState(() { _selectedClassId = null; _selectedClassName = null; _selectedSubject = null; _subjectList = []; _chapterMaterialList = []; _subChapterMaterialList = []; });
          }),
          if (_selectedSubject != null) _buildFilterTag(_getSelectedSubjectName(), () {
            setState(() { _selectedSubject = null; _chapterMaterialList = []; _subChapterMaterialList = []; });
          }),
        ]))),
        GestureDetector(
          onTap: () { setState(() { _selectedClassId = null; _selectedClassName = null; _selectedSubject = null; _subjectList = []; _chapterMaterialList = []; _subChapterMaterialList = []; }); },
          child: Text(lp.getTranslatedText({'en': 'Clear', 'id': 'Hapus'}), style: TextStyle(fontSize: 11, color: ColorUtils.error600, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildFilterTag(String label, VoidCallback onRemove) {
    final p = _getPrimaryColor();
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: p.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 11, color: p, fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        GestureDetector(onTap: onRemove, child: Icon(Icons.close, size: 12, color: p)),
      ]),
    );
  }

  Widget _buildContent(LanguageProvider languageProvider) {
    if (_isLoading) {
      return SkeletonListLoading(padding: const EdgeInsets.only(top: 8, bottom: 80), showActions: false);
    }
    // Show overview when no subject selected yet
    if (_selectedSubject == null) {
      return _buildOverview(languageProvider);
    }
    if (_isLoadingBab || _isLoadingProgress) {
      return SkeletonListLoading(padding: const EdgeInsets.only(top: 8, bottom: 80), showActions: false);
    }
    if (_chapterMaterialList.isEmpty) {
      return _buildEmptyState(
        languageProvider.getTranslatedText({'en': 'No materials available for this subject', 'id': 'Tidak ada materi untuk mata pelajaran ini'}),
        languageProvider,
      );
    }
    final filtered = _getFilteredChapterContent();
    if (filtered.isEmpty) {
      return EmptyState(
        title: languageProvider.getTranslatedText({'en': 'No Materials Found', 'id': 'Materi Tidak Ditemukan'}),
        subtitle: languageProvider.getTranslatedText({'en': 'No search results found for "${_searchController.text}"', 'id': 'Tidak ditemukan hasil pencarian untuk "${_searchController.text}"'}),
        icon: Icons.search,
      );
    }
    return RefreshIndicator(
      onRefresh: _forceRefresh,
      color: _getPrimaryColor(),
      child: widget.embedded ? _buildTimelineView() : _buildContentList(),
    );
  }

  /// Flat timeline view for embedded mode — shows all sub-chapters linearly
  /// with chapter headers as dividers. Optimized for quick scanning and selection.
  Widget _buildTimelineView() {
    final p = _getPrimaryColor();
    final chapters = _getFilteredChapterContent();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      children: chapters.asMap().entries.expand((entry) {
        final idx = entry.key;
        final chapter = entry.value;
        final chId = chapter['id'].toString();
        final chColor = ColorUtils.getColorForIndex(idx);
        final subs = _subChapterMaterialList.where((sc) => sc['bab_id'].toString() == chId).toList();
        final isChChecked = _checkedChapter[chId] ?? false;

        return [
          // Chapter header
          Padding(
            padding: EdgeInsets.only(top: idx > 0 ? 20 : 4, bottom: 8),
            child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: chColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: chColor.withValues(alpha: 0.25))),
                child: Center(child: Text('${chapter['urutan'] ?? idx + 1}', style: TextStyle(color: chColor, fontWeight: FontWeight.w700, fontSize: 14)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(chapter['judul_bab'] ?? chapter['title'] ?? '-', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: ColorUtils.slate900), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (subs.isNotEmpty) Text('${subs.length} sub-bab', style: TextStyle(color: ColorUtils.slate500, fontSize: 12)),
              ])),
              // Chapter checkbox (indeterminate when partial)
              Builder(builder: (_) {
                final checkedCount = subs.where((sc) => _checkedSubChapter[sc['id'].toString()] == true).length;
                final isAllChecked = subs.isNotEmpty ? checkedCount == subs.length : isChChecked;
                final isPartial = subs.isNotEmpty && checkedCount > 0 && checkedCount < subs.length;

                Color bgColor = ColorUtils.slate50;
                Color borderColor = ColorUtils.slate300;
                double borderWidth = 1;
                Widget? icon;

                if (isAllChecked) {
                  bgColor = ColorUtils.success600;
                  borderColor = ColorUtils.success600;
                  borderWidth = 1.5;
                  icon = const Icon(Icons.check_rounded, size: 16, color: Colors.white);
                } else if (isPartial) {
                  bgColor = ColorUtils.slate500;
                  borderColor = ColorUtils.slate500;
                  borderWidth = 1.5;
                  icon = const Icon(Icons.remove_rounded, size: 16, color: Colors.white);
                }

                return GestureDetector(
                  onTap: () => _handleChapterCheck(chId, !isAllChecked),
                  child: Container(width: 28, height: 28, decoration: BoxDecoration(
                    color: bgColor, borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: borderColor, width: borderWidth),
                  ), child: icon),
                );
              }),
            ]),
          ),
          // Sub-chapters as timeline items
          ...subs.asMap().entries.map((subEntry) {
            final subIdx = subEntry.key;
            final sc = subEntry.value;
            final scId = sc['id'].toString();
            final isScChecked = _checkedSubChapter[scId] ?? false;
            final isLast = subIdx == subs.length - 1;

            return IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Timeline connector
                SizedBox(width: 36, child: Column(children: [
                  Container(width: 2, height: 8, color: chColor.withValues(alpha: 0.3)),
                  Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: isScChecked ? ColorUtils.success600 : chColor.withValues(alpha: 0.3))),
                  if (!isLast) Expanded(child: Container(width: 2, color: chColor.withValues(alpha: 0.3))),
                ])),
                const SizedBox(width: 12),
                // Sub-chapter card
                Expanded(child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Material(color: Colors.transparent, child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _navigateToSubChapterDetail(Map<String, dynamic>.from(sc), Map<String, dynamic>.from(chapter)),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isScChecked ? ColorUtils.success600.withValues(alpha: 0.3) : ColorUtils.slate200),
                      ),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(sc['judul_sub_bab'] ?? sc['title'] ?? '-', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: ColorUtils.slate800)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.auto_stories_rounded, size: 12, color: ColorUtils.success600),
                            const SizedBox(width: 4),
                            Text('Materi', style: TextStyle(fontSize: 10, color: ColorUtils.success600, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            Icon(Icons.quiz_rounded, size: 12, color: ColorUtils.warning600),
                            const SizedBox(width: 4),
                            Text('Kuis', style: TextStyle(fontSize: 10, color: ColorUtils.warning600, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            Icon(Icons.bookmark_rounded, size: 12, color: ColorUtils.info600),
                            const SizedBox(width: 4),
                            Text('Ref', style: TextStyle(fontSize: 10, color: ColorUtils.info600, fontWeight: FontWeight.w500)),
                          ]),
                        ])),
                        const SizedBox(width: 8),
                        // Checkbox
                        GestureDetector(
                          onTap: () => _handleSubChapterCheck(scId, chId, !isScChecked),
                          child: Container(width: 26, height: 26, decoration: BoxDecoration(
                            color: isScChecked ? ColorUtils.success600 : ColorUtils.slate50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isScChecked ? ColorUtils.success600 : ColorUtils.slate300, width: isScChecked ? 1.5 : 1),
                          ), child: isScChecked ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right, size: 18, color: p),
                      ]),
                    ),
                  )),
                )),
              ]),
            );
          }),
        ];
      }).toList(),
    );
  }



  Widget _buildOverview(LanguageProvider lp) {
    if (_isLoadingOverview) {
      return SkeletonListLoading(padding: const EdgeInsets.only(top: 8, bottom: 80), showActions: false);
    }
    if (_overviewSummary.isEmpty) {
      return _buildEmptyState(
        lp.getTranslatedText({'en': 'No teaching materials found', 'id': 'Tidak ada materi mengajar'}),
        lp,
      );
    }
    final p = _getPrimaryColor();
    return RefreshIndicator(
      onRefresh: _forceRefresh,
      color: p,
      child: _isListView ? _buildListView(lp, p) : _buildCardView(lp, p),
    );
  }

  // ── Card view (default) — cards with "Lihat Bab" button ──

  Widget _buildCardView(LanguageProvider lp, Color p) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _overviewSummary.length,
      itemBuilder: (context, index) {
        final g = _overviewSummary[index];
        final cn = g['class_name']?.toString() ?? '-';
        final sn = g['subject_name']?.toString() ?? '-';
        final totalChapters = g['total_chapters'] ?? 0;
        final totalSubs = g['total_sub_chapters'] ?? 0;
        final checked = g['checked'] ?? 0;
        final generated = g['generated'] ?? 0;
        final progressPct = (g['progress_pct'] ?? 0).toDouble();
        final pctColor = progressPct >= 80 ? ColorUtils.success600 : (progressPct >= 40 ? ColorUtils.warning600 : ColorUtils.slate400);
        final classId = g['class_id']?.toString() ?? '';
        final subjectId = g['subject_id']?.toString() ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Material(color: Colors.transparent, child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openChapterSheet(classId, cn, subjectId, sn, lp),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ColorUtils.slate200), boxShadow: ColorUtils.corporateShadow(elevation: 1.0)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header row
                Row(children: [
                  SizedBox(width: 44, height: 44, child: Stack(alignment: Alignment.center, children: [
                    SizedBox(width: 44, height: 44, child: CircularProgressIndicator(value: progressPct / 100, strokeWidth: 4, backgroundColor: ColorUtils.slate100, color: pctColor)),
                    Text('${progressPct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: pctColor)),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Kelas: $cn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ColorUtils.slate900), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(sn, style: TextStyle(fontSize: 12, color: p, fontWeight: FontWeight.w600)),
                  ])),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: p.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$totalChapters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p)),
                    Text('bab', style: TextStyle(fontSize: 8, color: p, fontWeight: FontWeight.w500)),
                  ])),
                ]),
                const SizedBox(height: 10),
                // Stats row + Lihat Bab
                Row(children: [
                  _overviewStatChip(Icons.list_rounded, '$totalSubs sub-bab', ColorUtils.slate600),
                  const SizedBox(width: 10),
                  _overviewStatChip(Icons.check_circle_outline, '$checked selesai', ColorUtils.success600),
                  const SizedBox(width: 10),
                  _overviewStatChip(Icons.auto_awesome_outlined, '$generated AI', ColorUtils.violet500),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: p.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(lp.getTranslatedText({'en': 'View', 'id': 'Lihat Bab'}), style: TextStyle(fontSize: 11, color: p, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right, size: 14, color: p),
                    ])),
                ]),
              ]),
            ),
          )),
        );
      },
    );
  }

  /// Opens the embedded material screen as a detail sheet.
  void _openChapterSheet(String classId, String cn, String subjectId, String sn, LanguageProvider lp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: TeacherMaterialScreen(
            teacher: widget.teacher,
            initialClassId: classId,
            initialClassName: cn,
            initialSubjectId: subjectId,
            initialSubjectName: sn,
            embedded: true,
          ),
        ),
      ),
    );
  }

  // ── List view — grouped by subject, shows classes as badges ──

  Widget _buildListView(LanguageProvider lp, Color p) {
    // Group by subject
    final Map<String, List<dynamic>> bySubject = {};
    for (final g in _overviewSummary) {
      final sn = g['subject_name']?.toString() ?? '-';
      bySubject.putIfAbsent(sn, () => []).add(g);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: bySubject.entries.map((entry) {
        final subjectName = entry.key;
        final items = entry.value;
        final totalChapters = items.first['total_chapters'] ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ColorUtils.slate200), boxShadow: ColorUtils.corporateShadow(elevation: 1.0)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Subject header
            Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: p.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.menu_book_outlined, color: p, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(subjectName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ColorUtils.slate900)),
                Text('$totalChapters bab · ${items.length} kelas', style: TextStyle(fontSize: 12, color: ColorUtils.slate500)),
              ])),
            ]),
            const SizedBox(height: 10),
            // Class rows
            ...items.map((g) {
              final cn = g['class_name']?.toString() ?? '-';
              final progressPct = (g['progress_pct'] ?? 0).toDouble();
              final pctColor = progressPct >= 80 ? ColorUtils.success600 : (progressPct >= 40 ? ColorUtils.warning600 : ColorUtils.slate400);
              final classId = g['class_id']?.toString() ?? '';
              final subjectId = g['subject_id']?.toString() ?? '';

              return Material(color: Colors.transparent, child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openChapterSheet(classId, cn, subjectId, subjectName, lp),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: ColorUtils.slate50, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: p.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(cn, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: progressPct / 100, minHeight: 6, backgroundColor: ColorUtils.slate200, color: pctColor))),
                    const SizedBox(width: 8),
                    Text('${progressPct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: pctColor)),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right, size: 16, color: ColorUtils.slate400),
                  ]),
                ),
              ));
            }),
          ]),
        );
      }).toList(),
    );
  }

  Widget _overviewStatChip(IconData icon, String label, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _buildEmptyState(String message, LanguageProvider languageProvider) {
    return EmptyState(
      title: languageProvider.getTranslatedText({
        'en': 'No Materials',
        'id': 'Tidak Ada Materi',
      }),
      subtitle: message,
      icon: Icons.menu_book,
    );
  }

  Color _getCheckboxColor(String id, {bool isSubChapter = false}) {
    if (isSubChapter) {
      if (_usedSubChapter[id] == true) return ColorUtils.info600;
      if (_generatedSubChapter[id] == true) return ColorUtils.violet500;
      return ColorUtils.success600;
    } else {
      if (_usedChapter[id] == true) return ColorUtils.info600;
      if (_generatedChapter[id] == true) return ColorUtils.violet500;
      return ColorUtils.success600;
    }
  }

  bool _hasAutoExpanded = false;

  /// In embedded mode, auto-expand and scroll to the first un-checked chapter
  /// (or the last checked one if all filled). Called once after content loads.
  void _autoExpandToRelevantChapter() {
    if (!widget.embedded || _hasAutoExpanded || _chapterMaterialList.isEmpty) return;
    _hasAutoExpanded = true;

    // Find first chapter that is NOT fully checked
    String? targetChapterId;
    for (final chapter in _chapterMaterialList) {
      final chapterId = chapter['id']?.toString();
      if (chapterId == null) continue;

      final isChecked = _checkedChapter[chapterId] == true;
      if (!isChecked) {
        targetChapterId = chapterId;
        break;
      }
    }

    // If all checked, go to last chapter
    if (targetChapterId == null && _chapterMaterialList.isNotEmpty) {
      targetChapterId = _chapterMaterialList.last['id']?.toString();
    }

    if (targetChapterId != null) {
      setState(() {
        _expandedChapter[targetChapterId!] = true;
      });
    }
  }

  /// Delegates to [MaterialContentList] — purely presentational.
  /// Expand/collapse and checkbox mutations flow back via callbacks.
  Widget _buildContentList() {
    // Auto-expand relevant chapter in embedded mode
    if (widget.embedded) _autoExpandToRelevantChapter();
    return MaterialContentList(
      filteredChapterMaterials: _getFilteredChapterContent(),
      subChapterMaterialList: _subChapterMaterialList,
      expandedChapter: _expandedChapter,
      checkedChapter: _checkedChapter,
      checkedSubChapter: _checkedSubChapter,
      getCheckboxColor: _getCheckboxColor,
      onChapterExpanded: (chapterId, newExpanded) {
        setState(() => _expandedChapter[chapterId] = newExpanded);
      },
      onChapterCheck: _handleChapterCheck,
      onSubChapterTap: _navigateToSubChapterDetail,
      onSubChapterCheck: _handleSubChapterCheck,
    );
  }

  String _getSelectedSubjectName() {
    if (_selectedSubject == null) return '-';
    final mp = _subjectList.firstWhere(
      (mp) => (mp['id'] ?? mp['mata_pelajaran_id'])?.toString() == _selectedSubject?.toString(),
      orElse: () => {'nama': '-', 'name': '-'},
    );
    return mp['nama'] ?? mp['name'] ?? '-';
  }

  late final MaterialTourHelper _tourHelper = MaterialTourHelper(
    filterKey: _filterKey,
    searchKey: _searchKey,
  );

  Future<void> _checkAndShowTour() => _tourHelper.checkAndShow(context);
}

