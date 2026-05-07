import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// Handles input mode state and submission logic:
/// student filtering, attendance status tracking,
/// lesson hour detection, and bulk attendance submission.
mixin AttendanceInputMixin on ConsumerState<AttendancePage> {
  // ── Abstract state accessors ──

  List<Student> get studentList;
  set studentList(List<Student> v);

  List<Student> get filteredStudentList;
  set filteredStudentList(List<Student> v);

  Map<String, String> get attendanceStatus;

  bool get isLoadingInput;
  set isLoadingInput(bool v);

  List<dynamic> get lessonHours;
  set lessonHours(List<dynamic> v);

  String get teacherId;

  List<dynamic> get classList;

  String? get selectedClassId;

  // Methods that subclass may access
  void detectCurrentLessonHour();

  // ═══════════════════════════════════════════
  // INPUT MODE SUBMISSION
  // ═══════════════════════════════════════════

  Future<void> submitAttendance() async {
    final lp = ref.read(languageRiverpod);
    final tid = Teacher.fromJson(widget.teacher).id;

    // Validation
    if (tid.isEmpty) {
      SnackBarUtils.showError(
        context,
        lp.getTranslatedText({
          'en': 'Invalid teacher data. Please login again.',
          'id': 'Data guru tidak valid. Silakan login ulang.',
        }),
      );
      return;
    }

    final selectedSubjectId = getInputSelectedSubjectId();
    if (selectedSubjectId == null) {
      SnackBarUtils.showError(
        context,
        lp.getTranslatedText({
          'en': 'Please select a subject first',
          'id': 'Pilih mata pelajaran terlebih dahulu',
        }),
      );
      return;
    }

    if (filteredStudentList.isEmpty) {
      SnackBarUtils.showError(
        context,
        lp.getTranslatedText({
          'en': 'No students to save',
          'id': 'Tidak ada siswa untuk disimpan',
        }),
      );
      return;
    }

    setState(() => setInputIsSubmitting(true));
    try {
      final selectedDate = getInputSelectedDate();
      final date = DateFormat('yyyy-MM-dd').format(selectedDate);

      final attendances = filteredStudentList.map((s) {
        final status = attendanceStatus[s.id] ?? 'hadir';
        return {
          'student_id': s.id,
          'status': _mapStatusToBackend(status),
          'notes': '',
        };
      }).toList();

      final result = await AttendanceService.createBulkAttendance(
        teacherId: tid.toString(),
        subjectId: selectedSubjectId,
        classId: filteredStudentList.first.classId ?? selectedClassId ?? '',
        date: date,
        lessonHourId: getInputSelectedLessonHourId(),
        attendances: attendances,
      );

      if (!mounted) return;

      final ok = result['success'] ?? 0;
      final fail = result['failed'] ?? 0;

      if (fail == 0) {
        SnackBarUtils.showSuccess(
          context,
          lp.getTranslatedText({
            'en': 'Attendance saved for $ok students',
            'id': 'Absensi disimpan untuk $ok siswa',
          }),
        );
        if (widget.embedded && mounted) {
          Navigator.of(context).pop();
          return;
        }
      } else {
        SnackBarUtils.showWarning(
          context,
          lp.getTranslatedText({
            'en': '$ok saved, $fail failed',
            'id': '$ok berhasil, $fail gagal',
          }),
        );
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
    } finally {
      if (mounted) {
        setState(() => setInputIsSubmitting(false));
      }
    }
  }

  // ═══════════════════════════════════════════
  // STUDENT FILTERING
  // ═══════════════════════════════════════════

  void filterStudents() {
    final term = getInputSearchText().toLowerCase();
    setState(() {
      filteredStudentList = studentList.where((s) {
        final matchSearch =
            term.isEmpty ||
            s.name.toLowerCase().contains(term) ||
            s.studentNumber.toLowerCase().contains(term);
        final matchStatus =
            getInputSelectedStatusFilter() == null ||
            (attendanceStatus[s.id] ?? 'hadir') ==
                getInputSelectedStatusFilter();
        final matchClass =
            selectedClassId == null || s.classId == selectedClassId;
        return matchSearch && matchStatus && matchClass;
      }).toList();
    });
  }

  // ═══════════════════════════════════════════
  // LESSON HOUR DETECTION
  // ═══════════════════════════════════════════

  void detectLessonHour() {
    // Prefer the exact lesson_hour_id when the caller had it (Jadwal
    // → presensi flow). Same-day-different-day collision avoidance:
    // each (day, hour_number) tuple has its own UUID; matching by
    // hour_number alone picks whichever day's slot happens to come
    // first in the list, which is rarely the schedule the user
    // actually tapped on.
    final providedId = widget.initialLessonHourId;
    if (providedId != null && providedId.isNotEmpty) {
      setState(() => setInputSelectedLessonHourId(providedId));
      return;
    }

    if (widget.initialLessonHourNumber != null) {
      for (final lh in lessonHours) {
        final hourNum = lh['hour_number'] ?? lh['jam_ke'];
        if (hourNum?.toString() == widget.initialLessonHourNumber.toString()) {
          setState(() => setInputSelectedLessonHourId(lh['id']?.toString()));
          return;
        }
      }
    }

    for (final lh in lessonHours) {
      final start = (lh['start_time'] ?? lh['jam_mulai'])?.toString() ?? '';
      final end = (lh['end_time'] ?? lh['jam_selesai'])?.toString() ?? '';
      if (_isWithinScheduleTime(start, end)) {
        setState(() => setInputSelectedLessonHourId(lh['id']?.toString()));
        return;
      }
    }
  }

  // ═══════════════════════════════════════════
  // LOAD SUBJECTS BY CLASS
  // ═══════════════════════════════════════════

  Future<void> loadSubjectsByClass(String? classId) async {
    if (classId == null) return;
    try {
      final subjects = await getIt<ApiTeacherService>().getSubjectByTeacher(
        teacherId,
        classId: classId,
      );
      if (mounted) {
        setState(() => setInputSubjectTeacher(subjects));
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════
  // HELPER METHODS (subclass must provide)
  // ═══════════════════════════════════════════

  // These are state accessors that will be implemented by the screen class.
  // Must be PUBLIC (no underscore) so they resolve across library boundaries.
  DateTime getInputSelectedDate();
  String? getInputSelectedSubjectId();
  String? getInputSelectedLessonHourId();
  void setInputSelectedLessonHourId(String? v);
  void setInputIsSubmitting(bool v);
  String? getInputSelectedStatusFilter();
  String getInputSearchText();
  void setInputSubjectTeacher(List<dynamic> v);

  // ─────────────────────────────────────────
  // STATIC HELPERS
  // ─────────────────────────────────────────

  static bool _isWithinScheduleTime(String jamMulai, String jamSelesai) {
    if (jamMulai.isEmpty || jamSelesai.isEmpty) {
      return false;
    }
    try {
      final now = TimeOfDay.now();
      final sp = jamMulai.split(':');
      final ep = jamSelesai.split(':');
      final start = TimeOfDay(
        hour: int.parse(sp[0]),
        minute: int.parse(sp[1].split('.')[0]),
      );
      final end = TimeOfDay(
        hour: int.parse(ep[0]),
        minute: int.parse(ep[1].split('.')[0]),
      );
      final nowM = now.hour * 60 + now.minute;
      final sM = start.hour * 60 + start.minute;
      final eM = end.hour * 60 + end.minute;
      return nowM >= sM && nowM <= eM;
    } catch (e) {
      AppLogger.error('attendance', 'Error parsing time: $e');
      return false;
    }
  }

  static String _mapStatusToBackend(String status) {
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
}
