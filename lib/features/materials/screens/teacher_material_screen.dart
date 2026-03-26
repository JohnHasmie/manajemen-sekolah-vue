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
  List<dynamic> _babMateriList = [];
  List<dynamic> _subBabMateriList = [];

  // Search dan Filter
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  // State untuk expanded/collapsed
  final Map<String, bool> _expandedBab = {};

  // State untuk ceklis
  final Map<String, bool> _checkedBab = {};
  final Map<String, bool> _checkedSubBab = {};

  // State untuk generated (sudah pernah di-generate)
  final Map<String, bool> _generatedBab = {};
  final Map<String, bool> _generatedSubBab = {};

  // State untuk used (sudah digunakan di class activity) - Blue Check
  final Map<String, bool> _usedBab = {};
  final Map<String, bool> _usedSubBab = {};

  // Teacher profile ID (dari tabel teachers, bukan user ID)
  String? _teacherProfileId;

  // Fungsi untuk mendapatkan bab yang dicentang tapi belum di-generate
  List<Map<String, dynamic>> _getCheckedNotGeneratedBab() {
    return _babMateriList
        .where((bab) {
          final hasSubChapters = _subBabMateriList.any(
            (sb) => sb['bab_id'].toString() == bab['id'].toString(),
          );

          return _checkedBab[bab['id']] == true &&
              _generatedBab[bab['id']] != true &&
              _usedBab[bab['id']] != true && // Exclude used
              !hasSubChapters; // Only include if it has NO sub-chapters
        })
        .toList()
        .cast<Map<String, dynamic>>();
  }

  // Fungsi untuk mendapatkan sub bab yang dicentang tapi belum di-generate
  List<Map<String, dynamic>> _getCheckedNotGeneratedSubBab() {
    return _subBabMateriList
        .where(
          (subBab) =>
              _checkedSubBab[subBab['id']] == true &&
              _generatedSubBab[subBab['id']] != true &&
              _usedSubBab[subBab['id']] != true, // Exclude used
        )
        .toList()
        .cast<Map<String, dynamic>>();
  }

  // Fungsi untuk navigate ke halaman class activity dengan bab yang dipilih
  /// Navigates to ClassActivity screen with checked chapters for RPP generation.
  /// Like a Vue `methods.navigateToGenerate()` that uses `this.$router.push()`.
  void _navigateToGenerateRPP() async {
    // Gunakan yang belum di-generate
    final checkedBab = _getCheckedNotGeneratedBab();
    final checkedSubBab = _getCheckedNotGeneratedSubBab();

    if (checkedBab.isEmpty && checkedSubBab.isEmpty) {
            SnackBarUtils.showInfo(context, 'Pilih minimal 1 bab atau sub bab untuk di-generate');
      return;
    }

    String? selectedBabId;
    String? selectedSubBabId;

    // If sub bab is selected, get its parent bab and the sub bab itself
    if (checkedSubBab.isNotEmpty) {
      final firstSubBab = checkedSubBab.first;
      selectedSubBabId = firstSubBab['id']?.toString();
      selectedBabId = firstSubBab['bab_id']?.toString();

      AppLogger.debug('material', 'Selected sub bab: $selectedSubBabId, parent bab: $selectedBabId',);
    }
    // If only bab is selected (no sub bab)
    else if (checkedBab.isNotEmpty) {
      selectedBabId = checkedBab.first['id']?.toString();

      AppLogger.debug('material', 'Selected bab only: $selectedBabId');
    }

    // Prepare additional materials (all checked sub-chapters)
    // We pass ALL checked sub-chapters as "additional" materials.
    // The activity form logic will filter out the primary one if needed.
    List<Map<String, dynamic>> additionalMaterials = [];
    if (checkedSubBab.isNotEmpty) {
      for (var sub in checkedSubBab) {
        additionalMaterials.add({
          'chapter_id': sub['bab_id'],
          'sub_chapter_id': sub['id'],
        });
      }
    }

    // Prepare list to mark as generated upon success
    final List<Map<String, dynamic>> materialsToMarkAsGenerated = [];
    for (var bab in checkedBab) {
      materialsToMarkAsGenerated.add({'bab_id': bab['id'], 'sub_bab_id': null});
    }
    for (var subBab in checkedSubBab) {
      materialsToMarkAsGenerated.add({
        'bab_id': subBab['bab_id'],
        'sub_bab_id': subBab['id'],
      });
    }

    if (!mounted) return;

    await AppNavigator.push(context, ClassActifityScreen(
          initialSubjectId: _selectedSubject,
          initialSubjectName: _getSelectedSubjectName(),
          initialClassId: _selectedClassId ?? widget.initialClassId,
          initialClassName: _selectedClassName ?? widget.initialClassName,
          initialBabId: selectedBabId,
          initialSubBabId: selectedSubBabId,
          initialAdditionalMaterials: additionalMaterials,
          materialsToMarkAsGenerated: materialsToMarkAsGenerated,
          autoShowActivityDialog: true,
        ));

    // Refresh data after returning
    if (mounted && _selectedSubject != null) {
      _loadBabMateri(_selectedSubject!);
    }
  }

  bool _isLoading = false;
  bool _isLoadingBab = false;

  // Tour properties
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  String? _tourId;

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

  String? _buildMateriCacheKey() {
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

    final cacheKey = 'materi_subjects_${teacherId}_$classId';

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
      _babMateriList = [];
      _subBabMateriList = [];
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
      _loadBabMateri(_selectedSubject!);
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

      final cacheKey = _buildMateriCacheKey();

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
        final subjectCacheKey = 'materi_subjects_${teacherId}_$effectiveClassKey';
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
        final classesCacheKey = 'teacher_classes_$teacherId';
        final profileCacheKey = 'teacher_profile_$teacherId';

        if (needClasses && useCache) {
          try {
            final cachedClasses = await LocalCacheService.load(classesCacheKey, ttl: const Duration(hours: 3));
            if (cachedClasses != null && cachedClasses is List) {
              classes = List<dynamic>.from(cachedClasses);
              classes.sort((a, b) {
                String nameA = (a['name'] ?? a['nama'] ?? '').toString();
                String nameB = (b['name'] ?? b['nama'] ?? '').toString();
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
              String nameA = (a['name'] ?? a['nama'] ?? '').toString();
              String nameB = (b['name'] ?? b['nama'] ?? '').toString();
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
        LocalCacheService.save('materi_subjects_${teacherId}_$effectiveClassKey', subject);
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
  Future<void> _loadBabMateri(String subjectId, {bool useCache = true}) async {
    final babCacheKey = 'materi_bab_${widget.teacher['id']}_$subjectId';

    // Show skeleton if list is empty
    if (_babMateriList.isEmpty && mounted) {
      setState(() => _isLoadingBab = true);
    }

    // Step 1: Try cache → return early if hit
    if (useCache && _babMateriList.isEmpty) {
      try {
        final cached = await LocalCacheService.load(babCacheKey, ttl: const Duration(hours: 3));
        if (cached != null && mounted) {
          final cachedData = Map<String, dynamic>.from(cached);
          final cachedBab = List<dynamic>.from(cachedData['babMateri'] ?? []);
          final cachedSubBab = List<dynamic>.from(cachedData['subBabMateri'] ?? []);

          if (cachedBab.isNotEmpty) {
            setState(() {
              _babMateriList = cachedBab;
              _subBabMateriList = cachedSubBab;
              _isLoadingBab = false;
              _expandedBab.clear();
              _checkedBab.clear();
              _checkedSubBab.clear();
              _generatedBab.clear();
              _generatedSubBab.clear();
              _usedBab.clear();
              _usedSubBab.clear();
              for (var bab in cachedBab) {
                _expandedBab[bab['id'].toString()] = false;
                _checkedBab[bab['id'].toString()] = false;
                _generatedBab[bab['id'].toString()] = false;
                _usedBab[bab['id'].toString()] = false;
              }
              for (var subBab in cachedSubBab) {
                _checkedSubBab[subBab['id'].toString()] = false;
              }
            });
            // Load progress from DB non-blocking (always fresh — this is user-specific state)
            _loadMateriProgress(subjectId);
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

      final babMateri = await getIt<ApiSubjectService>().getBabMateri(
        subjectId: masterSubjectId,
      );
      if (!mounted) return;

      // Extract sub-chapters directly from getBabMateri response
      // (backend already includes sub_chapters nested in each chapter)
      final allSubBabs = <dynamic>[];
      for (var bab in babMateri) {
        final subChapters = bab['sub_chapters'];
        if (subChapters is List) {
          allSubBabs.addAll(subChapters);
        }
      }

      setState(() {
        _babMateriList = babMateri;
        _subBabMateriList = List.from(allSubBabs);
        _isLoadingBab = false;

        _expandedBab.clear();
        _checkedBab.clear();
        _checkedSubBab.clear();
        _generatedBab.clear();
        _generatedSubBab.clear();
        _usedBab.clear();
        _usedSubBab.clear();

        for (var bab in babMateri) {
          _expandedBab[bab['id'].toString()] = false;
          _checkedBab[bab['id'].toString()] = false;
          _generatedBab[bab['id'].toString()] = false;
          _usedBab[bab['id'].toString()] = false;
        }

        for (var subBab in _subBabMateriList) {
          _checkedSubBab[subBab['id'].toString()] = false;
        }

      });

      // Save to cache (non-blocking)
      LocalCacheService.save(babCacheKey, {
        'babMateri': babMateri,
        'subBabMateri': allSubBabs,
      });

      // Load progress dari database (non-blocking — UI already shows bab structure)
      _loadMateriProgress(subjectId);

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
      if (_babMateriList.isEmpty) {
                SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  // Fungsi untuk menangani perubahan ceklis pada sub bab
  void _handleSubBabCheck(String subBabId, String babId, bool? value) {
    // Prevent unchecking if already generated (Purple) or Used (Blue)
    if ((_generatedSubBab[subBabId] == true || _usedSubBab[subBabId] == true) &&
        value == false) {
      return;
    }

    setState(() {
      _checkedSubBab[subBabId] = value ?? false;

      // Cek apakah semua sub bab dalam bab ini sudah dicentang
      // Ambil daftar sub bab yang dimiliki oleh babId ini
      final subBabsForThisBab = _subBabMateriList.where((sb) {
        return sb['bab_id'].toString() == babId.toString();
      }).toList();

      if (subBabsForThisBab.isNotEmpty) {
        // Cek apakah setiap sub bab sudah dicentang
        final allChecked = subBabsForThisBab.every((sb) {
          final sbId = sb['id'].toString();
          return _checkedSubBab[sbId] == true;
        });

        // Update status ceklis bab
        _checkedBab[babId] = allChecked;

        AppLogger.debug('material', 'SubBab check changed: $subBabId -> $value');
        AppLogger.debug('material', 'Bab $babId auto-check status: $allChecked');
      }
    });

    // Save to database
    _saveProgress(babId, subBabId, value ?? false);
  }

  // Fungsi untuk menangani perubahan ceklis pada bab
  void _handleBabCheck(String babId, bool? value) {
    // Prevent unchecking if already generated (Purple) or Used (Blue)
    if ((_generatedBab[babId] == true || _usedBab[babId] == true) &&
        value == false) {
      return;
    }

    setState(() {
      _checkedBab[babId] = value ?? false;

      // Update sub-babs logic:
      // If checking Bab (True): Check all sub-babs.
      // If unchecking Bab (False): Uncheck all sub-babs EXCEPT those that are Generated (Purple).
      for (var subBab in _subBabMateriList.where(
        (subBab) => subBab['bab_id'] == babId,
      )) {
        if (value == true) {
          _checkedSubBab[subBab['id']] = true;
        } else {
          // If unchecking, only uncheck if NOT generated and NOT used
          if (_generatedSubBab[subBab['id']] != true &&
              _usedSubBab[subBab['id']] != true) {
            _checkedSubBab[subBab['id']] = false;
          }
        }
      }
    });

    // Save to database (bab and all its sub-babs)
    _saveBabAndSubBabsProgress(babId, value ?? false);
  }

  // Load materi progress from database
  Future<void> _loadMateriProgress(String subjectId) async {
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
          final babId = item['bab_id'];
          final subBabId = item['sub_bab_id'];
          final isChecked =
              item['is_checked'] == 1 || item['is_checked'] == true;
          final isGenerated =
              item['is_generated'] == 1 || item['is_generated'] == true;
          final isUsed = item['is_used'] == 1 || item['is_used'] == true;

          if (subBabId != null) {
            // Sub bab checked and generated status
            _checkedSubBab[subBabId.toString()] = isChecked;
            _generatedSubBab[subBabId.toString()] = isGenerated;
            _usedSubBab[subBabId.toString()] = isUsed;
          } else if (babId != null) {
            // Bab checked and generated status (no specific sub bab)
            _checkedBab[babId.toString()] = isChecked;
            _generatedBab[babId.toString()] = isGenerated;
            _usedBab[babId.toString()] = isUsed;
          }
        }

        // Final pass: Recalculate Bab status based on Sub-Babs
        // This ensures visual correctness even if Bab record is absent in DB
        for (var bab in _babMateriList) {
          final babId = bab['id'].toString();
          final subBabsForThisBab = _subBabMateriList
              .where((sb) => sb['bab_id'].toString() == babId)
              .toList();

          if (subBabsForThisBab.isNotEmpty) {
            final allSubBabsChecked =
                subBabsForThisBab.isNotEmpty &&
                subBabsForThisBab.every(
                  (sb) => _checkedSubBab[sb['id'].toString()] == true,
                );
            _checkedBab[babId] = allSubBabsChecked;
          }
        }
      });
    } catch (e) {
      AppLogger.error('material', 'Error loading progress: $e');
    }
  }

  // Save single progress to database
  Future<void> _saveProgress(
    String babId,
    String? subBabId,
    bool isChecked,
  ) async {
    try {
      final String? teacherId = widget.teacher['id'];
      if (teacherId == null || _selectedSubject == null) return;

      await getIt<ApiSubjectService>().saveMateriProgress({
        'teacher_id': teacherId,
        'subject_id': _selectedSubject,
        'class_id': _selectedClassId,
        'chapter_id': babId,
        'sub_chapter_id': subBabId,
        'is_checked': isChecked ? 1 : 0,
      });

      AppLogger.info('material', 'Progress saved: bab=$babId, sub_bab=$subBabId, checked=$isChecked',);
    } catch (e) {
      AppLogger.error('material', 'Error saving progress: $e');
    }
  }

  // Save bab and all its sub-babs progress to database
  Future<void> _saveBabAndSubBabsProgress(String babId, bool isChecked) async {
    try {
      final String? teacherId = widget.teacher['id'];
      if (teacherId == null || _selectedSubject == null) return;

      // Prepare batch items
      final List<Map<String, dynamic>> progressItems = [];

      // Debug sub-bab count
      final subBabsForThisBab = _subBabMateriList
          .where((sb) => sb['bab_id'].toString() == babId.toString())
          .toList();

      AppLogger.debug('material', 'Found ${subBabsForThisBab.length} sub-babs for bab $babId');

      // Add bab itself ONLY if it has NO sub-chapters
      // If it has sub-chapters, its status is derived and shouldn't be saved explicitly
      if (subBabsForThisBab.isEmpty) {
        progressItems.add({
          'bab_id': babId,
          'sub_bab_id': null,
          'is_checked': isChecked ? 1 : 0,
        });
      }

      // Add all sub-babs of this bab
      for (var subBab in subBabsForThisBab) {
        // Respect locks: If unchecking, don't include if Generated or Used
        if (isChecked == false) {
          final isGenerated = _generatedSubBab[subBab['id']] == true;
          final isUsed = _usedSubBab[subBab['id']] == true;
          if (isGenerated || isUsed) continue;
        }

        progressItems.add({
          'bab_id': babId,
          'sub_bab_id': subBab['id'],
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

  // Navigasi ke halaman detail sub bab
  void _navigateToSubBabDetail(
    Map<String, dynamic> subBab,
    Map<String, dynamic> bab,
  ) {
    AppNavigator.push(context, SubBabDetailPage(
          teacherId: _teacherProfileId ?? widget.teacher['id'],
          subjectId: _selectedSubject ?? '',
          subBab: subBab,
          bab: bab,
          checked: _checkedSubBab[subBab['id'].toString()] ?? false,
          onCheckChanged: (value) {
            _handleSubBabCheck(
              subBab['id'].toString(),
              bab['id'].toString(),
              value,
            );
          },
        ));
  }

  List<dynamic> _getFilteredBabMateri() {
    final searchTerm = _searchController.text.toLowerCase();

    if (searchTerm.isEmpty) {
      return _babMateriList;
    }

    return _babMateriList.where((bab) {
      final matchesBab =
          (bab['judul_bab']?.toString().toLowerCase().contains(searchTerm) ??
          false);

      // Cari juga di sub bab yang terkait
      final subBabMatches = _subBabMateriList
          .where((subBab) => subBab['bab_id'] == bab['id'])
          .any(
            (subBab) =>
                subBab['judul_sub_bab']?.toString().toLowerCase().contains(
                  searchTerm,
                ) ??
                false,
          );

      return matchesBab || subBabMatches;
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
              SizedBox(width: 12),
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
              SizedBox(width: 8),
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
                        SizedBox(width: 8),
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
              // Header dengan gradient seperti presence_teacher
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
                        '${_getFilteredBabMateri().length} ${languageProvider.getTranslatedText({'en': 'materials found', 'id': 'materi ditemukan'})}',
                        style: TextStyle(
                          color: ColorUtils.slate500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 8),

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
                    : _babMateriList.isEmpty
                    ? _buildEmptyState(
                        languageProvider.getTranslatedText({
                          'en': 'No materials available for this subject',
                          'id': 'Tidak ada materi untuk mata pelajaran ini',
                        }),
                        languageProvider,
                      )
                    : _getFilteredBabMateri().isEmpty
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
                    : _buildMateriList(),
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
      padding: EdgeInsets.all(16),
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
            padding: EdgeInsets.all(12),
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
                        : '${_babMateriList.length} ${languageProvider.getTranslatedText({'en': 'materials', 'id': 'bab materi'})} • ${_getSelectedSubjectName()}',
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
          SizedBox(height: 12),

          // Tombol Generate Kegiatan jika ada yang dicentang
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
            SizedBox(height: 12),
          ],

          // Dropdown Kelas
          _buildKelasDropdown(languageProvider),
          SizedBox(height: 12),

          // Dropdown Mata Pelajaran
          _buildMataPelajaranDropdown(languageProvider),
        ],
      ),
    );
  }

  Widget _buildKelasDropdown(LanguageProvider languageProvider) {
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
                        SizedBox(width: 8),
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
                    _babMateriList = [];
                    _subBabMateriList = [];
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
                        SizedBox(width: 8),
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
                    _babMateriList = [];
                    _subBabMateriList = [];
                    _isLoadingBab = true;
                    _searchController.clear();
                  });
                  _loadBabMateri(newValue);
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

  Color _getCheckboxColor(String id, {bool isSubBab = false}) {
    if (isSubBab) {
      if (_usedSubBab[id] == true) return ColorUtils.info600;
      if (_generatedSubBab[id] == true) return Color(0xFF8B5CF6);
      return ColorUtils.success600;
    } else {
      if (_usedBab[id] == true) return ColorUtils.info600;
      if (_generatedBab[id] == true) return Color(0xFF8B5CF6);
      return ColorUtils.success600;
    }
  }

  Widget _buildMateriList() {
    final filteredBabMateri = _getFilteredBabMateri();

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filteredBabMateri.length,
      itemBuilder: (context, index) {
        final bab = filteredBabMateri[index];
        final cardColor = ColorUtils.getColorForIndex(index);
        final babIdStr = bab['id'].toString();
        final isExpanded = _expandedBab[babIdStr] ?? false;

        return Container(
          margin: EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() {
                  _expandedBab[babIdStr] = !isExpanded;
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
                      padding: EdgeInsets.all(16),
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
                                '${bab['urutan']}',
                                style: TextStyle(
                                  color: cardColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bab['judul_bab'] ?? 'Judul Bab',
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
                                  'Bab ${bab['urutan']}',
                                  style: TextStyle(
                                    color: ColorUtils.slate500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Checkbox(
                            value: _checkedBab[babIdStr] ?? false,
                            onChanged: (value) {
                              _handleBabCheck(babIdStr, value);
                            },
                            activeColor: _getCheckboxColor(babIdStr),
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
                      _buildSubBabList(bab),
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

  Widget _buildSubBabList(Map<String, dynamic> bab) {
    final subBabsForBab = _subBabMateriList
        .where((subBab) => subBab['bab_id'].toString() == bab['id'].toString())
        .toList();

    if (subBabsForBab.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Tidak ada sub-bab',
          style: TextStyle(color: ColorUtils.slate400),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: subBabsForBab.map((subBab) {
        final subBabIdStr = subBab['id'].toString();
        final subBabColor = ColorUtils.getColorForIndex(
          int.parse(subBab['urutan']?.toString() ?? '0'),
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToSubBabDetail(subBab, bab),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: subBabColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: subBabColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${subBab['urutan']}',
                        style: TextStyle(
                          color: subBabColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      subBab['judul_sub_bab'] ?? 'Judul Sub Bab',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: ColorUtils.slate800,
                      ),
                    ),
                  ),
                  Checkbox(
                    value: _checkedSubBab[subBabIdStr] ?? false,
                    onChanged: (value) {
                      _handleSubBabCheck(
                        subBabIdStr,
                        bab['id'].toString(),
                        value,
                      );
                    },
                    activeColor: _getCheckboxColor(subBabIdStr, isSubBab: true),
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
    final babChecked = _checkedBab.values.where((checked) => checked).length;
    final subBabChecked = _checkedSubBab.values
        .where((checked) => checked)
        .length;
    return babChecked + subBabChecked;
  }

  int _getCheckedNotGeneratedCount() {
    return _getCheckedNotGeneratedBab().length +
        _getCheckedNotGeneratedSubBab().length;
  }

  Future<void> _checkAndShowTour() async {
    try {
      const tourCacheKey = 'tour_materi_screen_guru';
      final cached = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true && cached['tour'] != null) {
          _tourId = cached['tour']['id']?.toString();
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
    List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "LEWATI",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        if (_tourId != null) {
          getIt<ApiTourService>().completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_materi_screen_guru', {'should_show': false});
        }
      },
      onSkip: () {
        if (_tourId != null) {
          getIt<ApiTourService>().completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_materi_screen_guru', {'should_show': false});
        }
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];

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


