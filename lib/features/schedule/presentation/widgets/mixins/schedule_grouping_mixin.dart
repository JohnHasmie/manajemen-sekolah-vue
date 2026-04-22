// Mixin for schedule grouping and scroll target logic.
import 'package:flutter/material.dart';

/// Model for a day's schedule group.
class DayGroup {
  final String dayName;
  final List<Map<String, dynamic>> schedules;
  const DayGroup({required this.dayName, required this.schedules});
}

/// Model for scroll target position.
class ScrollTarget {
  final int groupIdx;
  final int scheduleIdx;
  final bool isCurrent;
  const ScrollTarget({
    required this.groupIdx,
    required this.scheduleIdx,
    required this.isCurrent,
  });
}

/// Mixin providing schedule grouping and scroll target logic.
mixin ScheduleGroupingMixin {
  // Required abstract members from State.
  void setState(VoidCallback fn);
  BuildContext get context;

  // State access for grouping.
  List<dynamic> get schedules => [];
  List<String> get dayOrder => [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  // Abstract methods that must be implemented by the mixing class.
  String getDayName(Map<String, dynamic> schedule);
  bool isDayPast(String dayName);
  bool isDayToday(String dayName);
  bool isHourPast(Map<String, dynamic> schedule);
  bool isHourCurrent(Map<String, dynamic> schedule);
  int startTimeMinutes(Map<String, dynamic> schedule);

  /// Groups schedules by day name in the correct order.
  List<DayGroup> groupByDay() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final schedule in schedules) {
      final s = schedule as Map<String, dynamic>;
      final dayName = getDayName(s);
      grouped.putIfAbsent(dayName, () => []).add(s);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => startTimeMinutes(a).compareTo(startTimeMinutes(b)));
    }
    final groups = <DayGroup>[];
    for (final day in dayOrder) {
      if (grouped.containsKey(day)) {
        groups.add(DayGroup(dayName: day, schedules: grouped[day]!));
      }
    }
    return groups;
  }

  /// Finds the scroll target (current, next, or future lesson).
  /// Returns null if no suitable target found.
  ScrollTarget? findScrollTarget(List<DayGroup> groups) {
    // Today: find current or next lesson
    for (int g = 0; g < groups.length; g++) {
      if (!isDayToday(groups[g].dayName)) continue;
      for (int i = 0; i < groups[g].schedules.length; i++) {
        final schedule = groups[g].schedules[i];
        if (isHourCurrent(schedule)) {
          return ScrollTarget(groupIdx: g, scheduleIdx: i, isCurrent: true);
        }
        if (!isHourPast(schedule)) {
          return ScrollTarget(groupIdx: g, scheduleIdx: i, isCurrent: false);
        }
      }
    }

    // Today passed — find first lesson of next upcoming day
    for (int g = 0; g < groups.length; g++) {
      if (!isDayPast(groups[g].dayName) && !isDayToday(groups[g].dayName)) {
        return ScrollTarget(groupIdx: g, scheduleIdx: 0, isCurrent: false);
      }
    }

    return null;
  }
}
