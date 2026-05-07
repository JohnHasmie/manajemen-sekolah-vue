import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/teacher_attendance_controller.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/teacher_attendance_state.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_detail.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/per_student_status_picker.dart';

/// Builds the per-student row on the attendance detail screen
/// (Frame B/F from `_design/teacher_attendance_detail_mockup.html`).
///
/// Single-line layout: `[# avatar name+NIS ── pill]` with the saved
/// status rendered as a colored pill on the right. When `canEdit` is
/// true the pill is tap-to-edit and opens the per-student status
/// picker (Frame E); otherwise (Frame F · past academic year) the pill
/// renders at 70% opacity and the row is non-interactive.
mixin TeacherAttendanceDetailCardMixin
    on ConsumerState<TeacherAttendanceDetailPage> {
  // Implemented by other mixins on the screen.
  String getStudentStatus(String studentId, TeacherAttendanceState state);
  Color getStatusColor(String status);
  String getStatusText(String status, LanguageProvider languageProvider);

  Widget buildStudentCard(
    Student student,
    LanguageProvider languageProvider,
    TeacherAttendanceState state,
    int index,
  ) {
    final status = getStudentStatus(student.id, state);
    final Color statusColor = getStatusColor(status);
    final String statusText = getStatusText(status, languageProvider);
    final avatarColor = ColorUtils.getColorForIndex(index);
    // Notes aren't currently surfaced on the Attendance read model
    // (only sent on createAttendance). When that field is added to
    // the model, _buildBody can render the note pill inline again.
    const String? note = null;

    final card = Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildIndexNumber(index),
          const SizedBox(width: 6),
          _buildAvatar(student, avatarColor),
          const SizedBox(width: 10),
          Expanded(child: _buildBody(student, note)),
          const SizedBox(width: 8),
          _buildPill(statusColor, statusText),
        ],
      ),
    );

    if (!widget.canEdit) {
      // Frame F · read-only — no tap, slightly muted.
      return Opacity(opacity: 0.92, child: card);
    }

    // Frame B · edit-on-pill.
    return InkWell(
      onTap: () => _openStatusPicker(student, status, note),
      borderRadius: BorderRadius.circular(14),
      child: card,
    );
  }

  Widget _buildIndexNumber(int index) {
    return SizedBox(
      width: 22,
      child: Text(
        '${index + 1}.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: ColorUtils.slate400,
        ),
      ),
    );
  }

  Widget _buildAvatar(Student student, Color avatarColor) {
    final initials = _initials(student.name);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: avatarColor.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: avatarColor,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildBody(Student student, String? note) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          student.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate900,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${widget.className} · NIS ${student.studentNumber}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: ColorUtils.slate500,
            fontWeight: FontWeight.w500,
            height: 1.1,
          ),
        ),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ColorUtils.slate50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 10,
                  color: ColorUtils.slate400,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: ColorUtils.slate600,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPill(Color color, String label) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.2,
            ),
          ),
          if (widget.canEdit) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              size: 12,
              color: color.withValues(alpha: 0.7),
            ),
          ],
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Opens Frame E — the per-student status picker bottom sheet.
  ///
  /// On confirm the picker dispatches `updateStatus` + `saveChanges`
  /// through the existing controller, then the AsyncNotifier reloads.
  Future<void> _openStatusPicker(
    Student student,
    String currentStatus,
    String? currentNote,
  ) async {
    final params = TeacherAttendanceParams(
      subjectId: widget.subjectId,
      classId: widget.classId,
      date: widget.date,
      teacherId:
          widget.filterTeacherId ??
          ((widget.canEdit ? (widget.teacher['id']?.toString()) : null) ?? ''),
      lessonHourId: widget.lessonHourId,
    );

    await showPerStudentStatusPicker(
      context: context,
      student: student,
      className: widget.className,
      initialStatus: currentStatus,
      initialNote: currentNote,
      onApply: (status, note) async {
        // Drop the change into the controller's edited-status map and
        // persist via the same path the FAB/Edit sheet uses, so it
        // re-fetches on success and the row repaints.
        ref.read(teacherAttendanceProvider(params).notifier)
          ..updateStatus(student.id, status);
        await ref
            .read(teacherAttendanceProvider(params).notifier)
            .saveChanges();
      },
    );
  }
}
