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
    final subjectName = (model.subjectName ?? '').isEmpty ? '-' : model.subjectName!;
    final className = (model.className ?? '').isEmpty ? '-' : model.className!;
    final summary =
        (this as dynamic).getSummary(schedule, dayName)
            as Map<String, dynamic>?;
    final attFilled = (this as dynamic).hasAttendance(summary, schedule) as bool;
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            subjectName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isPast ? ColorUtils.slate500 : ColorUtils.slate800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _buildClassBadge(className, isPast, isCurrent, isNext, primary),
      ],
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

  Widget _buildClassBadge(
    String className,
    bool isPast,
    bool isCurrent,
    bool isNext,
    Color primary,
  ) {
    return Container(
      padding: isCurrent || isNext
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : EdgeInsets.zero,
      decoration: isCurrent || isNext
          ? BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      child: Text(
        '${(this as dynamic).tr({'en': 'Class', 'id': 'Kelas'}) as String}: $className',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isPast ? ColorUtils.slate400 : primary,
        ),
      ),
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
    return _buildMiniButton(
      label: (this as dynamic).tr({'en': 'Atten', 'id': 'Presensi'}) as String,
      isFilled: attFilled,
      isPast: isPast,
      primary: primary,
      onTap: () => (this as dynamic).openAttendance(
        context,
        schedule,
        attFilled,
        (this as dynamic).getSummary(schedule, dayName),
      ),
    );
  }

  Widget _buildMaterialButton(
    bool matFilled,
    bool isPast,
    Color primary,
    Map<String, dynamic> schedule,
  ) {
    return _buildMiniButton(
      label: (this as dynamic).tr({'en': 'Mat', 'id': 'Materi'}) as String,
      isFilled: matFilled,
      isPast: isPast,
      primary: primary,
      onTap: () => (this as dynamic).openMaterial(context, schedule),
    );
  }

  Widget _buildActivityButton(
    bool actFilled,
    bool isPast,
    Color primary,
    Map<String, dynamic> schedule,
  ) {
    return _buildMiniButton(
      label: (this as dynamic).tr({'en': 'Act', 'id': 'Kegiatan'}) as String,
      isFilled: actFilled,
      isPast: isPast,
      primary: primary,
      onTap: () => (this as dynamic).openClassActivity(context, schedule),
    );
  }

  Widget _buildMiniButton({
    required String label,
    required bool isFilled,
    required bool isPast,
    required Color primary,
    required VoidCallback onTap,
  }) {
    final color = isFilled ? primary : Colors.transparent;
    final borderColor = isFilled
        ? color
        : (isPast ? ColorUtils.slate200 : ColorUtils.slate200);
    final textColor = isFilled
        ? Colors.white
        : (isPast ? ColorUtils.slate400 : primary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        constraints: const BoxConstraints(minWidth: 60),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
