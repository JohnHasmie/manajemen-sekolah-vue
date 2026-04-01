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

import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
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
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_detail.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_quick_actions_sheet.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_filter_sheet.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_summary_item.dart';

import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_teacher_class_list.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_teacher_header.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_search_filter_bar.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_input_form.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_results_mode.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_input_mode.dart';

part 'teacher_attendance_screen_helpers.dart';

/// Teacher attendance management page with two modes: view results and input.
///
/// This is a StatefulWidget with complex local state. Props (like Vue props):
/// - [teacher] -- current teacher info
/// - [initialDate] / [initialSubjectId] / etc. -- optional deep-link params
class AttendancePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  final DateTime? initialDate;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final String? initialclassId;
  final String? initialClassName;
  final int? initialLessonHourNumber;
  final String? initialStartTime;
  final int initialTabIndex;

  final bool embedded;

  const AttendancePage({
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
    this.embedded = false,
  });

  @override
  AttendancePageState createState() => AttendancePageState();
}

/// State for [AttendancePage].
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
class AttendancePageState extends ConsumerState<AttendancePage>
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
    final academicYearId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
    return 'presence_initial_${teacherId}_$academicYearId';
  }

  String? _buildSummaryCacheKey() {
    final teacherId = widget.teacher['id']?.toString() ?? '';
    if (teacherId.isEmpty) return null;
    final academicYearId = ref
        .read(academicYearRiverpod)
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

  /// Loads all initial data: subjects, classes, students, and optionally
  /// detects the current lesson schedule. Like a Vue `mounted()` that
  /// calls multiple `axios.get()` in sequence.
  Future<void> _loadInitialData({bool useCache = true}) async {
    try {
      final academicYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      final cacheKey = _buildPresenceCacheKey();
      final teacherId = widget.teacher['id']?.toString() ?? '';

      // ─── Fast path for embedded mode (opened from schedule card) ───
      // Skip class list, subject list, and schedule auto-detection.
      // Only load students and lesson hours (needed for the input form).
      if (widget.embedded &&
          widget.initialclassId != null &&
          widget.initialSubjectId != null) {
        final [studentList, lessonHours] = await Future.wait([
          _loadWithCache(
            cacheKey: 'school_student_data_$academicYearId',
            ttl: const Duration(hours: 6),
            apiFetcher: () => getIt<ApiStudentService>().getStudent(
              academicYearId: academicYearId,
            ),
            useCache: useCache,
          ),
          _loadWithCache(
            cacheKey: 'school_lesson_hour_data',
            ttl: const Duration(hours: 24),
            apiFetcher: () => getIt<ApiScheduleService>().getJamPelajaran(),
            useCache: useCache,
          ),
        ]);

        if (!mounted) return;

        setState(() {
          _studentList = studentList.map((s) => Student.fromJson(s)).toList();
          final seen = <String>{};
          _lessonHours = lessonHours.where((lh) {
            final key =
                '${lh['hour_number'] ?? lh['name']}_${lh['start_time']}_${lh['end_time']}';
            return seen.add(key);
          }).toList();
          _filteredStudentList = _studentList;
          for (var student in _studentList) {
            _attendanceStatus[student.id] = 'hadir';
          }
          _isLoadingInput = false;
        });

        _detectCurrentLessonHour();
        return;
      }

      // ─── Step 1: Try TeacherProvider for classList (populated by Dashboard) ───
      final teacherProvider = ref.read(teacherRiverpod);

      List<dynamic>? providerClassList;
      if (teacherProvider.isLoaded && teacherProvider.allClasses.isNotEmpty) {
        providerClassList = teacherProvider.allClasses;
        AppLogger.debug(
          'attendance',
          'Using TeacherProvider classList (${providerClassList.length} classes)',
        );
      }

      // Step 2: Try composite local cache for instant display
      if (useCache && _classList.isEmpty && cacheKey != null) {
        try {
          final cached = await LocalCacheService.load(
            cacheKey,
            ttl: const Duration(hours: 3),
          );
          if (cached != null && mounted) {
            final cachedData = Map<String, dynamic>.from(cached);
            setState(() {
              _classList = List<dynamic>.from(cachedData['classList'] ?? []);
              _subjectTeacher = List<dynamic>.from(
                cachedData['subjects'] ?? [],
              );
              _lessonHours = List<dynamic>.from(
                cachedData['lessonHours'] ?? [],
              );
              final studentRaw = List<dynamic>.from(
                cachedData['studentList'] ?? [],
              );
              _studentList = studentRaw
                  .map((s) => Student.fromJson(Map<String, dynamic>.from(s)))
                  .toList();
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
        apiFetcher: () => getIt<ApiStudentService>().getStudent(
          academicYearId: academicYearId,
        ),
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
        apiFetcher: () =>
            _getSubjectByTeacher(teacherId, classId: _selectedClassId),
        useCache: useCache,
      );

      final [classList, studentList, lessonHours, subjects] = await Future.wait(
        [classListFuture, studentFuture, lessonHourFuture, subjectFuture],
      );

      if (!mounted) return;

      setState(() {
        _subjectTeacher = subjects;
        _classList = classList;
        _studentList = studentList.map((s) => Student.fromJson(s)).toList();
        // Deduplicate lesson hours (API returns per-day, causing repeats)
        final seen = <String>{};
        _lessonHours = lessonHours.where((lh) {
          final key =
              '${lh['hour_number'] ?? lh['name']}_${lh['start_time']}_${lh['end_time']}';
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
      AppLogger.error('attendance', 'AttendancePage initial data error: $e');
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
          if (lhStart.isNotEmpty &&
              widget.initialStartTime!.startsWith(lhStart.split('.')[0])) {
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
      final semester = _getCurrentTerm();
      final academicYear = _getCurrentAcademicYear();
      possibleCacheKeys.add(
        'schedule_teacher_${teacherId}_${semester}_$academicYear',
      );

      for (final key in possibleCacheKeys) {
        try {
          final cached = await LocalCacheService.load(
            key,
            ttl: const Duration(hours: 3),
          );
          if (cached != null) {
            final cachedData = Map<String, dynamic>.from(cached);
            final allSchedules = List<dynamic>.from(cachedData['schedules'] ?? []);

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

              AppLogger.debug(
                'attendance',
                'Detected today schedule from teaching_schedule cache (${todaySchedules.length} items)',
              );
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
            final startTime =
                (schedule['jam_mulai'] ?? schedule['start_time'] ?? '')
                    .toString();
            final endTime =
                (schedule['jam_selesai'] ?? schedule['end_time'] ?? '')
                    .toString();

            if (_isWithinScheduleTime(startTime, endTime)) {
              currentSchedule = schedule;
              break;
            }
          }

          if (currentSchedule != null) {
            _selectedSubjectId =
                (currentSchedule['mata_pelajaran_id'] ??
                        currentSchedule['subject_id'])
                    ?.toString();
            _selectedClassId =
                (currentSchedule['kelas_id'] ?? currentSchedule['class_id'])
                    ?.toString();
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
        final cached = await LocalCacheService.load(
          summaryCacheKey,
          ttl: const Duration(hours: 1),
        );
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
          AppLogger.info(
            'attendance',
            'Loaded ${_attendanceSummaryList.length} summaries from cache',
          );
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
      final academicYearId = ref
          .read(academicYearRiverpod)
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
        final cacheData = sortedList
            .map(
              (s) => {
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
              },
            )
            .toList();
        await LocalCacheService.save(summaryCacheKey, cacheData);
      }

      AppLogger.info(
        'attendance',
        'Loaded ${_attendanceSummaryList.length} absensi summaries',
      );
    } catch (e) {
      AppLogger.error('attendance', 'Error loading absensi summary: $e');
      if (mounted) {
        if (_attendanceSummaryList.isEmpty) {
          setState(() => _isLoadingSummary = false);
        }
      }
    }
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
      builder: (_) => AttendanceQuickActionsSheet(
        languageProvider: languageProvider,
        onStatusSelected: (status) => _setAllStatus(status, languageProvider),
      ),
    );
  }

  void _setAllStatus(String status, LanguageProvider languageProvider) {
    setState(() {
      for (var student in _filteredStudentList) {
        _attendanceStatus[student.id] = status;
      }
    });

    SnackBarUtils.showInfo(
      context,
      languageProvider.getTranslatedText({
        'en':
            'All students set to ${_getStatusText(status, languageProvider).toLowerCase()}',
        'id':
            'Semua siswa diatur menjadi ${_getStatusText(status, languageProvider).toLowerCase()}',
      }),
    );
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
  // _buildModeSwitcher was inlined into AttendanceTeacherHeader -- removed.

  // ========== CLASS LIST VIEW ==========
  Widget _buildInlineClassList(LanguageProvider languageProvider) {
    // Delegated to AttendanceTeacherClassList widget.
    return AttendanceTeacherClassList(
      classList: _classList,
      primaryColor: _getPrimaryColor(),
      languageProvider: languageProvider,
      onClassSelected: (classData) {
        setState(() {
          _selectedClassId = classData['id'];
        });
        _loadSubjectsByClass(classData['id']);
        if (_tabController.index == 0) {
          _loadAttendanceSummary();
        }
      },
    );
  }

  // ========== MODE 0: VIEW RESULTS ==========
  /// Builds the "View Results" tab UI. Delegated to [AttendanceResultsMode].
  Widget _buildResultsMode() {
    final languageProvider = ref.watch(languageRiverpod);
    return AttendanceResultsMode(
      selectedClassId: _selectedClassId,
      isLoadingSummary: _isLoadingSummary,
      filteredSummaries: _getFilteredSummaries(),
      searchController: _searchController,
      hasActiveFilter: _hasActiveFilter,
      filterChips: _buildFilterChips(languageProvider),
      primaryColor: _getPrimaryColor(),
      classListWidget: _buildInlineClassList(languageProvider),
      searchFilterBarWidget: _buildSearchAndFilter(languageProvider),
      onClearAllFilters: _clearAllFilters,
      onNavigateToDetail: _navigateToAttendanceDetail,
      onDelete: (summary) => _deleteAttendance(summary, languageProvider),
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

  // ========== HEADER BARU SEPERTI ADMIN PRESENCE ==========
  Widget _buildHeader(LanguageProvider languageProvider) {
    // Delegated to AttendanceTeacherHeader widget.
    return AttendanceTeacherHeader(
      tabController: _tabController,
      tabSwitcherKey: _tabSwitcherKey,
      primaryColor: _getPrimaryColor(),
      gradient: _getCardGradient(),
      currentTabIndex: _tabController.index,
      hasClassSelected: _selectedClassId != null,
      languageProvider: languageProvider,
      onBack: () {
        if (_selectedClassId != null) {
          setState(() {
            _selectedClassId = null;
            _studentList = [];
          });
        } else {
          AppNavigator.pop(context);
        }
      },
      onRefresh: _forceRefresh,
    );
  }

  // ========== SEARCH BAR WITH FILTER LIKE ADMIN ==========
  Widget _buildSearchAndFilter(LanguageProvider languageProvider) {
    // Delegated to AttendanceSearchFilterBar widget.
    return AttendanceSearchFilterBar(
      searchController: _searchController,
      searchFilterKey: _searchFilterKey,
      hasActiveFilter: _hasActiveFilter,
      primaryColor: _getPrimaryColor(),
      showFilterButton: _tabController.index == 0,
      languageProvider: languageProvider,
      onSearchChanged: () => setState(() {}),
      onFilterTap: _showFilterSheet,
    );
  }

  // ========== FILTER SHEET SEPERTI ADMIN ==========
  void _showFilterSheet() {
    final languageProvider = ref.read(languageRiverpod);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AttendanceFilterSheet(
        languageProvider: languageProvider,
        primaryColor: _getPrimaryColor(),
        initialDateFilter: _selectedDateFilter,
        initialSubjectIds: _selectedSubjectIds,
        initialDayIds: _selectedDayIds,
        initialLessonHourIds: _selectedLessonHourIds,
        subjects: _subjectTeacher,
        lessonHours: _lessonHours,
        onApply: (result) {
          setState(() {
            _selectedDateFilter = result.dateFilter;
            _selectedSubjectIds = result.subjectIds;
            _selectedDayIds = result.dayIds;
            _selectedLessonHourIds = result.lessonHourIds;
            _checkActiveFilter();
          });
        },
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

  void _navigateToAttendanceDetail(AttendanceSummaryItem summary) {
    AppNavigator.push(
      context,
      TeacherAttendanceDetailPage(
        subjectId: summary.subjectId,
        subjectName: summary.subjectName,
        date: summary.date,
        classId: summary.classId ?? '',
        className: summary.className ?? 'Unknown Class',
        teacher: widget.teacher,
        lessonHourId: summary.lessonHourId,
        lessonHourName: summary.lessonHourName,
      ),
    );
  }

  // ========== MODE 2: INPUT ABSENSI (REDESIGNED) ==========
  /// Builds the "Input Attendance" tab UI. Delegated to [AttendanceInputMode].
  Widget _buildInputMode() {
    final languageProvider = ref.watch(languageRiverpod);
    return AttendanceInputMode(
      isLoadingInput: _isLoadingInput,
      inputFormWidget: AttendanceInputForm(
        selectedDate: _selectedDate,
        selectedLessonHourId: _selectedLessonHourId,
        lessonHours: _lessonHours,
        selectedClassId: _selectedClassId,
        classList: _classList,
        selectedSubjectId: _selectedSubjectId,
        subjectTeacher: _subjectTeacher,
        primaryColor: _getPrimaryColor(),
        languageProvider: languageProvider,
        embedded: widget.embedded,
        initialClassName: widget.initialClassName,
        initialSubjectName: widget.initialSubjectName,
        initialLessonHourNumber: widget.initialLessonHourNumber,
        onDatePicked: (picked) {
          setState(() {
            _selectedDate = picked;
            _detectCurrentSchedule();
          });
        },
        onLessonHourChanged: (value) {
          setState(() {
            _selectedLessonHourId = value;
          });
        },
        onClassChanged: (value) {
          setState(() {
            _selectedClassId = value;
            _filterStudentsByClass(value);
          });
          _loadSubjectsByClass(value);
        },
        onSubjectChanged: (value) {
          setState(() {
            _selectedSubjectId = value;
          });
        },
        onQuickActionsPressed: () => _showQuickActionsSheet(languageProvider),
      ),
      selectedSubjectId: _selectedSubjectId,
      filteredStudentList: _filteredStudentList,
      attendanceStatus: _attendanceStatus,
      isSubmitting: _isSubmitting,
      primaryColor: _getPrimaryColor(),
      searchController: _searchControllerInput,
      onSearchChanged: _filterStudents,
      onQuickActionsPressed: () => _showQuickActionsSheet(languageProvider),
      onStatusChanged: (studentId, status) {
        setState(() {
          _attendanceStatus[studentId] = status;
        });
      },
      onSubmit: _submitAttendance,
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
      SnackBarUtils.showError(
        context,
        languageProvider.getTranslatedText({
          'en': 'Invalid teacher data. Please login again.',
          'id': 'Data guru tidak valid. Silakan login ulang.',
        }),
      );
      return;
    }

    if (_selectedSubjectId == null) {
      SnackBarUtils.showError(
        context,
        languageProvider.getTranslatedText({
          'en': 'Please select a subject first',
          'id': 'Pilih mata pelajaran terlebih dahulu',
        }),
      );
      return;
    }

    if (_filteredStudentList.isEmpty) {
      SnackBarUtils.showError(
        context,
        languageProvider.getTranslatedText({
          'en': 'No students to save',
          'id': 'Tidak ada siswa untuk disimpan',
        }),
      );
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
          AppLogger.error(
            'attendance',
            'Attendance save error for ${student.name}: $e',
          );

          // Clean user-friendly message
          final String cleanerMessage = e.toString().replaceAll(
            'Exception: ',
            '',
          );
          errorMessages.add('${student.name}: $cleanerMessage');
        }
      }

      if (!mounted) return;

      // Tampilkan hasil
      if (errorCount == 0) {
        SnackBarUtils.showSuccess(
          context,
          languageProvider.getTranslatedText({
            'en': 'Attendance successfully saved for $successCount students',
            'id': 'Absensi berhasil disimpan untuk $successCount siswa',
          }),
        );

        // Reset form setelah berhasil
        _resetForm();

        // Pindah ke tab Hasil (index 0)
        _tabController.animateTo(0);
      } else {
        SnackBarUtils.showWarning(
          context,
          languageProvider.getTranslatedText({
            'en': '$successCount successful, $errorCount failed',
            'id': '$successCount berhasil, $errorCount gagal',
          }),
        );
        _showErrorDetails(errorMessages, languageProvider);
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        '${languageProvider.getTranslatedText({'en': 'Error:', 'id': 'Error:'})} $e',
      );
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

      SnackBarUtils.showSuccess(
        context,
        languageProvider.getTranslatedText({
          'en': 'Attendance deleted successfully',
          'id': 'Absensi berhasil dihapus',
        }),
      );

      // Reload summary data
      _loadAttendanceSummary();
    } catch (e) {
      AppLogger.error('attendance', 'Delete attendance error: $e');
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);

    if (widget.embedded) {
      return Scaffold(
        backgroundColor: ColorUtils.slate50,
        appBar: AppBar(
          backgroundColor: _getPrimaryColor(),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            '${languageProvider.getTranslatedText({'en': 'Attendance', 'id': 'Presensi'})} — ${widget.initialSubjectName ?? ''} ${widget.initialClassName ?? ''}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          elevation: 0,
        ),
        body: _tabController.index == 0
            ? _buildResultsMode()
            : _buildInputMode(),
      );
    }

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _buildHeader(languageProvider),
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
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'presence_teacher_screen',
        'guru',
      );
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
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
    final List<TargetFocus> targets = _createTourTargets(_tabSwitcherKey, _searchFilterKey);
    if (targets.isEmpty) return;

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "LEWATI",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        getIt<ApiTourService>().completeTour(
          name: 'presence_teacher_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('presence_teacher_screen', 'guru'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'presence_teacher_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('presence_teacher_screen', 'guru'),
          {'should_show': false},
        );
        return true;
      },
    ).show(context: context);
  }

}
