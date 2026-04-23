import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';

/// Mixin providing formatting helper methods for the admin
/// schedule controller.
mixin FormattingFilteringMixin {
  /// Returns the grade level string for a class ID.
  String getGradeLevel(String classId, List<dynamic> classList) {
    try {
      final classItem = classList.firstWhere(
        (k) => k['id'] == classId,
        orElse: () => {},
      );
      return classItem['grade_level']?.toString() ?? '-';
    } catch (e) {
      return '-';
    }
  }

  /// Formats start–end time from a schedule map into
  /// "HH:mm - HH:mm".
  String formatTime(Map<String, dynamic> schedule) {
    final model = Schedule.fromJson(schedule);
    final startTime = model.startTime ?? '';
    final endTime = model.endTime ?? '';

    if (startTime.isEmpty || endTime.isEmpty) {
      return '-';
    }
    return '$startTime - $endTime';
  }

  /// Translates a day name between Indonesian and English
  /// based on [languageCode] ('id' or 'en').
  String translateDay(String dayName, String languageCode) {
    if (dayName.isEmpty) return '';

    const Map<String, String> enToId = {
      'Monday': 'Senin',
      'Tuesday': 'Selasa',
      'Wednesday': 'Rabu',
      'Thursday': 'Kamis',
      'Friday': 'Jumat',
      'Saturday': 'Sabtu',
      'Sunday': 'Minggu',
    };

    const Map<String, String> idToEn = {
      'Senin': 'Monday',
      'Selasa': 'Tuesday',
      'Rabu': 'Wednesday',
      'Kamis': 'Thursday',
      'Jumat': 'Friday',
      'Sabtu': 'Saturday',
      'Minggu': 'Sunday',
    };

    String normalizedDay = dayName.trim();
    if (normalizedDay.isNotEmpty) {
      normalizedDay =
          normalizedDay[0].toUpperCase() + normalizedDay.substring(1);
    }

    if (languageCode == 'id') {
      if (idToEn.containsKey(normalizedDay)) {
        return normalizedDay;
      }
      return enToId[normalizedDay] ?? normalizedDay;
    } else {
      if (enToId.containsKey(normalizedDay)) {
        return normalizedDay;
      }
      return idToEn[normalizedDay] ?? normalizedDay;
    }
  }

  /// Resolves day IDs for a schedule entry to localised
  /// day-name strings.
  String formatScheduleDays(
    Map<String, dynamic> schedule,
    List<dynamic> dayList,
    String languageCode,
  ) {
    final daysIds = [];
    if (schedule['days_ids'] != null) {
      if (schedule['days_ids'] is List) {
        daysIds.addAll(schedule['days_ids']);
      } else if (schedule['days_ids'] is String) {
        try {
          final raw = schedule['days_ids'] as String;
          final clean = raw
              .replaceAll('[', '')
              .replaceAll(']', '')
              .replaceAll('"', '')
              .replaceAll("'", '');
          if (clean.trim().isNotEmpty) {
            daysIds.addAll(clean.split(',').map((e) => e.trim()));
          }
        } catch (e) {
          // Malformed days_ids string
        }
      }
    }

    if (daysIds.isEmpty) {
      final model = Schedule.fromJson(schedule);
      if (model.dayId != null && model.dayId!.isNotEmpty) {
        daysIds.add(model.dayId);
      }
    }

    if (daysIds.isNotEmpty) {
      final dayNames = daysIds
          .map((id) {
            final idStr = id.toString();
            final day = dayList.firstWhere(
              (d) => d['id'].toString().toLowerCase() == idStr.toLowerCase(),
              orElse: () => {},
            );
            if ((day as Map).isNotEmpty) {
              return translateDay(
                day['name'] ?? day['nama'] ?? '',
                languageCode,
              );
            }
            return '';
          })
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      if (dayNames.isNotEmpty) {
        return dayNames.join(', ');
      }
    }

    final dayNameFallback = Schedule.fromJson(schedule).dayName ?? '';
    if (dayNameFallback.isNotEmpty) {
      return translateDay(dayNameFallback, languageCode);
    }

    return 'No Day';
  }
}
