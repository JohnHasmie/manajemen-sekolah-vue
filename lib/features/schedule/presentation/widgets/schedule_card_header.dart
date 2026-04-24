import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_card_helpers.dart';

/// Header section of a schedule card — compact hour chip + subject/time/class.
class ScheduleCardHeader extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final Color accentColor;
  final Color subTextColor;
  final String selectedAcademicYear;
  final LanguageProvider languageProvider;

  /// Day-specific color for the hour box (e.g. indigo for Monday).
  final Color? dayColor;

  /// Whether the card is dimmed (past schedule).
  final bool isPast;

  /// Whether this is viewed in wali kelas (homeroom) mode.
  final bool isHomeroomView;

  const ScheduleCardHeader({
    super.key,
    required this.schedule,
    required this.accentColor,
    required this.subTextColor,
    required this.selectedAcademicYear,
    required this.languageProvider,
    this.dayColor,
    this.isPast = false,
    this.isHomeroomView = false,
  });

  Schedule get _model => Schedule.fromJson(schedule);

  Color get _hourBoxColor {
    if (isPast) return ColorUtils.slate400;
    return dayColor ?? accentColor;
  }

  /// Theme/primary color — always uses accentColor (green).
  Color get _themeColor {
    if (isPast) return ColorUtils.slate400;
    return accentColor;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildHourChip(),
        const SizedBox(width: 10),
        Expanded(child: _buildInfo()),
      ],
    );
  }

  // ── Hour chip: compact day-colored rounded square ──

  Widget _buildHourChip() {
    final color = _hourBoxColor;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: isPast
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withValues(alpha: 0.78)],
              ),
        color: isPast ? color : null,
        borderRadius: BorderRadius.circular(10),
        boxShadow: isPast
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Center(
        child: Text(
          _model.lessonHour?.toString() ?? '-',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1,
          ),
        ),
      ),
    );
  }

  // ── Right side: subject + class badge on top, time + teacher below ──

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildTopRow(), const SizedBox(height: 4), _buildBottomRow()],
    );
  }

  /// Subject name + class badge.
  Widget _buildTopRow() {
    final className = (_model.className ?? '').isNotEmpty
        ? _model.className!
        : '-';

    return Row(
      children: [
        Expanded(
          child: Text(
            (_model.subjectName ?? '').isNotEmpty
                ? _model.subjectName!
                : languageProvider.getTranslatedText({
                    'en': 'Subject',
                    'id': 'Mata Pelajaran',
                  }),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: isPast ? ColorUtils.slate500 : ColorUtils.slate800,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _themeColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: _themeColor.withValues(alpha: 0.18),
              width: 0.5,
            ),
          ),
          child: Text(
            className,
            style: TextStyle(
              fontSize: 11,
              color: _themeColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  /// Time range + teacher name (teacher only shown in Wali Kelas mode).
  Widget _buildBottomRow() {
    final hasTeacher = isHomeroomView && (_model.teacherName ?? '').isNotEmpty;

    return Row(
      children: [
        _buildTimeText(),
        if (hasTeacher) ...[_buildDot(), Expanded(child: _buildTeacherText())],
      ],
    );
  }

  /// Inline time range — no pill background, just icon + text.
  Widget _buildTimeText() {
    final color = _themeColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_rounded, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          '${formatTimeStr(_model.startTime)}'
          ' – ${formatTimeStr(_model.endTime)}',
          style: TextStyle(
            fontSize: 11.5,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Separator dot between time and teacher.
  Widget _buildDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '·',
        style: TextStyle(
          fontSize: 13,
          color: _themeColor.withValues(alpha: 0.5),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  /// Inline teacher name — icon + text, no background.
  Widget _buildTeacherText() {
    final color = _themeColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.person_rounded, size: 12, color: color),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            _model.teacherName!,
            style: TextStyle(
              fontSize: 11.5,
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
}
