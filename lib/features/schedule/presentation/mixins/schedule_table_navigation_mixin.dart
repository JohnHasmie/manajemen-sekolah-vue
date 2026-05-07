import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/embedded_activity_list_screen.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/teacher_schedule_table_view.dart';

mixin ScheduleTableNavigationMixin on State<TeacherScheduleTableView> {
  void openAttendance(
    BuildContext context,
    Map<String, dynamic> schedule,
    bool hasData,
    Map<String, dynamic>? summary,
  ) {
    showAttendanceDialog(context, schedule, 1);
  }

  void showAttendanceDialog(
    BuildContext context,
    Map<String, dynamic> schedule,
    int tabIndex,
  ) {
    final widget = (this as dynamic).widget;
    final onRefresh = widget.onRefresh as VoidCallback;
    final scheduleData = extractScheduleData(schedule);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return buildAttendanceSheet(schedule, scheduleData, tabIndex, widget);
      },
    ).then((_) => onRefresh());
  }

  Widget buildAttendanceSheet(
    Map<String, dynamic> schedule,
    Map<String, dynamic> scheduleData,
    int tabIndex,
    dynamic widget,
  ) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return AttendancePage(
          teacher: {
            'id': widget.teacherId as String,
            'nama': widget.teacherNama as String,
          },
          initialDate:
              (this as dynamic).computeScheduleDate(schedule) as DateTime,
          initialSubjectId: scheduleData['subjectId'],
          initialSubjectName: scheduleData['subjectName'],
          initialclassId: scheduleData['classId'],
          initialClassName: scheduleData['className'],
          initialLessonHourNumber: scheduleData['lessonHour'],
          initialLessonHourId: scheduleData['lessonHourId'],
          initialTabIndex: tabIndex,
          embedded: true,
          scrollController: scrollController,
        );
      },
    );
  }

  Map<String, dynamic> extractScheduleData(Map<String, dynamic> schedule) {
    final model = Schedule.fromJson(schedule);
    return {
      'subjectId': model.subjectId,
      'subjectName': model.subjectName,
      'classId': model.classId,
      'className': model.className,
      'lessonHour': model.lessonHour,
      // Each (day, hour_number) tuple owns a distinct UUID. The
      // attendance form needs the exact UUID — not just the hour
      // number — so it can scope hydration / submit to the right
      // per-day slot. Without this the matrix-view → presensi flow
      // would surface another day's already-saved attendance and
      // block new entry, same way the card-view flow did.
      'lessonHourId': model.lessonHourId,
    };
  }

  void openMaterial(BuildContext context, Map<String, dynamic> schedule) {
    final model = Schedule.fromJson(schedule);
    final subjectId = model.subjectId;
    final subjectName = model.subjectName;
    final classId = model.classId;
    final className = model.className;
    final widget = (this as dynamic).widget;
    final onRefresh = widget.onRefresh as VoidCallback;
    final teacherId = widget.teacherId as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: TeacherMaterialScreen(
            teacher: {'id': teacherId, 'nama': widget.teacherNama as String},
            initialSubjectId: subjectId,
            initialSubjectName: subjectName,
            initialClassId: classId,
            initialClassName: className,
            embedded: true,
          ),
        ),
      ),
    ).then((_) async {
      // Record material view after user interacted and closed the sheet.
      if (classId != null && subjectId != null && teacherId.isNotEmpty) {
        final date = DateFormat(
          'yyyy-MM-dd',
        ).format((this as dynamic).computeScheduleDate(schedule) as DateTime);
        await getIt<ApiScheduleService>().recordMaterialView(
          teacherId: teacherId,
          classId: classId,
          subjectId: subjectId,
          date: date,
          lessonHourId: model.lessonHourId,
        );
      }
      onRefresh();
    });
  }

  void openClassActivity(BuildContext context, Map<String, dynamic> schedule) {
    final model = Schedule.fromJson(schedule);
    final subjectId = model.subjectId;
    final subjectName = model.subjectName;
    final classId = model.classId;
    final className = model.className;
    final widget = (this as dynamic).widget;
    final onRefresh = widget.onRefresh as VoidCallback;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: EmbeddedActivityListScreen(
            teacherId: widget.teacherId as String,
            teacherName: widget.teacherNama as String,
            classId: classId ?? '',
            className: className ?? '',
            subjectId: subjectId ?? '',
            subjectName: subjectName ?? '',
            initialDate:
                (this as dynamic).computeScheduleDate(schedule) as DateTime,
            lessonHourId: model.lessonHourId,
          ),
        ),
      ),
    ).then((_) => onRefresh());
  }
}
