// Teacher presence (attendance) management screen.
// Like `pages/teacher/Attendance.vue` in a Vue app.
//
// The largest screen in the app (~5600 lines). Provides two modes via tabs:
// 1. "Results" mode -- view attendance summaries with search/filter
// 2. "Input" mode -- take attendance for a class/subject/date
//
// Supports auto-detection of current lesson hour, class-based filtering,
// bulk status setting, and multi-layer caching. In Laravel terms, this
// combines AttendanceController@index, @store, and @summary.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/widgets/tab_switcher.dart';
import 'package:manajemensekolah/core/models/student.dart';
import 'package:manajemensekolah/features/schedule/services/schedule_service.dart';
import 'package:manajemensekolah/features/students/services/student_service.dart';
import 'package:manajemensekolah/features/teachers/services/teacher_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/attendance/screens/teacher_attendance_detail.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Data model for an attendance summary row.
/// Like a Laravel Eloquent Model or a TypeScript interface -- a plain data class
/// that holds computed attendance counts for a subject on a specific date.
// Model for Attendance Summary
class AttendanceSummaryItem {
  final String subjectId;
  final String subjectName;
  final DateTime date;
  final int totalStudent;
  final int present;
  final int absent;
  final String? classId;
  final String? className;
  final String? lessonHourId;
  final String? lessonHourName;

  AttendanceSummaryItem({
    required this.subjectId,
    required this.subjectName,
    required this.date,
    required this.totalStudent,
    required this.present,
    required this.absent,
    this.classId,
    this.className,
    this.lessonHourId,
    this.lessonHourName,
  });

  String get key =>
      '$subjectId-${DateFormat('yyyy-MM-dd').format(date)}-$classId-$lessonHourId';
}

/// Teacher attendance management page with two modes: view results and input.
///
/// This is a StatefulWidget with complex local state. Props (like Vue props):
/// - [teacher] -- current teacher info
/// - [initialDate] / [initialSubjectId] / etc. -- optional deep-link params
class PresencePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  final DateTime? initialDate;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final String? initialclassId;
  final String? initialClassName;
  final int? initialLessonHourNumber;
  final String? initialStartTime;
  final int initialTabIndex;

  const PresencePage({
    super.key,
    required this.teacher,
    this.initialDate,
    this.initialSubjectId,
    this.initialSubjectName,
    this.initialclassId,
    this.initialClassName,
    this.initialLessonHourNumber,
    this.initialStartTime,
    this.initialTabIndex = 0,
  });

  @override
  PresencePageState createState() => PresencePageState();
}

/// State for [PresencePage].
///
/// Like a Vue page component with `data() { return {...} }`.
/// Uses `TickerProviderStateMixin` for the tab animation controller.
///
/// Key state variables:
/// - Tab 0 ("Results"): [_attendanceSummaryList], filters, search
/// - Tab 1 ("Input"): [_studentList], [_attendanceStatus] map, selected date/subject/class
/// - [_lessonHours] / [_selectedLessonHourId] -- lesson period selection
/// - Various filter states for both modes
///
/// `setState()` is like Vue's reactivity -- triggers a re-render when data changes.
class PresencePageState extends ConsumerState<PresencePage>
    with TickerProviderStateMixin {
  // Tab Controller for TabSwitcher
  late TabController _tabController;

  // Data for View Results mode
  List<AttendanceSummaryItem> _attendanceSummaryList = [];
  bool _isLoadingSummary = false;

  // Data for Attendance Input mode
  DateTime _selectedDate = DateTime.now();
  String? _selectedSubjectId;
  String? _selectedClassId;
  List<dynamic> _subjectTeacher = [];
  List<dynamic> _classList = [];
  List<Student> _studentList = [];
  List<Student> _filteredStudentList = [];
  final Map<String, String> _attendanceStatus = {};
  bool _isLoadingInput = true;
  bool _isSubmitting = false;
  bool _hasActiveFilter = false;
  bool _showSearch = false;

  // Lesson Hour State
  List<dynamic> _lessonHours = [];
  String? _selectedLessonHourId;

  // Filter for Results Mode
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDateFilter;
  List<String> _selectedSubjectIds = [];
  List<String> _selectedDayIds = [];
  List<String> _selectedLessonHourIds = [];

  // Filter for Input Mode
  final TextEditingController _searchControllerInput = TextEditingController();
  String? _selectedStatusFilter;

  // Tour properties
  final GlobalKey _searchFilterKey = GlobalKey();
  final GlobalKey _tabSwitcherKey = GlobalKey();

  /// Like Vue's `mounted()` lifecycle hook. Sets up tab controller, applies
  /// initial params (deep linking), and loads all initial data (subjects,
  /// classes, schedules, lesson hours). The multi-step initialization
  /// detects the current schedule to auto-select subject/class.
  @override
  void initState() {
    super.initState();

    // Initialize with data from teaching_schedule if provided
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
    if (widget.initialSubjectId != null) {
      _selectedSubjectId = widget.initialSubjectId;
    }
    if (widget.initialclassId != null) {
      _selectedClassId = widget.initialclassId;
    }

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      // TabController listener fires twice (animation start + end).
      // Only react once — after the animation settles.
      if (_tabController.indexIsChanging) return;
      if (!mounted) return;
      setState(() {
        // Trigger rebuild when tab changes
        if (_tabController.index == 0) {
          _loadAttendanceSummary();
        }
      });
    });

    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchControllerInput.dispose();
    super.dispose();
  }

  String? _buildPresenceCacheKey() {
    final teacherId = widget.teacher['id']?.toString() ?? '';
    if (teacherId.isEmpty) return null;
    final academicYearId = ref.read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
    return 'presence_initial_${teacherId}_$academicYearId';
  }

  String? _buildSummaryCacheKey() {
    final teacherId = widget.teacher['id']?.toString() ?? '';
    if (teacherId.isEmpty) return null;
    final academicYearId = ref.read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
    return 'presence_summary_${teacherId}_$academicYearId';
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('presence_');
    setState(() {
      _isLoadingInput = true;
      _isLoadingSummary = true;
    });
    _loadInitialData(useCache: false);
  }

  /// Load a single data source with cache-first pattern.
  /// Returns cached data if available, otherwise fetches from API and saves to cache.
  Future<List<dynamic>> _loadWithCache({
    required String cacheKey,
    required Duration ttl,
    required Future<List<dynamic>> Function() apiFetcher,
    bool useCache = true,
  }) async {
    // Try cache first
    if (useCache) {
      try {
        final cached = await LocalCacheService.load(cacheKey, ttl: ttl);
        if (cached != null) {
          AppLogger.debug('attendance', 'Cache hit: $cacheKey');
          return List<dynamic>.from(cached);
        }
      } catch (e) {
        AppLogger.error('attendance', 'Cache load error ($cacheKey): $e');
      }
    }

    // Fetch from API
    final data = await apiFetcher();
    if (data.isNotEmpty) {
      LocalCacheService.save(cacheKey, data);
    }
    return data;
  }

  /// Loads all initial data: subjects, classes, students, and optionally
  /// detects the current lesson schedule. Like a Vue `mounted()` that
  /// calls multiple `axios.get()` in sequence.
  Future<void> _loadInitialData({bool useCache = true}) async {
    try {
      final academicYearId = ref.read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      final cacheKey = _buildPresenceCacheKey();
      final teacherId = widget.teacher['id']?.toString() ?? '';

      // ─── Step 1: Try TeacherProvider for classList (populated by Dashboard) ───
      final teacherProvider = ref.read(teacherRiverpod);

      List<dynamic>? providerClassList;
      if (teacherProvider.isLoaded && teacherProvider.allClasses.isNotEmpty) {
        providerClassList = teacherProvider.allClasses;
        AppLogger.debug('attendance', 'Using TeacherProvider classList (${providerClassList.length} classes)');
      }

      // Step 2: Try composite local cache for instant display
      if (useCache && _classList.isEmpty && cacheKey != null) {
        try {
          final cached = await LocalCacheService.load(cacheKey, ttl: const Duration(hours: 3));
          if (cached != null && mounted) {
            final cachedData = Map<String, dynamic>.from(cached);
            setState(() {
              _classList = List<dynamic>.from(cachedData['classList'] ?? []);
              _subjectTeacher = List<dynamic>.from(cachedData['subjects'] ?? []);
              _lessonHours = List<dynamic>.from(cachedData['lessonHours'] ?? []);
              final studentRaw = List<dynamic>.from(cachedData['studentList'] ?? []);
              _studentList = studentRaw.map((s) => Student.fromJson(Map<String, dynamic>.from(s))).toList();
              _filteredStudentList = _studentList;
              for (var student in _studentList) {
                _attendanceStatus[student.id] = 'hadir';
              }
              if (_classList.isNotEmpty) _isLoadingInput = false;
            });
            AppLogger.info('attendance', 'Loaded presence composite cache');
          }
        } catch (e) {
          AppLogger.error('attendance', 'Presence cache load error: $e');
        }
      }

      // If provider has classes, use them immediately for display
      if (_classList.isEmpty && providerClassList != null && mounted) {
        setState(() {
          _classList = providerClassList!;
          if (_classList.isNotEmpty) _isLoadingInput = false;
        });
      }

      // Step 3: Show loading only if still empty
      if (_classList.isEmpty && mounted) {
        setState(() => _isLoadingInput = true);
      }

      // Step 4: Fetch data — each source uses its own cache
      final classListFuture = providerClassList != null
          ? Future.value(providerClassList)
          : _loadWithCache(
              cacheKey: 'presence_classes_${teacherId}_$academicYearId',
              ttl: const Duration(hours: 6),
              apiFetcher: () => getIt<ApiTeacherService>().getTeacherClasses(
                teacherId,
                academicYearId: academicYearId,
              ),
              useCache: useCache,
            );

      final studentFuture = _loadWithCache(
        cacheKey: 'school_student_data_$academicYearId',
        ttl: const Duration(hours: 6),
        apiFetcher: () => getIt<ApiStudentService>().getStudent(academicYearId: academicYearId),
        useCache: useCache,
      );

      final lessonHourFuture = _loadWithCache(
        cacheKey: 'school_lesson_hour_data',
        ttl: const Duration(hours: 24),
        apiFetcher: () => getIt<ApiScheduleService>().getJamPelajaran(),
        useCache: useCache,
      );

      final subjectFuture = _loadWithCache(
        cacheKey: 'presence_subjects_${teacherId}_${_selectedClassId ?? 'all'}',
        ttl: const Duration(hours: 3),
        apiFetcher: () => _getSubjectByTeacher(teacherId, classId: _selectedClassId),
        useCache: useCache,
      );

      final [classList, studentList, lessonHours, subjects] = await Future.wait([
        classListFuture,
        studentFuture,
        lessonHourFuture,
        subjectFuture,
      ]);

      if (!mounted) return;

      setState(() {
        _subjectTeacher = subjects;
        _classList = classList;
        _studentList = studentList.map((s) => Student.fromJson(s)).toList();
        // Deduplicate lesson hours (API returns per-day, causing repeats)
        final seen = <String>{};
        _lessonHours = lessonHours.where((lh) {
          final key = '${lh['hour_number'] ?? lh['name']}_${lh['start_time']}_${lh['end_time']}';
          return seen.add(key);
        }).toList();
        _filteredStudentList = _studentList;

        for (var student in _studentList) {
          _attendanceStatus[student.id] = 'hadir';
        }

        _isLoadingInput = false;
      });

      // Save composite cache for early loading next time
      if (cacheKey != null) {
        await LocalCacheService.save(cacheKey, {
          'classList': classList,
          'subjects': subjects,
          'lessonHours': lessonHours,
          'studentList': studentList,
        });
      }

      // Auto-detect current schedule if not initialized from teaching_schedule
      if (widget.initialSubjectId == null) {
        await _detectCurrentSchedule();
      }

      _detectCurrentLessonHour();

      // Load summary data for view mode
      _loadAttendanceSummary();
    } catch (e) {
      AppLogger.error('attendance', 'PresencePage initial data error: $e');
      if (!mounted) return;

      // Only show error if no cached data
      if (_classList.isEmpty) {
                SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _checkAndShowTour();
          }
        });
      }
    }
  }

  Future<List<dynamic>> _getSubjectByTeacher(
    String teacherId, {
    String? classId,
  }) async {
    try {
      final result = await getIt<ApiTeacherService>().getSubjectByTeacher(
        teacherId,
        classId: classId,
      );
      return result;
    } catch (e) {
      AppLogger.error('attendance', 'Error getting mata pelajaran by guru: $e');
      return [];
    }
  }

  Future<void> _loadSubjectsByClass(String? classId) async {
    setState(() {
      _isLoadingInput = true;
    });

    try {
      final result = await _getSubjectByTeacher(
        widget.teacher['id'],
        classId: classId,
      );

      setState(() {
        _subjectTeacher = result;
        _isLoadingInput = false;

        // Reset subject selection if it's no longer in the list
        if (_selectedSubjectId != null &&
            !_subjectTeacher.any((s) => s['id'] == _selectedSubjectId)) {
          _selectedSubjectId = null;
        }
      });
    } catch (e) {
      AppLogger.error('attendance', 'Error loading subjects by class: $e');
      setState(() {
        _isLoadingInput = false;
      });
    }
  }

  // Get current academic year
  String _getCurrentAcademicYear() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;
    if (currentMonth >= 7) {
      return '$currentYear/${currentYear + 1}';
    } else {
      return '${currentYear - 1}/$currentYear';
    }
  }

  // Get current semester
  String _getCurrentSemester() {
    final now = DateTime.now();
    final currentMonth = now.month;
    if (currentMonth >= 7) {
      return '1';
    } else {
      return '2';
    }
  }

  // Get current day ID (1=Senin, 2=Selasa, etc.)
  String _getCurrentDayId() {
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Monday, 7=Sunday
    return weekday.toString();
  }

  // Check if current time is within schedule time
  bool _isWithinScheduleTime(String jamMulai, String jamSelesai) {
    if (jamMulai.isEmpty || jamSelesai.isEmpty) return false;
    try {
      final now = TimeOfDay.now();
      final startParts = jamMulai.split(':');
      final endParts = jamSelesai.split(':');

      final start = TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1].split('.')[0]),
      );
      final end = TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1].split('.')[0]),
      );

      final nowMinutes = now.hour * 60 + now.minute;
      final startMinutes = start.hour * 60 + start.minute;
      final endMinutes = end.hour * 60 + end.minute;

      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    } catch (e) {
      AppLogger.error('attendance', 'Error parsing time: $e');
      return false;
    }
  }

  /// Auto-detects the current lesson hour based on the device time,
  /// or uses the initial lesson hour from schedule navigation.
  void _detectCurrentLessonHour() {
    if (_lessonHours.isEmpty) return;

    // Priority 1: Match by initialLessonHourNumber from schedule navigation
    if (widget.initialLessonHourNumber != null) {
      for (var lh in _lessonHours) {
        final hourNum = int.tryParse(lh['hour_number']?.toString() ?? '');
        if (hourNum == widget.initialLessonHourNumber) {
          setState(() => _selectedLessonHourId = lh['id']?.toString());
          return;
        }
      }
      // Fallback: match by start_time if hour_number didn't match
      if (widget.initialStartTime != null) {
        for (var lh in _lessonHours) {
          final lhStart = lh['start_time']?.toString() ?? '';
          if (lhStart.isNotEmpty && widget.initialStartTime!.startsWith(lhStart.split('.')[0])) {
            setState(() => _selectedLessonHourId = lh['id']?.toString());
            return;
          }
        }
      }
    }

    // Priority 2: Auto-detect based on current time
    for (var lh in _lessonHours) {
      final startTime = lh['start_time']?.toString() ?? '';
      final endTime = lh['end_time']?.toString() ?? '';

      if (_isWithinScheduleTime(startTime, endTime)) {
        setState(() {
          _selectedLessonHourId = lh['id']?.toString();
        });
        break;
      }
    }
  }

  // Load today's schedules and detect current one.
  // Uses cached schedule from teaching_schedule screen if available — NO extra API call.
  /// Auto-detects the current subject/class based on today's schedule and time.
  /// Like a smart default selector that pre-fills the form fields.
  Future<void> _detectCurrentSchedule() async {
    try {
      final teacherId = widget.teacher['id']?.toString() ?? '';
      final dayId = _getCurrentDayId();

      // ─── Try teaching_schedule's cached data first (already fetched by that screen) ───
      List<dynamic>? todaySchedules;

      // Search for any matching teaching_schedule cache
      final possibleCacheKeys = <String>[];
      // Teaching schedule caches with pattern: schedule_teacher_{id}_{semester}_{year}
      final semester = _getCurrentSemester();
      final academicYear = _getCurrentAcademicYear();
      possibleCacheKeys.add('schedule_teacher_${teacherId}_${semester}_$academicYear');

      for (final key in possibleCacheKeys) {
        try {
          final cached = await LocalCacheService.load(key, ttl: const Duration(hours: 3));
          if (cached != null) {
            final cachedData = Map<String, dynamic>.from(cached);
            final allSchedules = List<dynamic>.from(cachedData['jadwal'] ?? []);

            if (allSchedules.isNotEmpty) {
              // Filter locally by today's day ID
              todaySchedules = allSchedules.where((s) {
                final sDayId = (s['day_id'] ?? s['hari_id'] ?? '').toString();
                // Also check days_ids array
                final daysIds = s['days_ids'];
                if (sDayId == dayId) return true;
                if (daysIds is List) {
                  return daysIds.any((id) => id.toString() == dayId);
                }
                if (daysIds is String) {
                  return daysIds.contains(dayId);
                }
                return false;
              }).toList();

              AppLogger.debug('attendance', 'Detected today schedule from teaching_schedule cache (${todaySchedules.length} items)');
              break;
            }
          }
        } catch (e) {
          AppLogger.error('attendance', 'Cache read error ($key): $e');
        }
      }

      // ─── Fallback: fetch from API only if no cache available ───
      if (todaySchedules == null) {
        AppLogger.debug('attendance', 'No schedule cache, fetching from API');
        todaySchedules = await getIt<ApiScheduleService>().getSchedule(
          teacherId: teacherId,
          dayId: dayId,
          semesterId: semester,
          academicYear: academicYear,
        );
      }

      setState(() {
        if (todaySchedules != null && todaySchedules.isNotEmpty) {
          // Find current schedule based on time
          Map<String, dynamic>? currentSchedule;
          for (var schedule in todaySchedules) {
            final startTime = (schedule['jam_mulai'] ?? schedule['start_time'] ?? '').toString();
            final endTime = (schedule['jam_selesai'] ?? schedule['end_time'] ?? '').toString();

            if (_isWithinScheduleTime(startTime, endTime)) {
              currentSchedule = schedule;
              break;
            }
          }

          if (currentSchedule != null) {
            _selectedSubjectId = (currentSchedule['mata_pelajaran_id'] ?? currentSchedule['subject_id'])
                ?.toString();
            _selectedClassId = (currentSchedule['kelas_id'] ?? currentSchedule['class_id'])?.toString();
            _filterStudentsByClass(_selectedClassId);
          }
        }
      });
    } catch (e) {
      AppLogger.error('attendance', 'Error detecting current schedule: $e');
    }
  }

  /// Loads attendance summary data for the "Results" tab.
  /// Fetches all attendance records, groups them by subject+date+class,
  /// and calculates present/absent counts. Like a Laravel query with
  /// `groupBy()` and `count()` aggregation.
  Future<void> _loadAttendanceSummary({bool useCache = true}) async {
    if (!mounted) return;

    final summaryCacheKey = _buildSummaryCacheKey();

    // Step 1: Try cache for instant display
    if (useCache && _attendanceSummaryList.isEmpty && summaryCacheKey != null) {
      try {
        final cached = await LocalCacheService.load(summaryCacheKey, ttl: const Duration(hours: 1));
        if (cached != null && mounted) {
          final cachedList = List<dynamic>.from(cached);
          setState(() {
            _attendanceSummaryList = cachedList.map((item) {
              final m = Map<String, dynamic>.from(item);
              return AttendanceSummaryItem(
                subjectId: m['subjectId'] ?? '',
                subjectName: m['subjectName'] ?? '',
                date: DateTime.tryParse(m['date'] ?? '') ?? DateTime.now(),
                totalStudent: m['totalStudent'] ?? 0,
                present: m['present'] ?? 0,
                absent: m['absent'] ?? 0,
                classId: m['classId'],
                className: m['className'],
                lessonHourId: m['lessonHourId'],
                lessonHourName: m['lessonHourName'],
              );
            }).toList();
            _isLoadingSummary = false;
          });
          AppLogger.info('attendance', 'Loaded ${_attendanceSummaryList.length} summaries from cache');
        }
      } catch (e) {
        AppLogger.error('attendance', 'Summary cache load error: $e');
      }
    }

    // Step 2: Show loading only if still empty
    if (_attendanceSummaryList.isEmpty && mounted) {
      setState(() => _isLoadingSummary = true);
    }

    // Step 3: Fetch fresh from API
    try {
      final academicYearId = ref.read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      final attendanceData = await AttendanceService.getAttendanceSummary(
        teacherId: widget.teacher['id'],
        academicYearId: academicYearId,
      );

      final Map<String, AttendanceSummaryItem> summaryMap = {};

      for (var record in attendanceData) {
        final subjectId = (record['subject_id'] ?? '').toString();
        final subjectName = record['subject_name'] ?? 'Unknown';
        final className = record['class_name'] ?? 'Unknown';
        final classId = (record['class_id'] ?? '').toString();
        final lessonHourId = (record['lesson_hour_id'] ?? '').toString();
        final lessonHourName = record['lesson_hour_name'] ?? '';
        final dateStr = record['date']?.toString() ?? '';
        final date = _parseLocalDate(dateStr);

        final summary = AttendanceSummaryItem(
          subjectId: subjectId,
          subjectName: subjectName,
          date: date,
          totalStudent:
              int.tryParse(record['total_students']?.toString() ?? '0') ?? 0,
          present: int.tryParse(record['present']?.toString() ?? '0') ?? 0,
          absent: int.tryParse(record['absent']?.toString() ?? '0') ?? 0,
          classId: classId,
          className: className,
          lessonHourId: lessonHourId,
          lessonHourName: lessonHourName,
        );

        summaryMap[summary.key] = summary;
      }

      if (!mounted) return;

      final sortedList = summaryMap.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _attendanceSummaryList = sortedList;
        _isLoadingSummary = false;
      });

      // Save to cache
      if (summaryCacheKey != null) {
        final cacheData = sortedList.map((s) => {
          'subjectId': s.subjectId,
          'subjectName': s.subjectName,
          'date': s.date.toIso8601String(),
          'totalStudent': s.totalStudent,
          'present': s.present,
          'absent': s.absent,
          'classId': s.classId,
          'className': s.className,
          'lessonHourId': s.lessonHourId,
          'lessonHourName': s.lessonHourName,
        }).toList();
        await LocalCacheService.save(summaryCacheKey, cacheData);
      }

      AppLogger.info('attendance', 'Loaded ${_attendanceSummaryList.length} absensi summaries');
    } catch (e) {
      AppLogger.error('attendance', 'Error loading absensi summary: $e');
      if (mounted) {
        if (_attendanceSummaryList.isEmpty) {
          setState(() => _isLoadingSummary = false);
        }
      }
    }
  }

  // Helper function to parse date string as local date (not UTC)
  DateTime _parseLocalDate(String dateString) {
    // Use AppDateUtils for consistent and correct parsing
    return AppDateUtils.parseApiDate(dateString) ?? DateTime.now();
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedDateFilter != null ||
          _selectedSubjectIds.isNotEmpty ||
          _selectedDayIds.isNotEmpty ||
          _selectedLessonHourIds.isNotEmpty;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedDateFilter = null;
      _selectedSubjectIds.clear();
      _selectedDayIds.clear();
      _selectedLessonHourIds.clear();
      _hasActiveFilter = false;
    });
  }

  // ========== SHOW QUICK ACTIONS SHEET ==========
  void _showQuickActionsSheet(LanguageProvider languageProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              languageProvider.getTranslatedText({
                'en': 'Set All Students To',
                'id': 'Atur Semua Siswa Menjadi',
              }),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppSpacing.lg),
            _buildQuickActionOption('hadir', languageProvider),
            _buildQuickActionOption('terlambat', languageProvider),
            _buildQuickActionOption('izin', languageProvider),
            _buildQuickActionOption('sakit', languageProvider),
            _buildQuickActionOption('alpha', languageProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionOption(
    String status,
    LanguageProvider languageProvider,
  ) {
    return ListTile(
      leading: Icon(_getStatusIcon(status), color: _getStatusColor(status)),
      title: Text(_getStatusText(status, languageProvider)),
      onTap: () {
        _setAllStatus(status, languageProvider);
        AppNavigator.pop(context);
      },
    );
  }

  void _setAllStatus(String status, LanguageProvider languageProvider) {
    setState(() {
      for (var student in _filteredStudentList) {
        _attendanceStatus[student.id] = status;
      }
    });

        SnackBarUtils.showInfo(context, languageProvider.getTranslatedText({
            'en':
                'All students set to ${_getStatusText(status, languageProvider).toLowerCase()}',
            'id':
                'Semua siswa diatur menjadi ${_getStatusText(status, languageProvider).toLowerCase()}',
          }));
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'hadir':
        return Icons.check_circle;
      case 'terlambat':
        return Icons.watch_later;
      case 'izin':
        return Icons.assignment_turned_in;
      case 'sakit':
        return Icons.local_hospital;
      case 'alpha':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  // ========== FILTER FOR INPUT MODE ==========
  void _filterStudents() {
    final searchTerm = _searchControllerInput.text.toLowerCase();

    setState(() {
      _filteredStudentList = _studentList.where((student) {
        // Search filter
        final matchesSearch =
            searchTerm.isEmpty ||
            student.name.toLowerCase().contains(searchTerm) ||
            student.studentNumber.toLowerCase().contains(searchTerm);

        // Status filter
        final matchesStatus =
            _selectedStatusFilter == null ||
            (_attendanceStatus[student.id] ?? 'hadir') == _selectedStatusFilter;

        // Class filter
        final matchesClass =
            _selectedClassId == null || student.classId == _selectedClassId;

        return matchesSearch && matchesStatus && matchesClass;
      }).toList();
    });
  }

  // ========== MODE SWITCHER ==========
  Widget _buildModeSwitcher(LanguageProvider languageProvider) {
    return Container(
      key: _tabSwitcherKey,
      margin: const EdgeInsets.all(AppSpacing.lg),
      child: TabSwitcher(
        tabController: _tabController,
        primaryColor: _getPrimaryColor(),
        tabs: [
          TabItem(
            label: languageProvider.getTranslatedText({
              'en': 'Attendance Results',
              'id': 'Hasil Absensi',
            }),
            icon: Icons.list_alt,
          ),
          TabItem(
            label: languageProvider.getTranslatedText({
              'en': 'Add Attendance',
              'id': 'Tambah Absensi',
            }),
            icon: Icons.add_circle,
          ),
        ],
      ),
    );
  }

  // ========== CLASS LIST VIEW ==========
  Widget _buildInlineClassList(LanguageProvider languageProvider) {
    if (_classList.isEmpty) {
      return EmptyState(
        title: languageProvider.getTranslatedText({
          'en': 'No Class Data',
          'id': 'Data Kelas Kosong',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': 'You do not have any classes for this academic year',
          'id': 'Anda tidak mengampu kelas untuk tahun ajaran ini',
        }),
        icon: Icons.class_outlined,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppSpacing.lg),
      physics: AlwaysScrollableScrollPhysics(),
      itemCount: _classList.length,
      itemBuilder: (context, index) {
        final classData = _classList[index];
        final isHomeroom = classData['is_homeroom'] == true;
        final accentColor = isHomeroom
            ? _getPrimaryColor()
            : ColorUtils.getColorForIndex(index);

        return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedClassId = classData['id'];
                });
                _loadSubjectsByClass(classData['id']);
                if (_tabController.index == 0) {
                  _loadAttendanceSummary();
                }
          
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ColorUtils.slate200),
                  boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Icon(
                        isHomeroom
                            ? Icons.home_work_rounded
                            : Icons.class_rounded,
                        color: accentColor,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  classData['nama'] ??
                                      classData['name'] ??
                                      'Unknown Class',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: ColorUtils.slate900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isHomeroom) ...[
                                SizedBox(width: AppSpacing.sm),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getPrimaryColor().withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _getPrimaryColor().withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Wali Kelas',
                                    style: TextStyle(
                                      color: _getPrimaryColor(),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if ([classData['tingkat'], classData['jurusan']].any(
                            (e) => e != null && e.toString().isNotEmpty,
                          )) ...[
                            SizedBox(height: 3),
                            Text(
                              [classData['tingkat'], classData['jurusan']]
                                  .where(
                                    (e) => e != null && e.toString().isNotEmpty,
                                  )
                                  .join(' • '),
                              style: TextStyle(
                                color: ColorUtils.slate600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (classData['homeroom_teacher_name'] != null) ...[
                            SizedBox(height: 2),
                            Text(
                              'Wali Kelas: ${classData['homeroom_teacher_name']}',
                              style: TextStyle(
                                color: ColorUtils.slate500,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: ColorUtils.slate400,
                    ),
                  ],
                ),
              ),
            ),
        );
      },
    );
  }

  // ========== MODE 0: VIEW RESULTS ==========
  /// Builds the "View Results" tab UI with attendance summary cards.
  /// Like a Vue `<AttendanceResults>` component with filterable list.
  Widget _buildResultsMode() {
    final languageProvider = ref.watch(languageRiverpod);
        // Show Class List first if not selected
        if (_selectedClassId == null) {
          return _buildInlineClassList(languageProvider);
        }

        if (_isLoadingSummary) {
          return SkeletonListLoading(itemCount: 5, infoTagCount: 2);
        }

        final filteredSummaries = _getFilteredSummaries();

        return Column(
          children: [
            // Search dan Filter Bar
            _buildSearchAndFilter(languageProvider),

            // Filter Chips
            if (_hasActiveFilter) ...[
              SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: 34,
                child: Row(
                  children: [
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          ..._buildFilterChips(languageProvider).map((filter) {
                            return Container(
                              margin: EdgeInsets.only(right: 6),
                              child: InkWell(
                                onTap: filter['onRemove'],
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getPrimaryColor().withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _getPrimaryColor().withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        filter['label'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _getPrimaryColor(),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: AppSpacing.xs),
                                      Icon(
                                        Icons.close,
                                        size: 14,
                                        color: _getPrimaryColor(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: InkWell(
                        onTap: _clearAllFilters,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: ColorUtils.error600.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: ColorUtils.error600.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Clear',
                              'id': 'Hapus',
                            }),
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.error600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.xs),
            ],

            SizedBox(height: AppSpacing.sm),

            Expanded(
              child: filteredSummaries.isEmpty
                  ? EmptyState(
                      title: languageProvider.getTranslatedText({
                        'en': 'No attendance records',
                        'id': 'Belum ada data absensi',
                      }),
                      subtitle:
                          _searchController.text.isEmpty && !_hasActiveFilter
                          ? languageProvider.getTranslatedText({
                              'en': 'No attendance data available',
                              'id': 'Tidak ada data absensi tersedia',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'No search results found',
                              'id': 'Tidak ditemukan hasil pencarian',
                            }),
                      icon: Icons.list_alt,
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: filteredSummaries.length,
                      itemBuilder: (context, index) {
                        final summary = filteredSummaries[index];
                        return _buildSummaryCard(
                          summary,
                          languageProvider,
                          index,
                        );
                      },
                    ),
            ),
          ],
        );
  }

  List<AttendanceSummaryItem> _getFilteredSummaries() {
    final searchTerm = _searchController.text.toLowerCase();
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 6));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    return _attendanceSummaryList.where((summary) {
      // Class filter (Fix: Ensure results match selected class)
      if (_selectedClassId != null &&
          _selectedClassId!.isNotEmpty &&
          summary.classId != _selectedClassId) {
        return false;
      }

      // Search filter
      final matchesSearch =
          searchTerm.isEmpty ||
          summary.subjectName.toLowerCase().contains(searchTerm);

      // Date filter
      bool matchesDateFilter = true;
      if (_selectedDateFilter != null) {
        if (_selectedDateFilter == 'today') {
          matchesDateFilter = _isSameDay(summary.date, now);
        } else if (_selectedDateFilter == 'week') {
          matchesDateFilter =
              summary.date.isAfter(startOfWeek.subtract(Duration(days: 1))) &&
              summary.date.isBefore(endOfWeek.add(Duration(days: 1)));
        } else if (_selectedDateFilter == 'month') {
          matchesDateFilter =
              summary.date.isAfter(startOfMonth.subtract(Duration(days: 1))) &&
              summary.date.isBefore(endOfMonth.add(Duration(days: 1)));
        }
      }

      // Subject filter
      final matchesSubject =
          _selectedSubjectIds.isEmpty ||
          _selectedSubjectIds.contains(summary.subjectId);

      // Day filter
      final matchesDay =
          _selectedDayIds.isEmpty ||
          _selectedDayIds.contains(summary.date.weekday.toString());

      // Lesson Hour filter
      final matchesLessonHour =
          _selectedLessonHourIds.isEmpty ||
          _selectedLessonHourIds.contains(summary.lessonHourId);

      return matchesSearch &&
          matchesDateFilter &&
          matchesSubject &&
          matchesDay &&
          matchesLessonHour;
    }).toList();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // ========== HEADER BARU SEPERTI ADMIN PRESENCE ==========
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
                onTap: () {
                  if (_selectedClassId != null) {
                    setState(() {
                      _selectedClassId = null;
                      _studentList = [];
                    });
                  } else {
                    AppNavigator.pop(context);
                  }
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
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tabController.index == 0
                          ? languageProvider.getTranslatedText({
                              'en': 'Attendance Results',
                              'id': 'Hasil Absensi',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'Add Attendance',
                              'id': 'Tambah Absensi',
                            }),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      _tabController.index == 0
                          ? languageProvider.getTranslatedText({
                              'en': 'View attendance records',
                              'id': 'Lihat catatan kehadiran',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'Record student attendance',
                              'id': 'Catat kehadiran siswa',
                            }),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
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
          SizedBox(height: AppSpacing.lg),

          // Mode Switcher di dalam header
          _buildModeSwitcher(languageProvider),
        ],
      ),
    );
  }

  // ========== SEARCH BAR WITH FILTER LIKE ADMIN ==========
  Widget _buildSearchAndFilter(LanguageProvider languageProvider) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        key: _searchFilterKey,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
                boxShadow: ColorUtils.corporateShadow(elevation: 0.5),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: ColorUtils.slate900, fontSize: 14),
                decoration: InputDecoration(
                  hintText: languageProvider.getTranslatedText({
                    'en': 'Search attendance...',
                    'id': 'Cari absensi...',
                  }),
                  hintStyle: TextStyle(
                    color: ColorUtils.slate400,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: ColorUtils.slate400,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          if (_tabController.index == 0) ...[
            SizedBox(width: AppSpacing.sm),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _hasActiveFilter ? _getPrimaryColor() : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasActiveFilter
                      ? _getPrimaryColor()
                      : ColorUtils.slate200,
                ),
                boxShadow: ColorUtils.corporateShadow(elevation: 0.5),
              ),
              child: IconButton(
                onPressed: _showFilterSheet,
                icon: Icon(
                  Icons.tune,
                  color: _hasActiveFilter ? Colors.white : ColorUtils.slate600,
                  size: 20,
                ),
                tooltip: languageProvider.getTranslatedText({
                  'en': 'Filter',
                  'id': 'Filter',
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ========== FILTER SHEET SEPERTI ADMIN ==========
  void _showFilterSheet() {
    final languageProvider = ref.read(languageRiverpod);

    String? tempDateFilter = _selectedDateFilter;
    final List<String> tempSubjectIds = List.from(_selectedSubjectIds);
    final List<String> tempDayIds = List.from(_selectedDayIds);
    final List<String> tempLessonHourIds = List.from(_selectedLessonHourIds);

    final days = [
      {'en': 'Monday', 'id': 'Senin', 'val': '1'},
      {'en': 'Tuesday', 'id': 'Selasa', 'val': '2'},
      {'en': 'Wednesday', 'id': 'Rabu', 'val': '3'},
      {'en': 'Thursday', 'id': 'Kamis', 'val': '4'},
      {'en': 'Friday', 'id': 'Jumat', 'val': '5'},
      {'en': 'Saturday', 'id': 'Sabtu', 'val': '6'},
      {'en': 'Sunday', 'id': 'Minggu', 'val': '7'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Gradient header
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getPrimaryColor(),
                        _getPrimaryColor().withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(20, 14, 16, 20),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.filter_list,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Filter Attendance',
                                'id': 'Filter Absensi',
                              }),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                tempDateFilter = null;
                                tempSubjectIds.clear();
                                tempDayIds.clear();
                                tempLessonHourIds.clear();
                              });
                            },
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Reset',
                                'id': 'Reset',
                              }),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Range
                        _buildSectionHeader(
                          languageProvider.getTranslatedText({
                            'en': 'Date Range',
                            'id': 'Rentang Tanggal',
                          }),
                          Icons.calendar_today_outlined,
                        ),
                        SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              [
                                {
                                  'label': languageProvider.getTranslatedText({
                                    'en': 'Today',
                                    'id': 'Hari Ini',
                                  }),
                                  'val': 'today',
                                },
                                {
                                  'label': languageProvider.getTranslatedText({
                                    'en': 'This Week',
                                    'id': 'Minggu Ini',
                                  }),
                                  'val': 'week',
                                },
                                {
                                  'label': languageProvider.getTranslatedText({
                                    'en': 'This Month',
                                    'id': 'Bulan Ini',
                                  }),
                                  'val': 'month',
                                },
                              ].map((item) {
                                final isSelected =
                                    tempDateFilter == item['val'];
                                return FilterChip(
                                  label: Text(item['label']!),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setSheetState(() {
                                      tempDateFilter = selected
                                          ? item['val']
                                          : null;
                                    });
                                  },
                                  backgroundColor: Colors.white,
                                  selectedColor: _getPrimaryColor().withValues(
                                    alpha: 0.2,
                                  ),
                                  checkmarkColor: _getPrimaryColor(),
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? _getPrimaryColor()
                                        : ColorUtils.slate600,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                );
                              }).toList(),
                        ),

                        // Subject
                        if (_subjectTeacher.isNotEmpty) ...[
                          _buildSectionHeader(
                            languageProvider.getTranslatedText({
                              'en': 'Subject',
                              'id': 'Mata Pelajaran',
                            }),
                            Icons.book_outlined,
                          ),
                          SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _subjectTeacher.map((subject) {
                              final subjectId = subject['id'].toString();
                              final isSelected = tempSubjectIds.contains(
                                subjectId,
                              );
                              final label =
                                  subject['name'] ??
                                  subject['nama'] ??
                                  subject['mata_pelajaran_nama'] ??
                                  'Subject';
                              return FilterChip(
                                label: Text(label),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setSheetState(() {
                                    if (selected) {
                                      tempSubjectIds.add(subjectId);
                                    } else {
                                      tempSubjectIds.remove(subjectId);
                                    }
                                  });
                                },
                                backgroundColor: Colors.white,
                                selectedColor: _getPrimaryColor().withValues(
                                  alpha: 0.2,
                                ),
                                checkmarkColor: _getPrimaryColor(),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? _getPrimaryColor()
                                      : ColorUtils.slate600,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        // Day
                        _buildSectionHeader(
                          languageProvider.getTranslatedText({
                            'en': 'Day',
                            'id': 'Hari',
                          }),
                          Icons.today_outlined,
                        ),
                        SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: days.map((d) {
                            final val = d['val']!;
                            final isSelected = tempDayIds.contains(val);
                            final label = languageProvider.getTranslatedText({
                              'en': d['en']!,
                              'id': d['id']!,
                            });
                            return FilterChip(
                              label: Text(label),
                              selected: isSelected,
                              onSelected: (selected) {
                                setSheetState(() {
                                  if (selected) {
                                    tempDayIds.add(val);
                                  } else {
                                    tempDayIds.remove(val);
                                  }
                                });
                              },
                              backgroundColor: Colors.white,
                              selectedColor: _getPrimaryColor().withValues(
                                alpha: 0.2,
                              ),
                              checkmarkColor: _getPrimaryColor(),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? _getPrimaryColor()
                                    : ColorUtils.slate600,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            );
                          }).toList(),
                        ),

                        // Lesson Hour
                        if (_lessonHours.isNotEmpty) ...[
                          _buildSectionHeader(
                            languageProvider.getTranslatedText({
                              'en': 'Lesson Hour',
                              'id': 'Jam Pelajaran',
                            }),
                            Icons.access_time_outlined,
                          ),
                          SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _lessonHours.map((lh) {
                              final lhId = lh['id'].toString();
                              final isSelected = tempLessonHourIds.contains(
                                lhId,
                              );
                              return FilterChip(
                                label: Text(lh['name'] ?? 'Jam'),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setSheetState(() {
                                    if (selected) {
                                      tempLessonHourIds.add(lhId);
                                    } else {
                                      tempLessonHourIds.remove(lhId);
                                    }
                                  });
                                },
                                backgroundColor: Colors.white,
                                selectedColor: _getPrimaryColor().withValues(
                                  alpha: 0.2,
                                ),
                                checkmarkColor: _getPrimaryColor(),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? _getPrimaryColor()
                                      : ColorUtils.slate600,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: ColorUtils.slate200)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => AppNavigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 13),
                            side: BorderSide(color: ColorUtils.slate300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Cancel',
                              'id': 'Batal',
                            }),
                            style: TextStyle(
                              color: ColorUtils.slate700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedDateFilter = tempDateFilter;
                              _selectedSubjectIds = tempSubjectIds;
                              _selectedDayIds = tempDayIds;
                              _selectedLessonHourIds = tempLessonHourIds;
                              _checkActiveFilter();
                            });
                            AppNavigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 13),
                            backgroundColor: _getPrimaryColor(),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Apply Filter',
                              'id': 'Terapkan Filter',
                            }),
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(top: 24, bottom: 0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ColorUtils.slate700),
          SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: ColorUtils.slate900,
            ),
          ),
        ],
      ),
    );
  }

  // ========== FILTER CHIPS SEPERTI ADMIN ==========
  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    final List<Map<String, dynamic>> filterChips = [];

    if (_selectedDateFilter != null) {
      final label = _selectedDateFilter == 'today'
          ? languageProvider.getTranslatedText({
              'en': 'Today',
              'id': 'Hari Ini',
            })
          : _selectedDateFilter == 'week'
          ? languageProvider.getTranslatedText({
              'en': 'This Week',
              'id': 'Minggu Ini',
            })
          : languageProvider.getTranslatedText({
              'en': 'This Month',
              'id': 'Bulan Ini',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Date', 'id': 'Tanggal'})}: $label',
        'onRemove': () {
          setState(() {
            _selectedDateFilter = null;
            _checkActiveFilter();
          });
        },
      });
    }

    if (_selectedSubjectIds.isNotEmpty) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Subject', 'id': 'Mata Pelajaran'})}: ${_selectedSubjectIds.length}',
        'onRemove': () {
          setState(() {
            _selectedSubjectIds.clear();
            _checkActiveFilter();
          });
        },
      });
    }

    if (_selectedDayIds.isNotEmpty) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Day', 'id': 'Hari'})}: ${_selectedDayIds.length}',
        'onRemove': () {
          setState(() {
            _selectedDayIds.clear();
            _checkActiveFilter();
          });
        },
      });
    }

    if (_selectedLessonHourIds.isNotEmpty) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Hour', 'id': 'Jam'})}: ${_selectedLessonHourIds.length}',
        'onRemove': () {
          setState(() {
            _selectedLessonHourIds.clear();
            _checkActiveFilter();
          });
        },
      });
    }

    return filterChips;
  }

  Widget _buildSummaryCard(
    AttendanceSummaryItem summary,
    LanguageProvider languageProvider,
    int index,
  ) {
    final attendanceRate = summary.totalStudent > 0
        ? (summary.present / summary.totalStudent * 100).round()
        : 0;

    final progressColor = attendanceRate >= 80
        ? ColorUtils.success600
        : attendanceRate >= 60
        ? ColorUtils.warning600
        : ColorUtils.error600;

    return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToAttendanceDetail(summary),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: subject name + delete button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getPrimaryColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _getPrimaryColor().withValues(alpha: 0.15),
                        ),
                      ),
                      child: Icon(
                        Icons.book_outlined,
                        color: _getPrimaryColor(),
                        size: 20,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    // Subject + class + date info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.subjectName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.class_outlined,
                                size: 12,
                                color: _getPrimaryColor(),
                              ),
                              SizedBox(width: AppSpacing.xs),
                              Text(
                                summary.className ?? 'Kelas',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getPrimaryColor(),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (summary.lessonHourName != null &&
                                  summary.lessonHourName!.isNotEmpty) ...[
                                Text(
                                  ' • ',
                                  style: TextStyle(
                                    color: ColorUtils.slate400,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  summary.lessonHourName!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ColorUtils.slate600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            DateFormat(
                              'EEEE, dd MMMM yyyy',
                              'id_ID',
                            ).format(summary.date),
                            style: TextStyle(
                              fontSize: 11,
                              color: ColorUtils.slate500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    // Delete button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _deleteAttendance(summary, languageProvider),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: ColorUtils.error600.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ColorUtils.error600.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: ColorUtils.error600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: AppSpacing.md),
                Divider(color: ColorUtils.slate100, height: 1),
                SizedBox(height: 10),

                // Attendance info row with info tags
                Row(
                  children: [
                    _buildInfoTag(
                      icon: Icons.check_circle_outline,
                      label: '${summary.present} Hadir',
                      tagColor: ColorUtils.success600,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _buildInfoTag(
                      icon: Icons.cancel_outlined,
                      label: '${summary.absent} Absen',
                      tagColor: ColorUtils.error600,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _buildInfoTag(
                      icon: Icons.people_outline,
                      label: '${summary.totalStudent} Siswa',
                      tagColor: _getPrimaryColor(),
                    ),
                    Spacer(),
                    // Detail button
                    GestureDetector(
                      onTap: () => _navigateToAttendanceDetail(summary),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getPrimaryColor().withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getPrimaryColor().withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 12,
                              color: _getPrimaryColor(),
                            ),
                            SizedBox(width: AppSpacing.xs),
                            Text(
                              'Detail',
                              style: TextStyle(
                                fontSize: 11,
                                color: _getPrimaryColor(),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 10),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: summary.totalStudent > 0
                        ? summary.present / summary.totalStudent
                        : 0,
                    minHeight: 6,
                    backgroundColor: ColorUtils.slate200,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  '$attendanceRate% ${languageProvider.getTranslatedText({'en': 'Attendance', 'id': 'Kehadiran'})}',
                  style: TextStyle(fontSize: 10, color: ColorUtils.slate500),
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildInfoTag({
    required IconData icon,
    required String label,
    Color? tagColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tagColor != null
            ? tagColor.withValues(alpha: 0.1)
            : ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: tagColor != null
              ? tagColor.withValues(alpha: 0.2)
              : ColorUtils.slate200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: tagColor ?? ColorUtils.slate600),
          SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: tagColor ?? ColorUtils.slate700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAttendanceDetail(AttendanceSummaryItem summary) {
    AppNavigator.push(context, TeacherAbsensiDetailPage(
          subjectId: summary.subjectId,
          subjectName: summary.subjectName,
          date: summary.date,
          classId: summary.classId ?? '',
          className: summary.className ?? 'Unknown Class',
          teacher: widget.teacher,
          lessonHourId: summary.lessonHourId,
          lessonHourName: summary.lessonHourName,
        ));
  }

  // ========== MODE 2: INPUT ABSENSI (REDESIGNED) ==========
  /// Builds the "Input Attendance" tab UI with student list and status selectors.
  /// Like a Vue `<AttendanceInput>` component with date picker, class/subject
  /// dropdowns, and per-student status buttons.
  Widget _buildInputMode() {
    final languageProvider = ref.watch(languageRiverpod);
        if (_isLoadingInput) {
          return SkeletonListLoading(itemCount: 4, infoTagCount: 1);
        }

        return Column(
          children: [
            // 1. Form Section (Date, Hour, Class, Subject)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ColorUtils.slate200),
                boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Date & Lesson Hour
                  Row(
                    children: [
                      // Date Picker
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedDate = picked;
                                _detectCurrentSchedule();
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: ColorUtils.slate50,
                              border: Border.all(color: ColorUtils.slate200),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: _getPrimaryColor(),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    DateFormat(
                                      'EEE, dd MMM yyyy',
                                      'id_ID',
                                    ).format(_selectedDate),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: ColorUtils.slate800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Lesson Hour Dropdown
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: ColorUtils.slate50,
                            border: Border.all(color: ColorUtils.slate200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedLessonHourId,
                              isExpanded: true,
                              hint: Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Hour',
                                  'id': 'Jam',
                                }),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: ColorUtils.slate500,
                                ),
                              ),
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: ColorUtils.slate600,
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                color: ColorUtils.slate800,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'Select Hour',
                                      'id': 'Pilih Jam',
                                    }),
                                    style: TextStyle(
                                      color: ColorUtils.slate500,
                                    ),
                                  ),
                                ),
                                ..._lessonHours.map(
                                  (lh) => DropdownMenuItem(
                                    value: lh['id']?.toString(),
                                    child: Text(
                                      '${lh['name']} (${lh['start_time']} - ${lh['end_time']})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedLessonHourId = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Row 2: Class & Subject
                  Row(
                    children: [
                      // Class Dropdown
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: ColorUtils.slate50,
                            border: Border.all(color: ColorUtils.slate200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedClassId,
                              isExpanded: true,
                              hint: Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Class',
                                  'id': 'Kelas',
                                }),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: ColorUtils.slate500,
                                ),
                              ),
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: ColorUtils.slate600,
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                color: ColorUtils.slate800,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'Select Class',
                                      'id': 'Pilih Kelas',
                                    }),
                                    style: TextStyle(
                                      color: ColorUtils.slate500,
                                    ),
                                  ),
                                ),
                                ..._classList.map(
                                  (classItem) => DropdownMenuItem(
                                    value: classItem['id'],
                                    child: Text(classItem['name']),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedClassId = value;
                                  _filterStudentsByClass(value);
                                });
                                _loadSubjectsByClass(value);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Subject Dropdown
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: ColorUtils.slate50,
                            border: Border.all(color: ColorUtils.slate200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSubjectId,
                              isExpanded: true,
                              hint: Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Subject',
                                  'id': 'Mapel',
                                }),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: ColorUtils.slate500,
                                ),
                              ),
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: ColorUtils.slate600,
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                color: ColorUtils.slate800,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'Select Subject',
                                      'id': 'Pilih Mapel',
                                    }),
                                    style: TextStyle(
                                      color: ColorUtils.slate500,
                                    ),
                                  ),
                                ),
                                ..._subjectTeacher.map(
                                  (mp) => DropdownMenuItem(
                                    value: mp['id'],
                                    child: Text(
                                      mp['nama'] ??
                                          mp['name'] ??
                                          mp['mata_pelajaran_nama'] ??
                                          'Unknown',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedSubjectId = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Warning if no subjects
                  if (_subjectTeacher.isEmpty && _selectedClassId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'No subjects assigned for this class.',
                          'id': 'Tidak ada mata pelajaran untuk kelas ini.',
                        }),
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  const SizedBox(height: AppSpacing.md),

                  // Quick Actions Row (Search & Quick Attendance)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_showSearch)
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: TextField(
                              controller: _searchControllerInput,
                              onChanged: (value) => _filterStudents(),
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: languageProvider.getTranslatedText({
                                  'en': 'Search name/NIS...',
                                  'id': 'Cari nama/NIS...',
                                }),
                                prefixIcon: const Icon(Icons.search, size: 16),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: ColorUtils.slate300,
                                  ),
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () {
                                    setState(() {
                                      _showSearch = false;
                                      _searchControllerInput.clear();
                                      _filterStudents();
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        IconButton(
                          icon: Icon(Icons.search, color: ColorUtils.slate600),
                          onPressed: () {
                            setState(() {
                              _showSearch = true;
                            });
                          },
                          tooltip: languageProvider.getTranslatedText({
                            'en': 'Search Student',
                            'id': 'Cari Siswa',
                          }),
                        ),

                      if (!_showSearch) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          decoration: BoxDecoration(
                            color: _getPrimaryColor().withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.checklist_rtl,
                              color: _getPrimaryColor(),
                            ),
                            onPressed: () {
                              _showQuickActionsSheet(languageProvider);
                            },
                            tooltip: languageProvider.getTranslatedText({
                              'en': 'Quick Attendance',
                              'id': 'Presensi Cepat',
                            }),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            iconSize: 20,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // 2. Student List Area
            Expanded(
              child: _selectedSubjectId == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              size: 64,
                              color: ColorUtils.slate300,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Please select Class and Subject first',
                                'id':
                                    'Silakan pilih Kelas dan Mapel terlebih dahulu',
                              }),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: ColorUtils.slate600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              languageProvider.getTranslatedText({
                                'en':
                                    'Or ensure you have a schedule for the selected date',
                                'id':
                                    'Atau pastikan anda memiliki jadwal pada tanggal yang dipilih',
                              }),
                              style: TextStyle(
                                fontSize: 13,
                                color: ColorUtils.slate400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : _filteredStudentList.isEmpty
                  ? EmptyState(
                      title: languageProvider.getTranslatedText({
                        'en': 'No Students',
                        'id': 'Tidak ada siswa',
                      }),
                      subtitle: languageProvider.getTranslatedText({
                        'en': 'No students found for selected class',
                        'id': 'Tidak ada siswa untuk kelas yang dipilih',
                      }),
                      icon: Icons.people_outline,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 80),
                      itemCount: _filteredStudentList.length,
                      itemBuilder: (context, index) => _buildStudentItem(
                        _filteredStudentList[index],
                        languageProvider,
                      ),
                    ),
            ),

            // 3. Submit Button
            if (_selectedSubjectId != null && _filteredStudentList.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: ColorUtils.slate200)),
                  boxShadow: [
                    BoxShadow(
                      color: ColorUtils.slate900.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitAttendance,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 20),
                        label: Text(
                          _isSubmitting
                              ? languageProvider.getTranslatedText({
                                  'en': 'Saving...',
                                  'id': 'Menyimpan...',
                                })
                              : languageProvider.getTranslatedText({
                                  'en': 'Save Attendance',
                                  'id': 'Simpan Absensi',
                                }),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getPrimaryColor(),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
  }

  // ========== STUDENT ITEM BUILDER BARU ==========
  Widget _buildStudentItem(Student student, LanguageProvider languageProvider) {
    final status = _attendanceStatus[student.id] ?? 'hadir';
    final Color statusColor = _getStatusColor(status);
    final String statusText = _getStatusText(status, languageProvider);
    final avatarColor = _getAvatarColor(student.name);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: avatarColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'NIS: ${student.studentNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickStatusButton(
                    'hadir',
                    'H',
                    ColorUtils.success600,
                    student.id,
                  ),
                  _buildQuickStatusButton(
                    'terlambat',
                    'T',
                    ColorUtils.violet700,
                    student.id,
                  ),
                  _buildQuickStatusButton(
                    'sakit',
                    'S',
                    ColorUtils.warning600,
                    student.id,
                  ),
                  _buildQuickStatusButton(
                    'izin',
                    'I',
                    ColorUtils.info600,
                    student.id,
                  ),
                  _buildQuickStatusButton(
                    'alpha',
                    'A',
                    ColorUtils.error600,
                    student.id,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatusButton(
    String status,
    String label,
    Color color,
    String studentId,
  ) {
    final isSelected =
        _attendanceStatus[studentId]?.toLowerCase() == status.toLowerCase();
    return GestureDetector(
      onTap: () {
        setState(() {
          _attendanceStatus[studentId] = status;
        });
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // ========== HELPER FUNCTIONS ==========
  void _filterStudentsByClass(String? classId) {
    setState(() {
      _selectedClassId = classId;
      _filterStudents();
    });
  }

  /// Submits attendance records for all students to the API.
  /// Like a Vue `methods.submitForm()` calling `axios.post('/api/attendance')`
  /// for each student. Shows progress, handles errors, and displays
  /// success/failure summary. In Laravel: `AttendanceController@store`.
  Future<void> _submitAttendance() async {
    final languageProvider = ref.read(languageRiverpod);

    // Validate teacher_id
    final teacherId = widget.teacher['id'];
    if (teacherId == null) {
            SnackBarUtils.showError(context, languageProvider.getTranslatedText({
              'en': 'Invalid teacher data. Please login again.',
              'id': 'Data guru tidak valid. Silakan login ulang.',
            }));
      return;
    }

    if (_selectedSubjectId == null) {
            SnackBarUtils.showError(context, languageProvider.getTranslatedText({
              'en': 'Please select a subject first',
              'id': 'Pilih mata pelajaran terlebih dahulu',
            }));
      return;
    }

    if (_filteredStudentList.isEmpty) {
            SnackBarUtils.showError(context, languageProvider.getTranslatedText({
              'en': 'No students to save',
              'id': 'Tidak ada siswa untuk disimpan',
            }));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      int successCount = 0;
      int errorCount = 0;
      final List<String> errorMessages = [];

      final date = DateFormat('yyyy-MM-dd').format(_selectedDate);

      for (var student in _filteredStudentList) {
        try {
          final status = _attendanceStatus[student.id] ?? 'hadir';

          await AttendanceService.createAttendance({
            'student_id': student.id,
            'teacher_id': teacherId,
            'subject_id': _selectedSubjectId,
            'class_id': student.classId,
            'date': date,
            'status': _mapStatusToBackend(status),
            'notes': '',
            'lesson_hour_id': _selectedLessonHourId,
          });

          successCount++;
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (e) {
          errorCount++;
          // Debug logging as requested
          AppLogger.error('attendance', 'Attendance save error for ${student.name}: $e');

          // Clean user-friendly message
          final String cleanerMessage = e.toString().replaceAll('Exception: ', '');
          errorMessages.add('${student.name}: $cleanerMessage');
        }
      }

      if (!mounted) return;

      // Tampilkan hasil
      if (errorCount == 0) {
                SnackBarUtils.showSuccess(context, languageProvider.getTranslatedText({
                'en':
                    'Attendance successfully saved for $successCount students',
                'id': 'Absensi berhasil disimpan untuk $successCount siswa',
              }));

        // Reset form setelah berhasil
        _resetForm();

        // Pindah ke tab Hasil (index 0)
        _tabController.animateTo(0);
      } else {
                SnackBarUtils.showWarning(context, languageProvider.getTranslatedText({
                'en': '$successCount successful, $errorCount failed',
                'id': '$successCount berhasil, $errorCount gagal',
              }));
        _showErrorDetails(errorMessages, languageProvider);
      }
    } catch (e) {
      if (!mounted) return;
            SnackBarUtils.showError(context, '${languageProvider.getTranslatedText({'en': 'Error:', 'id': 'Error:'})} $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showErrorDetails(
    List<String> errors,
    LanguageProvider languageProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageProvider.getTranslatedText({
            'en': 'Error Details',
            'id': 'Detail Error',
          }),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Some attendance failed to save:',
                  'id': 'Beberapa absensi gagal disimpan:',
                }),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...errors.map(
                (error) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• $error', style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(context),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Close',
                'id': 'Tutup',
              }),
            ),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      // Reset status absensi ke default
      for (var student in _studentList) {
        _attendanceStatus[student.id] = 'hadir';
      }
      // Reset filter kelas
      _selectedClassId = null;
      _selectedStatusFilter = null;
      _searchControllerInput.clear();
      _filterStudents();
    });

    // Re-detect current schedule after reset
    _detectCurrentSchedule();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return Colors.green;
      case 'sakit':
        return Colors.orange;
      case 'izin':
        return Colors.blue;
      case 'alpha':
        return Colors.red;
      case 'terlambat':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }

  String _getStatusText(String status, LanguageProvider languageProvider) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return languageProvider.getTranslatedText({
          'en': 'Present',
          'id': 'Hadir',
        });
      case 'sakit':
        return languageProvider.getTranslatedText({
          'en': 'Sick',
          'id': 'Sakit',
        });
      case 'izin':
        return languageProvider.getTranslatedText({
          'en': 'Permission',
          'id': 'Izin',
        });
      case 'alpha':
        return languageProvider.getTranslatedText({
          'en': 'Absent',
          'id': 'Alpha',
        });
      case 'terlambat':
        return languageProvider.getTranslatedText({
          'en': 'Late',
          'id': 'Terlambat',
        });
      default:
        return languageProvider.getTranslatedText({
          'en': 'Present',
          'id': 'Hadir',
        });
    }
  }

  String _mapStatusToBackend(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return 'present';
      case 'terlambat':
        return 'late';
      case 'izin':
        return 'excused';
      case 'sakit':
        return 'sick';
      case 'alpha':
      case 'absent':
        return 'absent';
      default:
        return 'present';
    }
  }

  Future<void> _deleteAttendance(
    AttendanceSummaryItem summary,
    LanguageProvider languageProvider,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageProvider.getTranslatedText({
            'en': 'Delete Attendance',
            'id': 'Hapus Absensi',
          }),
        ),
        content: Text(
          languageProvider.getTranslatedText({
            'en':
                'Are you sure you want to delete attendance for ${summary.subjectName} on ${DateFormat('dd MMMM yyyy', 'id_ID').format(summary.date)}?',
            'id':
                'Apakah Anda yakin ingin menghapus absensi ${summary.subjectName} pada ${DateFormat('dd MMMM yyyy', 'id_ID').format(summary.date)}?',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(context, false),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Cancel',
                'id': 'Batal',
              }),
            ),
          ),
          TextButton(
            onPressed: () => AppNavigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Delete',
                'id': 'Hapus',
              }),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AttendanceService.deleteAttendanceSummary(
        teacherId: widget.teacher['id'],
        subjectId: summary.subjectId,
        date: DateFormat('yyyy-MM-dd').format(summary.date),
        classId: summary.classId,
        lessonHourId: summary.lessonHourId,
      );

      if (!mounted) return;

            SnackBarUtils.showSuccess(context, languageProvider.getTranslatedText({
              'en': 'Attendance deleted successfully',
              'id': 'Absensi berhasil dihapus',
            }));

      // Reload summary data
      _loadAttendanceSummary();
    } catch (e) {
      AppLogger.error('attendance', 'Delete attendance error: $e');
      if (mounted) {
                SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Color _getAvatarColor(String nama) {
    final index = nama.isNotEmpty ? nama.codeUnitAt(0) % 6 : 0;
    return ColorUtils.getColorForIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
        return Scaffold(
          backgroundColor:
              ColorUtils.slate50, // Background same as announcements
          body: Column(
            children: [
              // Header baru seperti pengumuman
              _buildHeader(languageProvider),

              // Content
              Expanded(
                child: _tabController.index == 0
                    ? _buildResultsMode()
                    : _buildInputMode(),
              ),
            ],
          ),
        );
  }

  Future<void> _checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus('presence_teacher_screen', 'guru');
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
      AppLogger.error('attendance', 'Error checking tour status: $e');
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
        getIt<ApiTourService>().completeTour(name: 'presence_teacher_tour', role: 'guru', platform: 'mobile');
        LocalCacheService.save(CacheKeyBuilder.tourStatus('presence_teacher_screen', 'guru'), {'should_show': false});
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(name: 'presence_teacher_tour', role: 'guru', platform: 'mobile');
        LocalCacheService.save(CacheKeyBuilder.tourStatus('presence_teacher_screen', 'guru'), {'should_show': false});
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    final List<TargetFocus> targets = [];

    targets.add(
      TargetFocus(
        identify: "TabSwitcher",
        keyTarget: _tabSwitcherKey,
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
                    "Mode Absensi",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Pilih 'Hasil Absensi' untuk melihat rekapan daftar hadir sebelumnya, atau 'Tambah Absensi' untuk mulai memanggil daftar hadir siswa hari ini.",
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
        identify: "SearchFilter",
        keyTarget: _searchFilterKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Pencarian & Filter",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Gunakan kotak pencarian ini untuk mencari data absensi, dan gunakan tombol filter di sebelah kanannya untuk mencari rekapan absensi berdasarkan hari, bulan, atau mata pelajaran tertentu.",
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

// ========== HELPER FUNCTIONS FOR STYLING ==========
Color _getPrimaryColor() {
  return ColorUtils.getRoleColor('guru');
}

LinearGradient _getCardGradient() {
  final primaryColor = _getPrimaryColor();
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
  );
}
