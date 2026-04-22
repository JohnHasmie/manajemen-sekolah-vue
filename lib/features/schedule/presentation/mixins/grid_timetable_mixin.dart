import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/timetable_data_source.dart';

/// Result returned by [updateGridData] method.
class GridUpdateResult {
  final List<ScheduleGridData> gridData;
  final TimetableDataSource timetableDataSource;

  const GridUpdateResult({
    required this.gridData,
    required this.timetableDataSource,
  });
}

/// Mixin providing grid and timetable data generation for
/// the admin schedule controller.
mixin GridTimetableMixin {
  /// Provides access to Riverpod [Ref].
  Ref get ref;

  /// Rebuilds the [TimetableDataSource] and
  /// [ScheduleGridData] list from the current schedule list
  /// and reference data.
  GridUpdateResult updateGridData({
    required List<dynamic> scheduleList,
    required List<dynamic> dayList,
    required List<dynamic> classList,
    required List<dynamic> lessonHourList,
    required List<dynamic> availableDays,
    required String? selectedDayId,
    required String? selectedClassId,
    required String? selectedJamPelajaran,
    required Function(Map<String, dynamic>) onScheduleTap,
  }) {
    final gridData = _generateTimetableData(
      scheduleList: scheduleList,
      dayList: dayList,
      classList: classList,
    );

    final languageProvider = ref.read(languageRiverpod);

    var filteredDayList = dayList;
    if (selectedDayId != null) {
      filteredDayList = dayList
          .where((d) => d['id'].toString() == selectedDayId)
          .toList();
    }

    final days = filteredDayList
        .map(
          (d) => translateDay(
            d['name'] ?? d['nama'] ?? '',
            languageProvider.currentLanguage,
          ),
        )
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList();

    var filteredClassList = classList;
    if (selectedClassId != null) {
      filteredClassList = classList
          .where((c) => c['id'].toString() == selectedClassId)
          .toList();
    }

    List<String> timeSlots = _generateTimeSlots(lessonHourList);
    if (selectedJamPelajaran != null) {
      timeSlots = lessonHourList
          .where((jp) {
            final h = (jp['hour_number'] ?? jp['jam_ke'])?.toString();
            return h == selectedJamPelajaran;
          })
          .map((jam) {
            String start = (jam['start_time'] ?? jam['jam_mulai'] ?? '')
                .toString();
            String end = (jam['end_time'] ?? jam['jam_selesai'] ?? '')
                .toString();
            if (start.length > 5) {
              start = start.substring(0, 5);
            }
            if (end.length > 5) {
              end = end.substring(0, 5);
            }
            return '$start-$end';
          })
          .toSet()
          .toList();
    }

    final dataSource = TimetableDataSource(
      timeSlots: timeSlots,
      days: days,
      classList: filteredClassList,
      gridData: gridData,
      primaryColor: getPrimaryColor(),
      onScheduleTap: onScheduleTap,
    );

    return GridUpdateResult(
      gridData: gridData,
      timetableDataSource: dataSource,
    );
  }

  /// Generates time slot strings from lesson hours.
  List<String> _generateTimeSlots(List<dynamic> lessonHourList) {
    final slots = lessonHourList
        .map((jam) {
          String start = (jam['start_time'] ?? jam['jam_mulai'] ?? '')
              .toString();
          String end = (jam['end_time'] ?? jam['jam_selesai'] ?? '').toString();
          if (start.length > 5) {
            start = start.substring(0, 5);
          }
          if (end.length > 5) {
            end = end.substring(0, 5);
          }
          return '$start-$end';
        })
        .toSet()
        .toList();

    slots.sort((a, b) {
      final startA = a.split('-').first;
      final startB = b.split('-').first;
      return startA.compareTo(startB);
    });

    return slots;
  }

  /// Generates grid data from schedule list.
  List<ScheduleGridData> _generateTimetableData({
    required List<dynamic> scheduleList,
    required List<dynamic> dayList,
    required List<dynamic> classList,
  }) {
    final List<ScheduleGridData> timetableData = [];
    final dayIdToName = _buildDayNameMap(dayList);
    final classIdToName = _buildClassNameMap(classList);
    final languageProvider = ref.read(languageRiverpod);

    for (final schedule in scheduleList) {
      final daysIds = _extractDayIds(schedule);
      for (final rawDayId in daysIds) {
        final dayId = rawDayId.toString();
        final gridItem = _createGridItem(
          schedule: schedule,
          dayId: dayId,
          dayIdToName: dayIdToName,
          classIdToName: classIdToName,
          languageCode: languageProvider.currentLanguage,
        );
        timetableData.add(gridItem);
      }
    }

    return timetableData;
  }

  /// Builds a map of day IDs to day names.
  Map<String, String> _buildDayNameMap(List<dynamic> dayList) {
    final Map<String, String> dayIdToName = {};
    for (final day in dayList) {
      final id = day['id']?.toString() ?? '';
      final name = day['name'] ?? day['nama'] ?? '';
      if (id.isNotEmpty) {
        dayIdToName[id] = name;
      }
    }
    return dayIdToName;
  }

  /// Builds a map of class IDs to class names.
  Map<String, String> _buildClassNameMap(List<dynamic> classList) {
    final Map<String, String> classIdToName = {};
    for (final cls in classList) {
      final id = cls['id']?.toString() ?? '';
      final name = cls['name'] ?? cls['nama'] ?? '';
      if (id.isNotEmpty) {
        classIdToName[id] = name;
      }
    }
    return classIdToName;
  }

  /// Extracts day IDs from a schedule item.
  List<dynamic> _extractDayIds(Map<String, dynamic> schedule) {
    final daysIds = [];
    if (schedule['days_ids'] != null) {
      if (schedule['days_ids'] is List) {
        daysIds.addAll(schedule['days_ids']);
      } else if (schedule['days_ids'] is String) {
        try {
          final parsed = (schedule['days_ids'] as String)
              .replaceAll('[', '')
              .replaceAll(']', '')
              .split(',');
          daysIds.addAll(parsed);
        } catch (e) {
          // Malformed days_ids
        }
      }
    }
    if (daysIds.isEmpty) {
      final dayId = Schedule.fromJson(schedule).dayId;
      if (dayId != null && dayId.isNotEmpty) {
        daysIds.add(dayId);
      }
    }
    return daysIds;
  }

  /// Creates a grid item from schedule data.
  ScheduleGridData _createGridItem({
    required Map<String, dynamic> schedule,
    required String dayId,
    required Map<String, String> dayIdToName,
    required Map<String, String> classIdToName,
    required String languageCode,
  }) {
    final model = Schedule.fromJson(schedule);
    final classId = model.classId ?? '';
    final dayName = dayIdToName[dayId] ?? '';
    final translatedDayName = translateDay(dayName, languageCode);
    final className = classIdToName[classId] ?? model.className ?? '';
    final formattedTimeSlot = _formatTimeSlot(schedule);

    return ScheduleGridData(
      id: model.id,
      timeSlot: formattedTimeSlot,
      day: translatedDayName,
      classroom: className,
      subject: (model.subjectName ?? '').isEmpty ? '-' : model.subjectName!,
      teacher: model.teacherName ?? '',
      originalData: schedule,
    );
  }

  /// Formats time slot from schedule.
  String _formatTimeSlot(Map<String, dynamic> schedule) {
    final model = Schedule.fromJson(schedule);
    final timeSlot = '${model.startTime ?? ''}-${model.endTime ?? ''}';
    final List<String> parts = timeSlot.split('-');
    String start = parts[0];
    String end = parts.length > 1 ? parts[1] : '';
    if (start.length > 5) {
      start = start.substring(0, 5);
    }
    if (end.length > 5) {
      end = end.substring(0, 5);
    }
    return '$start-$end';
  }

  /// Translates a day name between Indonesian and English.
  String translateDay(String dayName, String languageCode);

  /// Returns the primary color for the admin role.
  Color getPrimaryColor() => ColorUtils.getRoleColor('admin');
}
