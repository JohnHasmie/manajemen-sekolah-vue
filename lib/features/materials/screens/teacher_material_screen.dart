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
// - [MateriPage] -- the main material browser with subject/chapter tree
// - [SubBabDetailPage] -- detail view for a sub-chapter's content
//
// In Laravel terms, combines MaterialController@index, @show, and
// ChapterController with progress tracking.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/enhanced_search_bar.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/class_activity/screens/teacher_class_activity_screen.dart';
import 'package:manajemensekolah/features/materials/screens/sub_chapter_detail_screen.dart';
import 'package:manajemensekolah/features/subjects/services/subject_service.dart';
import 'package:manajemensekolah/features/teachers/services/teacher_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Teaching material browser with subject, chapter, and sub-chapter navigation.
///
/// This is a StatefulWidget with complex local state for managing the chapter
/// tree, checkboxes, progress tracking, and AI generation flow. In Vue terms,
/// it is like a page component with deeply nested reactive data.
///
/// Props (like Vue props): [teacher], optional initial* for deep linking.
class MateriPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final String? initialClassId;
  final String? initialClassName;

  const MateriPage({
    super.key,
    required this.teacher,
    this.initialSubjectId,
    this.initialSubjectName,
    this.initialClassId,
    this.initialClassName,
  });

  @override
  MateriPageState createState() => MateriPageState();
}

/// State for [MateriPage].
///
/// Like a Vue page component with `data() { return {...} }`. Manages:
/// - Subject/class selection dropdowns
/// - Chapter (bab) and sub-chapter (sub-bab) tree with expand/collapse
/// - Checkbox state for selecting items to generate AI content
/// - Progress tracking (generated, used status) per chapter
///
/// `setState()` is like Vue's reactivity -- triggers UI rebuild.
class MateriPageState extends ConsumerState<MateriPage> {
  String? _selectedSubject;
  String? _selectedClassId;
  String? _selectedClassName;
  List<dynamic> _subjectList = [];
  List<dynamic> _classList = [];
  List<dynamic> _chapterMaterialList = [];
  List<dynamic> _subChapterMaterialList = [];

  // Search dan Filter
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

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

  // Navigate to class activity page with selected chapters
  /// Navigates to ClassActivity screen with checked chapters for RPP generation.
  /// Like a Vue `methods.navigateToGenerate()` that uses `this.$router.push()`.
  void _navigateToGenerateRPP() async {
    // Use ones that haven't been generated yet
    final checkedChapters = _getCheckedNotGeneratedChapters();
    final checkedSubChapters = _getCheckedNotGeneratedSubChapters();

    if (checkedChapters.isEmpty && checkedSubChapters.isEmpty) {
            SnackBarUtils.showInfo(context, 'Pilih minimal 1 bab atau sub bab untuk di-generate');
      return;
    }

    String? selectedChapterId;
    String? selectedSubChapterId;

    // If sub-chapter is selected, get its parent chapter and the sub-chapter itself
    if (checkedSubChapters.isNotEmpty) {
      final firstSubChapter = checkedSubChapters.first;
      selectedSubChapterId = firstSubChapter['id']?.toString();
      selectedChapterId = firstSubChapter['bab_id']?.toString();

      AppLogger.debug('material', 'Selected sub-chapter: $selectedSubChapterId, parent chapter: $selectedChapterId',);
    }
    // If only chapter is selected (no sub-chapter)
    else if (checkedChapters.isNotEmpty) {
      selectedChapterId = checkedChapters.first['id']?.toString();

      AppLogger.debug('material', 'Selected chapter only: $selectedChapterId');
    }

    // Prepare additional materials (all checked sub-chapters)
    // We pass ALL checked sub-chapters as "additional" materials.
    // The activity form logic will filter out the primary one if needed.
    final List<Map<String, dynamic>> additionalMaterials = [];
    if (checkedSubChapters.isNotEmpty) {
      for (var sub in checkedSubChapters) {
        additionalMaterials.add({
          'chapter_id': sub['bab_id'],
          'sub_chapter_id': sub['id'],
        });
      }
    }

    // Prepare list to mark as generated upon success
    final List<Map<String, dynamic>> materialsToMarkAsGenerated = [];
    for (var chapter in checkedChapters) {
      materialsToMarkAsGenerated.add({'bab_id': chapter['id'], 'sub_bab_id': null});
    }
    for (var subChapter in checkedSubChapters) {
      materialsToMarkAsGenerated.add({
        'bab_id': subChapter['bab_id'],
        'sub_bab_id': subChapter['id'],
      });
    }

    if (!mounted) return;

    await AppNavigator.push(context, ClassActifityScreen(
          initialSubjectId: _selectedSubject,
          initialSubjectName: _getSelectedSubjectName(),
          initialClassId: _selectedClassId ?? widget.initialClassId,
          initialClassName: _selectedClassName ?? widget.initialClassName,
          initialChapterId: selectedChapterId,
          initialSubChapterId: selectedSubChapterId,
          initialAdditionalMaterials: additionalMaterials,
          materialsToMarkAsGenerated: materialsToMarkAsGenerated,
          autoShowActivityDialog: true,
        ));

    // Refresh data after returning
    if (mounted && _selectedSubject != null) {
      _loadChapterMaterials(_selectedSubject!);
    }
  }

  bool _isLoading = false;
  bool _isLoadingBab = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _buildMaterialCacheKey() {
    final teacherId = widget.teacher['id']?.toString() ?? '';
    if (teacherId.isEmpty) return null;
    return 'materi_data_$teacherId';
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
  Future<void> _loadSubjectsForClass(String classId, {bool useCache = true}) async {
    final String? teacherId = widget.teacher['id'];
    if (teacherId == null) return;

    final cacheKey = CacheKeyBuilder.custom('materi_subjects', teacherId, classId);

    // Try cache first
    if (useCache) {
      try {
        final cached = await LocalCacheService.load(cacheKey, ttl: const Duration(hours: 6));
        if (cached != null && mounted) {
          final subjects = List<dynamic>.from(cached);
          if (subjects.isNotEmpty) {
            _applySubjectList(subjects);
            AppLogger.info('material', 'Loaded subjects for class $classId from cache');
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
      final subjects = await apiTeacherService.getSubjectByTeacher(teacherId, classId: classId);
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
      _loadChapterMaterials(_selectedSubject!);
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

      if (teacherId == null || teacherId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
                SnackBarUtils.showInfo(context, 'Error: ID guru tidak valid');
        return;
      }

      final cacheKey = _buildMaterialCacheKey();

      // ─── Step 1: Try TeacherProvider (populated by Dashboard) ───
      final teacherProvider = ref.read(teacherRiverpod);

      // Resolve teacher profile ID from provider (skip /api/teacher/{id})
      if (teacherProvider.isLoaded && teacherProvider.teacherId != null) {
        _teacherProfileId = teacherProvider.teacherId;
        AppLogger.debug('material', 'TeacherProvider: profileId=$_teacherProfileId');
      }

      List<dynamic>? providerClassList;
      if (teacherProvider.isLoaded && teacherProvider.allClasses.isNotEmpty) {
        providerClassList = teacherProvider.allClasses;
        AppLogger.debug('material', 'Using TeacherProvider classList (${providerClassList.length} classes)');
      }

      // ─── Step 2: Resolve classList early (for subject filtering) ───
      List<dynamic> resolvedClasses = providerClassList ?? [];

      // If no provider classes, try loading from cache or will be fetched later
      if (resolvedClasses.isEmpty && useCache && cacheKey != null) {
        try {
          final cached = await LocalCacheService.load(cacheKey, ttl: const Duration(hours: 3));
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
        selectedClassName = resolvedClasses[0]['name'] ?? resolvedClasses[0]['nama'];
      }

      // ─── Step 3: Try subjects cache (per class) → return early if hit ───
      final effectiveClassKey = selectedClassId ?? 'no_class';
      if (useCache && _subjectList.isEmpty) {
        final subjectCacheKey = CacheKeyBuilder.custom('materi_subjects', teacherId, effectiveClassKey);
        try {
          final cachedSubjects = await LocalCacheService.load(subjectCacheKey, ttl: const Duration(hours: 6));
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

              AppLogger.info('material', 'Loaded from cache (classes + subjects for $selectedClassId) — skipping API');
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
        final classesCacheKey = CacheKeyBuilder.custom('teacher_classes', teacherId);
        final profileCacheKey = CacheKeyBuilder.teacherProfile(teacherId);

        if (needClasses && useCache) {
          try {
            final cachedClasses = await LocalCacheService.load(classesCacheKey, ttl: const Duration(hours: 3));
            if (cachedClasses != null && cachedClasses is List) {
              classes = List<dynamic>.from(cachedClasses);
              classes.sort((a, b) {
                final String nameA = (a['name'] ?? a['nama'] ?? '').toString();
                final String nameB = (b['name'] ?? b['nama'] ?? '').toString();
                return nameA.compareTo(nameB);
              });
              AppLogger.debug('material', 'TeacherClasses: from cache (${classes.length})');
            }
          } catch (_) {}
        }

        if (needProfile && useCache) {
          try {
            final cachedProfile = await LocalCacheService.load(profileCacheKey, ttl: const Duration(hours: 6));
            if (cachedProfile != null && cachedProfile is Map) {
              _teacherProfileId = cachedProfile['id']?.toString();
              AppLogger.debug('material', 'TeacherProfile: from cache (id=$_teacherProfileId)');
            }
          } catch (_) {}
        }

        // Only fetch from API what's still missing
        final bool stillNeedClasses = classes.isEmpty;
        final bool stillNeedProfile = _teacherProfileId == null;

        if (stillNeedClasses || stillNeedProfile) {
          final List<Future> teacherFutures = [];
          if (stillNeedClasses) teacherFutures.add(getIt<ApiTeacherService>().getTeacherClasses(teacherId));
          if (stillNeedProfile) teacherFutures.add(apiTeacherService.getTeacherById(teacherId));

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
              AppLogger.debug('material', 'Could not resolve teacher profile ID: $e');
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

      // Fetch subjects filtered by selected class + materi in parallel
      final List<Future> futures = [
        apiTeacherService.getSubjectByTeacher(teacherId, classId: selectedClassId),
        getIt<ApiSubjectService>().getMateri(teacherId: teacherId),
      ];

      final results = await Future.wait(futures);
      if (!mounted) return;

      final subject = results[0] as List<dynamic>;

      AppLogger.debug('material', 'Mata pelajaran found: ${subject.length} (class: $selectedClassId)');
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

      // Save subjects cache in background
      if (subject.isNotEmpty) {
        LocalCacheService.save(CacheKeyBuilder.custom('materi_subjects', teacherId, effectiveClassKey), subject);
      }
      AppLogger.info('material', 'Saved materi data to cache');
    } catch (e) {
      AppLogger.error('material', 'Error loading MateriPage data: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isLoadingBab = false;
      });
            SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
    }
  }

  /// Loads chapters (bab) and sub-chapters (sub-bab) for a subject.
  /// Like `axios.get('/api/subjects/{id}/chapters')` in Vue.
  /// Also loads progress data to mark generated/used chapters.
  Future<void> _loadChapterMaterials(String subjectId, {bool useCache = true}) async {
    final chapterCacheKey = CacheKeyBuilder.custom('materi_bab', widget.teacher['id'].toString(), subjectId);

    // Show skeleton if list is empty
    if (_chapterMaterialList.isEmpty && mounted) {
      setState(() => _isLoadingBab = true);
    }

    // Step 1: Try cache → return early if hit
    if (useCache && _chapterMaterialList.isEmpty) {
      try {
        final cached = await LocalCacheService.load(chapterCacheKey, ttl: const Duration(hours: 3));
        if (cached != null && mounted) {
          final cachedData = Map<String, dynamic>.from(cached);
          final cachedChapters = List<dynamic>.from(cachedData['chapterMaterials'] ?? cachedData['chapterMaterials'] ?? []);
          final cachedSubChapters = List<dynamic>.from(cachedData['subChapterMaterials'] ?? cachedData['subChapterMaterials'] ?? []);

          if (cachedChapters.isNotEmpty) {
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
            });
            // Load progress from DB non-blocking (always fresh — this is user-specific state)
            _loadMaterialProgress(subjectId);
            // Trigger tour check
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _checkAndShowTour();
            });
            AppLogger.info('material', 'Loaded bab materi from cache — skipping API');
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
      final masterSubjectId = subject?['subject_id']?.toString() ?? subject?['id']?.toString() ?? subjectId;

      final chapterMaterials = await getIt<ApiSubjectService>().getChapterMaterials(
        subjectId: masterSubjectId,
      );
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

      // Load progress from database (non-blocking — UI already shows chapter structure)
      _loadMaterialProgress(subjectId);

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
  void _handleSubChapterCheck(String subChapterId, String chapterId, bool? value) {
    // Prevent unchecking if already generated (Purple) or Used (Blue)
    if ((_generatedSubChapter[subChapterId] == true || _usedSubChapter[subChapterId] == true) &&
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

        AppLogger.debug('material', 'SubChapter check changed: $subChapterId -> $value');
        AppLogger.debug('material', 'Chapter $chapterId auto-check status: $allChecked');
      }
    });

    // Save to database
    _saveProgress(chapterId, subChapterId, value ?? false);
  }

  // Handle checkbox change on chapter
  void _handleChapterCheck(String chapterId, bool? value) {
    // Prevent unchecking if already generated (Purple) or Used (Blue)
    if ((_generatedChapter[chapterId] == true || _usedChapter[chapterId] == true) &&
        value == false) {
      return;
    }

    setState(() {
      _checkedChapter[chapterId] = value ?? false;

      // Update sub-chapters logic:
      // If checking chapter (True): Check all sub-chapters.
      // If unchecking chapter (False): Uncheck all sub-chapters EXCEPT those that are Generated (Purple).
      for (var subChapter in _subChapterMaterialList.where(
        (sc) => sc['bab_id'] == chapterId,
      )) {
        if (value == true) {
          _checkedSubChapter[subChapter['id']] = true;
        } else {
          // If unchecking, only uncheck if NOT generated and NOT used
          if (_generatedSubChapter[subChapter['id']] != true &&
              _usedSubChapter[subChapter['id']] != true) {
            _checkedSubChapter[subChapter['id']] = false;
          }
        }
      }
    });

    // Save to database (chapter and all its sub-chapters)
    _saveChapterAndSubChaptersProgress(chapterId, value ?? false);
  }

  // Load materi progress from database
  Future<void> _loadMaterialProgress(String subjectId) async {
    try {
      final String? teacherId = widget.teacher['id'];
      if (teacherId == null) return;

      final progress = await getIt<ApiSubjectService>().getMateriProgress(
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

      setState(() {
        // Apply checked and generated state from database
        for (var item in progress) {
          final chapterId = item['bab_id'];
          final subChapterId = item['sub_bab_id'];
          final isChecked =
              item['is_checked'] == 1 || item['is_checked'] == true;
          final isGenerated =
              item['is_generated'] == 1 || item['is_generated'] == true;
          final isUsed = item['is_used'] == 1 || item['is_used'] == true;

          if (subChapterId != null) {
            // Sub-chapter checked and generated status
            _checkedSubChapter[subChapterId.toString()] = isChecked;
            _generatedSubChapter[subChapterId.toString()] = isGenerated;
            _usedSubChapter[subChapterId.toString()] = isUsed;
          } else if (chapterId != null) {
            // Chapter checked and generated status (no specific sub-chapter)
            _checkedChapter[chapterId.toString()] = isChecked;
            _generatedChapter[chapterId.toString()] = isGenerated;
            _usedChapter[chapterId.toString()] = isUsed;
          }
        }

        // Final pass: Recalculate chapter status based on sub-chapters
        // This ensures visual correctness even if chapter record is absent in DB
        for (var chapter in _chapterMaterialList) {
          final chapterId = chapter['id'].toString();
          final subChaptersForThisChapter = _subChapterMaterialList
              .where((sb) => sb['bab_id'].toString() == chapterId)
              .toList();

          if (subChaptersForThisChapter.isNotEmpty) {
            final allSubChaptersChecked =
                subChaptersForThisChapter.isNotEmpty &&
                subChaptersForThisChapter.every(
                  (sb) => _checkedSubChapter[sb['id'].toString()] == true,
                );
            _checkedChapter[chapterId] = allSubChaptersChecked;
          }
        }
      });
    } catch (e) {
      AppLogger.error('material', 'Error loading progress: $e');
    }
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

      AppLogger.info('material', 'Progress saved: chapter=$chapterId, subChapter=$subChapterId, checked=$isChecked',);
    } catch (e) {
      AppLogger.error('material', 'Error saving progress: $e');
    }
  }

  // Save chapter and all its sub-chapters progress to database
  Future<void> _saveChapterAndSubChaptersProgress(String chapterId, bool isChecked) async {
    try {
      final String? teacherId = widget.teacher['id'];
      if (teacherId == null || _selectedSubject == null) return;

      // Prepare batch items
      final List<Map<String, dynamic>> progressItems = [];

      // Debug sub-chapter count
      final subChaptersForThisChapter = _subChapterMaterialList
          .where((sb) => sb['bab_id'].toString() == chapterId.toString())
          .toList();

      AppLogger.debug('material', 'Found ${subChaptersForThisChapter.length} sub-chapters for chapter $chapterId');

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

      AppLogger.info('material', 'Batch progress saved: ${progressItems.length} items');
    } catch (e) {
      AppLogger.error('material', 'Error batch saving progress: $e');
    }
  }

  // Navigate to sub-chapter detail page
  void _navigateToSubChapterDetail(
    Map<String, dynamic> subChapter,
    Map<String, dynamic> bab,
  ) {
    AppNavigator.push(context, SubBabDetailPage(
          teacherId: _teacherProfileId ?? widget.teacher['id'],
          subjectId: _selectedSubject ?? '',
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
        ));
  }

  List<dynamic> _getFilteredChapterMaterials() {
    final searchTerm = _searchController.text.toLowerCase();

    if (searchTerm.isEmpty) {
      return _chapterMaterialList;
    }

    return _chapterMaterialList.where((chapter) {
      final matchesChapter =
          (chapter['judul_bab']?.toString().toLowerCase().contains(searchTerm) ??
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

  Widget _buildHeader(LanguageProvider languageProvider) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: _getCardGradient(),
        boxShadow: [
          BoxShadow(
            color: _getPrimaryColor().withValues(alpha: 0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => AppNavigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Learning Materials',
                        'id': 'Materi Pembelajaran',
                      }),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      AppLocalizations.selectAndOrganizeMaterials.tr,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _navigateToGenerateRPP,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'refresh') {
                    _forceRefresh();
                  }
                },
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.more_vert, color: Colors.white, size: 20),
                ),
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                        SizedBox(width: AppSpacing.sm),
                        Text('Perbarui Data'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
        return Scaffold(
          backgroundColor: ColorUtils.slate50,
          body: Column(
            children: [
              // Header with gradient like presence_teacher
              _buildHeader(languageProvider),

              // Filter Section
              _buildFilterSection(languageProvider),

              // Search Bar
              Builder(builder: (context) {
                  final translatedFilterOptions = [
                    languageProvider.getTranslatedText({
                      'en': 'All',
                      'id': 'Semua',
                    }),
                    languageProvider.getTranslatedText({
                      'en': 'Today',
                      'id': 'Hari Ini',
                    }),
                    languageProvider.getTranslatedText({
                      'en': 'This Week',
                      'id': 'Minggu Ini',
                    }),
                  ];

                  return Container(
                    key: _searchKey,
                    child: EnhancedSearchBar(
                      controller: _searchController,
                      hintText: languageProvider.getTranslatedText({
                        'en': 'Search materials...',
                        'id': 'Cari materi...',
                      }),
                      onChanged: (value) {
                        setState(() {});
                      },
                      filterOptions: translatedFilterOptions,
                      selectedFilter:
                          translatedFilterOptions[_selectedFilter == 'All'
                              ? 0
                              : _selectedFilter == 'Today'
                              ? 1
                              : 2],
                      onFilterChanged: (filter) {
                        final index = translatedFilterOptions.indexOf(filter);
                        setState(() {
                          _selectedFilter = index == 0
                              ? 'All'
                              : index == 1
                              ? 'Today'
                              : 'This Week';
                        });
                      },
                      showFilter: true,
                    ),
                  );
                }),

              // Search Results Info
              if (_searchController.text.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '${_getFilteredChapterMaterials().length} ${languageProvider.getTranslatedText({'en': 'materials found', 'id': 'materi ditemukan'})}',
                        style: TextStyle(
                          color: ColorUtils.slate500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: AppSpacing.sm),

              // Content Section
              Expanded(
                child: _isLoading
                    ? SkeletonListLoading(
                        padding: EdgeInsets.only(top: 8, bottom: 80),
                        showActions: false,
                      )
                    : _selectedSubject == null
                    ? _buildEmptyState(
                        languageProvider.getTranslatedText({
                          'en': 'Select subject to view materials',
                          'id': 'Pilih mata pelajaran untuk melihat materi',
                        }),
                        languageProvider,
                      )
                    : _isLoadingBab
                    ? SkeletonListLoading(
                        padding: EdgeInsets.only(top: 8, bottom: 80),
                        showActions: false,
                      )
                    : _chapterMaterialList.isEmpty
                    ? _buildEmptyState(
                        languageProvider.getTranslatedText({
                          'en': 'No materials available for this subject',
                          'id': 'Tidak ada materi untuk mata pelajaran ini',
                        }),
                        languageProvider,
                      )
                    : _getFilteredChapterMaterials().isEmpty
                    ? EmptyState(
                        title: languageProvider.getTranslatedText({
                          'en': 'No Materials Found',
                          'id': 'Materi Tidak Ditemukan',
                        }),
                        subtitle: languageProvider.getTranslatedText({
                          'en':
                              'No search results found for "${_searchController.text}"',
                          'id':
                              'Tidak ditemukan hasil pencarian untuk "${_searchController.text}"',
                        }),
                        icon: Icons.search,
                      )
                    : _buildMaterialList(),
              ),
            ],
          ),
        );
  }

  Widget _buildFilterSection(LanguageProvider languageProvider) {
    final totalChecked = _getCheckedCount();
    final primaryColor = _getPrimaryColor();

    return Container(
      key: _filterKey,
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: ColorUtils.slate200, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Info Filter Aktif
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.filter_alt_rounded,
                    size: 16,
                    color: primaryColor,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _subjectList.isEmpty
                        ? languageProvider.getTranslatedText({
                            'en': 'No subjects available',
                            'id': 'Tidak ada mata pelajaran',
                          })
                        : '${_chapterMaterialList.length} ${languageProvider.getTranslatedText({'en': 'materials', 'id': 'bab materi'})} • ${_getSelectedSubjectName()}',
                    style: TextStyle(fontSize: 12, color: ColorUtils.slate700),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$totalChecked ${languageProvider.getTranslatedText({'en': 'checked', 'id': 'dicentang'})}',
                    style: TextStyle(
                      fontSize: 11,
                      color: primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md),

          // Generate Activity button if any items are checked
          if (totalChecked > 0 && _getCheckedNotGeneratedCount() > 0) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToGenerateRPP,
                icon: Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  'Generate Kegiatan Kelas (${_getCheckedNotGeneratedCount()})',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.success600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            SizedBox(height: AppSpacing.md),
          ],

          // Dropdown Kelas
          _buildClassDropdown(languageProvider),
          SizedBox(height: AppSpacing.md),

          // Dropdown Mata Pelajaran
          _buildMataPelajaranDropdown(languageProvider),
        ],
      ),
    );
  }

  Widget _buildClassDropdown(LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate600,
          ),
        ),
        SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedClassId,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: ColorUtils.slate500),
              items: _classList.map((c) {
                return DropdownMenuItem<String>(
                  value: c['id'],
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.class_rounded,
                          size: 16,
                          color: ColorUtils.slate500,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            c['name'] ?? c['nama'] ?? 'Unknown',
                            style: TextStyle(
                              color: ColorUtils.slate800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedClassId = newValue;
                    final selectedClass = _classList.firstWhere(
                      (c) => c['id'] == newValue,
                    );
                    _selectedClassName =
                        selectedClass['name'] ?? selectedClass['nama'];
                    _chapterMaterialList = [];
                    _subChapterMaterialList = [];
                    _subjectList = [];
                    _selectedSubject = null;
                    _isLoadingBab = false;
                    _isLoading = true;
                    _searchController.clear();
                  });
                  // Reload subjects filtered by the new class
                  _loadSubjectsForClass(newValue);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMataPelajaranDropdown(LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({
            'en': 'Subject',
            'id': 'Mata Pelajaran',
          }),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate600,
          ),
        ),
        SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSubject,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: ColorUtils.slate500),
              items: _subjectList.map((mp) {
                return DropdownMenuItem<String>(
                  value: mp['id'],
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 16,
                          color: ColorUtils.slate500,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            mp['name'] ?? mp['nama'] ?? 'Unknown',
                            style: TextStyle(
                              color: ColorUtils.slate800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedSubject = newValue;
                    _chapterMaterialList = [];
                    _subChapterMaterialList = [];
                    _isLoadingBab = true;
                    _searchController.clear();
                  });
                  _loadChapterMaterials(newValue);
                }
              },
            ),
          ),
        ),
      ],
    );
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

  Widget _buildMaterialList() {
    final filteredChapterMaterials = _getFilteredChapterMaterials();

    return ListView.builder(
      padding: EdgeInsets.all(AppSpacing.lg),
      itemCount: filteredChapterMaterials.length,
      itemBuilder: (context, index) {
        final chapter = filteredChapterMaterials[index];
        final cardColor = ColorUtils.getColorForIndex(index);
        final chapterIdStr = chapter['id'].toString();
        final isExpanded = _expandedChapter[chapterIdStr] ?? false;

        return Container(
          margin: EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() {
                  _expandedChapter[chapterIdStr] = !isExpanded;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ColorUtils.slate200),
                  boxShadow: ColorUtils.corporateShadow(elevation: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cardColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: cardColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${chapter['urutan']}',
                                style: TextStyle(
                                  color: cardColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  chapter['judul_bab'] ?? 'Judul Bab',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: ColorUtils.slate900,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Bab ${chapter['urutan']}',
                                  style: TextStyle(
                                    color: ColorUtils.slate500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Checkbox(
                            value: _checkedChapter[chapterIdStr] ?? false,
                            onChanged: (value) {
                              _handleChapterCheck(chapterIdStr, value);
                            },
                            activeColor: _getCheckboxColor(chapterIdStr),
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: ColorUtils.slate100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isExpanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: ColorUtils.slate500,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Sub Bab List (Expandable)
                    if (isExpanded) ...[
                      Divider(height: 1, color: ColorUtils.slate200),
                      _buildSubChapterList(chapter),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubChapterList(Map<String, dynamic> bab) {
    final subChaptersForChapter = _subChapterMaterialList
        .where((sc) => sc['bab_id'].toString() == bab['id'].toString())
        .toList();

    if (subChaptersForChapter.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Tidak ada sub-bab',
          style: TextStyle(color: ColorUtils.slate400),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: subChaptersForChapter.map((subChapter) {
        final subChapterIdStr = subChapter['id'].toString();
        final subChapterColor = ColorUtils.getColorForIndex(
          int.parse(subChapter['urutan']?.toString() ?? '0'),
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToSubChapterDetail(subChapter, bab),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: subChapterColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: subChapterColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${subChapter['urutan']}',
                        style: TextStyle(
                          color: subChapterColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      subChapter['judul_sub_bab'] ?? 'Judul Sub Bab',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: ColorUtils.slate800,
                      ),
                    ),
                  ),
                  Checkbox(
                    value: _checkedSubChapter[subChapterIdStr] ?? false,
                    onChanged: (value) {
                      _handleSubChapterCheck(
                        subChapterIdStr,
                        bab['id'].toString(),
                        value,
                      );
                    },
                    activeColor: _getCheckboxColor(subChapterIdStr, isSubChapter: true),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: ColorUtils.slate400,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getSelectedSubjectName() {
    if (_selectedSubject == null) return '-';
    final mp = _subjectList.firstWhere(
      (mp) => mp['id'] == _selectedSubject,
      orElse: () => {'nama': '-'},
    );
    return mp['nama'] ?? '-';
  }

  int _getCheckedCount() {
    final chapterChecked = _checkedChapter.values.where((checked) => checked).length;
    final subChapterChecked = _checkedSubChapter.values
        .where((checked) => checked)
        .length;
    return chapterChecked + subChapterChecked;
  }

  int _getCheckedNotGeneratedCount() {
    return _getCheckedNotGeneratedChapters().length +
        _getCheckedNotGeneratedSubChapters().length;
  }

  Future<void> _checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus('materi_screen', 'guru');
      final cached = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('material', 'Error checking tour status: $e');
    }
  }

  void _showTour() {
    final List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "LEWATI",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        getIt<ApiTourService>().completeTour(name: 'materi_screen_tour', role: 'guru', platform: 'mobile');
        LocalCacheService.save(CacheKeyBuilder.tourStatus('materi_screen', 'guru'), {'should_show': false});
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(name: 'materi_screen_tour', role: 'guru', platform: 'mobile');
        LocalCacheService.save(CacheKeyBuilder.tourStatus('materi_screen', 'guru'), {'should_show': false});
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    final List<TargetFocus> targets = [];

    targets.add(
      TargetFocus(
        identify: "FilterSection",
        keyTarget: _filterKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Pilih Kelas & Mata Pelajaran",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Pilih kelas dan mata pelajaran yang Anda ampu di sini untuk melihat daftar Bab dan Sub-bab materi yang telah ditentukan oleh kurikulum.",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "SearchBar",
        keyTarget: _searchKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Pencarian Materi",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Gunakan kolom ini untuk mencari nama bab atau sub-bab dengan cepat.",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    return targets;
  }
}


