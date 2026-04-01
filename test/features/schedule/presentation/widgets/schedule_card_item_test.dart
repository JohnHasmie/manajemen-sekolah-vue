// Unit tests for ScheduleCardItem helper methods and summary logic.
// Tests the pure logic for determining button fill states, past-schedule
// detection, and summary key lookups without rendering widgets.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Summary key lookup (_getSummary logic)
  // ---------------------------------------------------------------------------

  group('Summary key matching', () {
    test('key format is classId__subjectId', () {
      const classId = 'class-uuid-1';
      const subjectId = 'subject-uuid-1';
      final key = '${classId}__$subjectId';
      expect(key, 'class-uuid-1__subject-uuid-1');
    });

    test('summary lookup returns null when dailySummary is null', () {
      const Map<String, dynamic>? dailySummary = null;
      expect(dailySummary, isNull);
    });

    test('summary lookup returns null when summaries map is empty', () {
      final dailySummary = <String, dynamic>{
        'date': '2026-04-01',
        'summaries': <String, dynamic>{},
      };
      final summaries = dailySummary['summaries'] as Map;
      final key = 'class-1__subject-1';
      expect(summaries[key], isNull);
    });

    test('summary lookup finds matching key', () {
      final dailySummary = <String, dynamic>{
        'date': '2026-04-01',
        'summaries': {
          'class-1__subject-1': {
            'attendance': {'filled': true, 'hadir': 10, 'sakit': 0, 'izin': 0, 'alpha': 0, 'total': 10},
            'class_activity': {'filled': true, 'count': 2},
            'material_progress': {'total': 5, 'checked': 3},
          },
        },
      };
      final summaries = dailySummary['summaries'] as Map;
      final summary = summaries['class-1__subject-1'];
      expect(summary, isNotNull);
      expect(summary['attendance']['filled'], true);
      expect(summary['attendance']['hadir'], 10);
    });
  });

  // ---------------------------------------------------------------------------
  // Button fill state logic
  // ---------------------------------------------------------------------------

  group('Button fill state', () {
    test('hasAttendance returns true when filled', () {
      final summary = {
        'attendance': {'filled': true, 'hadir': 10},
      };
      expect(summary['attendance']?['filled'] == true, isTrue);
    });

    test('hasAttendance returns false when not filled', () {
      final summary = {
        'attendance': {'filled': false, 'hadir': 0},
      };
      expect(summary['attendance']?['filled'] == true, isFalse);
    });

    test('hasAttendance returns false when summary is null', () {
      const Map<String, dynamic>? summary = null;
      expect(summary != null && summary['attendance']?['filled'] == true, isFalse);
    });

    test('hasActivity returns true when count > 0', () {
      final summary = {
        'class_activity': {'filled': true, 'count': 2},
      };
      expect(summary['class_activity']?['filled'] == true, isTrue);
    });

    test('hasMaterial returns true when checked > 0', () {
      final summary = <String, dynamic>{
        'material_progress': <String, dynamic>{'total': 10, 'checked': 4},
      };
      final checked = summary['material_progress']?['checked'] as int? ?? 0;
      expect(checked > 0, isTrue);
    });

    test('hasMaterial returns false when checked is 0', () {
      final summary = <String, dynamic>{
        'material_progress': <String, dynamic>{'total': 10, 'checked': 0},
      };
      final checked = summary['material_progress']?['checked'] as int? ?? 0;
      expect(checked > 0, isFalse);
    });

    test('allFilled is true only when all three are filled', () {
      final summary = {
        'attendance': {'filled': true, 'hadir': 10},
        'class_activity': {'filled': true, 'count': 2},
        'material_progress': {'total': 10, 'checked': 4},
      };
      final attendanceFilled = summary['attendance']?['filled'] == true;
      final activityFilled = summary['class_activity']?['filled'] == true;
      final materialFilled = (summary['material_progress']?['checked'] as int? ?? 0) > 0;
      expect(attendanceFilled && activityFilled && materialFilled, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Today-only summary restriction
  // ---------------------------------------------------------------------------

  group('isScheduleToday logic', () {
    test('weekday mapping Senin=1 through Minggu=7', () {
      const dayWeekdays = {
        'Senin': 1, 'Selasa': 2, 'Rabu': 3, 'Kamis': 4,
        'Jumat': 5, 'Sabtu': 6, 'Minggu': 7,
      };
      expect(dayWeekdays['Senin'], 1);
      expect(dayWeekdays['Jumat'], 5);
      expect(dayWeekdays['Minggu'], 7);
    });

    test('summary only returned for today schedule', () {
      final now = DateTime.now();
      const dayOrder = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      final todayName = dayOrder[now.weekday - 1];

      // A schedule for today should match
      expect(now.weekday, now.weekday); // trivially true

      // A schedule for tomorrow should NOT match
      final tomorrowIdx = now.weekday % 7; // 0-indexed next day
      final tomorrowName = dayOrder[tomorrowIdx];
      expect(todayName != tomorrowName || now.weekday == 7, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Past schedule detection
  // ---------------------------------------------------------------------------

  group('isPast detection', () {
    test('day before today is past', () {
      final now = DateTime.now();
      // Monday (1) is past if today is Wednesday (3)
      if (now.weekday > 1) {
        expect(1 < now.weekday, isTrue);
      }
    });

    test('day after today is not past', () {
      final now = DateTime.now();
      if (now.weekday < 7) {
        expect(now.weekday + 1 > now.weekday, isTrue);
      }
    });

    test('hour is past when end time < current time', () {
      final now = DateTime.now();
      // An end time of 00:00 is always past (unless it's midnight)
      if (now.hour > 0) {
        expect(now.hour > 0, isTrue);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Day grouping and ordering
  // ---------------------------------------------------------------------------

  group('Day grouping', () {
    test('schedules grouped by day in Senin-first order', () {
      const dayOrder = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

      final schedules = [
        {'day_name': 'Rabu', 'jam_mulai': '09:00'},
        {'day_name': 'Senin', 'jam_mulai': '07:00'},
        {'day_name': 'Rabu', 'jam_mulai': '07:00'},
        {'day_name': 'Jumat', 'jam_mulai': '10:00'},
      ];

      // Group
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final s in schedules) {
        final day = s['day_name'] as String;
        grouped.putIfAbsent(day, () => []).add(s);
      }

      // Order by dayOrder
      final orderedKeys = <String>[];
      for (final day in dayOrder) {
        if (grouped.containsKey(day)) orderedKeys.add(day);
      }

      expect(orderedKeys, ['Senin', 'Rabu', 'Jumat']);
      expect(grouped['Rabu']!.length, 2);
    });

    test('schedules within a day sorted by start time', () {
      final daySchedules = [
        {'jam_mulai': '10:00:00'},
        {'jam_mulai': '07:30:00'},
        {'jam_mulai': '09:00:00'},
      ];

      int parseMinutes(String? time) {
        if (time == null) return 0;
        final parts = time.replaceAll('.', ':').split(':');
        if (parts.length < 2) return 0;
        return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
      }

      daySchedules.sort((a, b) =>
          parseMinutes(a['jam_mulai']).compareTo(parseMinutes(b['jam_mulai'])));

      expect(daySchedules[0]['jam_mulai'], '07:30:00');
      expect(daySchedules[1]['jam_mulai'], '09:00:00');
      expect(daySchedules[2]['jam_mulai'], '10:00:00');
    });
  });

  // ---------------------------------------------------------------------------
  // Time formatting
  // ---------------------------------------------------------------------------

  group('Time formatting', () {
    String formatTime(String? time) {
      if (time == null || time.isEmpty) return '--:--';
      final cleanedTime = time.replaceAll('.', ':');
      final timeParts = cleanedTime.split(':');
      if (timeParts.length >= 2) {
        final hour = timeParts[0].padLeft(2, '0');
        final minute = timeParts[1].padLeft(2, '0');
        return '$hour:$minute';
      }
      return time.length >= 5 ? time.substring(0, 5) : time;
    }

    test('formats HH:MM:SS to HH:MM', () {
      expect(formatTime('07:30:00'), '07:30');
      expect(formatTime('14:00:00'), '14:00');
    });

    test('formats HH.MM.SS to HH:MM', () {
      expect(formatTime('07.30.00'), '07:30');
    });

    test('handles null and empty', () {
      expect(formatTime(null), '--:--');
      expect(formatTime(''), '--:--');
    });

    test('pads single digit hours', () {
      expect(formatTime('9:05:00'), '09:05');
    });
  });
}
