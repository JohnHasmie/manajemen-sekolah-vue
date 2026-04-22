import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          expand: false,
          builder: (context, scrollController) {
            return AttendancePage(
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
            );
          },
        );
      },
    ).then((_) {
      // Refresh data after edit sheet is closed
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
