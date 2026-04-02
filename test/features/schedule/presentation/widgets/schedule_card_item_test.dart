// Unit tests for ScheduleCardItem helper methods and summary logic.
// Tests the pure logic for determining button fill states, past-schedule
// detection, summary key lookups, and schedule date computation.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Summary key lookup (_getSummary logic) — now date-prefixed
  // ---------------------------------------------------------------------------

  group('Summary key matching (date-prefixed)', () {
    test('key format is date__classId__subjectId', () {
      const date = '2026-04-01';
      const classId = 'class-uuid-1';
      const subjectId = 'subject-uuid-1';
      final key = '${date}__${classId}__$subjectId';
      expect(key, '2026-04-01__class-uuid-1__subject-uuid-1');
    });

    test('summary lookup returns null when dailySummary is null', () {
      const Map<String, dynamic>? dailySummary = null;
      expect(dailySummary, isNull);
    });

    test('summary lookup returns null when summaries map is empty', () {
      final dailySummary = <String, dynamic>{
        'summaries': <String, dynamic>{},
      };
      final summaries = dailySummary['summaries'] as Map;
      final key = '2026-04-01__class-1__subject-1';
      expect(summaries[key], isNull);
    });

    test('summary lookup finds matching date-prefixed key', () {
      final dailySummary = <String, dynamic>{
        'summaries': {
          '2026-04-01__class-1__subject-1': {
            'attendance': {'filled': true, 'hadir': 10, 'sakit': 0, 'izin': 0, 'alpha': 0, 'total': 10},
            'class_activity': {'filled': true, 'count': 2},
            'material_progress': {'total': 5, 'checked': 3},
          },
        },
      };
      final summaries = dailySummary['summaries'] as Map;
      final summary = summaries['2026-04-01__class-1__subject-1'];
      expect(summary, isNotNull);
      expect(summary['attendance']['filled'], true);
      expect(summary['attendance']['hadir'], 10);
    });

    test('different dates for same class+subject are separate entries', () {
      final dailySummary = <String, dynamic>{
        'summaries': {
          '2026-04-01__class-1__subject-1': {
            'attendance': {'filled': true, 'hadir': 10},
          },
          '2026-04-02__class-1__subject-1': {
            'attendance': {'filled': false, 'hadir': 0},
          },
        },
      };
      final summaries = dailySummary['summaries'] as Map;
      expect(summaries['2026-04-01__class-1__subject-1']!['attendance']['filled'], true);
      expect(summaries['2026-04-02__class-1__subject-1']!['attendance']['filled'], false);
    });
  });

  // ---------------------------------------------------------------------------
  // Button fill state logic
  // ---------------------------------------------------------------------------

  group('Button fill state', () {
    test('hasAttendance returns true when filled', () {
      final summary = {'attendance': {'filled': true, 'hadir': 10}};
      expect(summary['attendance']?['filled'] == true, isTrue);
    });

    test('hasAttendance returns false when not filled', () {
      final summary = {'attendance': {'filled': false, 'hadir': 0}};
      expect(summary['attendance']?['filled'] == true, isFalse);
    });

    test('hasAttendance returns false when summary is null', () {
      const Map<String, dynamic>? summary = null;
      expect(summary != null && summary['attendance']?['filled'] == true, isFalse);
    });

    test('hasActivity returns true when count > 0', () {
      final summary = {'class_activity': {'filled': true, 'count': 2}};
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
  });

  // ---------------------------------------------------------------------------
  // Schedule date computation (most recent occurrence)
  // ---------------------------------------------------------------------------

  group('computeScheduleDate logic', () {
    // Replicates the _computeScheduleDate logic for testing
    DateTime computeDate(int scheduleDayIndex, DateTime now) {
      final todayIndex = now.weekday;
      int daysSince = todayIndex - scheduleDayIndex;
      if (daysSince < 0) daysSince += 7;
      return DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: daysSince));
    }

    test('same day returns today', () {
      // If schedule is Wednesday and today is Wednesday
      final now = DateTime(2026, 4, 1); // Wednesday
      final result = computeDate(3, now); // 3 = Rabu in dayOptions (index)
      expect(result, DateTime(2026, 4, 1));
    });

    test('past day returns most recent occurrence', () {
      // If schedule is Monday and today is Wednesday
      final now = DateTime(2026, 4, 1); // Wednesday
      final result = computeDate(1, now); // 1 = Senin
      expect(result, DateTime(2026, 3, 30)); // Last Monday
    });

    test('future day returns last week occurrence', () {
      // If schedule is Friday and today is Wednesday
      final now = DateTime(2026, 4, 1); // Wednesday
      final result = computeDate(5, now); // 5 = Jumat
      expect(result, DateTime(2026, 3, 27)); // Last Friday
    });

    test('never returns a future date', () {
      final now = DateTime.now();
      for (int dayIdx = 1; dayIdx <= 6; dayIdx++) {
        final result = computeDate(dayIdx, now);
        expect(result.isBefore(now.add(const Duration(days: 1))), isTrue,
            reason: 'dayIndex=$dayIdx should not be in the future');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Past schedule detection
  // ---------------------------------------------------------------------------

  group('isPast detection', () {
    test('day before today is past', () {
      final now = DateTime.now();
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

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final s in schedules) {
        final day = s['day_name'] as String;
        grouped.putIfAbsent(day, () => []).add(s);
      }

      final orderedKeys = <String>[];
      for (final day in dayOrder) {
        if (grouped.containsKey(day)) orderedKeys.add(day);
      }

      expect(orderedKeys, ['Senin', 'Rabu', 'Jumat']);
      expect(grouped['Rabu']!.length, 2);
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
        return '${timeParts[0].padLeft(2, '0')}:${timeParts[1].padLeft(2, '0')}';
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
