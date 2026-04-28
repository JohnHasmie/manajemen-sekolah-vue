// Full-month calendar grid showing each day color-coded by attendance
// status. Used by the parent Kehadiran "Lihat kalender penuh" screen.
//
// Visual contract (mockup `Parent_Phase3_Kehadiran_Calendar_Mockup.svg`)
// ---------------------------------------------------------------------
//   • SEN-JUM in slate-500, SAB-MIN in slate-400 (visual de-emphasis
//     for weekends).
//   • Each weekday cell is a 28×32 rounded square colored by status.
//   • Days outside the target month render as plain slate-300 text on
//     transparent bg.
//   • Selected day (when `selectedDate` matches) gets a 2 px brand
//     azure ring around it.
//   • Tap any day → fires [onDaySelected].
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/attendance/attendance_status.dart';

/// 7-column SEN-MIN month calendar with per-day status colouring.
class AttendanceCalendarGrid extends StatelessWidget {
  /// Any [DateTime] in the target month — only the year/month parts
  /// are read. The grid renders that full calendar month from the
  /// nearest preceding Monday through the following Sunday.
  final DateTime month;

  /// Sparse map of day → status. Days missing from the map render in
  /// neutral slate (treated as "no record" rather than "alpha" — the
  /// calendar shouldn't lie about days the school hasn't reported on).
  final Map<DateTime, AttendanceStatus> dayStatuses;

  /// Optional currently-selected day — gets the brand azure ring.
  final DateTime? selectedDate;

  /// Tap callback — receives the date the user tapped (already
  /// normalised to year/month/day).
  final ValueChanged<DateTime>? onDaySelected;

  /// Brand color for the selected-day ring. Defaults to parent azure.
  final Color brandColor;

  const AttendanceCalendarGrid({
    super.key,
    required this.month,
    required this.dayStatuses,
    this.selectedDate,
    this.onDaySelected,
    this.brandColor = const Color(0xFF1A8FBE),
  });

  @override
  Widget build(BuildContext context) {
    final cells = _buildCells();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Weekdays(),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          for (final week in cells)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  for (final day in week)
                    Expanded(
                      child: Center(
                        child: _DayCell(
                          day: day,
                          targetMonth: month,
                          status: day == null
                              ? AttendanceStatus.none
                              : dayStatuses[_normalize(day)] ??
                                  AttendanceStatus.none,
                          isSelected: selectedDate != null &&
                              day != null &&
                              _normalize(selectedDate!) == _normalize(day),
                          brandColor: brandColor,
                          onTap: day == null || onDaySelected == null
                              ? null
                              : () => onDaySelected!(_normalize(day)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Build a 6×7 grid of dates covering the target month plus
  /// surrounding weekdays. Empty slots are `null`.
  List<List<DateTime?>> _buildCells() {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final lastOfMonth =
        DateTime(month.year, month.month + 1, 0); // day 0 of next month
    // Indonesian weeks start on Monday → weekday=1 ⇒ first column.
    // weekday=7 (Sun) ⇒ last column.
    final firstWeekdayIdx = firstOfMonth.weekday - 1; // 0..6
    final totalSlots = firstWeekdayIdx + lastOfMonth.day;
    final rows = (totalSlots / 7).ceil();
    final cells = <List<DateTime?>>[];
    var dayCounter = 1;
    var slotIdx = 0;
    for (var r = 0; r < rows; r++) {
      final week = <DateTime?>[];
      for (var c = 0; c < 7; c++) {
        if (slotIdx < firstWeekdayIdx ||
            dayCounter > lastOfMonth.day) {
          week.add(null);
        } else {
          week.add(DateTime(month.year, month.month, dayCounter));
          dayCounter++;
        }
        slotIdx++;
      }
      cells.add(week);
    }
    return cells;
  }

  static DateTime _normalize(DateTime d) =>
      DateTime(d.year, d.month, d.day);
}

class _Weekdays extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const headers = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'];
    return Row(
      children: [
        for (var i = 0; i < headers.length; i++)
          Expanded(
            child: Center(
              child: Text(
                headers[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: i >= 5
                      ? const Color(0xFF94A3B8)
                      : ColorUtils.slate500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime? day;
  final DateTime targetMonth;
  final AttendanceStatus status;
  final bool isSelected;
  final Color brandColor;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.targetMonth,
    required this.status,
    required this.isSelected,
    required this.brandColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (day == null) {
      return const SizedBox(width: 28, height: 32);
    }

    final inMonth =
        day!.year == targetMonth.year && day!.month == targetMonth.month;
    if (!inMonth) {
      // Outside-month placeholder — slate text on transparent.
      return SizedBox(
        width: 28,
        height: 32,
        child: Center(
          child: Text(
            '${day!.day}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFFCBD5E1),
            ),
          ),
        ),
      );
    }

    final palette = statusPalette(status);
    final isWeekend = day!.weekday >= 6;
    final cellBg = status == AttendanceStatus.none
        ? Colors.transparent
        : palette.bg;
    final cellText = status == AttendanceStatus.none
        ? (isWeekend
            ? const Color(0xFF94A3B8)
            : const Color(0xFF475569))
        : palette.text;

    final cell = Container(
      width: 28,
      height: 32,
      decoration: BoxDecoration(
        color: cellBg,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      alignment: Alignment.center,
      child: Text(
        '${day!.day}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: status == AttendanceStatus.none
              ? FontWeight.w500
              : FontWeight.w700,
          color: cellText,
        ),
      ),
    );

    final wrapped = isSelected
        ? Container(
            width: 36,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              border: Border.all(color: brandColor, width: 2),
            ),
            alignment: Alignment.center,
            child: cell,
          )
        : cell;

    if (onTap == null) return wrapped;
    return Material(
      color: Colors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        onTap: onTap,
        child: wrapped,
      ),
    );
  }
}
