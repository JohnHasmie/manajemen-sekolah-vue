import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';

/// Handles all data-loading logic for the teacher
/// attendance screen: user resolution, grouped /
/// timeline fetching, embedded-mode student loading,
/// and cache helpers.
mixin AttendanceDataMixin on ConsumerState<AttendancePage> {
  // ── Abstract state accessors ──
  // Implemented by the main State class.

  String get teacherId;
  set teacherId(String v);

  String get teacherNama;
  set teacherNama(String v);

  List<dynamic> get classList;
  set classList(List<dynamic> v);

  List<dynamic> get lessonHours;
  set lessonHours(List<dynamic> v);

  List<dynamic> get homeroomClassesList;
  set homeroomClassesList(List<dynamic> v);

  Map<String, dynamic>? get selectedHomeroomClass;
  set selectedHomeroomClass(Map<String, dynamic>? v);

  bool get isLoading;
  set isLoading(bool v);

  bool get isLoadingMore;
  set isLoadingMore(bool v);

  int get currentPage;
  set currentPage(int v);

  bool get hasMoreData;
  set hasMoreData(bool v);

  List<dynamic> get groupedAttendance;
  set groupedAttendance(List<dynamic> v);

  bool get isHomeroomView;
  String? get filterClassId;
  String? get filterSubjectId;
  String? get filterDateOption;
  TextEditingController get searchController;

  // Timeline state
  List<dynamic> get timelineAttendance;
  set timelineAttendance(List<dynamic> v);
  bool get timelineHasMore;
  set timelineHasMore(bool v);
  bool get timelineLoadingMore;
  set timelineLoadingMore(bool v);
  bool get isTimelineView;

  // Embedded / input state
  List<Student> get studentList;
  set studentList(List<Student> v);
  List<Student> get filteredStudentList;
  set filteredStudentList(List<Student> v);
  Map<String, String> get attendanceStatus;
  bool get isLoadingInput;
  set isLoadingInput(bool v);

  // Methods from other parts of the state
  void detectCurrentLessonHour();
  Future<void> loadSubjectsByClass(String? classId);
  void setAttendanceError(String? message);

  // ═══════════════════════════════════════════
  // USER DATA LOADING
  // ═══════════════════════════════════════════

  Future<void> loadUserData() async {
    final _tm = Teacher.fromJson(widget.teacher);
    String tid = _tm.id;
    String tname = _tm.name;

    // Try TeacherProvider
    if (tid.isEmpty) {
      final tp = ref.read(teacherRiverpod);
      if (tp.isLoaded) {
        tid = tp.teacherId ?? '';
        tname = tp.teacherName ?? '';
      }
    }

    // Try API lookup
    if (tid.isEmpty) {
      try {
        final prefs = await getIt<ApiTeacherService>().getTeacherByUserId(tid);
        tid = prefs?['id']?.toString() ?? '';
        tname = prefs?['nama']?.toString() ?? prefs?['name']?.toString() ?? '';
      } catch (_) {}
    }

    if (tid.isEmpty) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    teacherId = tid;
    teacherNama = tname;
    await loadInitialData(tid);
  }

  Future<void> loadInitialData(String teacherId) async {
    setState(() => isLoading = true);
    try {
      final ayId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      // Load lesson hours (cached) while the combined summary+classes
      // request runs — just one network round-trip instead of two.
      final hoursFuture = loadWithCache(
        cacheKey: 'school_lesson_hour_data',
        ttl: const Duration(hours: 24),
        apiFetcher: () => getIt<ApiScheduleService>().getJamPelajaran(),
      );

      final summaryResult = await AttendanceService.getTeacherAttendanceSummary(
        teacherId: teacherId,
        academicYearId: ayId,
        page: 1,
        perPage: 20,
        includeClasses: true, // piggy-back classes in the same request
      );

      final hours = await hoursFuture;
      if (!mounted) return;

      // Extract classes from the combined response.
      final classes =
          (summaryResult['teacher_classes'] as List?)
              ?.map((c) => Map<String, dynamic>.from(c as Map))
              .toList() ??
          [];
      final homeroom = classes.where((c) => c['is_homeroom'] == true).toList();

      final data = (summaryResult['data'] as List?) ?? [];
      final pagination = summaryResult['pagination'];

      setAttendanceError(null);
      setState(() {
        classList = classes;
        lessonHours = hours;
        homeroomClassesList = homeroom;
        if (homeroom.isNotEmpty && selectedHomeroomClass == null) {
          selectedHomeroomClass = homeroom.first;
        }
        groupedAttendance = data;
        hasMoreData = pagination?['has_next_page'] == true;
        currentPage = 1;
        isLoading = false;
      });
    } catch (e) {
      AppLogger.error('attendance', 'Error loading initial data: $e');
      if (mounted) {
        setState(() => isLoading = false);
        setAttendanceError(ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  // ═══════════════════════════════════════════
  // EMBEDDED DATA LOADING
  // ═══════════════════════════════════════════

  Future<void> loadEmbeddedData() async {
    try {
      final ayId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      final [stuList, hours] = await Future.wait([
        loadWithCache(
          cacheKey:
              'class_student_data_'
              '${widget.initialclassId}_$ayId',
          ttl: const Duration(hours: 6),
          apiFetcher: () => getIt<ApiStudentService>().getStudentByClass(
            widget.initialclassId!,
            academicYearId: ayId,
          ),
        ),
        loadWithCache(
          cacheKey: 'school_lesson_hour_data',
          ttl: const Duration(hours: 24),
          apiFetcher: () => getIt<ApiScheduleService>().getJamPelajaran(),
        ),
      ]);

      if (!mounted) return;

      setState(() {
        studentList = stuList.map((s) => Student.fromJson(s)).toList();
        filteredStudentList = studentList;
        lessonHours = _deduplicateHours(hours);
        for (final s in studentList) {
          attendanceStatus[s.id] = 'hadir';
        }
        isLoadingInput = false;
      });

      detectCurrentLessonHour();

      // Load subjects for the pre-selected class so the subject dropdown
      // is populated in embedded mode (e.g. opened from schedule card).
      if (widget.initialclassId != null) {
        loadSubjectsByClass(widget.initialclassId!);
      }

      // Edit-mode hydration. When the sheet was opened from a session
      // detail page (`Update Kehadiran` / `Edit Attendance`) the form
      // previously defaulted every student to 'hadir', wiping out the
      // existing record. Fetch what's actually stored for the
      // date+subject+class[+lesson hour] tuple and override the
      // defaults before the user starts editing.
      await _hydrateExistingAttendance();
    } catch (e) {
      AppLogger.error('attendance', 'Error loading embedded data: $e');
      if (mounted) {
        setState(() => isLoadingInput = false);
      }
    }
  }

  /// Pulls existing attendance records for the open (date, subject,
  /// class[, lesson hour]) tuple and overrides the `attendanceStatus`
  /// map. No-op when the tuple is incomplete or when the API call
  /// returns nothing — that's the genuine "new session" case where
  /// the default 'hadir' is the right starting point.
  Future<void> _hydrateExistingAttendance() async {
    final subjectId = widget.initialSubjectId;
    final classId = widget.initialclassId;
    final date = widget.initialDate;
    if (subjectId == null || classId == null || date == null) return;

    String? lessonHourId;
    // Prefer the exact lesson_hour_id when the caller had it (Jadwal
    // → presensi flow). The lookup-by-hour_number fallback only fires
    // for callers that genuinely don't know the UUID (e.g. the
    // session-detail "Update Kehadiran" path which parses a number
    // out of "Jam ke-5"). Without this, hydration would
    // `firstWhere((lh) => lh['hour_number'] == N)` on the global
    // lesson-hour list and pick whatever day's slot matched first —
    // typically not the user's day — locking the form to another
    // day's already-saved records.
    final providedId = widget.initialLessonHourId;
    if (providedId != null && providedId.isNotEmpty) {
      lessonHourId = providedId;
    } else if (widget.initialLessonHourNumber != null) {
      final match = lessonHours.cast<Map<dynamic, dynamic>>().firstWhere(
        (lh) => lh['hour_number'] == widget.initialLessonHourNumber,
        orElse: () => const <dynamic, dynamic>{},
      );
      final id = match['id'];
      if (id != null) lessonHourId = id.toString();
    }

    try {
      final dateStr =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final existing = await AttendanceService.getAttendance(
        teacherId: teacherId.isNotEmpty ? teacherId : null,
        subjectId: subjectId,
        classId: classId,
        date: dateStr,
        lessonHourId: lessonHourId,
      );
      if (!mounted || existing.isEmpty) return;

      setState(() {
        for (final att in existing) {
          attendanceStatus[att.studentId] = _normalizeStatus(att.status);
        }
      });
    } catch (e) {
      // Hydration failure is non-fatal — the form still works with
      // the 'hadir' default and the user can re-enter what they need.
      AppLogger.error('attendance', 'hydrate existing attendance: $e');
    }
  }

  /// Normalises the various status values the backend may persist
  /// ("Present", "hadir", "late", "Terlambat", …) into the lowercase
  /// Indonesian token the input form's status segments use.
  String _normalizeStatus(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'present':
      case 'hadir':
        return 'hadir';
      case 'late':
      case 'terlambat':
        return 'terlambat';
      case 'sick':
      case 'sakit':
        return 'sakit';
      case 'excused':
      case 'permit':
      case 'permission':
      case 'izin':
        return 'izin';
      case 'absent':
      case 'alpha':
        return 'alpha';
      default:
        return raw.trim().toLowerCase();
    }
  }

  List<dynamic> _deduplicateHours(List<dynamic> hours) {
    final seen = <String>{};
    return hours.where((lh) {
      final key =
          '${lh['hour_number'] ?? lh['name']}'
          '_${lh['start_time']}_${lh['end_time']}';
      return seen.add(key);
    }).toList();
  }

  // ═══════════════════════════════════════════
  // GROUPED ATTENDANCE
  // ═══════════════════════════════════════════

  Future<void> refreshGroupedAttendance() async {
    setState(() {
      currentPage = 1;
      hasMoreData = true;
      groupedAttendance = [];
      isLoading = true;
    });
    await fetchGroupedAttendance();
  }

  Future<void> loadMoreGroupedAttendance() async {
    if (isLoadingMore || !hasMoreData) return;
    setState(() {
      currentPage = currentPage + 1;
      isLoadingMore = true;
    });
    await fetchGroupedAttendance();
  }

  Future<void> fetchGroupedAttendance() async {
    final ayId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
    try {
      final hcId = selectedHomeroomClass?['id']?.toString();
      final result = await AttendanceService.getTeacherAttendanceSummary(
        teacherId: isHomeroomView ? null : teacherId,
        classId: isHomeroomView ? hcId : filterClassId,
        academicYearId: ayId,
        subjectId: filterSubjectId,
        search: searchController.text.isNotEmpty ? searchController.text : null,
        dateFilter: filterDateOption,
        page: currentPage,
        perPage: 20,
        // Signal wali-kelas scope so the backend groups by teacher too and
        // returns teacher_id + teacher_name on each card.
        view: isHomeroomView ? 'wali_kelas' : 'mengajar',
      );
      if (!mounted) return;
      final data = (result['data'] as List?) ?? [];
      final pagination = result['pagination'];
      setAttendanceError(null);
      setState(() {
        if (currentPage == 1) {
          groupedAttendance = data;
        } else {
          _mergeNewGroups(data);
        }
        hasMoreData = pagination?['has_next_page'] == true;
        isLoading = false;
        isLoadingMore = false;
      });
    } catch (e) {
      AppLogger.error('attendance', 'Error fetching grouped attendance: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          isLoadingMore = false;
        });
        setAttendanceError(ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  void _mergeNewGroups(List<dynamic> data) {
    // In wali mode the backend groups by (class, subject, teacher), so the
    // dedup key must match — otherwise pages 2+ will drop legitimate rows
    // for the same class/subject taught by a different teacher.
    String keyOf(dynamic g) {
      final base = '${g['class_id']}__${g['subject_id']}';
      if (isHomeroomView) {
        return '$base'
            '__${g['teacher_id'] ?? ''}';
      }
      return base;
    }

    final existing = groupedAttendance.map(keyOf).toSet();
    for (final g in data) {
      if (!existing.contains(keyOf(g))) {
        groupedAttendance.add(g);
      }
    }
  }

  // ═══════════════════════════════════════════
  // TIMELINE
  // ═══════════════════════════════════════════

  Future<void> refreshTimeline() async {
    setState(() {
      timelineHasMore = false;
      timelineAttendance = [];
      isLoading = true;
    });
    await fetchTimeline();
  }

  Future<void> fetchTimeline() async {
    final ayId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
    try {
      final hcId = selectedHomeroomClass?['id']?.toString();
      final result = await AttendanceService.getAttendanceSummary(
        teacherId: isHomeroomView ? null : teacherId,
        classId: isHomeroomView ? hcId : filterClassId,
        subjectId: filterSubjectId,
        academicYearId: ayId,
      );
      if (!mounted) return;
      setAttendanceError(null);
      setState(() {
        timelineAttendance = result;
        timelineHasMore = false;
        isLoading = false;
        timelineLoadingMore = false;
      });
    } catch (e) {
      AppLogger.error('attendance', 'Error fetching timeline: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          timelineLoadingMore = false;
        });
        setAttendanceError(ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> forceRefresh() async {
    await LocalCacheService.clearStartingWith('presence_');
    if (isTimelineView) {
      refreshTimeline();
    } else {
      refreshGroupedAttendance();
    }
  }

  // ═══════════════════════════════════════════
  // CACHE HELPER
  // ═══════════════════════════════════════════

  Future<List<dynamic>> loadWithCache({
    required String cacheKey,
    required Duration ttl,
    required Future<List<dynamic>> Function() apiFetcher,
    bool useCache = true,
  }) async {
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
    final data = await apiFetcher();
    if (data.isNotEmpty) {
      LocalCacheService.save(cacheKey, data);
    }
    return data;
  }
}
