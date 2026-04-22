import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/teacher_schedule_table_view.dart';

mixin ScheduleTableTimeHelpersMixin on State<TeacherScheduleTableView> {
  String formatTime(String? time) {
    if (time == null || time.isEmpty) return '--:--';
    final cleaned = time.replaceAll('.', ':');
    final parts = cleaned.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return time.length >= 5 ? time.substring(0, 5) : time;
  }

  int startTimeMinutes(Map<String, dynamic> schedule) {
    final time = Schedule.fromJson(schedule).startTime;
    if (time == null || time.isEmpty) return 0;
    final parts = time.replaceAll('.', ':').split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  bool isHourPast(String dayName, Map<String, dynamic> schedule) {
    final isDayToday = (this as dynamic).isDayToday(dayName) as bool;
    final isDayPastVal = (this as dynamic).isDayPast(dayName) as bool;
    if (!isDayToday) return isDayPastVal;
    final endTime = Schedule.fromJson(schedule).endTime;
    if (endTime == null || endTime.isEmpty) return false;
    final parts = endTime.replaceAll('.', ':').split(':');
    if (parts.length < 2) return false;
    final endHour = int.tryParse(parts[0]) ?? 0;
    final endMinute = int.tryParse(parts[1]) ?? 0;
    final now = DateTime.now();
    return now.hour > endHour ||
        (now.hour == endHour && now.minute >= endMinute);
  }

  bool isHourCurrent(String dayName, Map<String, dynamic> schedule) {
    final isDayToday = (this as dynamic).isDayToday(dayName) as bool;
    if (!isDayToday) return false;
    final model = Schedule.fromJson(schedule);
    final startTime = model.startTime;
    final endTime = model.endTime;
    if (startTime == null || endTime == null) return false;

    int toMinutes(String t) {
      final parts = t.replaceAll('.', ':').split(':');
      if (parts.length < 2) return 0;
      return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    }

    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    return nowMinutes >= toMinutes(startTime) &&
        nowMinutes < toMinutes(endTime);
  }
}
