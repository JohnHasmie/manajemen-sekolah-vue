// Mixin for schedule timing helpers and day/hour calculations.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart'
    as sched;

/// Mixin providing time and day helper methods.
mixin ScheduleTimingMixin {
  // Required abstract member from State.
  void setState(VoidCallback fn);
  BuildContext get context;

  // State access for timing.
  Map<String, String> get dayIdMap => {};
  dynamic get languageProvider => null;

  /// Day order for weekday calculations.
  List<String> get dayOrder => [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  /// Maps Indonesian and English day names to standard form.
  String normalizeDayName(String name) {
    name = name.trim().toLowerCase();
    if (name.contains('senin') || name.contains('monday')) {
      return 'Senin';
    }
    if (name.contains('selasa') || name.contains('tuesday')) {
      return 'Selasa';
    }
    if (name.contains('rabu') || name.contains('wednesday')) {
      return 'Rabu';
    }
    if (name.contains('kamis') || name.contains('thursday')) {
      return 'Kamis';
    }
    if (name.contains('jumat') || name.contains('friday')) {
      return 'Jumat';
    }
    if (name.contains('sabtu') || name.contains('saturday')) {
      return 'Sabtu';
    }
    if (name.contains('minggu') || name.contains('sunday')) {
      return 'Minggu';
    }
    return 'Senin';
  }

  /// Extracts day name from schedule using day_id or day_name.
  String getDayNameFromSchedule(Map<String, dynamic> schedule) {
    final model = sched.Schedule.fromJson(schedule);
    final dayId = model.dayId;
    if (dayId != null && dayId.isNotEmpty) {
      final entry = dayIdMap.entries.firstWhere(
        (e) => e.value.toString() == dayId,
        orElse: () => const MapEntry('', ''),
      );
      if (entry.key.isNotEmpty) {
        return normalizeDayName(entry.key);
      }
    }
    final rawName = model.dayName ?? '';
    return rawName.isNotEmpty ? normalizeDayName(rawName) : 'Senin';
  }

  /// Gets weekday (1-7) for a day name.
  int dayWeekday(String dayName) {
    final idx = dayOrder.indexOf(dayName);
    return idx >= 0 ? idx + 1 : 1;
  }

  /// Checks if a day is in the past.
  bool isDayPastCheck(String dayName) =>
      dayWeekday(dayName) < DateTime.now().weekday;

  /// Checks if a day is today.
  bool isDayTodayCheck(String dayName) =>
      dayWeekday(dayName) == DateTime.now().weekday;

  /// Parses time string (HH:MM or HH.MM) to minutes.
  int _timeToMinutes(String timeStr) {
    final parts = timeStr.replaceAll('.', ':').split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  /// Checks if a lesson's end time has passed.
  bool isHourPastCheck(Map<String, dynamic> schedule) {
    final endTime = sched.Schedule.fromJson(schedule).endTime;
    if (endTime == null || endTime.isEmpty) return false;
    final parts = endTime.replaceAll('.', ':').split(':');
    if (parts.length < 2) return false;
    final endHour = int.tryParse(parts[0]) ?? 0;
    final endMinute = int.tryParse(parts[1]) ?? 0;
    final now = DateTime.now();
    return now.hour > endHour ||
        (now.hour == endHour && now.minute >= endMinute);
  }

  /// Checks if a lesson is currently in progress.
  bool isHourCurrentCheck(Map<String, dynamic> schedule) {
    final model = sched.Schedule.fromJson(schedule);
    final startTime = model.startTime;
    final endTime = model.endTime;
    if (startTime == null || endTime == null) return false;

    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    return nowMinutes >= _timeToMinutes(startTime) &&
        nowMinutes < _timeToMinutes(endTime);
  }

  /// Gets start time in minutes since midnight.
  int startTimeMinutesValue(Map<String, dynamic> schedule) {
    final time = sched.Schedule.fromJson(schedule).startTime;
    if (time == null || time.isEmpty) return 0;
    return _timeToMinutes(time);
  }
}
