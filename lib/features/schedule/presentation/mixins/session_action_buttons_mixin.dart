import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/teacher_schedule_table_view.dart';

mixin SessionActionButtonsMixin on State<TeacherScheduleTableView> {
  Widget buildSessionInfoColumn(
    Map<String, dynamic> schedule,
    String dayName,
    bool isPast,
    bool isCurrent,
    bool isNext,
    Color primary,
  ) {
    final model = Schedule.fromJson(schedule);
    final subjectName = (model.subjectName ?? '').isEmpty
        ? '-'
        : model.subjectName!;
    final className = (model.className ?? '').isEmpty ? '-' : model.className!;
    final summary =
        (this as dynamic).getSummary(schedule, dayName)
            as Map<String, dynamic>?;
    final attFilled =
        (this as dynamic).hasAttendance(summary, schedule) as bool;
    final matFilled = (this as dynamic).hasMaterial(summary, schedule) as bool;
    final actFilled = (this as dynamic).hasActivity(summary, schedule) as bool;

    final isHomeroomView = widget.isHomeroomView;
    final teacherName = isHomeroomView && (model.teacherName ?? '').isNotEmpty
        ? model.teacherName!
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSubjectClassRow(
          subjectName,
          className,
          isPast,
          isCurrent,
          isNext,
          primary,
        ),
        if (teacherName != null) ...[
          const SizedBox(height: 4),
          _buildTeacherRow(teacherName, isPast, primary),
        ],
        const SizedBox(height: 8),
        _buildActionButtons(
          attFilled,
          matFilled,
          actFilled,
          isPast,
          primary,
          schedule,
          dayName,
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    bool attFilled,
    bool matFilled,
    bool actFilled,
    bool isPast,
    Color primary,
    Map<String, dynamic> schedule,
    String dayName,
  ) {
    return _buildActionButtonsRow(
      attFilled,
      matFilled,
      actFilled,
      isPast,
      primary,
      schedule,
      dayName,
    );
  }

  Widget _buildSubjectClassRow(
    String subjectName,
    String className,
    bool isPast,
    bool isCurrent,
    bool isNext,
    Color primary,
  ) {
    final cobalt = ColorUtils.brandCobalt;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            subjectName,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: isPast ? ColorUtils.slate500 : ColorUtils.slate900,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _buildClassPill(className, isPast, cobalt),
      ],
    );
  }

  Widget _buildClassPill(String className, bool isPast, Color cobalt) {
    final color = isPast ? ColorUtils.slate500 : cobalt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        className,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _buildTeacherRow(String teacherName, bool isPast, Color primary) {
    final color = isPast ? ColorUtils.slate400 : ColorUtils.slate600;
    return Row(
      children: [
        Icon(Icons.person_rounded, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            teacherName,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtonsRow(
    bool attFilled,
    bool matFilled,
    bool actFilled,
    bool isPast,
    Color primary,
    Map<String, dynamic> schedule,
    String dayName,
  ) {
    return Row(
      children: [
        _buildAttendanceButton(attFilled, isPast, primary, schedule, dayName),
        const SizedBox(width: 4),
        _buildMaterialButton(matFilled, isPast, primary, schedule),
        const SizedBox(width: 4),
        _buildActivityButton(actFilled, isPast, primary, schedule),
      ],
    );
  }

  Widget _buildAttendanceButton(
    bool attFilled,
    bool isPast,
    Color primary,
    Map<String, dynamic> schedule,
    String dayName,
  ) {
    final summary =
        (this as dynamic).getSummary(schedule, dayName)
            as Map<String, dynamic>?;
    final att = summary?['attendance'];
    String label =
        (this as dynamic).tr({'en': 'Atten', 'id': 'Presensi'}) as String;
    if (attFilled && att is Map && att['filled'] == true) {
      final hadir = (att['hadir'] is num) ? (att['hadir'] as num).toInt() : 0;
      final total = (att['total'] is num) ? (att['total'] as num).toInt() : 0;
      if (total > 0) label = '$hadir/$total';
    }

    return _buildMiniPill(
      label: label,
      icon: Icons.fact_check_rounded,
      kind: attFilled
          ? _MiniKind.filled
          : (isPast ? _MiniKind.muted : _MiniKind.cobalt),
      onTap: () => (this as dynamic).openAttendance(
        context,
        schedule,
        attFilled,
        summary,
      ),
    );
  }

  Widget _buildMaterialButton(
    bool matFilled,
    bool isPast,
    Color primary,
    Map<String, dynamic> schedule,
  ) {
    return _buildMiniPill(
      label: (this as dynamic).tr({'en': 'Mat', 'id': 'Materi'}) as String,
      icon: Icons.library_books_rounded,
      kind: matFilled
          ? _MiniKind.filled
          : (isPast ? _MiniKind.muted : _MiniKind.outline),
      onTap: () => (this as dynamic).openMaterial(context, schedule),
    );
  }

  Widget _buildActivityButton(
    bool actFilled,
    bool isPast,
    Color primary,
    Map<String, dynamic> schedule,
  ) {
    return _buildMiniPill(
      label: (this as dynamic).tr({'en': 'Act', 'id': 'Kegiatan'}) as String,
      icon: Icons.assignment_rounded,
      kind: actFilled
          ? _MiniKind.warn
          : (isPast ? _MiniKind.muted : _MiniKind.outline),
      onTap: () => (this as dynamic).openClassActivity(context, schedule),
    );
  }

  Widget _buildMiniPill({
    required String label,
    required IconData icon,
    required _MiniKind kind,
    required VoidCallback onTap,
  }) {
    final (bg, fg) = switch (kind) {
      _MiniKind.outline => (ColorUtils.slate100, ColorUtils.slate500),
      _MiniKind.muted => (ColorUtils.slate100, ColorUtils.slate400),
      _MiniKind.cobalt => (
        ColorUtils.brandCobalt.withValues(alpha: 0.10),
        ColorUtils.brandCobalt,
      ),
      _MiniKind.filled => (
        ColorUtils.success600.withValues(alpha: 0.10),
        ColorUtils.success600,
      ),
      _MiniKind.warn => (
        ColorUtils.warning600.withValues(alpha: 0.10),
        ColorUtils.warning600,
      ),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: fg,
                letterSpacing: 0.3,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MiniKind { outline, muted, cobalt, filled, warn }
