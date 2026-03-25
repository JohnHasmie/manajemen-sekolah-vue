// Grade input screen for teachers — class/subject selection wizard.
// Like `pages/teacher/GradeBook.vue` in a Vue app.
//
// This is the first part of a multi-step screen: Step 0 (select class) ->
// Step 1 (select subject) -> Step 2 (navigates to GradeBookPage).
// In Laravel terms, this is the entry point for GradeController.
//
// Contains:
// - [GradePage] -- the class/subject selection wizard (Steps 0-1)
//
// Related files (extracted from this file):
// - grade_book_screen.dart -- GradeBookPage (grade table with inline editing)
// - grade_input_form.dart -- GradeInputForm (individual grade edit dialog)
// - grade_input_form_new.dart -- GradeInputFormNew (bulk grade input form)
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/classrooms/services/classroom_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/schedule/services/schedule_service.dart';
import 'package:manajemensekolah/features/subjects/services/subject_service.dart';
import 'package:manajemensekolah/features/teachers/services/teacher_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/grades/screens/grade_book_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// The class/subject selection screen (Steps 0-1) before entering the grade book.
///
/// This StatefulWidget acts as a navigation wizard. In Vue terms, it is like
/// a parent page component that conditionally renders child components based
/// on `currentStep`. Props: [teacher] -- the logged-in teacher's data map.
class GradePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;

  const GradePage({super.key, required this.teacher});

  @override
  GradePageState createState() => GradePageState();
}

/// The mutable State for [GradePage] -- the class/subject selection wizard.
///
/// This is like a Vue page component with its own local state
/// (`data() { return {...} }`). Key state:
/// - [_currentStep] -- 0 for class list, 1 for subject list
/// - [_classList] / [_subjectList] -- data arrays from API
/// - [_selectedClass] / [_selectedSubject] -- currently selected items
/// - [_todaySchedules] -- used to highlight today's scheduled classes/subjects
///
/// `setState()` is like Vue's reactivity -- triggers a re-render when data changes.
class GradePageState extends ConsumerState<GradePage> {
  // Services
  final ApiSubjectService apiSubjectService = getIt<ApiSubjectService>();
  final ApiTeacherService apiTeacherService = getIt<ApiTeacherService>();

  // State
  int _currentStep = 0; // 0: Class List, 1: Subject List, 2: Grade Book

  // Data Lists
  List<dynamic> _classList = [];
  List<dynamic> _subjectList = [];
  List<dynamic> _todaySchedules = [];
  Map<String, String> _dayIdMap = {};
  String _currentDayIndo = '';

  // Selected Data
  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedSubject;

  // Filtering & Pagination
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool get _canEdit {
    final role = widget.teacher['role']?.toString().toLowerCase() ?? '';
    bool canEditRole = role == 'guru' || role == 'teacher';

    // If viewing a subject, check if we have edit permission for it
    if (canEditRole &&
        _selectedSubject != null &&
        _selectedSubject!.containsKey('can_edit')) {
      return _selectedSubject!['can_edit'] == true;
    }

    return canEditRole;
  }

  // Pagination State
  int _currentPage = 1;
  final int _perPage = 20;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  /// Like Vue's `mounted()` lifecycle hook. Sets up scroll/search listeners
  /// and loads initial data. Uses `addPostFrameCallback` to ensure the widget
  /// tree is built before accessing `context` (needed for Provider).
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadTodaySchedules();
      _loadClasses();
    });
  }

  /// Like Vue's `beforeUnmount()` -- disposes controllers to prevent memory leaks.
  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Infinite scroll handler -- triggers loading more items when near bottom.
  /// Like a Vue Intersection Observer or `@scroll` handler.
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && !_isLoading) {
        if (_currentStep == 0) {
          _loadMoreClasses();
        } else if (_currentStep == 1) {
          _loadMoreSubjects();
        }
      }
    }
  }

  void _onSearchChanged() {
    // Manual search triggered by button/enter
  }

  /// Executes search -- resets to page 1 and reloads data.
  /// Like a Vue `methods.handleSearch()` triggered by a search button.
  void _handleSearch() {
    setState(() {
      _currentPage = 1;
    });
    if (_currentStep == 0) {
      _loadClasses();
    } else if (_currentStep == 1) {
      setState(() {}); // Local filtering
    }
  }

  // ==================== CACHE KEYS ====================

  String? _buildClassCacheKey() {
    if (_currentPage != 1) return null;
    if (_searchController.text.trim().isNotEmpty) return null;

    final academicYearProvider = ref.read(academicYearRiverpod);
    final yearId = academicYearProvider.selectedAcademicYear?['id']?.toString() ?? 'default';
    final teacherId = widget.teacher['id']?.toString() ?? 'unknown';
    return 'grade_classes_${teacherId}_$yearId';
  }

  String? _buildSubjectCacheKey() {
    if (_selectedClass == null) return null;

    final academicYearProvider = ref.read(academicYearRiverpod);
    final yearId = academicYearProvider.selectedAcademicYear?['id']?.toString() ?? 'default';
    final teacherId = widget.teacher['id']?.toString() ?? 'unknown';
    final classId = _selectedClass!['id']?.toString() ?? 'unknown';
    return 'grade_subjects_${teacherId}_${classId}_$yearId';
  }

  // ==================== LOAD LOGIC ====================

  /// Fetches the list of classes the teacher can grade.
  /// Uses cache-first strategy via LocalCacheService/TeacherProvider.
  /// Like a Vue `methods.fetchClasses()` calling `axios.get('/api/classes')`.
  Future<void> _loadClasses({bool resetPage = true, bool useCache = true}) async {
    final role = widget.teacher['role']?.toString().toLowerCase() ?? '';
    final isGuru = _canEdit && role.contains('guru');

    if (resetPage) {
      _currentPage = 1;
      _hasMoreData = true;

      // ─── Step 1: Try TeacherProvider (populated by Dashboard) ───
      if (isGuru && useCache) {
        final teacherProvider = ref.read(teacherRiverpod);
        if (teacherProvider.isLoaded && teacherProvider.allClasses.isNotEmpty) {
          List<dynamic> providerClasses = List.from(teacherProvider.allClasses);
          _sortClassesByTodaySchedule(providerClasses);
          setState(() {
            _classList = providerClasses;
            _hasMoreData = false;
            _isLoading = false;
          });
          AppLogger.debug('grades', 'Grade classes from TeacherProvider (${providerClasses.length})');
          return; // ✅ Provider hit — no API needed
        }
      }

      // ─── Step 2: Try loading from cache → return early ───
      if (useCache) {
        final cacheKey = _buildClassCacheKey();
        if (cacheKey != null) {
          try {
            final cached = await LocalCacheService.load(
              cacheKey,
              ttl: const Duration(hours: 3),
            );
            if (cached != null && mounted) {
              final cachedData = Map<String, dynamic>.from(cached);
              final cachedClasses = List<dynamic>.from(cachedData['classes'] ?? []);
              if (cachedClasses.isNotEmpty) {
                setState(() {
                  _classList = cachedClasses;
                  _hasMoreData = cachedData['hasMoreData'] ?? false;
                  _isLoading = false;
                });
                AppLogger.info('grades', 'Grade classes loaded from cache');
                return; // ✅ Cache hit — no API needed
              }
            }
          } catch (e) {
            AppLogger.error('grades', e);
          }
        }
      }

      // Show skeleton only if no data yet
      if (_classList.isEmpty && mounted) {
        setState(() {
          _isLoading = true;
        });
      }
    }

    // ─── Step 3: No cache — fetch fresh from API ───
    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      List<dynamic> loadedClasses = [];

      if (isGuru) {
        final response = await getIt<ApiTeacherService>().getTeacherClasses(
          widget.teacher['id'],
          academicYearId: academicYearId,
        );
        loadedClasses = response;
        _hasMoreData = false;
      } else {
        // Admin: Load ALL classes
        final response = await getIt<ApiClassService>().getClassPaginated(
          page: _currentPage,
          limit: _perPage,
          academicYearId: academicYearId,
          search: _searchController.text,
        );
        loadedClasses = response['data'] ?? [];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
      }

      // Sort: Today's classes first
      _sortClassesByTodaySchedule(loadedClasses);

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

      // ─── Step 4: Save to cache ───
      if (resetPage) {
        final cacheKey = _buildClassCacheKey();
        if (cacheKey != null) {
          LocalCacheService.save(cacheKey, {
            'classes': loadedClasses,
            'hasMoreData': _hasMoreData,
          });
        }
      }
    } catch (e) {
      AppLogger.error('grades', e);
      if (mounted) {
        if (_classList.isEmpty) {
          setState(() => _isLoading = false);
        }
        _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  /// Sort classes so today's scheduled classes appear first
  void _sortClassesByTodaySchedule(List<dynamic> classes) {
    final role = widget.teacher['role']?.toString().toLowerCase() ?? '';
    if (role.contains('guru') && _todaySchedules.isNotEmpty) {
      final todayClassIds = _todaySchedules
          .map((s) => (s['class_id'] ?? s['kelas_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      classes.sort((a, b) {
        final idA = a['id'].toString();
        final idB = b['id'].toString();
        final isTodayA = todayClassIds.contains(idA);
        final isTodayB = todayClassIds.contains(idB);

        if (isTodayA && !isTodayB) return -1;
        if (!isTodayA && isTodayB) return 1;
        return 0;
      });
    }
  }

  Future<void> _loadMoreClasses() async {
    if (widget.teacher['role'] == 'guru') return;
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _loadClasses(resetPage: false);
    setState(() => _isLoadingMore = false);
  }

  /// Fetches subjects available for the selected class.
  /// Like calling `axios.get('/api/subjects?classId=...')` in Vue.
  Future<void> _loadSubjects({bool useCache = true}) async {
    // ─── Step 1: Try loading from cache → return early ───
    if (useCache) {
      final cacheKey = _buildSubjectCacheKey();
      if (cacheKey != null) {
        try {
          final cached = await LocalCacheService.load(
            cacheKey,
            ttl: const Duration(hours: 3),
          );
          if (cached != null && mounted) {
            final cachedData = Map<String, dynamic>.from(cached);
            final cachedSubjects = List<dynamic>.from(cachedData['subjects'] ?? []);
            if (cachedSubjects.isNotEmpty) {
              setState(() {
                _subjectList = cachedSubjects;
                _isLoading = false;
              });
              AppLogger.info('grades', 'Grade subjects loaded from cache — skipping API');
              return; // ✅ Cache hit — no API needed
            }
          }
        } catch (e) {
          AppLogger.error('grades', e);
        }
      }
    }

    // Show skeleton only if no data yet
    if (_subjectList.isEmpty && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    // ─── Step 2: No cache — fetch fresh from API ───
    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      List<dynamic> subjects = [];

      final isHomeroom = _selectedClass?['is_homeroom'] == true;
      final role = widget.teacher['role']?.toString().toLowerCase() ?? '';
      final isGuru = role.contains('guru') || role.contains('teacher');
      final isAdmin =
          !isGuru; // Assuming non-guru is admin/staff with higher privs

      // 1. Fetch subjects taught by THIS teacher in this class
      final mySchedules = await getIt<ApiScheduleService>().getSchedulesPaginated(
        limit: 100,
        teacherId: widget.teacher['id'],
        classId: _selectedClass!['id'].toString(),
        tahunAjaran: academicYearId,
      );
      final myData = mySchedules['data'] ?? [];
      final mySubjectIds = <String>{};
      for (var item in myData) {
        final subject = item['subject'] ?? item['mata_pelajaran'];
        if (subject != null) {
          mySubjectIds.add(subject['id'].toString());
        }
      }

      if (isHomeroom || isAdmin) {
        // 2. Homeroom or Admin: Get ALL subjects assigned to this class
        final response = await dioClient.get(
          '/class/${_selectedClass!['id']}/subjects',
        );

        final allSubjects = response.data is List ? response.data as List : [];
        final uniqueSubjects = <String, Map<String, dynamic>>{};

        for (var subject in allSubjects) {
          final subjectId = subject['id'].toString();
          var s = Map<String, dynamic>.from(subject);
          // Editable if Admin OR if I teach it
          s['can_edit'] = isAdmin || mySubjectIds.contains(subjectId);
          uniqueSubjects[subjectId] = s;
        }
        subjects = uniqueSubjects.values.toList();
      } else {
        // 3. Regular Teacher (Non-Homeroom): Only SHOW what I teach
        final uniqueSubjects = <String, Map<String, dynamic>>{};
        for (var item in myData) {
          final subject = item['subject'] ?? item['mata_pelajaran'];
          if (subject != null) {
            final subjectId = subject['id'].toString();
            var s = Map<String, dynamic>.from(subject);
            s['can_edit'] = true;
            uniqueSubjects[subjectId] = s;
          }
        }
        subjects = uniqueSubjects.values.toList();
      }

      // Sort subjects: Today's subjects for THIS teacher and THIS class first
      if (_todaySchedules.isNotEmpty && _selectedClass != null) {
        final selectedClassId = _selectedClass!['id'].toString();
        final todaySubjectIds = _todaySchedules
            .where(
              (s) =>
                  (s['class_id'] ?? s['kelas_id'] ?? '').toString() ==
                  selectedClassId,
            )
            .map(
              (s) =>
                  (s['subject_id'] ?? s['mata_pelajaran_id'] ?? '').toString(),
            )
            .where((id) => id.isNotEmpty)
            .toSet();

        subjects.sort((a, b) {
          final idA = a['id'].toString();
          final idB = b['id'].toString();
          final isTodayA = todaySubjectIds.contains(idA);
          final isTodayB = todaySubjectIds.contains(idB);

          if (isTodayA && !isTodayB) return -1;
          if (!isTodayA && isTodayB) return 1;
          return 0;
        });
      }

      if (mounted) {
        setState(() {
          _subjectList = subjects;
          _isLoading = false;
        });
      }

      // ─── Step 3: Save to cache ───
      final cacheKey = _buildSubjectCacheKey();
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'subjects': subjects,
        });
      }
    } catch (e) {
      AppLogger.error('grades', e);
      if (mounted) {
        if (_subjectList.isEmpty) {
          setState(() => _isLoading = false);
        }
        _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _loadMoreSubjects() async {}

  // ==================== PRIORITY LOGIC ====================

  /// Loads today's teaching schedule to highlight currently scheduled classes.
  /// Like a Vue `mounted()` helper that fetches schedule context data.
  Future<void> _loadTodaySchedules() async {
    try {
      // 1. Load Days — try cache first (shared with teaching_schedule)
      List<dynamic> days = [];
      try {
        final cachedDays = await LocalCacheService.load('school_day_data', ttl: const Duration(hours: 24));
        if (cachedDays != null) {
          days = List<dynamic>.from(cachedDays);
          AppLogger.debug('grades', 'Grade: days from cache');
        }
      } catch (_) {}
      if (days.isEmpty) {
        days = await getIt<ApiScheduleService>().getHari();
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
      final currentDayIndo = _normalizeDayName(currentDayISO);

      String? currentDayId;
      dayIdMap.forEach((key, value) {
        if (_normalizeDayName(key) == currentDayIndo) {
          currentDayId = value;
        }
      });

      // 3. Load Teacher Schedules — try teaching_schedule's cache first
      final academicYearProvider = ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']?.toString();
      final semesterProvider = academicYearProvider.selectedAcademicYear;
      final semester = semesterProvider?['semester']?.toString() ?? '1';
      final teacherId = widget.teacher['id']?.toString() ?? '';

      List<dynamic> allSchedules = [];

      // Try teaching_schedule's cached data
      final scheduleCacheKey = 'schedule_teacher_${teacherId}_${semester}_$academicYearId';
      try {
        final cached = await LocalCacheService.load(scheduleCacheKey, ttl: const Duration(hours: 3));
        if (cached != null) {
          final cachedData = Map<String, dynamic>.from(cached);
          allSchedules = List<dynamic>.from(cachedData['jadwal'] ?? []);
          AppLogger.debug('grades', 'Grade: schedules from teaching_schedule cache (${allSchedules.length})');
        }
      } catch (_) {}

      // Fallback to API
      if (allSchedules.isEmpty) {
        final schedules = await getIt<ApiScheduleService>().getSchedulesPaginated(
          limit: 100,
          teacherId: widget.teacher['id'],
          tahunAjaran: academicYearId,
        );
        allSchedules = schedules['data'] ?? [];
      }

      if (mounted) {
        setState(() {
          _dayIdMap = dayIdMap;
          _currentDayIndo = currentDayIndo;
          _todaySchedules = allSchedules.where((s) {
            final ids = _extractDayIds(s);
            // Tier 1: Match by ID
            if (currentDayId != null && ids.contains(currentDayId)) return true;
            // Tier 2: Match by Name mapping
            return ids.any((id) {
              final entry = _dayIdMap.entries.firstWhere(
                (e) => e.value == id,
                orElse: () => const MapEntry('', ''),
              );
              return entry.key.isNotEmpty &&
                  _normalizeDayName(entry.key) == currentDayIndo;
            });
          }).toList();
        });
      }
    } catch (e) {
      AppLogger.error('grades', e);
    }
  }

  String _normalizeDayName(String name) {
    name = name.trim().toLowerCase();
    if (name.contains('senin') || name.contains('monday')) return 'Senin';
    if (name.contains('selasa') || name.contains('tuesday')) return 'Selasa';
    if (name.contains('rabu') || name.contains('wednesday')) return 'Rabu';
    if (name.contains('kamis') || name.contains('thursday')) return 'Kamis';
    if (name.contains('jumat') || name.contains('friday')) return 'Jumat';
    if (name.contains('sabtu') || name.contains('saturday')) return 'Sabtu';
    if (name.contains('minggu') || name.contains('sunday')) return 'Minggu';
    return name;
  }

  List<String> _extractDayIds(dynamic schedule) {
    if (schedule == null) return [];
    final rawIds = schedule['days_ids'] ?? schedule['day_id'];
    if (rawIds == null) return [];

    if (rawIds is List) {
      return rawIds.map((e) => e.toString()).toList();
    }
    if (rawIds is String) {
      if (rawIds.contains('[')) {
        try {
          final parsed = json.decode(rawIds);
          if (parsed is List) return parsed.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return rawIds
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [rawIds.toString()];
  }

  // ==================== HELPER METHODS ====================

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
    );
  }

  // ==================== BUILDERS ====================

  Widget _buildInfoTag(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: ColorUtils.slate600),
          SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: ColorUtils.slate700,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Builds the class list UI (Step 0). Like a Vue `<ClassList>` component
  /// rendered with `v-if="currentStep === 0"`.
  Widget _buildStep0ClassList(LanguageProvider languageProvider) {
    // Filter locally if needed
    final searchTerm = _searchController.text.toLowerCase();
    final filtered = _classList.where((item) {
      final name = (item['nama'] ?? item['name'] ?? '')
          .toString()
          .toLowerCase();
      final level = (item['grade_level'] ?? item['tingkat'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(searchTerm) || level.contains(searchTerm);
    }).toList();

    if (_isLoading) {
      return SkeletonListLoading(padding: EdgeInsets.only(top: 8, bottom: 80));
    }

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.class_outlined,
        title: languageProvider.getTranslatedText({
          'en': 'No Classes Found',
          'id': 'Tidak Ada Kelas',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': 'Try adjusting your search filters',
          'id': 'Coba sesuaikan filter pencarian anda',
        }),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadClasses(),
      child: ListView.builder(
        padding: EdgeInsets.only(top: 8, bottom: 80),
        itemCount: filtered.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filtered.length) {
            return Container(
              padding: EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_getPrimaryColor()),
              ),
            );
          }
          final classData = filtered[index];
          final isHomeroom = classData['is_homeroom'] == true;
          final accentColor = isHomeroom
              ? ColorUtils.primary
              : _getPrimaryColor();
          final isToday = _todaySchedules.any(
            (s) =>
                (s['class_id'] ?? s['kelas_id'] ?? '').toString() ==
                classData['id'].toString(),
          );
          final gradeLevel = classData['grade_level'] ?? classData['tingkat'];
          final homeroomTeacher = classData['homeroom_teacher_name'];

          return Container(
            margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedClass = classData;
                    _currentStep = 1;
                    _searchController.clear();
                  });
                  _loadSubjects();
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ColorUtils.slate200, width: 1),
                    boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Icon(
                          isHomeroom
                              ? Icons.home_work_outlined
                              : Icons.class_outlined,
                          color: accentColor,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              classData['nama'] ?? classData['name'] ?? '-',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ColorUtils.slate900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                if (gradeLevel != null &&
                                    gradeLevel.toString().isNotEmpty)
                                  _buildInfoTag(
                                    Icons.school_outlined,
                                    gradeLevel.toString(),
                                  ),
                                if (isHomeroom)
                                  _buildInfoTag(
                                    Icons.home_outlined,
                                    'Wali Kelas',
                                  ),
                                if (homeroomTeacher != null)
                                  _buildInfoTag(
                                    Icons.person_outlined,
                                    homeroomTeacher.toString(),
                                  ),
                                if (isToday)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ColorUtils.success600.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: ColorUtils.success600.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.today,
                                          size: 11,
                                          color: ColorUtils.success600,
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          'Today',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: ColorUtils.success600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: ColorUtils.slate400,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds the subject list UI (Step 1). Like a Vue `<SubjectList>` component
  /// rendered with `v-if="currentStep === 1"`.
  Widget _buildStep1SubjectList(LanguageProvider languageProvider) {
    final searchTerm = _searchController.text.toLowerCase();
    final filtered = _subjectList.where((item) {
      final name = (item['nama'] ?? item['name'] ?? '')
          .toString()
          .toLowerCase();
      final code = (item['kode'] ?? item['code'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(searchTerm) || code.contains(searchTerm);
    }).toList();

    if (_isLoading) {
      return SkeletonListLoading(padding: EdgeInsets.only(top: 8, bottom: 80));
    }

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.menu_book_outlined,
        title: languageProvider.getTranslatedText({
          'en': 'No Subjects Found',
          'id': 'Tidak Ada Mata Pelajaran',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': 'No subjects found for this class',
          'id': 'Tidak ada mata pelajaran untuk kelas ini',
        }),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadSubjects(),
      child: ListView.builder(
        padding: EdgeInsets.only(top: 8, bottom: 80),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final subject = filtered[index];
          final subjectCode = subject['kode'] ?? subject['code'];
          final canEdit = subject['can_edit'] != false;
          final isToday = _todaySchedules.any(
            (s) =>
                (s['class_id'] ?? s['kelas_id'] ?? '').toString() ==
                    _selectedClass!['id'].toString() &&
                (s['subject_id'] ?? s['mata_pelajaran_id'] ?? '').toString() ==
                    subject['id'].toString(),
          );
          final accentColor = ColorUtils.warning600;

          return Container(
            margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedSubject = subject;
                    _currentStep = 2;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ColorUtils.slate200, width: 1),
                    boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Icon(
                          Icons.book_outlined,
                          color: accentColor,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject['nama'] ?? subject['name'] ?? '-',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ColorUtils.slate900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                if (subjectCode != null &&
                                    subjectCode.toString().isNotEmpty)
                                  _buildInfoTag(
                                    Icons.tag,
                                    subjectCode.toString(),
                                  ),
                                if (isToday)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ColorUtils.success600.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: ColorUtils.success600.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.today,
                                          size: 11,
                                          color: ColorUtils.success600,
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          'Today',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: ColorUtils.success600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (!canEdit)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ColorUtils.warning600.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: ColorUtils.warning600.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.lock_outline,
                                          size: 11,
                                          color: ColorUtils.warning600,
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          languageProvider.getTranslatedText({
                                            'en': 'Read Only',
                                            'id': 'Hanya Lihat',
                                          }),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: ColorUtils.warning600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: ColorUtils.slate400,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _handleWillPop() async {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        if (_currentStep == 0) {
          _selectedClass = null;
          _selectedSubject = null;
          _searchController.clear();
        } else if (_currentStep == 1) {
          _selectedSubject = null;
        }
      });
      return false;
    }
    return true;
  }

  Widget _buildHeader(BuildContext context, LanguageProvider languageProvider) {
    String title = '';
    String subtitle = '';

    if (_currentStep == 0) {
      title = languageProvider.getTranslatedText({
        'en': 'Input Grades',
        'id': 'Input Nilai',
      });
      subtitle = languageProvider.getTranslatedText({
        'en': 'Select Class',
        'id': 'Pilih Kelas',
      });
    } else if (_currentStep == 1) {
      title = _selectedClass?['nama'] ?? _selectedClass?['name'] ?? 'Class';
      subtitle = languageProvider.getTranslatedText({
        'en': 'Select Subject',
        'id': 'Pilih Mata Pelajaran',
      });
    } else {
      return SizedBox.shrink();
    }

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
                onTap: () async {
                  final shouldPop = await _handleWillPop();
                  if (shouldPop && mounted) Navigator.pop(context);
                },
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
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_currentDayIndo.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Jadwal Hari Ini: $_currentDayIndo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          // Search Bar matched to StudentManagement
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: _currentStep == 0
                          ? languageProvider.getTranslatedText({
                              'en': 'Search class...',
                              'id': 'Cari kelas...',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'Search subject...',
                              'id': 'Cari mata pelajaran...',
                            }),
                      hintStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _handleSearch(),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(right: 4),
                  child: IconButton(
                    icon: Icon(Icons.search, color: _getPrimaryColor()),
                    onPressed: _handleSearch,
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
        // If Step 2, we show GradeBookPage which handles its own scaffold/body
        if (_currentStep == 2) {
          return WillPopScope(
            onWillPop: _handleWillPop,
            child: GradeBookPage(
              teacher: widget.teacher,
              subject: _selectedSubject!,
              classData: _selectedClass!,
              onBack: () {
                setState(() {
                  _currentStep = 1;
                  _selectedSubject = null;
                });
              },
            ),
          );
        }

        return WillPopScope(
          onWillPop: _handleWillPop,
          child: Scaffold(
            backgroundColor: ColorUtils.slate50,
            body: Column(
              children: [
                _buildHeader(context, languageProvider),

                // Search Bar has been moved to Header
                Expanded(
                  child: _currentStep == 0
                      ? _buildStep0ClassList(languageProvider)
                      : _buildStep1SubjectList(languageProvider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
