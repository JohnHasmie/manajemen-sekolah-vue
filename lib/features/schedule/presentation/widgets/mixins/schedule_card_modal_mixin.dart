import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/'
    'embedded_activity_list_screen.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/'
    'teacher_material_screen.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/teacher_schedule_session_detail_screen.dart';

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

  /// Pushes the full TeacherMaterialScreen as a Material page route
  /// pre-resolved to the session's class+subject. Drops the legacy
  /// `embedded: true` flag so the screen renders the full brand
  /// chrome (BrandPageHeader, KPI strip, search row, expandable
  /// chapter cards, violet Generate AI FAB) — same surface the user
  /// gets when entering Materi from the bottom-nav.
  ///
  /// Records a material-view event when the page pops so the schedule
  /// card's "Materi" action chip turns green.
  void openMaterial(BuildContext ctx) {
    Navigator.of(ctx)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => TeacherMaterialScreen(
              teacher: {'id': teacherId, 'nama': teacherNama},
              initialSubjectId: subjectId,
              initialSubjectName: subjectName,
              initialClassId: classId,
              initialClassName: className,
            ),
          ),
        )
        .then((_) async {
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

  /// Pushes the full-page session detail screen — Frame E of the
  /// Jadwal redesign. Replaces the legacy modal-bottom-sheet summary
  /// (`ScheduleCardSummarySheet`) so the BrandPageHeader gets its full
  /// SafeArea and ESC / system-back behave predictably.
  ///
  /// IMPORTANT — do NOT `Navigator.pop` the detail screen before
  /// opening a sub-action sheet. The legacy bottom-sheet implementation
  /// popped the sheet first because the sheet otherwise covered the
  /// schedule list underneath; with the full-page detail screen we
  /// want the user to land BACK on the detail screen when they close
  /// the attendance / activity / material modal — popping here would
  /// silently dump them to the hub, which is what bug #1 reported.
  void showSummarySheet(BuildContext ctx, Map<String, dynamic>? summary) {
    TeacherScheduleSessionDetailScreen.push(
      ctx,
      schedule: schedule,
      summary: summary,
      languageProvider: languageProvider,
      onAttendanceTap: () => openAttendance(ctx, hasAttendance(summary)),
      onMaterialTap: () => openMaterial(ctx),
      onActivityTap: () => openClassActivity(ctx),
    );
  }
}
