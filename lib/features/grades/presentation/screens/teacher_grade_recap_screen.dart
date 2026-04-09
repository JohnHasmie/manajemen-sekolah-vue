// Grade recap (rekap nilai) screen for teachers -- final grade summary.
// Like `pages/teacher/GradeRecap/Index.vue` in a Vue app.
//
// A multi-step screen: Step 0 (select class) -> Step 1 (select subject) ->
// Step 2 (recap table with editable predikat/deskripsi per student per chapter).
// Supports adding/removing chapters (bab), bulk grade selection, auto-
// description generation, save to API, and Excel export.
// In Laravel terms: `GradeRecapController@index`, `@store`, `@export`.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/grades/data/grade_recap_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/grades/exports/grade_recap_export_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_selection_dialog.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/bulk_selection_dialog.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/edit_deskripsi_dialog.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_editable_cell.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_class_list.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_subject_list.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_search_bar.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_app_bar.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_table_view.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_tour_helper.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_unsaved_changes_dialog.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_delete_chapter_dialog.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_day_utils.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_cache_helpers.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_row_builder.dart';

/// Grade recap wizard: class selection -> subject selection -> recap table.
///
/// A StatefulWidget with complex spreadsheet-like editing capabilities.
/// Props (like Vue props): [teacher] -- current teacher info.
class GradeRecapPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic>? initialClass;
  final Map<String, dynamic>? initialSubject;

  const GradeRecapPage({super.key, required this.teacher, this.initialClass, this.initialSubject});

  @override
  ConsumerState<GradeRecapPage> createState() => _GradeRecapPageState();
}

/// State for [GradeRecapPage].
///
/// Like a Vue page component with `data() { return {...} }`. Manages:
/// - Multi-step wizard (class -> subject -> recap table)
/// - Editable table data with per-cell controllers (predikat, deskripsi, score)
/// - Chapter (bab) management (add/remove columns)
/// - Bulk grade operations and auto-description generation
/// - Excel export and unsaved change tracking
///
/// `setState()` is like Vue's reactivity -- triggers UI rebuild.
class _GradeRecapPageState extends ConsumerState<GradeRecapPage> {
  // Services
  final ApiSubjectService apiSubjectService = getIt<ApiSubjectService>();
  final ApiTeacherService apiTeacherService = getIt<ApiTeacherService>();

  // State
  int _currentStep = 0; // 0: Class List, 1: Subject List, 2: Recap Table

  // Data
  List<dynamic> _classList = [];
  List<dynamic> _subjectList = [];
  List<dynamic> _chapters = [];
  List<dynamic> _allAvailableChapters = [];
  List<dynamic> _todaySchedules = [];
  Map<String, String> _dayIdMap = {};

  // Computed Table Data
  List<Map<String, dynamic>> _tableData = [];
  List<dynamic> _rawGrades = [];

  // Selected Data
  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedSubject;

  // Controllers for editable fields
  final Map<String, TextEditingController> _predikatControllers = {};
  final Map<String, TextEditingController> _descriptionControllers = {};
  final Map<String, TextEditingController> _scoreControllers = {};

  // Loading & Pagination
  bool _isLoading = false;
  bool _isSaving = false;
  double _studentInfoWidth = 160.0; // Default width for frozen column
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  final int _perPage = 20;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  bool _isExporting = false;
  bool _hasUnsavedChanges = false;

  final GlobalKey _exportKey = GlobalKey();
  final GlobalKey _saveKey = GlobalKey();
  final GlobalKey _addChapterKey = GlobalKey();

  /// Like Vue's `mounted()` -- sets up scroll/search listeners and loads initial data.
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);

    // If opened with pre-selected class+subject, skip to table directly
    if (widget.initialClass != null && widget.initialSubject != null) {
      _selectedClass = widget.initialClass;
      _selectedSubject = widget.initialSubject;
      _currentStep = 2;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecapData());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadTodaySchedules();
        _loadClasses();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    for (var c in _predikatControllers.values) {
      c.dispose();
    }
    for (var c in _descriptionControllers.values) {
      c.dispose();
    }
    for (var c in _scoreControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && !_isLoading && _currentStep == 0) {
        _loadMoreClasses();
      }
    }
  }

  void _onSearchChanged() {
    // Manual search triggered by button
  }

  // ==================== PRIORITY LOGIC ====================

  Future<void> _loadTodaySchedules() async {
    try {
      // 1. Load Days — try cache first (shared with teaching_schedule)
      List<dynamic> days = [];
      try {
        final cachedDays = await LocalCacheService.load(
          'school_day_data',
          ttl: const Duration(hours: 24),
        );
        if (cachedDays != null) {
          days = List<dynamic>.from(cachedDays);
          AppLogger.debug('grades', 'Rekap: days from cache');
        }
      } catch (_) {}
      if (days.isEmpty) {
        days = await getIt<ApiScheduleService>().getDays();
        if (days.isNotEmpty) LocalCacheService.save('school_day_data', days);
      }

      final Map<String, String> dayIdMap = {};
      for (var day in days) {
        dayIdMap[day['nama'] ?? day['name'] ?? ''] = day['id'].toString();
      }

      // 2. Determine Today
      final now = DateTime.now();
      final dayNamesISO = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final currentDayISO = dayNamesISO[now.weekday - 1];
      final currentDayIndo = normalizeDayName(currentDayISO);

      String? currentDayId;
      dayIdMap.forEach((key, value) {
        if (normalizeDayName(key) == currentDayIndo) {
          currentDayId = value;
        }
      });

      if (!mounted) return;

      // 3. Load Teacher Schedules — try teaching_schedule's cache first
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();
      final semesterProvider = academicYearProvider.selectedAcademicYear;
      final semester = semesterProvider?['semester']?.toString() ?? '1';
      final teacherId = widget.teacher['id']?.toString() ?? '';

      List<dynamic> allSchedules = [];

      // Try teaching_schedule's cached data
      final scheduleCacheKey = CacheKeyBuilder.custom(
        'schedule_teacher',
        '${teacherId}_$semester',
        academicYearId,
      );
      try {
        final cached = await LocalCacheService.load(
          scheduleCacheKey,
          ttl: const Duration(hours: 3),
        );
        if (cached != null) {
          final cachedData = Map<String, dynamic>.from(cached);
          allSchedules = List<dynamic>.from(cachedData['schedules'] ?? []);
          AppLogger.debug(
            'grades',
            'Rekap: schedules from teaching_schedule cache (${allSchedules.length})',
          );
        }
      } catch (_) {}

      // Fallback to API
      if (allSchedules.isEmpty) {
        final schedules = await getIt<ApiScheduleService>()
            .getSchedulesPaginated(
              limit: 100,
              teacherId: widget.teacher['id'],
              academicYearId: academicYearId,
            );
        allSchedules = schedules['data'] ?? [];
      }

      if (mounted) {
        setState(() {
          _dayIdMap = dayIdMap;
          _todaySchedules = allSchedules.where((s) {
            final ids = extractDayIds(s);
            if (currentDayId != null && ids.contains(currentDayId)) return true;
            return ids.any((id) {
              final entry = _dayIdMap.entries.firstWhere(
                (e) => e.value == id,
                orElse: () => const MapEntry('', ''),
              );
              return entry.key.isNotEmpty &&
                  normalizeDayName(entry.key) == currentDayIndo;
            });
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading today schedules: $e');
    }
  }


  // ==================== HELPER METHODS ====================

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  // ==================== CACHE ====================

  String? _buildClassesCacheKey() {
    final teacherId = widget.teacher['id']?.toString() ?? '';
    if (teacherId.isEmpty) return null;
    final academicYearId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
    return 'rekap_nilai_classes_${teacherId}_$academicYearId';
  }

  String _buildRecapCacheKey() {
    final provider = ref.read(academicYearRiverpod);
    final academicYearId =
        (provider.selectedAcademicYear?['id'] ??
                provider.activeAcademicYear?['id'])
            ?.toString() ??
        '';
    final classId = _selectedClass?['id']?.toString() ?? '';
    final subjectId = _selectedSubject?['id']?.toString() ?? '';
    return 'rekap_nilai_recap_${classId}_${subjectId}_$academicYearId';
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('rekap_nilai_');
    if (_currentStep == 0) {
      _loadClasses(useCache: false);
    } else if (_currentStep == 1) {
      _loadSubjects(useCache: false);
    } else if (_currentStep == 2) {
      _loadRecapData(useCache: false);
    }
  }

  // ==================== LOAD DATA ====================

  Future<void> _loadClasses({
    bool resetPage = true,
    bool useCache = true,
  }) async {
    final role = widget.teacher['role']?.toString().toLowerCase() ?? '';
    final isTeacher = role.contains('guru');

    if (resetPage) {
      _currentPage = 1;
      _hasMoreData = true;

      // ─── Step 1: Try TeacherProvider (populated by Dashboard) ───
      if (isTeacher && useCache) {
        final teacherProvider = ref.read(teacherRiverpod);
        if (teacherProvider.isLoaded && teacherProvider.allClasses.isNotEmpty) {
          setState(() {
            _classList = List.from(teacherProvider.allClasses);
            _hasMoreData = false;
            _isLoading = false;
          });
          AppLogger.debug(
            'grades',
            'Rekap classes from TeacherProvider (${_classList.length})',
          );
          return; // ✅ Provider hit — no API needed
        }
      }

      // ─── Step 2: Try cache → return early ───
      if (useCache) {
        final cacheKey = _buildClassesCacheKey();
        if (cacheKey != null) {
          try {
            final cached = await LocalCacheService.load(
              cacheKey,
              ttl: const Duration(hours: 3),
            );
            if (cached != null && mounted) {
              final cachedClasses = List<dynamic>.from(cached);
              if (cachedClasses.isNotEmpty) {
                setState(() {
                  _classList = cachedClasses;
                  _isLoading = false;
                });
                AppLogger.debug(
                  'grades',
                  'Rekap classes from cache (${cachedClasses.length})',
                );
                return; // ✅ Cache hit — no API needed
              }
            }
          } catch (e) {
            AppLogger.error('grades', e);
          }
        }
      }

      // Show skeleton only if still empty
      if (_classList.isEmpty && mounted) {
        setState(() => _isLoading = true);
      }
    }

    // ─── Step 3: No cache — fetch fresh from API ───
    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      List<dynamic> loadedClasses = [];

      if (isTeacher) {
        loadedClasses = await getIt<ApiTeacherService>().getTeacherClasses(
          widget.teacher['id'],
          academicYearId: academicYearId,
        );
        _hasMoreData = false;
      } else {
        final response = await getIt<ApiClassService>().getClassPaginated(
          page: _currentPage,
          limit: _perPage,
          academicYearId: academicYearId,
          search: _searchController.text,
        );
        loadedClasses = response['data'] ?? [];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
      }

      if (mounted) {
        setState(() {
          if (resetPage) {
            _classList = loadedClasses;
          } else {
            _classList.addAll(loadedClasses);
          }
          _isLoading = false;
        });
      }

      // Save to cache (only for first page, no search)
      if (resetPage && _searchController.text.isEmpty) {
        final cacheKey = _buildClassesCacheKey();
        if (cacheKey != null) {
          await LocalCacheService.save(cacheKey, loadedClasses);
        }
      }
    } catch (e) {
      if (mounted) {
        if (_classList.isEmpty) {
          setState(() => _isLoading = false);
          SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
        }
      }
    }
  }

  Future<void> _loadMoreClasses() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _loadClasses(resetPage: false);
    setState(() => _isLoadingMore = false);
  }

  Future<void> _loadSubjects({bool useCache = true}) async {
    final subjectCacheKey = CacheKeyBuilder.custom(
      'rekap_nilai_subjects',
      widget.teacher['id'].toString(),
      _selectedClass!['id'].toString(),
    );

    // ─── Step 1: Try cache → return early ───
    if (useCache && _subjectList.isEmpty) {
      try {
        final cached = await LocalCacheService.load(
          subjectCacheKey,
          ttl: const Duration(hours: 3),
        );
        if (cached != null && mounted) {
          final cachedSubjects = List<dynamic>.from(cached);
          if (cachedSubjects.isNotEmpty) {
            setState(() {
              _subjectList = cachedSubjects;
              _isLoading = false;
            });
            AppLogger.debug(
              'grades',
              'Rekap subjects from cache (${cachedSubjects.length}) — skipping API',
            );
            return; // ✅ Cache hit — no API needed
          }
        }
      } catch (e) {
        AppLogger.error('grades', e);
      }
    }

    // Show skeleton only if still empty
    if (_subjectList.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }

    // ─── Step 2: No cache — fetch fresh from API ───
    try {
      final response = await dioClient.get(
        '/class/${_selectedClass!['id']}/subjects',
        queryParameters: {'teacher_id': widget.teacher['id']},
      );

      final allSubjects = response.data is List ? response.data as List : [];
      if (mounted) {
        setState(() {
          _subjectList = allSubjects;
          _isLoading = false;
        });
      }

      // Save to cache
      await LocalCacheService.save(subjectCacheKey, allSubjects);
    } catch (e) {
      if (mounted) {
        if (_subjectList.isEmpty) {
          setState(() => _isLoading = false);
          SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
        }
      }
    }
  }

  /// Loads recap data (students, grades, chapters) for the selected class/subject.
  /// Like `axios.get('/api/grade-recaps')` in Vue. Processes raw data into
  /// an editable table structure.
  Future<void> _loadRecapData({bool useCache = true}) async {
    try {
      final provider = ref.read(academicYearRiverpod);
      final academicYearId =
          (provider.selectedAcademicYear?['id'] ??
                  provider.activeAcademicYear?['id'])
              ?.toString() ??
          '';

      if (academicYearId.isEmpty) {
        throw Exception(
          'Academic Year is required but not selected or active.',
        );
      }

      final classId = _selectedClass!['id'].toString();
      final subjectId = _selectedSubject!['id'].toString();
      final masterSubjectId =
          _selectedSubject?['subject_id']?.toString() ??
          _selectedSubject?['id']?.toString() ??
          subjectId;

      final recapCacheKey = _buildRecapCacheKey();

      // ─── Step 1: Try cache → return early ───
      if (useCache) {
        final cached = await LocalCacheService.load(
          recapCacheKey,
          ttl: const Duration(hours: 3),
        );
        if (cached != null && cached is Map) {
          final cachedStudents = List<dynamic>.from(cached['students'] ?? []);
          final cachedChapters = List<dynamic>.from(cached['chapters'] ?? []);
          final cachedRawGrades = List<dynamic>.from(cached['rawGrades'] ?? []);
          final cachedRecaps = List<dynamic>.from(cached['recaps'] ?? []);

          if (cachedStudents.isNotEmpty) {
            _chapters = List.from(cachedChapters);
            _allAvailableChapters = List.from(
              cached['allChapters'] ?? cachedChapters,
            );
            _applyRecapChapterNames(cachedRecaps);

            setState(() {
              _rawGrades = cachedRawGrades;
              _allAvailableChapters = List.from(
                cached['allChapters'] ?? cachedChapters,
              );
            });

            _processTableData(
              cachedStudents,
              _chapters,
              cachedRawGrades,
              cachedRecaps,
            );

            // Trigger tour
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _currentStep == 2) _checkAndShowTour();
            });

            AppLogger.debug('grades', 'Rekap data from cache — skipping API');
            return; // ✅ Cache hit — no API needed
          }
        }
      }

      // ─── Step 2: Show skeleton only if no data yet ───
      if (_tableData.isEmpty) {
        setState(() => _isLoading = true);
      }

      // ─── Step 3: Load each data source with individual cache ───
      // This allows cross-screen cache reuse (e.g. students from presence,
      // bab-material from materi_screen)

      final studentCacheKey = CacheKeyBuilder.studentsByClass(classId);
      final chapterCacheKey = CacheKeyBuilder.custom(
        'bab_material',
        masterSubjectId,
      );
      final gradesCacheKey = CacheKeyBuilder.custom(
        'rekap_grades',
        '${classId}_$subjectId',
        academicYearId,
      );
      final recapsCacheKey = CacheKeyBuilder.custom(
        'rekap_recaps',
        '${classId}_$subjectId',
        academicYearId,
      );

      // Load all 4 sources in parallel — each checks its own cache first
      final results = await Future.wait([
        loadWithCache(
          cacheKey: studentCacheKey,
          ttl: const Duration(hours: 6),
          apiFetcher: () =>
              getIt<ApiClassService>().getStudentsByClassId(classId),
          useCache: useCache,
        ),
        loadWithCache(
          cacheKey: chapterCacheKey,
          ttl: const Duration(hours: 12),
          apiFetcher: () => getIt<ApiSubjectService>().getChapterMaterials(
            subjectId: masterSubjectId,
          ),
          useCache: useCache,
        ),
        loadGradesWithCache(
          cacheKey: gradesCacheKey,
          ttl: const Duration(hours: 3),
          classId: classId,
          subjectId: subjectId,
          academicYearId: academicYearId,
          useCache: useCache,
        ),
        loadWithCache(
          cacheKey: recapsCacheKey,
          ttl: const Duration(hours: 3),
          apiFetcher: () => getIt<ApiGradeRecapService>().getGradeRecaps(
            classId: classId,
            subjectId: subjectId,
            academicYearId: academicYearId,
          ),
          useCache: useCache,
        ),
      ]);

      if (!mounted) return;

      final students = results[0];
      final chapters = results[1];
      final rawGrades = results[2];
      final recaps = results[3];

      _chapters = List.from(chapters);
      _allAvailableChapters = List.from(chapters);
      _applyRecapChapterNames(recaps);

      setState(() {
        _rawGrades = rawGrades;
        _allAvailableChapters = List.from(chapters);
      });

      _processTableData(students, _chapters, rawGrades, recaps);

      // Save composite cache for full return-early on next visit
      await LocalCacheService.save(recapCacheKey, {
        'students': students,
        'chapters': chapters,
        'allChapters': List.from(chapters),
        'rawGrades': rawGrades,
        'recaps': recaps,
      });

      // Trigger tour
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentStep == 2) {
          _checkAndShowTour();
        }
      });
    } catch (e) {
      if (mounted) {
        if (_tableData.isEmpty) {
          setState(() => _isLoading = false);
          SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
        }
      }
    }
  }

  void _applyRecapChapterNames(List<dynamic> recaps) {
    // Delegates to the extracted pure helper — see grade_recap_row_builder.dart
    applyRecapChapterNames(chapters: _chapters, recaps: recaps);
  }

  /// Transforms raw API data into structured table rows with per-student,
  /// per-chapter grade cells. Delegates pure computation to
  /// [buildGradeRecapRows] (see grade_recap_row_builder.dart) and wires the
  /// results back into TextEditingControllers + setState.
  ///
  /// Like a Vue computed that pivots data for display.
  void _processTableData(
    List<dynamic> students,
    List<dynamic> chapters,
    List<dynamic> rawGrades,
    List<dynamic> recaps,
  ) {
    // Dispose old controllers before clearing
    for (var c in _predikatControllers.values) {
      c.dispose();
    }
    for (var c in _descriptionControllers.values) {
      c.dispose();
    }
    for (var c in _scoreControllers.values) {
      c.dispose();
    }
    _predikatControllers.clear();
    _descriptionControllers.clear();
    _scoreControllers.clear();

    // Pure data computation — no BuildContext or controller dependencies
    final result = buildGradeRecapRows(
      students: students,
      chapters: chapters,
      rawGrades: rawGrades,
      recaps: recaps,
    );

    // Wire results into TextEditingControllers
    result.predikatTexts.forEach((id, text) {
      _predikatControllers[id] = TextEditingController(text: text);
    });
    result.descriptionTexts.forEach((id, text) {
      _descriptionControllers[id] = TextEditingController(text: text);
    });
    result.scoreTexts.forEach((key, text) {
      _scoreControllers[key] = TextEditingController(text: text);
    });

    setState(() {
      _chapters = chapters;
      _tableData = result.rows;
      _isLoading = false;
    });
  }

  void _showGradeSelectionDialog(
    String studentClassId,
    String type,
    int? chapterIndex,
  ) {
    showGradeSelectionDialog(
      context: context,
      rawGrades: _rawGrades,
      studentClassId: studentClassId,
      type: type,
      chapterIndex: chapterIndex,
      onAverageSelected: (average) {
        _updateTableValue(studentClassId, type, chapterIndex, average);
      },
    );
  }

  void _updateTableValue(
    String studentClassId,
    String type,
    int? chapterIndex,
    double newValue,
  ) {
    setState(() {
      final index = _tableData.indexWhere(
        (row) => row['student_class_id'] == studentClassId,
      );
      if (index != -1) {
        final row = _tableData[index];

        // Update Controller
        final key = '$studentClassId|$type|${chapterIndex ?? 'null'}';
        if (_scoreControllers.containsKey(key)) {
          _scoreControllers[key]!.text = newValue.toStringAsFixed(1);
        }

        if (type == 'bab' && chapterIndex != null) {
          row['bab_scores'][chapterIndex] = newValue;
        } else if (type == 'uts') {
          row['uts'] = newValue;
        } else if (type == 'uas') {
          row['uas'] = newValue;
        } else if (type == 'skill_score') {
          row['skill_score'] = newValue;
        }
        _recalculateRow(row);
      }
    });
  }

  void _showBulkSelectionDialog(String type, [int? chapterIndex]) {
    showBulkSelectionDialog(
      context: context,
      type: type,
      chapterIndex: chapterIndex,
      rawGrades: _rawGrades,
      allAvailableChapters: _allAvailableChapters,
      onApplyBulkGrades: (selectedBulk) {
        _applyBulkGrades(type, selectedBulk, chapterIndex);
      },
      onChapterNameChanged: (c) {
        setState(() {
          _chapters[chapterIndex!] = c;
        });
        _updateAllDescriptions();
      },
    );
  }

  /// Builds an editable grade cell for the recap table.
  /// Delegates to [GradeRecapEditableCell]; callbacks keep setState in this
  /// StatefulWidget rather than inside the extracted widget.
  Widget _buildEditableGradeCell(
    String studentClassId,
    String type,
    int? chapterIndex,
  ) {
    final key = '$studentClassId|$type|${chapterIndex ?? 'null'}';
    final controller = _scoreControllers[key];

    if (controller == null) return Text('-');

    return GradeRecapEditableCell(
      controller: controller,
      onHistoryTap: () =>
          _showGradeSelectionDialog(studentClassId, type, chapterIndex),
      onChanged: (newValue) =>
          _updateTableValueSilently(studentClassId, type, chapterIndex, newValue),
    );
  }

  void _updateTableValueSilently(
    String studentClassId,
    String type,
    int? chapterIndex,
    double newValue,
  ) {
    setState(() {
      final index = _tableData.indexWhere(
        (row) => row['student_class_id'] == studentClassId,
      );
      if (index != -1) {
        final row = _tableData[index];
        if (type == 'bab' && chapterIndex != null) {
          row['bab_scores'][chapterIndex] = newValue;
        } else if (type == 'uts') {
          row['uts'] = newValue;
        } else if (type == 'uas') {
          row['uas'] = newValue;
        } else if (type == 'skill_score') {
          row['skill_score'] = newValue;
        }
        _recalculateRow(row);
      }
    });
  }

  void _showEditDeskripsiDialog(String studentClassId, String studentName) {
    final languageProvider = ref.read(languageRiverpod);

    showEditDeskripsiDialog(
      context: context,
      currentDescription: _descriptionControllers[studentClassId]?.text ?? '',
      studentName: studentName,
      primaryColor: _getPrimaryColor(),
      translations: {
        'editDescTitle': languageProvider.getTranslatedText({
          'en': 'Edit Description - $studentName',
          'id': 'Edit Deskripsi - $studentName',
        }),
        'hint': languageProvider.getTranslatedText({
          'en': 'Enter description...',
          'id': 'Masukkan deskripsi...',
        }),
        'cancel': languageProvider.getTranslatedText({
          'en': 'Cancel',
          'id': 'Batal',
        }),
        'save': languageProvider.getTranslatedText({
          'en': 'Save',
          'id': 'Simpan',
        }),
      },
      onSave: (newDescription) {
        setState(() {
          _descriptionControllers[studentClassId]?.text = newDescription;
          final index = _tableData.indexWhere(
            (row) => row['student_class_id'] == studentClassId,
          );
          if (index != -1) {
            _tableData[index]['deskripsi'] = newDescription;
            _hasUnsavedChanges = true;
          }
        });
      },
    );
  }

  void _addChapter() {
    setState(() {
      final newIndex = _chapters.length;
      final newChapterName = 'Bab ${newIndex + 1}';

      // Create a fresh map for the new chapter and add it
      _chapters.add({
        'judul_bab': newChapterName,
        'judul': newChapterName,
        'title': newChapterName,
      });

      // Keep _allAvailableChapters in sync if needed
      _allAvailableChapters.add({
        'judul_bab': newChapterName,
        'judul': newChapterName,
        'title': newChapterName,
      });

      for (var row in _tableData) {
        final studentClassId = row['student_class_id'];

        // Expand score list safely
        if (row['bab_scores'] is List) {
          row['bab_scores'] = List<dynamic>.from(row['bab_scores'])..add(null);
        }

        // Initialize Controller for the new Bab
        final key = '$studentClassId|bab|$newIndex';
        _scoreControllers[key] = TextEditingController(text: '');

        _recalculateRow(row);
      }
    });

    _updateAllDescriptions();

    // Automatically open the naming/bulk-fill dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showBulkSelectionDialog('bab', _chapters.length - 1);
    });
  }

  void _deleteChapter(int chapterIndex) {
    if (_chapters.length <= 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Minimal harus ada 1 materi')));
      return;
    }

    showGradeRecapDeleteChapterDialog(
      context: context,
      onConfirm: () {
        setState(() {
          _chapters.removeAt(chapterIndex);

          for (var row in _tableData) {
            final studentClassId = row['student_class_id'];

            if (row['bab_scores'] is List &&
                row['bab_scores'].length > chapterIndex) {
              row['bab_scores'].removeAt(chapterIndex);
            }

            // Clear old bab controllers
            _scoreControllers.removeWhere(
              (k, v) => k.startsWith('$studentClassId|bab|'),
            );

            // Recreate new ones with updated indices
            for (int i = 0; i < _chapters.length; i++) {
              final key = '$studentClassId|bab|$i';
              _scoreControllers[key] = TextEditingController(
                text: row['bab_scores'][i] != null
                    ? row['bab_scores'][i].toStringAsFixed(1)
                    : '',
              );
            }

            _recalculateRow(row);
          }
        });
        _updateAllDescriptions();
      },
    );
  }

  void _applyBulkGrades(
    String type,
    List<Map<String, dynamic>> selectedAssessments, [
    int? chapterIndex,
  ]) {
    setState(() {
      for (var row in _tableData) {
        final studentClassId = row['student_class_id'];

        double totalScore = 0;
        int count = 0;

        for (var a in selectedAssessments) {
          final title = a['title'];
          final date = a['date'];

          final grades = _rawGrades.where((g) {
            final gStudentClassId =
                (g['student_class_id'] ?? g['siswa_kelas_id'])?.toString();
            if (gStudentClassId != studentClassId) return false;

            final gTitle =
                g['assessment']?['title'] ?? g['title'] ?? g['judul'] ?? '';
            final gDate =
                g['assessment']?['date'] ?? g['date'] ?? g['tanggal'] ?? '';
            final gType =
                (g['type'] ?? g['jenis'])?.toString().toLowerCase() ?? '';

            // For uts/uas we also ensure type matches for safety, combining pts/pas respectively.
            if (type == 'uts' && gType != 'uts' && gType != 'pts') return false;
            if (type == 'uas' && gType != 'uas' && gType != 'pas') return false;
            if (type != 'bab' &&
                type != 'uts' &&
                type != 'uas' &&
                gType != type) {
              return false;
            }

            return gTitle == title && gDate == date;
          }).toList();

          if (grades.isNotEmpty) {
            final s =
                double.tryParse(
                  (grades[0]['score'] ?? grades[0]['nilai'] ?? '0').toString(),
                ) ??
                0;
            totalScore += s;
            count++;
          }
        }

        if (count > 0) {
          final finalBulkScore = totalScore / count;

          // Update Controller
          final key = '$studentClassId|$type|${chapterIndex ?? 'null'}';
          if (_scoreControllers.containsKey(key)) {
            _scoreControllers[key]!.text = finalBulkScore.toStringAsFixed(1);
          }

          if (type == 'bab') {
            row['bab_scores'][chapterIndex!] = finalBulkScore;
          } else if (type == 'uts') {
            row['uts'] = finalBulkScore;
          } else if (type == 'uas') {
            row['uas'] = finalBulkScore;
          } else if (type == 'skill_score') {
            row['skill_score'] = finalBulkScore;
          }
          _recalculateRow(row);
          _hasUnsavedChanges = true;
        }
      }
    });

    if (type == 'bab') _updateAllDescriptions();
  }

  /// Recalculates [row]'s final score and optionally syncs skill_score.
  /// Delegates pure computation to [recalculateRow] (grade_recap_row_builder.dart).
  void _recalculateRow(Map<String, dynamic> row) {
    final newSkillText = recalculateRow(row, getController: null);
    if (newSkillText != null) {
      final studentClassId = row['student_class_id'];
      final key = '$studentClassId|skill_score|null';
      if (_scoreControllers.containsKey(key)) {
        _scoreControllers[key]!.text = newSkillText;
      }
    }
  }

  void _updateAllDescriptions() {
    final String autoDescriptionTemplate =
        "Telah memahami materi ${_chapters.map((c) => c['judul_bab'] ?? c['judul'] ?? c['title'] ?? 'Bab').join(', ')} dengan cukup baik.";

    setState(() {
      for (var row in _tableData) {
        final studentClassId = row['student_class_id'];
        // Only update if it was using the automatic description (or is empty)
        // For simplicity, we can update it if the user hasn't modified it markedly,
        // but here we just update if it's currently empty or previously auto-generated.
        // Or simply provide a button to "Reset Descriptions".
        // Let's just update the controllers.
        if (_descriptionControllers[studentClassId]?.text.isEmpty ?? true) {
          _descriptionControllers[studentClassId]?.text = autoDescriptionTemplate;
          row['deskripsi'] = autoDescriptionTemplate;
        }
      }
    });
  }

  /// Saves all recap data to the API.
  /// Like `axios.post('/api/grade-recaps/batch')` in Vue.
  /// In Laravel terms: `GradeRecapController@batchUpdate`.
  Future<void> _saveRecaps() async {
    setState(() => _isSaving = true);
    try {
      final provider = ref.read(academicYearRiverpod);
      final academicYearId =
          (provider.selectedAcademicYear?['id'] ??
                  provider.activeAcademicYear?['id'])
              ?.toString() ??
          '';

      if (academicYearId.isEmpty) {
        throw Exception(
          'Academic Year is required but not selected or active.',
        );
      }

      final List<Map<String, dynamic>> payload = [];

      for (var row in _tableData) {
        final String studentClassId = row['student_class_id'];
        payload.add({
          'student_class_id': studentClassId,
          'subject_id': _selectedSubject!['id'].toString(),
          'academic_year_id': academicYearId,
          'predikat': _predikatControllers[studentClassId]?.text,
          'deskripsi': _descriptionControllers[studentClassId]?.text,
          'bab_scores': row['bab_scores'],
          'bab_names': _chapters
              .map((c) => c['judul_bab'] ?? c['judul'] ?? c['title'] ?? 'Bab')
              .toList(),
          'uts_score': row['uts'],
          'uas_score': row['uas'],
          'final_score': row['final_score'],
          'skill_score': row['skill_score'],
        });
      }

      await getIt<ApiGradeRecapService>().batchSaveGradeRecap(payload);

      if (mounted) {
        setState(() => _hasUnsavedChanges = false);
        SnackBarUtils.showInfo(context, AppLocalizations.gradeRecapSaved.tr);
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Exports the recap table to an Excel file.
  /// Like clicking "Export to Excel" in a Vue data table component.
  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);
    try {
      final className =
          _selectedClass?['nama'] ?? _selectedClass?['name'] ?? 'Kelas';
      final subjectName =
          _selectedSubject?['nama'] ??
          _selectedSubject?['name'] ??
          'Mata_Pelajaran';

      await ExcelGradeRecapService.exportGradeRecapToExcel(
        tableData: _tableData,
        chapters: _chapters,
        className: className,
        subjectName: subjectName,
        context: context,
      );
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  // ==================== BUILDERS ====================

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    return showGradeRecapUnsavedChangesDialog(context, ref);
  }

  void _handleBackButton() async {
    if (_hasUnsavedChanges) {
      final canLeave = await _onWillPop();
      if (!canLeave) return;
    }

    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _searchController.clear();
        _hasUnsavedChanges = false;
      });
    } else {
      if (mounted) {
        AppNavigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final canLeave = await _onWillPop();
        if (canLeave && context.mounted) {
          AppNavigator.pop(context, result);
        }
      },
      child: Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(
          children: [
            // Dialog-style header (matching Buku Nilai)
            if (widget.initialClass != null && widget.initialSubject != null)
              _buildDialogHeader(languageProvider)
            else
              GradeRecapAppBar(
                currentStep: _currentStep,
                primaryColor: _getPrimaryColor(),
                title: languageProvider.getTranslatedText({'en': 'Grade Recap', 'id': 'Rekap Nilai'}),
                selectClassLabel: languageProvider.getTranslatedText({'en': 'Select Class', 'id': 'Pilih Kelas'}),
                selectedClassName: _selectedClass?['nama'] ?? _selectedClass?['name'] ?? '',
                selectedSubjectName: _selectedSubject?['nama'] ?? _selectedSubject?['name'] ?? '',
                updateDataLabel: AppLocalizations.updateData.tr,
                saveKey: _saveKey,
                exportKey: _exportKey,
                isSaving: _isSaving,
                onBack: _handleBackButton,
                onSave: _saveRecaps,
                onRefresh: _forceRefresh,
                onExportExcel: () { if (!_isExporting) _exportToExcel(); },
              ),

            // Search bar (wizard mode only)
            if (_currentStep < 2 && widget.initialClass == null)
              GradeRecapSearchBar(
                controller: _searchController,
                hintText: languageProvider.getTranslatedText({
                  'en': _currentStep == 0 ? 'Search classes...' : 'Search subjects...',
                  'id': _currentStep == 0 ? 'Cari kelas...' : 'Cari mata pelajaran...',
                }),
                onChanged: (_) => setState(() {}),
                onClear: () { _searchController.clear(); setState(() {}); },
              ),

            Expanded(child: _buildBody(languageProvider)),
          ],
        ),
      ),
    );
  }

  /// Dialog-style header matching Buku Nilai pattern
  Widget _buildDialogHeader(LanguageProvider lp) {
    final p = _getPrimaryColor();
    final subjectName = _selectedSubject?['nama'] ?? _selectedSubject?['name'] ?? '';
    final className = _selectedClass?['nama'] ?? _selectedClass?['name'] ?? '';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p, p.withValues(alpha: 0.85)]),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        // Drag handle
        Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
        // Title row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
          child: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.assessment_outlined, color: Colors.white, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lp.getTranslatedText({'en': 'Grade Recap', 'id': 'Rekap Nilai'}), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('$subjectName - $className', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            // Save
            GestureDetector(
              key: _saveKey,
              onTap: _isSaving ? null : _saveRecaps,
              child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: _isSaving
                    ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, color: Colors.white, size: 16)),
            ),
            const SizedBox(width: 6),
            // Export
            GestureDetector(
              key: _exportKey,
              onTap: _isExporting ? null : _exportToExcel,
              child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.download_rounded, color: Colors.white, size: 16)),
            ),
            const SizedBox(width: 6),
            // Close
            GestureDetector(
              onTap: () async { final canLeave = await _onWillPop(); if (canLeave && mounted) Navigator.pop(context); },
              child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.close, color: Colors.white, size: 18)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildBody(LanguageProvider languageProvider) {
    if (_currentStep == 0) return _buildClassList(languageProvider);
    if (_currentStep == 1) return _buildSubjectList(languageProvider);

    // Step 2 — recap table, delegated to [GradeRecapTableView].
    // All state mutations (resize, chapter add/delete, dialog triggers) flow
    // back here via callbacks — the extracted widget is purely presentational.
    return GradeRecapTableView(
      tableData: _tableData,
      chapters: _chapters,
      isLoading: _isLoading,
      studentInfoWidth: _studentInfoWidth,
      primaryColor: _getPrimaryColor(),
      addChapterKey: _addChapterKey,
      labels: {
        'studentInfo': languageProvider.getTranslatedText({
          'en': 'STUDENT INFO',
          'id': 'INFO SISWA',
        }),
        'finalLabel': languageProvider.getTranslatedText({
          'en': 'Final',
          'id': 'Akhir',
        }),
        'skillLabel': languageProvider.getTranslatedText({
          'en': 'Skill',
          'id': 'Keterampilan',
        }),
        'gradeLabel': languageProvider.getTranslatedText({
          'en': 'Grade',
          'id': 'Pred',
        }),
        'descLabel': languageProvider.getTranslatedText({
          'en': 'Description',
          'id': 'Deskripsi',
        }),
        'gradeData': languageProvider.getTranslatedText({
          'en': 'Grade Data',
          'id': 'Data Nilai',
        }),
        'addBab': languageProvider.getTranslatedText({
          'en': 'Add Bab',
          'id': 'Tambah Bab',
        }),
      },
      predikatControllers: _predikatControllers,
      descriptionControllers: _descriptionControllers,
      cellBuilder: _buildEditableGradeCell,
      onWidthChanged: (newWidth) {
        setState(() {
          _studentInfoWidth = newWidth.clamp(100.0, 350.0);
        });
      },
      onBulkSelect: _showBulkSelectionDialog,
      onDeleteChapter: _deleteChapter,
      onAddChapter: _addChapter,
      onDeskripsiTap: _showEditDeskripsiDialog,
    );
  }

  /// Delegates to [GradeRecapClassList].
  /// All wizard-state mutations (setState + _loadSubjects) stay here via
  /// the [onClassTap] callback — the extracted widget is purely presentational.
  Widget _buildClassList(LanguageProvider languageProvider) {
    return GradeRecapClassList(
      classList: _classList,
      searchQuery: _searchController.text.toLowerCase(),
      isLoading: _isLoading,
      isLoadingMore: _isLoadingMore,
      primaryColor: _getPrimaryColor(),
      todaySchedules: _todaySchedules,
      todayLabel: languageProvider.getTranslatedText({
        'en': 'TODAY',
        'id': 'HARI INI',
      }),
      emptyLabel: languageProvider.getTranslatedText({
        'en': 'No classes found',
        'id': 'Kelas tidak ditemukan',
      }),
      scrollController: _scrollController,
      onClassTap: (item) {
        setState(() {
          _selectedClass = item;
          _currentStep = 1;
          _searchController.clear();
        });
        _loadSubjects();
      },
    );
  }

  /// Delegates to [GradeRecapSubjectList].
  /// All wizard-state mutations (setState + _loadRecapData) stay here via
  /// the [onSubjectTap] callback — the extracted widget is purely presentational.
  Widget _buildSubjectList(LanguageProvider languageProvider) {
    return GradeRecapSubjectList(
      subjectList: _subjectList,
      searchQuery: _searchController.text.toLowerCase(),
      isLoading: _isLoading,
      emptyLabel: languageProvider.getTranslatedText({
        'en': 'No subjects found',
        'id': 'Mata pelajaran tidak ditemukan',
      }),
      onSubjectTap: (item) {
        setState(() {
          _selectedSubject = item;
          _currentStep = 2;
          _searchController.clear();
        });
        _loadRecapData();
      },
    );
  }

  late final GradeRecapTourHelper _tourHelper = GradeRecapTourHelper(
    addChapterKey: _addChapterKey,
    saveKey: _saveKey,
    exportKey: _exportKey,
  );

  Future<void> _checkAndShowTour() => _tourHelper.checkAndShow(context);
}
