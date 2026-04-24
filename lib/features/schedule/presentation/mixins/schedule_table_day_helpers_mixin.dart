import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/teacher_schedule_table_view.dart';

const _kDayOrder = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

mixin ScheduleTableDayHelpersMixin on State<TeacherScheduleTableView> {
  late List<String> _availableDays;

  List<String> computeAvailableDays(List<dynamic> schedules) {
    final daySet = <String>{};
    for (final schedule in schedules) {
      final dayName = resolveDayName(schedule);
      if (dayName != null) daySet.add(dayName);
    }
    return _kDayOrder.where(daySet.contains).toList();
  }

  String? resolveDayName(dynamic schedule) {
    final dayIdMap = (this as dynamic).widget.dayIdMap as Map<String, String>;
    final model = Schedule.fromJson(
      Map<String, dynamic>.from(schedule as Map),
    );
    final dayId = model.dayId;
    if (dayId != null && dayId.isNotEmpty) {
      final entry = dayIdMap.entries.firstWhere(
        (e) => e.value.toString() == dayId,
        orElse: () => const MapEntry('', ''),
      );
      if (entry.key.isNotEmpty) return normalizeDayName(entry.key);
    }
    final rawName = model.dayName ?? '';
    return rawName.isNotEmpty ? normalizeDayName(rawName) : null;
  }

  String normalizeDayName(String name) {
    name = name.trim().toLowerCase();
    if (name.contains('senin') || name.contains('monday')) return 'Senin';
    if (name.contains('selasa') || name.contains('tuesday')) {
      return 'Selasa';
    }
    if (name.contains('rabu') || name.contains('wednesday')) return 'Rabu';
    if (name.contains('kamis') || name.contains('thursday')) return 'Kamis';
    if (name.contains('jumat') || name.contains('friday')) return 'Jumat';
    if (name.contains('sabtu') || name.contains('saturday')) return 'Sabtu';
    return 'Senin';
  }

  int dayWeekday(String dayName) {
    final idx = _kDayOrder.indexOf(dayName);
    return idx >= 0 ? idx + 1 : 1;
  }

  bool isDayPast(String dayName) =>
      dayWeekday(dayName) < DateTime.now().weekday;

  bool isDayToday(String dayName) =>
      dayWeekday(dayName) == DateTime.now().weekday;

  int findTodayTabIndex() {
    for (int i = 0; i < _availableDays.length; i++) {
      if (isDayToday(_availableDays[i])) return i;
    }
    for (int i = 0; i < _availableDays.length; i++) {
      if (!isDayPast(_availableDays[i])) return i;
    }
    return 0;
  }
}
