import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/app_draggable_sheet.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/'
    'teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart'
    as sched;
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_card_action_button.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_card_attendance_detail.dart';

/// Mixin for action button building and attendance dialogs.
mixin ScheduleCardActionMixin {
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

  /// Exact `lesson_hour_id` UUID for the schedule slot the card
  /// represents. Each (day, hour_number) tuple owns a distinct UUID,
  /// so we cannot reconstruct it on the AttendancePage side from
  /// hour_number alone — the schedule already has it, just forward it.
  String? get lessonHourId => null;

  VoidCallback? get onRefresh => null;

  // Color and data access.
  Color getPrimaryColor() => Colors.blue;
  Map<String, dynamic>? getSummary() => null;
  DateTime computeScheduleDate() => DateTime.now();
  bool hasAttendance(Map<String, dynamic>? summary) => false;

  /// Builds the row of action buttons for the card.
  ///
  /// When [ctx] is provided it is used instead of the [context] getter,
  /// which allows StatelessWidget hosts (e.g. ScheduleCardItem) to forward
  /// the BuildContext from their build method.
  ///
  /// `isCurrent` (the lesson is happening RIGHT NOW) promotes the
  /// Presensi chip to the cobalt CTA state so the teacher sees a
  /// pulled-out call-to-action when they enter the screen mid-lesson.
  Widget buildActionButtons(
    Color primary,
    bool attendanceFilled,
    bool activityFilled,
    bool materialFilled, {
    BuildContext? ctx,
    bool isCurrent = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: buildAttendanceButton(
            primary,
            attendanceFilled,
            ctx: ctx,
            isCobaltCta: isCurrent && !attendanceFilled,
            attendanceCount: _attendanceCountLabel(),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(child: buildActivityButton(primary, activityFilled, ctx: ctx)),
        const SizedBox(width: 6),
        Expanded(child: buildMaterialButton(primary, materialFilled, ctx: ctx)),
      ],
    );
  }

  /// Builds attendance action button.
  Widget buildAttendanceButton(
    Color primary,
    bool isFilled, {
    BuildContext? ctx,
    bool isCobaltCta = false,
    String? attendanceCount,
  }) {
    return Builder(
      builder: (fallbackCtx) {
        final effectiveCtx = ctx ?? fallbackCtx;
        final label = isFilled && attendanceCount != null
            ? attendanceCount
            : languageProvider.getTranslatedText({
                'en': 'Attendance',
                'id': 'Presensi',
              });
        return ScheduleCardActionButton(
          icon: Icons.fact_check_rounded,
          label: label,
          state: ScheduleCardActionButton.resolveState(
            isFilled: isFilled,
            isCobaltCta: isCobaltCta,
          ),
          onPressed: () {
            openAttendance(effectiveCtx, isFilled);
          },
        );
      },
    );
  }

  /// Builds material action button.
  Widget buildMaterialButton(
    Color primary,
    bool isFilled, {
    BuildContext? ctx,
  }) {
    return Builder(
      builder: (fallbackCtx) {
        final effectiveCtx = ctx ?? fallbackCtx;
        return ScheduleCardActionButton(
          icon: Icons.library_books_rounded,
          label: languageProvider.getTranslatedText({
            'en': 'Material',
            'id': 'Materi',
          }),
          state: ScheduleCardActionButton.resolveState(isFilled: isFilled),
          onPressed: () => openMaterial(effectiveCtx),
        );
      },
    );
  }

  /// Builds class activity action button.
  Widget buildActivityButton(
    Color primary,
    bool isFilled, {
    BuildContext? ctx,
  }) {
    return Builder(
      builder: (fallbackCtx) {
        final effectiveCtx = ctx ?? fallbackCtx;
        return ScheduleCardActionButton(
          icon: Icons.assignment_rounded,
          label: languageProvider.getTranslatedText({
            'en': 'Activity',
            'id': 'Kegiatan',
          }),
          state: ScheduleCardActionButton.resolveState(isFilled: isFilled),
          onPressed: () => openClassActivity(effectiveCtx),
        );
      },
    );
  }

  /// Builds the live attendance count label like `28/28 Hadir` from
  /// the cached daily summary. Returns null when no aggregate data is
  /// available so callers fall back to "Presensi".
  String? _attendanceCountLabel() {
    final summary = getSummary();
    final att = summary?['attendance'];
    if (att is! Map) return null;
    if (att['filled'] != true) return null;
    final hadir = (att['hadir'] is num) ? (att['hadir'] as num).toInt() : 0;
    final total = (att['total'] is num) ? (att['total'] as num).toInt() : 0;
    if (total <= 0) return null;
    return '$hadir/$total Hadir';
  }

  /// Opens attendance view (detail sheet if filled, dialog if not).
  void openAttendance(BuildContext ctx, bool hasData) {
    if (hasData) {
      final summary = getSummary();
      final att = summary?['attendance'];
      showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ScheduleCardAttendanceDetail(
          subjectName: subjectName ?? '-',
          className: className ?? '-',
          schedule: schedule,
          attendance: att,
          primary: getPrimaryColor(),
          languageProvider: languageProvider,
          onEditTap: () {
            Navigator.pop(ctx);
            showAttendanceDialog(ctx, 1);
          },
        ),
      );
    } else {
      showAttendanceDialog(ctx, 1);
    }
  }

  /// Shows attendance dialog with initial tab index.
  void showAttendanceDialog(BuildContext ctx, int tabIndex) {
    AppDraggableSheet.show<void>(
      context: ctx,
      onClose: () => onRefresh?.call(),
      builder: (_, scrollController) => AttendancePage(
        teacher: {'id': teacherId, 'nama': teacherNama},
        initialDate: computeScheduleDate(),
        initialSubjectId: subjectId,
        initialSubjectName: subjectName,
        initialclassId: classId,
        initialClassName: className,
        initialLessonHourNumber: sched.Schedule.fromJson(schedule).lessonHour,
        // Pass the exact UUID so the form's hydration + new-row submit
        // both target the right per-day slot. Without this, hour_number
        // 1 from one day would happily surface another day's stored
        // attendance and block new entry.
        initialLessonHourId: lessonHourId,
        initialTabIndex: tabIndex,
        embedded: true,
        scrollController: scrollController,
      ),
    );
  }

  /// Opens material screen (stub for implementation).
  void openMaterial(BuildContext ctx);

  /// Opens class activity screen (stub for implementation).
  void openClassActivity(BuildContext ctx);
}
