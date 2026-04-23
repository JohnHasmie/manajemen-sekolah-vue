import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/teacher_schedule_table_view.dart';

mixin SessionRowBuildingMixin on State<TeacherScheduleTableView> {
  Widget buildSessionRow({
    required Map<String, dynamic> schedule,
    required String dayName,
    required bool isPast,
    required bool isCurrent,
    required bool isNext,
    required bool isLast,
  }) {
    final model = Schedule.fromJson(schedule);
    final sessionNum = model.lessonHour?.toString() ?? '-';
    final startTime =
        (this as dynamic).formatTime(model.startTime) as String;
    final endTime =
        (this as dynamic).formatTime(model.endTime) as String;
    final widget = (this as dynamic).widget;
    final primary = widget.primaryColor as Color;

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
      padding: const EdgeInsets.all(12),
      decoration: _buildRowDecoration(isCurrent, isNext, primary),
      child: _buildSessionRowContent(
        sessionNum,
        startTime,
        endTime,
        primary,
        isPast,
        isCurrent,
        isNext,
        schedule,
        dayName,
      ),
    );
  }

  Widget _buildSessionRowContent(
    String sessionNum,
    String startTime,
    String endTime,
    Color primary,
    bool isPast,
    bool isCurrent,
    bool isNext,
    Map<String, dynamic> schedule,
    String dayName,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildSessionTimeColumn(
          sessionNum,
          startTime,
          endTime,
          primary,
          isPast,
          isCurrent,
          isNext,
        ),
        const SizedBox(width: 12),
        Container(width: 1, height: 48, color: ColorUtils.slate200),
        const SizedBox(width: 12),
        Expanded(
          child: (this as dynamic).buildSessionInfoColumn(
            schedule,
            dayName,
            isPast,
            isCurrent,
            isNext,
            primary,
          ),
        ),
      ],
    );
  }

  BoxDecoration _buildRowDecoration(
    bool isCurrent,
    bool isNext,
    Color primary,
  ) {
    return BoxDecoration(
      color: isCurrent
          ? primary.withValues(alpha: 0.08)
          : (isNext ? primary.withValues(alpha: 0.04) : Colors.white),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isCurrent
            ? primary.withValues(alpha: 0.5)
            : (isNext ? primary.withValues(alpha: 0.2) : ColorUtils.slate200),
        width: isCurrent ? 1.5 : (isNext ? 1.2 : 1.0),
      ),
      boxShadow: _buildRowShadow(isCurrent, isNext, primary),
    );
  }

  List<BoxShadow> _buildRowShadow(bool isCurrent, bool isNext, Color primary) {
    if (isCurrent) {
      return [
        BoxShadow(
          color: primary.withValues(alpha: 0.15),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];
    }
    if (isNext) {
      return [
        BoxShadow(
          color: primary.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return [];
  }

  Widget _buildSessionTimeColumn(
    String sessionNum,
    String startTime,
    String endTime,
    Color primary,
    bool isPast,
    bool isCurrent,
    bool isNext,
  ) {
    return SizedBox(
      width: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSessionNumberBox(
            sessionNum,
            primary,
            isPast,
            isCurrent,
            isNext,
          ),
          const SizedBox(height: 6),
          _buildStartTimeText(startTime, isPast, isCurrent, isNext, primary),
          _buildEndTimeText(endTime, isPast, isCurrent, isNext, primary),
        ],
      ),
    );
  }

  Widget _buildStartTimeText(
    String startTime,
    bool isPast,
    bool isCurrent,
    bool isNext,
    Color primary,
  ) {
    return Text(
      startTime,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: isPast
            ? ColorUtils.slate400
            : (isCurrent || isNext ? primary : ColorUtils.slate700),
      ),
    );
  }

  Widget _buildEndTimeText(
    String endTime,
    bool isPast,
    bool isCurrent,
    bool isNext,
    Color primary,
  ) {
    return Text(
      endTime,
      style: TextStyle(
        fontSize: 9,
        color: isPast
            ? ColorUtils.slate300
            : (isCurrent || isNext
                  ? primary.withValues(alpha: 0.7)
                  : ColorUtils.slate400),
      ),
    );
  }

  Widget _buildSessionNumberBox(
    String sessionNum,
    Color primary,
    bool isPast,
    bool isCurrent,
    bool isNext,
  ) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isCurrent || isNext
            ? primary
            : (isPast ? ColorUtils.slate200 : ColorUtils.slate100),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        sessionNum,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isCurrent || isNext
              ? Colors.white
              : (isPast ? ColorUtils.slate500 : ColorUtils.slate700),
        ),
      ),
    );
  }
}
