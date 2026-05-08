import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/features/attendance/exports/attendance_export_service.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/teacher_attendance_state.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_detail.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_date_slot_picker.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// Builds the gradient header for the attendance detail screen.
///
/// Matches Frame B/F from `_design/teacher_attendance_detail_mockup.html`:
///   • back button (‹) + kicker (`PRESENSI · DETAIL` / `PRESENSI · ARSIP`)
///   • title row (`Edit Presensi` / `Lihat Presensi`) with realtime dot —
///     dot is green when canEdit, slate when read-only.
///   • context strip showing the subject icon, `subject · class`, and
///     a date · lesson-hour subtitle.
mixin TeacherAttendanceDetailHeaderMixin
    on ConsumerState<TeacherAttendanceDetailPage> {
  /// Get primary color for the role
  Color getPrimaryColor() => ColorUtils.getRoleColor('guru');

  /// Builds the shared `BrandPageHeader` for the attendance detail
  /// screen. Same gradient + centered title pattern as the main
  /// Presensi page; the subject·class·date context strip slots into
  /// `bottomSlot`. Pairs with `BrandPageLayout` so the KPI overview
  /// card overlaps the gradient and scrolls with the body.
  ///
  /// Read-only mode ("Lihat Presensi") surfaces a download icon in
  /// [actionIcons] that exports the loaded attendance via Excel.
  /// Edit mode renders no trailing icon (the previous more-horiz dot
  /// had no handler and read as a dead affordance).
  Widget buildHeader(
    BuildContext context,
    LanguageProvider languageProvider, {
    TeacherAttendanceState? state,
    bool isLoading = false,
  }) {
    final canEdit = widget.canEdit;
    final kicker = canEdit
        ? languageProvider.getTranslatedText({
            'en': 'Attendance · Detail',
            'id': 'Presensi · Detail',
          })
        : languageProvider.getTranslatedText({
            'en': 'Attendance · Archive',
            'id': 'Presensi · Arsip',
          });
    final title = canEdit
        ? languageProvider
            .getTranslatedText({'en': 'Edit Attendance', 'id': 'Edit Presensi'})
        : languageProvider.getTranslatedText({
            'en': 'View Attendance',
            'id': 'Lihat Presensi',
          });

    return BrandPageHeader(
      role: 'guru',
      title: title,
      subtitle: kicker,
      // green dot when editable (live), translucent slate when read-only.
      isRealtimeFresh: canEdit,
      kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
      actionIcons: canEdit
          ? null
          : [
              BrandHeaderIconButton(
                icon: Icons.download_rounded,
                onTap: state == null
                    ? () {}
                    : () => _exportAttendance(state),
              ),
            ],
      bottomSlot: _contextStrip(languageProvider),
    );
  }

  Future<void> _exportAttendance(TeacherAttendanceState state) async {
    if (state.attendanceRecords.isEmpty) {
      SnackBarUtils.showWarning(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'No attendance data to export',
          'id': 'Tidak ada data absensi untuk diekspor',
        }),
      );
      return;
    }
    await ExcelPresenceService.exportPresenceToExcel(
      presenceData: state.attendanceRecords,
      context: context,
      filters: {
        'class_id': widget.classId,
        'subject_id': widget.subjectId,
        'date': DateFormat('yyyy-MM-dd').format(widget.date),
        if (widget.lessonHourId != null) 'lesson_hour_id': widget.lessonHourId,
      },
    );
  }

  /// Context strip — subject letter avatar + subject·class title + date /
  /// lesson hour subtitle. Matches the mockup's `.ctx-strip` block.
  Widget _contextStrip(LanguageProvider lp) {
    final dateStr = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(widget.date);
    final lessonHour = (widget.lessonHourName ?? '').trim();
    final subtitleParts = <String>[
      dateStr,
      if (lessonHour.isNotEmpty) lessonHour,
    ];
    final subtitle = subtitleParts.join(' · ');
    final initial = widget.subjectName.isNotEmpty
        ? widget.subjectName[0].toUpperCase()
        : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.canEdit ? _openDateSlotPicker : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: getPrimaryColor(),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.subjectName} · ${widget.className}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.canEdit) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.edit_calendar_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Opens Frame D — the calendar + sessions picker. Selecting a date
  /// or session pushes a new TeacherAttendanceDetailPage scoped to
  /// that target so the teacher can switch sessions without
  /// backing-out to Presensi first.
  Future<void> _openDateSlotPicker() async {
    final res = await showAttendanceDateSlotPicker(
      context: context,
      teacherId: widget.filterTeacherId ?? Teacher.fromJson(widget.teacher).id,
      classId: widget.classId,
      initialMonth: widget.date,
    );
    if (!mounted || res == null) return;

    if (res.session != null) {
      final s = res.session!;
      final dateStr = (s['date'] ?? '').toString();
      final date = DateTime.tryParse(dateStr) ?? widget.date;
      AppNavigator.pushReplacement(
        context,
        TeacherAttendanceDetailPage(
          subjectId: (s['subject_id'] ?? widget.subjectId).toString(),
          subjectName: (s['subject_name'] ?? widget.subjectName).toString(),
          classId: (s['class_id'] ?? widget.classId).toString(),
          className: (s['class_name'] ?? widget.className).toString(),
          date: date,
          teacher: widget.teacher,
          lessonHourId: s['lesson_hour_id']?.toString(),
          lessonHourName: s['lesson_hour_name']?.toString(),
          canEdit: widget.canEdit,
          filterTeacherId: widget.filterTeacherId,
        ),
      );
    } else if (res.date != null) {
      AppNavigator.pushReplacement(
        context,
        TeacherAttendanceDetailPage(
          subjectId: widget.subjectId,
          subjectName: widget.subjectName,
          classId: widget.classId,
          className: widget.className,
          date: res.date!,
          teacher: widget.teacher,
          lessonHourId: widget.lessonHourId,
          lessonHourName: widget.lessonHourName,
          canEdit: widget.canEdit,
          filterTeacherId: widget.filterTeacherId,
        ),
      );
    }
  }
}
