import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/teacher_attendance_controller.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_detail.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// Mixin for user actions in teacher attendance detail.
mixin TeacherAttendanceDetailActionsMixin
    on ConsumerState<TeacherAttendanceDetailPage> {
  /// Open edit sheet for attendance changes
  void openEditSheet() {
    // Extract lesson hour number if possible
    int? lessonHourNum;
    if (widget.lessonHourName != null) {
      final match = RegExp(r'\d+').firstMatch(widget.lessonHourName!);
      if (match != null) {
        lessonHourNum = int.tryParse(match.group(0)!);
      }
    }

    // Push the input flow as a full-screen route (was a draggable
    // sheet) so it picks up the shared BrandPageLayout chrome —
    // centered title, KPI overlay, branded gradient. Refresh the
    // detail screen's data when the user pops back so freshly-saved
    // edits show up immediately.
    AppNavigator.push(
      context,
      AttendancePage(
        teacher: widget.teacher,
        initialDate: widget.date,
        initialSubjectId: widget.subjectId,
        initialSubjectName: widget.subjectName,
        initialclassId: widget.classId,
        initialClassName: widget.className,
        initialLessonHourNumber: lessonHourNum,
        initialTabIndex: 1, // Start on input tab
        embedded: true,
      ),
    ).then((_) {
      ref.invalidate(teacherAttendanceProvider(_controllerParams));
    });
  }

  /// Get controller parameters for provider
  TeacherAttendanceParams get _controllerParams => TeacherAttendanceParams(
    subjectId: widget.subjectId,
    classId: widget.classId,
    date: widget.date,
    teacherId: Teacher.fromJson(widget.teacher).id,
    lessonHourId: widget.lessonHourId,
  );
}
