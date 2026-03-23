// Teaching material (materi) management screen for teachers.
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
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/enhanced_search_bar.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/class_activity/screens/teacher_class_activity_screen.dart';
import 'package:manajemensekolah/core/providers/teacher_provider.dart';
import 'package:manajemensekolah/features/materials/screens/material_ai_result_screen.dart';
import 'package:manajemensekolah/features/subjects/services/subject_service.dart';
import 'package:manajemensekolah/features/teachers/services/teacher_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Teaching material browser with subject, chapter, and sub-chapter navigation.
///
/// This is a StatefulWidget with complex local state for managing the chapter
/// tree, checkboxes, progress tracking, and AI generation flow. In Vue terms,
/// it is like a page component with deeply nested reactive data.
///
/// Props (like Vue props): [teacher], optional initial* for deep linking.
class MateriPage extends StatefulWidget {
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
class MateriPageState extends State<MateriPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedSubject;
  String? _selectedClassId;
  String? _selectedClassName;
  List<dynamic> _subjectList = [];
  List<dynamic> _classList = [];
  List<dynamic> _materiList = [];
  List<dynamic> _babMateriList = [];
  List<dynamic> _subBabMateriList = [];
  List<dynamic> _contentMateriList = [];

  // Search dan Filter
  final TextEditingController _searchController = TextEditingController();
  final List<String> _filterOptions = ['All', 'Today', 'This Week'];
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pilih minimal 1 bab atau sub bab untuk di-generate'),
        ),
      );
      return;
    }

    String? selectedBabId;
    String? selectedSubBabId;

    // If sub bab is selected, get its parent bab and the sub bab itself
    if (checkedSubBab.isNotEmpty) {
      final firstSubBab = checkedSubBab.first;
      selectedSubBabId = firstSubBab['id']?.toString();
      selectedBabId = firstSubBab['bab_id']?.toString();

      if (kDebugMode) {
        print(
          'Selected sub bab: $selectedSubBabId, parent bab: $selectedBabId',
        );
      }
    }
    // If only bab is selected (no sub bab)
    else if (checkedBab.isNotEmpty) {
      selectedBabId = checkedBab.first['id']?.toString();

      if (kDebugMode) {
        print('Selected bab only: $selectedBabId');
      }
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

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClassActifityScreen(
          initialSubjectId: _selectedSubject,
          initialSubjectName: _getSelectedSubjectName(),
          initialClassId: _selectedClassId ?? widget.initialClassId,
          initialClassName: _selectedClassName ?? widget.initialClassName,
          initialBabId: selectedBabId,
          initialSubBabId: selectedSubBabId,
          initialAdditionalMaterials: additionalMaterials,
          materialsToMarkAsGenerated: materialsToMarkAsGenerated,
          autoShowActivityDialog: true,
        ),
      ),
    );

    // Refresh data after returning
    if (mounted && _selectedSubject != null) {
      _loadBabMateri(_selectedSubject!);
    }
  }

  // Mark selected materials as generated
  Future<void> _markSelectedAsGenerated(
    List<Map<String, dynamic>> babs,
    List<Map<String, dynamic>> subBabs,
  ) async {
    try {
      final String? teacherId = widget.teacher['id'];
      if (teacherId == null || _selectedSubject == null) return;

      final List<Map<String, dynamic>> items = [];

      // Add babs
      for (var bab in babs) {
        items.add({'bab_id': bab['id'], 'sub_bab_id': null});
      }

      // Add sub-babs
      for (var subBab in subBabs) {
        items.add({'bab_id': subBab['bab_id'], 'sub_bab_id': subBab['id']});
      }

      if (items.isEmpty) return;

      await ApiSubjectService.markMateriGenerated({
        'teacher_id': teacherId,
        'subject_id': _selectedSubject,
        'items': items,
      });
      if (!mounted) return;

      // Update local state
      setState(() {
        for (var bab in babs) {
          _generatedBab[bab['id']] = true;
        }
        for (var subBab in subBabs) {
          _generatedSubBab[subBab['id']] = true;
        }
      });

      if (kDebugMode) {
        print('Marked ${items.length} items as generated');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error marking as generated: $e');
      }
    }
  }

  bool _isLoading = false;
  bool _isLoadingBab = false;
  String _debugInfo = '';

  // Color scheme matching teaching schedule
  final Map<String, Color> _dayColorMap = {
    'Senin': Color(0xFF6366F1),
    'Selasa': Color(0xFF10B981),
    'Rabu': Color(0xFFF59E0B),
    'Kamis': Color(0xFFEF4444),
    'Jumat': Color(0xFF8B5CF6),
    'Sabtu': Color(0xFF06B6D4),
  };

  // Tour properties
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  String? _tourId;

  /// Like Vue's `mounted()` -- resolves teacher profile, loads subjects and
  /// chapters, applies initial selections if deep-linked, and shows tour.
  @override
  void initState() {
    super.initState();

    if (kDebugMode) {
      print('Teacher data received: ${widget.teacher}');
    }
    if (kDebugMode) {
      print('Teacher ID: ${widget.teacher['id']}');
    }

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
            if (kDebugMode) print('⚡ Loaded subjects for class $classId from cache');
            return;
          }
        }
      } catch (e) {
        if (kDebugMode) print('Subject cache error: $e');
      }
    }

    // Fetch from API with classId filter
    try {
      final apiTeacherService = ApiTeacherService();
      final subjects = await apiTeacherService.getSubjectByTeacher(teacherId, classId: classId);
      if (!mounted) return;

      _applySubjectList(subjects);

      // Save to cache
      if (subjects.isNotEmpty) {
        await LocalCacheService.save(cacheKey, subjects);
      }
    } catch (e) {
      if (kDebugMode) print('Error loading subjects for class: $e');
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

      if (subjects.isEmpty) {
        _debugInfo = 'Tidak ada mata pelajaran untuk kelas ini';
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
      if (kDebugMode) {
        print('Loading data for teacher ID: $teacherId');
      }

      if (teacherId == null || teacherId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: ID guru tidak valid')),
        );
        return;
      }

      final cacheKey = _buildMateriCacheKey();

      // ─── Step 1: Try TeacherProvider (populated by Dashboard) ───
      final teacherProvider = Provider.of<TeacherProvider>(
        context,
        listen: false,
      );

      // Resolve teacher profile ID from provider (skip /api/teacher/{id})
      if (teacherProvider.isLoaded && teacherProvider.teacherId != null) {
        _teacherProfileId = teacherProvider.teacherId;
        if (kDebugMode) print('⚡ TeacherProvider: profileId=$_teacherProfileId');
      }

      List<dynamic>? providerClassList;
      if (teacherProvider.isLoaded && teacherProvider.allClasses.isNotEmpty) {
        providerClassList = teacherProvider.allClasses;
        if (kDebugMode) print('⚡ Using TeacherProvider classList (${providerClassList.length} classes)');
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

              if (kDebugMode) print('⚡ Loaded from cache (classes + subjects for $selectedClassId) — skipping API');
              return; // ✅ Cache hit — no API calls needed
            }
          }
        } catch (e) {
          if (kDebugMode) print('Subject cache load error: $e');
        }
      }

      // ─── Step 3: No cache — show skeleton and fetch from API ───
      if (_subjectList.isEmpty && mounted) {
        setState(() => _isLoading = true);
      }

      final ApiTeacherService apiTeacherService = ApiTeacherService();

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
              if (kDebugMode) print('📦 TeacherClasses: from cache (${classes.length})');
            }
          } catch (_) {}
        }

        if (needProfile && useCache) {
          try {
            final cachedProfile = await LocalCacheService.load(profileCacheKey, ttl: const Duration(hours: 6));
            if (cachedProfile != null && cachedProfile is Map) {
              _teacherProfileId = cachedProfile['id']?.toString();
              if (kDebugMode) print('📦 TeacherProfile: from cache (id=$_teacherProfileId)');
            }
          } catch (_) {}
        }

        // Only fetch from API what's still missing
        final bool stillNeedClasses = classes.isEmpty;
        final bool stillNeedProfile = _teacherProfileId == null;

        if (stillNeedClasses || stillNeedProfile) {
          final List<Future> teacherFutures = [];
          if (stillNeedClasses) teacherFutures.add(ApiTeacherService.getTeacherClasses(teacherId));
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
              if (kDebugMode) print('Could not resolve teacher profile ID: $e');
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
        ApiSubjectService.getMateri(teacherId: teacherId),
      ];

      final results = await Future.wait(futures);
      if (!mounted) return;

      final subject = results[0] as List<dynamic>;
      final materi = results[1] as List<dynamic>;

      if (kDebugMode) {
        print('Mata pelajaran found: ${subject.length} (class: $selectedClassId)');
        print('Classes found: ${classes.length}');
      }

      if (subject.isEmpty) {
        setState(() {
          _isLoading = false;
          _subjectList = [];
          _debugInfo = 'Guru ini belum memiliki mata pelajaran untuk kelas ini';
        });
        return;
      }

      setState(() {
        _materiList = materi;
        _isLoading = false;
      });

      _applySubjectList(subject);

      // Save subjects cache in background
      if (subject.isNotEmpty) {
        LocalCacheService.save('materi_subjects_${teacherId}_$effectiveClassKey', subject);
      }
      if (kDebugMode) print('Saved materi data to cache');
    } catch (e) {
      if (kDebugMode) {
        print('Error loading MateriPage data: $e');
      }
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isLoadingBab = false;
        if (_subjectList.isEmpty) {
          _debugInfo = 'Error: ${e.toString()}';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
      );
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
              _debugInfo = '${cachedBab.length} bab materi, ${cachedSubBab.length} sub-bab ditemukan';
            });
            // Load progress from DB non-blocking (always fresh — this is user-specific state)
            _loadMateriProgress(subjectId);
            // Trigger tour check
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) _checkAndShowTour();
            });
            if (kDebugMode) print('⚡ Loaded bab materi from cache — skipping API');
            return; // ✅ Cache hit — no API calls for bab-material
          }
        }
      } catch (e) {
        if (kDebugMode) print('Bab cache load error: $e');
      }
    }

    // Step 2: No cache — fetch fresh from API
    try {
      final subject = _subjectList.firstWhere(
        (s) => s['id'] == subjectId,
        orElse: () => null,
      );
      final masterSubjectId = subject?['subject_id']?.toString();

      if (masterSubjectId == null) {
        if (kDebugMode) {
          print('Error: Master Subject ID not found for subject $subjectId');
        }
        if (mounted) setState(() => _isLoadingBab = false);
        return;
      }

      final babMateri = await ApiSubjectService.getBabMateri(
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

        _debugInfo =
            '${babMateri.length} bab materi, ${_subBabMateriList.length} sub-bab ditemukan';
      });

      // Save to cache (non-blocking)
      LocalCacheService.save(babCacheKey, {
        'babMateri': babMateri,
        'subBabMateri': allSubBabs,
      });

      // Load progress dari database (non-blocking — UI already shows bab structure)
      _loadMateriProgress(subjectId);

      // Trigger tour
      Future.delayed(Duration(milliseconds: 1000), () {
        if (mounted) {
          _checkAndShowTour();
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading bab and sub-bab: $e');
      }
      if (!mounted) return;
      setState(() => _isLoadingBab = false);
      if (_babMateriList.isEmpty) {
        setState(() {
          _debugInfo = 'Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
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

        if (kDebugMode) {
          print('SubBab check changed: $subBabId -> $value');
          print('Bab $babId auto-check status: $allChecked');
        }
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
  Future<void> _loadMateriProgress(String mataPelajaranId) async {
    try {
      final String? teacherId = widget.teacher['id'];
      if (teacherId == null) return;

      final progress = await ApiSubjectService.getMateriProgress(
        guruId: teacherId,
        mataPelajaranId: mataPelajaranId,
        classId: _selectedClassId,
      );
      if (!mounted) return;

      if (kDebugMode) {
        print('=== LOADING MATERI PROGRESS ===');
        print('Teacher ID: $teacherId');
        print('Subject ID: $mataPelajaranId');
        print('API Response Items: ${progress.length}');
        if (progress.isNotEmpty) {
          print('First item sample: ${progress.first}');
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
      if (kDebugMode) {
        print('Error loading progress: $e');
      }
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

      await ApiSubjectService.saveMateriProgress({
        'teacher_id': teacherId,
        'subject_id': _selectedSubject,
        'class_id': _selectedClassId,
        'chapter_id': babId,
        'sub_chapter_id': subBabId,
        'is_checked': isChecked ? 1 : 0,
      });

      if (kDebugMode) {
        print(
          'Progress saved: bab=$babId, sub_bab=$subBabId, checked=$isChecked',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving progress: $e');
      }
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

      if (kDebugMode) {
        print('Found ${subBabsForThisBab.length} sub-babs for bab $babId');
      }

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
      await ApiSubjectService.batchSaveMateriProgress({
        'guru_id': teacherId,
        'mata_pelajaran_id': _selectedSubject,
        'class_id': _selectedClassId,
        'progress_items': progressItems,
      });

      if (kDebugMode) {
        print('Batch progress saved: ${progressItems.length} items');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error batch saving progress: $e');
      }
    }
  }

  // Navigasi ke halaman detail sub bab
  void _navigateToSubBabDetail(
    Map<String, dynamic> subBab,
    Map<String, dynamic> bab,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubBabDetailPage(
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
        ),
      ),
    );
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
                onTap: () => Navigator.pop(context),
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
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          backgroundColor: ColorUtils.slate50,
          body: Column(
            children: [
              // Header dengan gradient seperti presence_teacher
              _buildHeader(languageProvider),

              // Filter Section
              _buildFilterSection(languageProvider),

              // Search Bar
              Consumer<LanguageProvider>(
                builder: (context, languageProvider, child) {
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
                },
              ),

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
      },
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
                    _contentMateriList = [];
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
    const tourCacheKey = 'tour_materi_screen_guru';
    try {
      // Try cache first
      final cached = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true && cached['tour'] != null) {
          _tourId = cached['tour']['id']?.toString();
          if (!mounted) return;
          _showTour();
        }
        return;
      }

      final status = await ApiTourService.getTourStatus(
        platform: 'mobile',
        role: 'guru',
        name: 'materi_screen_tour',
      );

      // Save to cache
      await LocalCacheService.save(tourCacheKey, status);

      if (status['should_show'] == true && status['tour'] != null) {
        _tourId = status['tour']['id'];

        if (!mounted) return;
        _showTour();
      }
    } catch (e) {
      if (kDebugMode) print('Error checking tour status: $e');
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
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_materi_screen_guru', {'should_show': false});
        }
      },
      onSkip: () {
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
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

/// Detail page for a sub-chapter (sub-bab) showing its content and AI materials.
///
/// Like a Vue `<SubChapterDetail>` component that shows content and allows
/// AI material generation. Contains both static content and AI-generated content
/// loaded asynchronously. Props include the sub-chapter data, parent chapter,
/// teacher/subject IDs, and a checkbox callback.
class SubBabDetailPage extends StatefulWidget {
  final Map<String, dynamic> subBab;
  final Map<String, dynamic> bab;
  final String teacherId;
  final String subjectId;
  final bool checked;
  final ValueChanged<bool?> onCheckChanged;

  const SubBabDetailPage({
    super.key,
    required this.subBab,
    required this.bab,
    required this.teacherId,
    required this.subjectId,
    required this.checked,
    required this.onCheckChanged,
  });

  @override
  SubBabDetailPageState createState() => SubBabDetailPageState();
}

class SubBabDetailPageState extends State<SubBabDetailPage>
    with SingleTickerProviderStateMixin {
  late bool _isChecked;
  List<dynamic> _contentMateriList = [];
  Map<String, dynamic>? _aiGeneratedData;
  bool _isLoading = false;
  bool _isLoadingAi = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _isChecked = widget.checked;
    _tabController = TabController(length: 3, vsync: this);
    _loadContentMateri();
    _loadAiContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadContentMateri() async {
    final contentCacheKey = 'materi_content_${widget.subBab['id']}';

    // Try cache — return early if hit
    try {
      final cached = await LocalCacheService.load(contentCacheKey, ttl: const Duration(hours: 6));
      if (cached != null && cached is List && mounted) {
        setState(() {
          _contentMateriList = List<dynamic>.from(cached);
          _isLoading = false;
        });
        if (kDebugMode) print('📦 ContentMateri ${widget.subBab['id']}: from cache');
        return;
      }
    } catch (e) {
      if (kDebugMode) print('Content cache load error: $e');
    }

    // No cache — fetch from API
    if (mounted) setState(() => _isLoading = true);

    try {
      final kontenMateri = await ApiSubjectService.getContentMateri(
        subBabId: widget.subBab['id'].toString(),
      );
      if (!mounted) return;

      setState(() {
        _contentMateriList = kontenMateri;
        _isLoading = false;
      });

      await LocalCacheService.save(contentCacheKey, kontenMateri);
    } catch (e) {
      if (kDebugMode) print('Error loading content materi: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAiContent() async {
    final aiCacheKey = 'materi_ai_${widget.teacherId}_${widget.bab['id']}_${widget.subBab['id']}';

    // Try local cache — return early if hit
    try {
      final cached = await LocalCacheService.load(aiCacheKey, ttl: const Duration(hours: 6));
      if (cached != null && cached is Map && mounted) {
        setState(() {
          _aiGeneratedData = Map<String, dynamic>.from(cached);
          _isLoadingAi = false;
        });
        if (kDebugMode) print('📦 AI content ${widget.subBab['id']}: from cache');
        return;
      }
    } catch (e) {
      if (kDebugMode) print('AI local cache load error: $e');
    }

    // No cache — fetch from API
    if (mounted) setState(() => _isLoadingAi = true);

    try {
      Map<String, dynamic>? aiData;

      try {
        final cacheResult = await ApiSubjectService.checkMaterialCache(
          teacherId: widget.teacherId,
          chapterId: widget.bab['id'].toString(),
          subChapterId: widget.subBab['id'].toString(),
        );
        if (!mounted) return;

        if (cacheResult != null) {
          final cacheData = cacheResult is Map && cacheResult['data'] is Map
              ? cacheResult['data']
              : cacheResult;

          final isCached = cacheData['cached'] == true;
          final materialId =
              (cacheData['material_id'] ?? cacheData['id'])?.toString();

          if (isCached && materialId != null) {
            final materialResult =
                await ApiSubjectService.getGeneratedMaterial(materialId);
            if (!mounted) return;

            final data = materialResult is Map
                ? (materialResult['data'] ?? materialResult)
                : null;
            if (data != null && data is Map<String, dynamic>) {
              aiData = data;
            }
          }
        }
      } catch (cacheError) {
        if (kDebugMode) {
          print('Check-cache failed: $cacheError, trying list fallback...');
        }
      }

      // Fallback: use list endpoint if check-cache failed
      if (aiData == null && mounted) {
        try {
          final listResult = await ApiSubjectService.listGeneratedMaterials(
            teacherId: widget.teacherId,
            chapterId: widget.bab['id'].toString(),
          );
          if (!mounted) return;

          final items = listResult is Map
              ? (listResult['data'] is List ? listResult['data'] : null)
              : (listResult is List ? listResult : null);

          if (items != null && items.isNotEmpty) {
            final subChapterId = widget.subBab['id'].toString();
            Map<String, dynamic>? match;

            for (final item in items) {
              if (item is Map<String, dynamic>) {
                final itemSubChapter =
                    (item['sub_chapter_id'] ?? item['sub_bab_id'])?.toString();
                if (itemSubChapter == subChapterId) {
                  match = item;
                  break;
                }
              }
            }

            if (match != null) {
              final materialId = match['id']?.toString();
              if (materialId != null) {
                final materialResult =
                    await ApiSubjectService.getGeneratedMaterial(materialId);
                if (!mounted) return;

                final data = materialResult is Map
                    ? (materialResult['data'] ?? materialResult)
                    : null;
                if (data != null && data is Map<String, dynamic>) {
                  aiData = data;
                }
              }
            }
          }
        } catch (listError) {
          if (kDebugMode) {
            print('List materials fallback also failed: $listError');
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _aiGeneratedData = aiData;
        _isLoadingAi = false;
      });

      if (aiData != null) {
        await LocalCacheService.save(aiCacheKey, aiData);
      }
    } catch (e) {
      if (kDebugMode) print('Error loading AI content: $e');
      if (!mounted) return;
      setState(() => _isLoadingAi = false);
    }
  }

  String _stripHtml(String html) {
    if (html.isEmpty) return '';
    var text = html.replaceAll(RegExp(r'<ul>|<ol>'), '\n');
    text = text.replaceAll(RegExp(r'</ul>|</ol>'), '\n');
    int counter = 1;
    while (text.contains('<li>')) {
      if (text.contains('<ol>')) {
        text = text.replaceFirst('<li>', '$counter. ');
        counter++;
      } else {
        text = text.replaceFirst('<li>', '• ');
      }
    }
    text = text.replaceAll('</li>', '\n');
    text = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    text = text.replaceAll(RegExp(r'<h3>'), '\n');
    text = text.replaceAll(RegExp(r'</h3>|<p>|</p>'), '\n');
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll(RegExp(r'\n{2,}'), '\n\n');
    return text.trim();
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
                onTap: () => Navigator.pop(context),
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
                      'BAB ${widget.bab['urutan']}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      widget.bab['judul_bab'] ?? 'Judul Bab',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  final newValue = !_isChecked;
                  setState(() {
                    _isChecked = newValue;
                  });
                  widget.onCheckChanged(newValue);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isChecked
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isChecked
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Done',
                          'id': 'Selesai',
                        }),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: _navigateToAiResult,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.description_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sub Bab ${widget.subBab['urutan']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        widget.subBab['judul_sub_bab'] ?? 'Judul Sub Bab',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          backgroundColor: ColorUtils.slate50,
          body: Column(
            children: [
              _buildHeader(languageProvider),
              Expanded(
                child: _isLoading
                    ? SkeletonListLoading(
                        padding: EdgeInsets.only(top: 8, bottom: 80),
                        showActions: false,
                      )
                    : (_contentMateriList.isEmpty && _aiGeneratedData == null && !_isLoadingAi)
                        ? _buildEmptyContent(languageProvider)
                        : _buildTabbedContent(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyContent(LanguageProvider languageProvider) {
    return EmptyState(
      title: languageProvider.getTranslatedText({
        'en': 'No Content',
        'id': 'Tidak Ada Konten',
      }),
      subtitle: languageProvider.getTranslatedText({
        'en':
            'Content for this sub-chapter is not available yet. Tap the AI button to generate.',
        'id':
            'Konten untuk sub bab ini belum tersedia. Tekan tombol AI untuk generate.',
      }),
      icon: Icons.article,
    );
  }

  // ==================== TABBED CONTENT ====================

  Map<String, dynamic>? _parseMaterialContent() {
    final raw = _aiGeneratedData?['material_content'];
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) {
      try {
        final parsed = json.decode(raw);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (_) {}
    }
    return null;
  }

  Widget _buildTabbedContent() {
    final primaryColor = _getPrimaryColor();
    final quizzes =
        (_aiGeneratedData?['quizzes'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
    final references =
        (_aiGeneratedData?['references'] as List?)
            ?.cast<Map<String, dynamic>>() ??
            [];

    return Column(
      children: [
        // Tab Bar
        Container(
          margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
          decoration: BoxDecoration(
            color: ColorUtils.slate100,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.all(4),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: primaryColor,
            unselectedLabelColor: ColorUtils.slate500,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              Tab(
                height: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_stories_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Materi'),
                  ],
                ),
              ),
              Tab(
                height: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.quiz_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Kuis'),
                    if (quizzes.isNotEmpty) ...[
                      SizedBox(width: 4),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${quizzes.length}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                height: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.menu_book_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Referensi'),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMateriTab(),
              _buildKuisTab(quizzes),
              _buildReferensiTab(references),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== TAB 1: MATERI ====================

  Widget _buildMateriTab() {
    final parsedContent = _parseMaterialContent();

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // AI Materi Section
        if (parsedContent != null) ...[
          // Ringkasan Card
          if (parsedContent['ringkasan'] != null)
            _buildSectionCard(
              icon: Icons.summarize_rounded,
              iconColor: Color(0xFF8B5CF6),
              title: 'Ringkasan',
              child: Text(
                parsedContent['ringkasan'] ?? '',
                style: TextStyle(
                  color: ColorUtils.slate700,
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
            ),

          // Poin Utama Card
          if (parsedContent['poin_utama'] is List) ...[
            SizedBox(height: 12),
            _buildSectionCard(
              icon: Icons.lightbulb_rounded,
              iconColor: Color(0xFFF59E0B),
              title: 'Poin Utama',
              child: Column(
                children: (parsedContent['poin_utama'] as List)
                    .asMap()
                    .entries
                    .map((entry) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom:
                          entry.key < (parsedContent['poin_utama'] as List).length - 1
                              ? 10
                              : 0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          margin: EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.value.toString(),
                            style: TextStyle(
                              color: ColorUtils.slate700,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Cara Mengajar Card
          if (parsedContent['cara_mengajar'] != null) ...[
            SizedBox(height: 12),
            _buildSectionCard(
              icon: Icons.school_rounded,
              iconColor: _getPrimaryColor(),
              title: 'Cara Mengajar',
              child: Text(
                parsedContent['cara_mengajar'] ?? '',
                style: TextStyle(
                  color: ColorUtils.slate700,
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
            ),
          ],
        ] else if (_aiGeneratedData != null) ...[
          // Fallback: raw material_content as text
          _buildSectionCard(
            icon: Icons.auto_awesome,
            iconColor: Colors.orange,
            title: 'Materi AI',
            child: Text(
              _stripHtml(
                  _aiGeneratedData!['material_content']?.toString() ?? ''),
              style: TextStyle(
                color: ColorUtils.slate700,
                fontSize: 14,
                height: 1.7,
              ),
            ),
          ),
        ],

        // AI Info Badge
        if (_aiGeneratedData != null) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getPrimaryColor().withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: _getPrimaryColor().withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome,
                    size: 16,
                    color: _getPrimaryColor().withValues(alpha: 0.6)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dibuat oleh AI  •  ${_aiGeneratedData!['ai_model_used'] ?? 'Claude'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: ColorUtils.slate500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _navigateToAiResult,
                  child: Text(
                    'Regenerate',
                    style: TextStyle(
                      fontSize: 11,
                      color: _getPrimaryColor(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Regular content from main backend
        if (_contentMateriList.isNotEmpty) ...[
          SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ColorUtils.slate200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.article_rounded,
                    color: ColorUtils.slate600, size: 16),
              ),
              SizedBox(width: 8),
              Text(
                'Konten Manual',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate800,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ..._contentMateriList.asMap().entries.map((entry) {
            final index = entry.key;
            final content = entry.value;
            final cardColor = ColorUtils.getColorForIndex(index);

            return Container(
              margin: EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ColorUtils.slate200),
                boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: cardColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
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
                            content['judul_konten'] ??
                                content['title'] ??
                                'Judul Konten',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: ColorUtils.slate900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            content['isi_konten'] ??
                                content['description'] ??
                                '',
                            style: TextStyle(
                              color: ColorUtils.slate600,
                              fontSize: 13,
                              height: 1.5,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  // ==================== TAB 2: KUIS ====================

  Widget _buildKuisTab(List<Map<String, dynamic>> quizzes) {
    if (quizzes.isEmpty) {
      return _buildEmptyTabState(
        icon: Icons.quiz_rounded,
        title: 'Belum Ada Kuis',
        subtitle: 'Generate materi AI untuk mendapatkan kuis otomatis.',
      );
    }

    // Separate MC and essay
    final mcQuizzes =
        quizzes.where((q) => q['question_type'] == 'multiple_choice').toList();
    final essayQuizzes =
        quizzes.where((q) => q['question_type'] == 'essay').toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // Stats row
        _buildQuizStats(quizzes),
        SizedBox(height: 16),

        // Pilihan Ganda
        if (mcQuizzes.isNotEmpty) ...[
          _buildSubSectionHeader(
            icon: Icons.check_circle_outline_rounded,
            title: 'Pilihan Ganda',
            count: mcQuizzes.length,
            color: _getPrimaryColor(),
          ),
          SizedBox(height: 10),
          ...mcQuizzes.asMap().entries.map((entry) =>
              _buildMcQuizCard(entry.key, entry.value, mcQuizzes.length)),
        ],

        // Essay
        if (essayQuizzes.isNotEmpty) ...[
          SizedBox(height: 16),
          _buildSubSectionHeader(
            icon: Icons.edit_note_rounded,
            title: 'Essay',
            count: essayQuizzes.length,
            color: Color(0xFF8B5CF6),
          ),
          SizedBox(height: 10),
          ...essayQuizzes.asMap().entries
              .map((entry) => _buildEssayQuizCard(entry.key, entry.value)),
        ],
      ],
    );
  }

  Widget _buildQuizStats(List<Map<String, dynamic>> quizzes) {
    final easy =
        quizzes.where((q) => q['difficulty'] == 'easy').length;
    final medium =
        quizzes.where((q) => q['difficulty'] == 'medium').length;
    final hard =
        quizzes.where((q) => q['difficulty'] == 'hard').length;
    final mc =
        quizzes.where((q) => q['question_type'] == 'multiple_choice').length;
    final essay = quizzes.where((q) => q['question_type'] == 'essay').length;

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getPrimaryColor().withValues(alpha: 0.08),
            _getPrimaryColor().withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _getPrimaryColor().withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          _buildStatItem('Total', '${quizzes.length}', _getPrimaryColor()),
          _buildStatDivider(),
          _buildStatItem('PG', '$mc', Color(0xFF2563EB)),
          _buildStatDivider(),
          _buildStatItem('Essay', '$essay', Color(0xFF8B5CF6)),
          _buildStatDivider(),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDiffDot(Colors.green, easy),
                SizedBox(width: 6),
                _buildDiffDot(Colors.orange, medium),
                SizedBox(width: 6),
                _buildDiffDot(Colors.red, hard),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 30,
      color: ColorUtils.slate200,
    );
  }

  Widget _buildDiffDot(Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 3),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate600,
          ),
        ),
      ],
    );
  }

  Widget _buildSubSectionHeader({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate800,
          ),
        ),
        SizedBox(width: 6),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMcQuizCard(
      int index, Map<String, dynamic> quiz, int totalMc) {
    final difficulty = quiz['difficulty']?.toString().toLowerCase() ?? '';
    final diffConfig = _getDifficultyConfig(difficulty);
    final options = quiz['options'] as List? ?? [];

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Container(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: _getPrimaryColor().withValues(alpha: 0.03),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _getPrimaryColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _getPrimaryColor(),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pertanyaan ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: diffConfig.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: diffConfig.color.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    diffConfig.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: diffConfig.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Question text
          Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Text(
              quiz['question'] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: ColorUtils.slate900,
                height: 1.5,
              ),
            ),
          ),
          // Options
          ...options.map((opt) {
            final option = opt as Map<String, dynamic>;
            final isCorrect = option['is_correct'] == true;
            return Container(
              margin: EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCorrect
                    ? Color(0xFF10B981).withValues(alpha: 0.08)
                    : ColorUtils.slate50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCorrect
                      ? Color(0xFF10B981).withValues(alpha: 0.3)
                      : ColorUtils.slate200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? Color(0xFF10B981).withValues(alpha: 0.15)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isCorrect
                            ? Color(0xFF10B981)
                            : ColorUtils.slate300,
                      ),
                    ),
                    child: Center(
                      child: isCorrect
                          ? Icon(Icons.check_rounded,
                              size: 14, color: Color(0xFF10B981))
                          : Text(
                              option['label'] ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ColorUtils.slate600,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      option['text'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isCorrect ? FontWeight.w600 : FontWeight.w400,
                        color: isCorrect
                            ? Color(0xFF059669)
                            : ColorUtils.slate700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          // Explanation
          if (quiz['explanation'] != null &&
              quiz['explanation'].toString().isNotEmpty) ...[
            Container(
              margin: EdgeInsets.fromLTRB(14, 4, 14, 14),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF3B82F6).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Color(0xFF3B82F6).withValues(alpha: 0.12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFF3B82F6).withValues(alpha: 0.7)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      quiz['explanation'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildEssayQuizCard(int index, Map<String, dynamic> quiz) {
    final difficulty = quiz['difficulty']?.toString().toLowerCase() ?? '';
    final diffConfig = _getDifficultyConfig(difficulty);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: Color(0xFF8B5CF6).withValues(alpha: 0.03),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF8B5CF6),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Essay ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: diffConfig.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: diffConfig.color.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    diffConfig.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: diffConfig.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Question
          Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Text(
              quiz['question'] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: ColorUtils.slate900,
                height: 1.5,
              ),
            ),
          ),
          // Answer key
          if (quiz['correct_answer'] != null) ...[
            Container(
              margin: EdgeInsets.fromLTRB(14, 0, 14, 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF10B981).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Color(0xFF10B981).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.key_rounded,
                          size: 14, color: Color(0xFF10B981)),
                      SizedBox(width: 6),
                      Text(
                        'Kunci Jawaban',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    quiz['correct_answer'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: ColorUtils.slate700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Explanation / Penilaian
          if (quiz['explanation'] != null &&
              quiz['explanation'].toString().isNotEmpty) ...[
            Container(
              margin: EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF8B5CF6).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Color(0xFF8B5CF6).withValues(alpha: 0.12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.grading_rounded,
                      size: 14,
                      color: Color(0xFF8B5CF6).withValues(alpha: 0.7)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      quiz['explanation'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            SizedBox(height: 6),
        ],
      ),
    );
  }

  // ==================== TAB 3: REFERENSI ====================

  Widget _buildReferensiTab(List<Map<String, dynamic>> references) {
    if (references.isEmpty) {
      return _buildEmptyTabState(
        icon: Icons.menu_book_rounded,
        title: 'Belum Ada Referensi',
        subtitle: 'Generate materi AI untuk mendapatkan referensi otomatis.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: references.length,
      separatorBuilder: (_, __) => SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ref = references[index];
        final refType = ref['type']?.toString() ?? '';
        final typeConfig = _getReferenceTypeConfig(refType);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with type badge
              Container(
                padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
                decoration: BoxDecoration(
                  color: typeConfig.color.withValues(alpha: 0.04),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(13)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: typeConfig.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          Icon(typeConfig.icon, size: 15, color: typeConfig.color),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: typeConfig.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          typeConfig.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: typeConfig.color,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Title
              Padding(
                padding: EdgeInsets.fromLTRB(14, 8, 14, 6),
                child: Text(
                  ref['title'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate900,
                    fontSize: 15,
                  ),
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Text(
                  _stripHtml(ref['content'] ?? ''),
                  style: TextStyle(
                    color: ColorUtils.slate600,
                    height: 1.6,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== SHARED HELPERS ====================

  void _navigateToAiResult() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MateriAiResultScreen(
          teacherId: widget.teacherId,
          subjectId: widget.subjectId,
          chapterId: widget.bab['id'].toString(),
          subChapterId: widget.subBab['id'].toString(),
          title: widget.subBab['judul_sub_bab'] ?? 'Materi Pembelajaran',
        ),
      ),
    ).then((_) {
      // Reload AI content when returning
      _loadAiContent();
    });
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.04),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: iconColor.withValues(alpha: 0.2)),
                  ),
                  child: Icon(icon, size: 15, color: iconColor),
                ),
                SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTabState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 28, color: ColorUtils.slate400),
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: ColorUtils.slate500,
              ),
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: _navigateToAiResult,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _getPrimaryColor(),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: _getPrimaryColor().withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Generate AI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({Color color, String label}) _getDifficultyConfig(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return (color: Color(0xFF10B981), label: 'Mudah');
      case 'medium':
        return (color: Color(0xFFF59E0B), label: 'Sedang');
      case 'hard':
        return (color: Color(0xFFEF4444), label: 'Sulit');
      default:
        return (color: ColorUtils.slate500, label: difficulty.toUpperCase());
    }
  }

  ({Color color, String label, IconData icon}) _getReferenceTypeConfig(
      String type) {
    switch (type) {
      case 'concept_deep_dive':
        return (
          color: Color(0xFF3B82F6),
          label: 'Pendalaman Konsep',
          icon: Icons.psychology_rounded
        );
      case 'real_world_example':
        return (
          color: Color(0xFF10B981),
          label: 'Contoh Nyata',
          icon: Icons.public_rounded
        );
      case 'common_misconception':
        return (
          color: Color(0xFFF59E0B),
          label: 'Miskonsepsi Umum',
          icon: Icons.warning_amber_rounded
        );
      case 'teaching_tip':
        return (
          color: Color(0xFF8B5CF6),
          label: 'Tips Mengajar',
          icon: Icons.tips_and_updates_rounded
        );
      default:
        return (
          color: Color(0xFF6366F1),
          label: type.replaceAll('_', ' ').toUpperCase(),
          icon: Icons.bookmark_rounded
        );
    }
  }
}
