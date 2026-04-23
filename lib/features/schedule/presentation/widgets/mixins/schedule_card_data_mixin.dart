import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';

/// Mixin for data extraction and date computation in schedule cards.
mixin ScheduleCardDataMixin {
  // Abstract member requiring implementation.
  void setState(VoidCallback fn);
  BuildContext get context;

  // Data access properties.
  Map<String, dynamic> get schedule => {};
  Map<String, String> get dayIdMap => {};
  List<String> get dayOptions => [];
  Map<String, dynamic>? get dailySummary => null;

  /// Typed view over [schedule] — all getters delegate here so the
  /// Indonesian↔English key normalization happens once.
  Schedule get _scheduleModel => Schedule.fromJson(schedule);

  /// Extracts subject ID from schedule data.
  String? get subjectId => _scheduleModel.subjectId;

  /// Extracts subject name from schedule data.
  String? get subjectName => _scheduleModel.subjectName;

  /// Extracts class ID from schedule data.
  String? get classId => _scheduleModel.classId;

  /// Extracts class name from schedule data.
  String? get className => _scheduleModel.className;

  /// Extracts lesson hour ID from schedule data.
  String? get lessonHourId => _scheduleModel.lessonHourId;

  /// Computes the date of the schedule based on day mapping.
  ///
  /// Uses a fixed Indonesian day-name → weekday-number map instead of
  /// [dayOptions] index (which includes "Semua Hari" at index 0 and
  /// would shift all indices by 1).
  DateTime computeScheduleDate() {
    final now = DateTime.now();
    final dayIdStr = _scheduleModel.dayId;
    final scheduleDay = dayIdMap.entries
        .firstWhere(
          (entry) => entry.value.toString() == dayIdStr,
          orElse: () => const MapEntry('Senin', '1'),
        )
        .key;

    // Map Indonesian day names to ISO weekday numbers (Monday=1 .. Sunday=7)
    const dayNameToWeekday = {
      'Senin': 1,
      'Selasa': 2,
      'Rabu': 3,
      'Kamis': 4,
      'Jumat': 5,
      'Sabtu': 6,
      'Minggu': 7,
    };

    final scheduleDayNum = dayNameToWeekday[scheduleDay] ?? 1;
    // Difference in days from the start of the current week (Monday)
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: now.weekday - 1));
    return monday.add(Duration(days: scheduleDayNum - 1));
  }

  /// Extracts summary data for current schedule/class/subject.
  Map<String, dynamic>? getSummary() {
    if (dailySummary == null) return null;
    final summaries = dailySummary!['summaries'];
    if (summaries == null || summaries is! Map) return null;
    final classIdVal = classId;
    final subjectIdVal = subjectId;
    if (classIdVal == null || subjectIdVal == null) return null;

    final date = computeScheduleDate();
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final key = '${dateStr}__${classIdVal}__$subjectIdVal';
    final s = summaries[key];
    return s is Map<String, dynamic> ? s : null;
  }

  /// Checks if attendance data exists and is filled for this specific
  /// schedule slot (lesson hour). Uses `hour_number` as the key because
  /// lesson_hour_id varies per day (each day has its own UUIDs for the
  /// same hour_number), but hour_number is consistent across days.
  bool hasAttendance(Map<String, dynamic>? summary) {
    if (summary == null) return false;
    final hourNum = _scheduleModel.lessonHour;
    if (hourNum != null) {
      final hours = summary['attendance_hours'];
      final key = hourNum.toString();
      if (hours is Map && hours[key] is Map) {
        return hours[key]['filled'] == true;
      }
      // No per-hour data for this slot → not filled
      return false;
    }
    // Fallback: no lesson_hour on schedule → use aggregate
    return summary['attendance']?['filled'] == true;
  }

  /// Checks if activity data exists and is filled for this specific
  /// schedule slot. Uses `hour_number` key in `activity_hours` so that
  /// different hour slots with the same class+subject are independent.
  bool hasActivity(Map<String, dynamic>? summary) {
    if (summary == null) return false;
    final hourNum = _scheduleModel.lessonHour;
    if (hourNum != null) {
      final hours = summary['activity_hours'];
      final key = hourNum.toString();
      if (hours is Map && hours[key] is Map) {
        return hours[key]['filled'] == true;
      }
      return false;
    }
    // Fallback: no lesson_hour → use aggregate
    return summary['class_activity']?['filled'] == true;
  }

  /// Checks if material has been viewed for this specific schedule slot.
  /// Uses `hour_number` key in `material_viewed_hours` (same reasoning
  /// as hasAttendance — day-independent).
  bool hasMaterial(Map<String, dynamic>? summary) {
    if (summary == null) return false;
    final hourNum = _scheduleModel.lessonHour;
    if (hourNum != null) {
      final hours = summary['material_viewed_hours'];
      final key = hourNum.toString();
      if (hours is Map) {
        return hours[key] == true;
      }
      return false;
    }
    // Fallback: no lesson_hour → use aggregate
    return summary['material_viewed'] == true;
  }

  /// Returns fill state record for all tracked items.
  ({bool attendanceFilled, bool activityFilled, bool materialFilled})
  getFillStates(Map<String, dynamic>? summary) {
    return (
      attendanceFilled: hasAttendance(summary),
      activityFilled: hasActivity(summary),
      materialFilled: hasMaterial(summary),
    );
  }
}
