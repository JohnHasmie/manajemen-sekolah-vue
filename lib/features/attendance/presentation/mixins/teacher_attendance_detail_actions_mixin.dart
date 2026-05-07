import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/widgets/app_draggable_sheet.dart';
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

    AppDraggableSheet.show<void>(
      context: context,
      onClose: () {
        // Refresh data after edit sheet is closed
        ref.invalidate(teacherAttendanceProvider(_controllerParams));
      },
      builder: (_, scrollController) => AttendancePage(
        teacher: widget.teacher,
        initialDate: widget.date,
        initialSubjectId: widget.subjectId,
        initialSubjectName: widget.subjectName,
        initialclassId: widget.classId,
        initialClassName: widget.className,
        initialLessonHourNumber: lessonHourNum,
        initialTabIndex: 1, // Start on input tab
        embedded: true,
        scrollController: scrollController,
      ),
    );
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
