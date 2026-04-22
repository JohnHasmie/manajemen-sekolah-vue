import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/'
    'embedded_activity_list_screen.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/'
    'teacher_material_screen.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_card_summary_sheet.dart';

/// Mixin for modal dialogs and sheets in schedule cards.
mixin ScheduleCardModalMixin {
  // Abstract members requiring implementation.
  void setState(VoidCallback fn);
  BuildContext get context;

  // Required state access.
  dynamic get languageProvider => null;
  String get teacherId => '';
  String get teacherNama => '';
  Map<String, dynamic> get schedule => {};
  String? get subjectId => null;
  String? get subjectName => null;
  String? get classId => null;
  String? get className => null;
  String? get lessonHourId => null;

  // Access to color and data.
  Color getPrimaryColor() => Colors.blue;
  Map<String, dynamic>? getSummary() => null;
  DateTime computeScheduleDate() => DateTime.now();
  bool hasAttendance(Map<String, dynamic>? summary) => false;
  void openAttendance(BuildContext ctx, bool hasData);

  // Refresh callback from parent screen.
  VoidCallback? get onRefresh => null;

  /// Opens material modal bottom sheet.
  /// When the sheet closes, records a material-view event and then
  /// refreshes the schedule summary so the materi button turns green.
  void openMaterial(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.9,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: TeacherMaterialScreen(
            teacher: {'id': teacherId, 'nama': teacherNama},
            initialSubjectId: subjectId,
            initialSubjectName: subjectName,
            initialClassId: classId,
            initialClassName: className,
            embedded: true,
          ),
        ),
      ),
    ).then((_) async {
      // Record material view after the user interacted and closed.
      final cId = classId;
      final sId = subjectId;
      if (cId != null && sId != null && teacherId.isNotEmpty) {
        final date = DateFormat('yyyy-MM-dd').format(computeScheduleDate());
        await getIt<ApiScheduleService>().recordMaterialView(
          teacherId: teacherId,
          classId: cId,
          subjectId: sId,
          date: date,
          lessonHourId: lessonHourId,
        );
      }
      onRefresh?.call();
    });
  }

  /// Opens class activity modal bottom sheet.
  /// Refreshes the schedule summary when the modal closes.
  void openClassActivity(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.9,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: EmbeddedActivityListScreen(
            teacherId: teacherId,
            teacherName: teacherNama,
            classId: classId ?? '',
            className: className ?? '',
            subjectId: subjectId ?? '',
            subjectName: subjectName ?? '',
            initialDate: computeScheduleDate(),
            lessonHourId: lessonHourId,
          ),
        ),
      ),
    ).then((_) => onRefresh?.call());
  }

  /// Shows summary sheet for the schedule card.
  void showSummarySheet(BuildContext ctx, Map<String, dynamic>? summary) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleCardSummarySheet(
        schedule: schedule,
        summary: summary,
        languageProvider: languageProvider,
        primary: getPrimaryColor(),
        onAttendanceTap: () {
          Navigator.pop(ctx);
          openAttendance(ctx, hasAttendance(summary));
        },
        onMaterialTap: () {
          Navigator.pop(ctx);
          openMaterial(ctx);
        },
        onActivityTap: () {
          Navigator.pop(ctx);
          openClassActivity(ctx);
        },
      ),
    );
  }
}
