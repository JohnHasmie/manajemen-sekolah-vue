import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/widgets/app_draggable_sheet.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_detail.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_date_slot_picker.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_quick_actions_sheet.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_detail_sheet.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';

/// Handles view toggle, bottom sheet navigation, and
/// core action flows for the teacher attendance screen.
mixin AttendanceNavigationMixin on ConsumerState<AttendancePage> {
  // ── Abstract state accessors ──

  Color get primaryColor;
  String get teacherId;
  String get teacherNama;
  List<dynamic> get classList;
  List<dynamic> get lessonHours;
  List<Student> get filteredStudentList;
  Map<String, String> get attendanceStatus;
  bool get isHomeroomView;
  bool get isTimelineView;
  set isTimelineView(bool v);

  List<dynamic> get timelineAttendance;
  set timelineAttendance(List<dynamic> v);
  bool get timelineHasMore;
  set timelineHasMore(bool v);
  bool get timelineLoadingMore;
  set timelineLoadingMore(bool v);

  Future<void> refreshGroupedAttendance();
  Future<void> refreshTimeline();
  Future<void> loadMoreGroupedAttendance();
  void detectLessonHour();

  // ═══════════════════════════════════════════
  // CORE NAVIGATION & ACTIONS
  // ═══════════════════════════════════════════

  @override
  void toggleView() {
    setState(() => isTimelineView = !isTimelineView);
    LocalCacheService.save('absensi_view_preference', {
      'is_timeline': isTimelineView,
    });
    if (isTimelineView && timelineAttendance.isEmpty) {
      refreshTimeline();
    }
  }

  /// Tap behaviour for a session card on Presensi.
  ///
  /// Per the brand-migration mockup (Frame B from
  /// `_design/teacher_attendance_detail_mockup.html`), tapping a card
  /// should jump directly to the detail/edit screen for that specific
  /// session — not show another sheet listing every date for the
  /// class+subject combo. We pull the latest session's date and
  /// lesson-hour-id from `latest_records[0]` (with `latest_date` /
  /// `latest_lesson_hour_id` as fallbacks) and navigate.
  ///
  /// If the group has no resolvable session yet (e.g. a freshly
  /// scheduled slot with zero records), we fall back to the all-dates
  /// sheet via [openAttendanceDetailSheet] so the teacher can still
  /// open Ambil Presensi via the FAB inside.
  @override
  void openAttendanceDetail({
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
    String? teacherId,
    Map<String, dynamic>? group,
  }) {
    final dyn = group;
    final latestRecords = (dyn?['latest_records'] as List?) ?? const [];
    final latestRow = latestRecords.isNotEmpty ? latestRecords.first : null;
    final dateStr =
        (latestRow is Map ? latestRow['date']?.toString() : null) ??
        dyn?['latest_date']?.toString();
    final lessonHourId =
        (latestRow is Map ? latestRow['lesson_hour_id']?.toString() : null) ??
        dyn?['latest_lesson_hour_id']?.toString();
    final lessonHourName =
        (latestRow is Map ? latestRow['lesson_hour_name']?.toString() : null) ??
        dyn?['latest_lesson_hour_name']?.toString();

    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    if (date == null) {
      // No resolvable session yet — surface the all-dates sheet so the
      // teacher can pick (or create) one via Ambil Presensi.
      openAttendanceDetailSheet(
        classId: classId,
        className: className,
        subjectId: subjectId,
        subjectName: subjectName,
        teacherId: teacherId,
      );
      return;
    }

    AppNavigator.push(
      context,
      TeacherAttendanceDetailPage(
        subjectId: subjectId,
        subjectName: subjectName,
        classId: classId,
        className: className,
        date: date,
        teacher: {'id': this.teacherId, 'nama': teacherNama},
        lessonHourId: lessonHourId,
        lessonHourName: lessonHourName,
        canEdit: !isHomeroomView,
        filterTeacherId: teacherId ?? (isHomeroomView ? null : this.teacherId),
      ),
    ).then((_) => refreshGroupedAttendance());
  }

  /// All-dates sheet (the previous default tap behaviour). Kept around
  /// for the fallback case above and as a future "Lihat Semua" entry
  /// point — long-press / overflow menu / View All chevron.
  void openAttendanceDetailSheet({
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
    String? teacherId,
  }) {
    AppDraggableSheet.show<void>(
      context: context,
      onClose: refreshGroupedAttendance,
      builder: (_, _) => AttendanceDetailSheet(
        teacherId: this.teacherId,
        teacherNama: teacherNama,
        classId: classId,
        className: className,
        subjectId: subjectId,
        subjectName: subjectName,
        filterTeacherId: teacherId ?? (isHomeroomView ? null : this.teacherId),
        lessonHours: lessonHours,
        classList: classList,
        primaryColor: primaryColor,
        languageProvider: ref.read(languageRiverpod),
        canEdit: !isHomeroomView,
      ),
    );
  }

  @override
  void openInputSheet({
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
    String? lessonHourId,
    String? lessonHourName,
  }) {
    // Push as a full-screen route instead of a draggable sheet so the
    // input form gets the same brand layout (centered title, KPI
    // overlay, scroll behavior) as the main Presensi page. Refresh the
    // listing on pop so newly-saved sessions appear right away.
    //
    // [lessonHourId] is forwarded so the save persists attendance with
    // the right slot — see the Ambil Presensi sheet's comment for why
    // a NULL persist breaks the "Belum diabsen" → "Sudah" reload.
    AppNavigator.push(
      context,
      AttendancePage(
        teacher: {'id': teacherId, 'nama': teacherNama},
        initialDate: DateTime.now(),
        initialSubjectId: subjectId,
        initialSubjectName: subjectName,
        initialclassId: classId,
        initialClassName: className,
        initialLessonHourId: lessonHourId,
        initialTabIndex: 1,
        embedded: true,
      ),
    ).then((_) => refreshGroupedAttendance());
  }

  @override
  void showQuickActionsSheet(LanguageProvider lp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      // Five tiles + handle + title + subtitle + safe-area inset
      // exceed the system's default ~9/16 cap on tall phones, causing
      // an 11-px bottom overflow. Letting the sheet size to its
      // content avoids the clamp; the sheet itself wraps its body in
      // a SingleChildScrollView so it still scrolls on shorter
      // devices instead of overflowing.
      isScrollControlled: true,
      builder: (_) => AttendanceQuickActionsSheet(
        languageProvider: lp,
        // Override every student's status (Tandai semua Hadir / Sakit / etc).
        onStatusSelected: (status) {
          setState(() {
            for (final s in filteredStudentList) {
              attendanceStatus[s.id] = status;
            }
          });
        },
        // Apply only to students that haven't been marked yet
        // (mockup's "Sisanya Alpa"). Default of 'hadir' on the mobile
        // form means an unmarked student is one whose key isn't in
        // attendanceStatus yet — guard with isEmpty just in case.
        onFillUnmarked: (status) {
          setState(() {
            for (final s in filteredStudentList) {
              final v = attendanceStatus[s.id];
              if (v == null || v.isEmpty) {
                attendanceStatus[s.id] = status;
              }
            }
          });
        },
        // Clear every student's mark — they go back to "no status set"
        // (the form's default-Hadir hydration kicks in on next render).
        onResetAll: () {
          setState(() {
            for (final s in filteredStudentList) {
              attendanceStatus.remove(s.id);
            }
          });
        },
        // Frame C — copy attendance from the teacher's most recent
        // session. Calls the new last-session endpoint and fills the
        // current form's status map student-by-student.
        onCopyFromLastSession: _copyFromLastSession,
        // Frame C — Pindah tanggal/sesi opens Frame D so the teacher
        // can switch slots without leaving Ambil Presensi.
        onMoveDateOrSession: () async {
          final res = await showAttendanceDateSlotPicker(
            context: context,
            teacherId: teacherId,
          );
          if (!mounted) return;
          if (res?.session != null) {
            // Re-open Ambil Presensi with the picked session. Forward
            // lesson_hour_id so the save persists under the right slot
            // (avoids the NULL-persist bug fixed in the picker flow).
            openInputSheet(
              classId: (res!.session!['class_id'] ?? '').toString(),
              className: (res.session!['class_name'] ?? '').toString(),
              subjectId: (res.session!['subject_id'] ?? '').toString(),
              subjectName: (res.session!['subject_name'] ?? '').toString(),
              lessonHourId: res.session!['lesson_hour_id']?.toString(),
              lessonHourName: res.session!['lesson_hour_name']?.toString(),
            );
          }
        },
      ),
    );
  }

  /// Frame C · "Salin dari sesi terakhir" implementation.
  Future<void> _copyFromLastSession() async {
    try {
      final last = await AttendanceService.getLastTeacherSession(
        teacherId: teacherId,
      );
      if (!mounted) return;
      final entries = (last['students'] as List?) ?? const [];
      if (entries.isEmpty) return;
      setState(() {
        for (final e in entries) {
          if (e is! Map) continue;
          final id = (e['student_id'] ?? '').toString();
          final status = (e['status'] ?? '').toString();
          if (id.isNotEmpty && status.isNotEmpty) {
            attendanceStatus[id] = status;
          }
        }
      });
    } catch (_) {
      /* swallow — UI shows no-op */
    }
  }

  @override
  void detectCurrentLessonHour() => detectLessonHour();

  @override
  Future<void> forceRefresh() async {
    await LocalCacheService.clearStartingWith('presence_');
    if (isTimelineView) {
      await refreshTimeline();
    } else {
      await refreshGroupedAttendance();
    }
  }
}
