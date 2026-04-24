import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/teacher_schedule_table_view.dart';

mixin ScheduleTableDataMixin on State<TeacherScheduleTableView> {
  List<Map<String, dynamic>> getSchedulesForDay(
    String dayName,
    List<dynamic> schedules,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final schedule in schedules) {
      final resolved = (this as dynamic).resolveDayName(schedule) as String?;
      if (resolved == dayName) {
        result.add(schedule as Map<String, dynamic>);
      }
    }
    result.sort(
      (a, b) => (this as dynamic)
          .startTimeMinutes(a)
          .compareTo((this as dynamic).startTimeMinutes(b)),
    );
    return result;
  }

  String tr(Map<String, String> map) {
    final languageProvider =
        (this as dynamic).widget.languageProvider as LanguageProvider?;
    return languageProvider?.getTranslatedText(map) ?? map['id'] ?? '';
  }

  Map<String, dynamic>? getSummary(
    Map<String, dynamic> schedule,
    String dayName,
  ) {
    final dailySummary =
        (this as dynamic).widget.dailySummary as Map<String, dynamic>?;
    if (dailySummary == null) return null;
    final summaries = dailySummary['summaries'];
    if (summaries == null || summaries is! Map) return null;
    final model = Schedule.fromJson(schedule);
    final classId = model.classId;
    final subjectId = model.subjectId;
    if (classId == null || subjectId == null) return null;
    final date = computeScheduleDate(schedule);
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final key = '${dateStr}__${classId}__$subjectId';
    final s = summaries[key];
    return s is Map<String, dynamic> ? s : null;
  }

  bool hasAttendance(
    Map<String, dynamic>? summary,
    Map<String, dynamic> schedule,
  ) {
    if (summary == null) return false;
    final hourNum = Schedule.fromJson(schedule).lessonHour;
    if (hourNum != null) {
      final hours = summary['attendance_hours'];
      final key = hourNum.toString();
      if (hours is Map && hours[key] is Map) {
        return hours[key]['filled'] == true;
      }
      return false;
    }
    return summary['attendance']?['filled'] == true;
  }

  bool hasActivity(
    Map<String, dynamic>? summary,
    Map<String, dynamic> schedule,
  ) {
    if (summary == null) return false;
    final hourNum = Schedule.fromJson(schedule).lessonHour;
    if (hourNum != null) {
      final hours = summary['activity_hours'];
      final key = hourNum.toString();
      if (hours is Map && hours[key] is Map) {
        return hours[key]['filled'] == true;
      }
      return false;
    }
    return summary['class_activity']?['filled'] == true;
  }

  bool hasMaterial(
    Map<String, dynamic>? summary,
    Map<String, dynamic> schedule,
  ) {
    if (summary == null) return false;
    final hourNum = Schedule.fromJson(schedule).lessonHour;
    if (hourNum != null) {
      final hours = summary['material_viewed_hours'];
      final key = hourNum.toString();
      if (hours is Map) {
        return hours[key] == true;
      }
      return false;
    }
    return summary['material_viewed'] == true;
  }

  /// Computes the date of the schedule based on day mapping.
  /// Uses a fixed Indonesian day-name → weekday-number map instead of
  /// dayOptions index (which includes "Semua Hari" at index 0).
  DateTime computeScheduleDate(Map<String, dynamic> schedule) {
    final now = DateTime.now();
    final dayIdMap = (this as dynamic).widget.dayIdMap as Map<String, String>;
    final targetDayId = Schedule.fromJson(schedule).dayId;
    final scheduleDay = dayIdMap.entries
        .firstWhere(
          (entry) => entry.value.toString() == targetDayId,
          orElse: () => const MapEntry('Senin', '1'),
        )
        .key;

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
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: now.weekday - 1));
    return monday.add(Duration(days: scheduleDayNum - 1));
  }
}
