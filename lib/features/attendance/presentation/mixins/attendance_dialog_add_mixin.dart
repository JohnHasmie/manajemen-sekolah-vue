import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_data_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_dialog_shared_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_input_picker_sheet.dart';

/// Handles the "Add Attendance" bottom-sheet dialog flow
mixin AttendanceDialogAddMixin
    on
        ConsumerState<AttendancePage>,
        AttendanceDataMixin,
        AttendanceDialogSharedMixin {
  // ── Abstract state accessors ──

  @override
  Color get primaryColor;

  void openInputSheet({
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
    String? lessonHourId,
    String? lessonHourName,
  });

  // ═══════════════════════════════════════════
  // ADD ATTENDANCE FLOW
  // ═══════════════════════════════════════════
  //
  // The legacy chip picker (Pilih Kelas + Pilih Mapel) was replaced
  // by the schedule-driven Ambil Presensi sheet — see
  // `attendance_input_picker_sheet.dart` for the design + flow.
  // The new sheet leads with today's actual teaching slots and falls
  // back to a manual date+class+subject picker when nothing is
  // scheduled or the teacher needs an off-schedule entry.

  void showAddAttendanceFlow(LanguageProvider lp) async {
    final ayId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
    final pick = await showAmbilPresensiSheet(
      context: context,
      lp: lp,
      teacherId: teacherId,
      classList: classList,
      academicYearId: ayId,
    );
    if (pick == null || !mounted) return;
    // Forward the picked session's lesson_hour_id so the input
    // form saves attendance under the right slot. Without this the
    // form persists lesson_hour_id = NULL and the teacher-calendar
    // GET later groups by (class, subject, lesson_hour_id) and
    // can't match the saved rows against the session card — the
    // "Belum diabsen" pill stays even after a successful save, and
    // overlapping JAM-KE-N sessions for different classes (e.g.
    // 8A and 8B at the same lesson hour) collapse into the same
    // NULL group.
    openInputSheet(
      classId: pick.classId,
      className: pick.className,
      subjectId: pick.subjectId,
      subjectName: pick.subjectName,
      lessonHourId: pick.lessonHourId,
      lessonHourName: pick.lessonHourName,
    );
  }
}
