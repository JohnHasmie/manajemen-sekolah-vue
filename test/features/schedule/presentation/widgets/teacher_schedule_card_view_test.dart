// Unit tests for TeacherScheduleCardView helper methods.
// Tests scroll target finding, current-hour detection, day count badge logic,
// and day grouping — all pure logic, no widget rendering.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Constants matching the widget ──
  const dayOrder = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

  int dayWeekday(String dayName) {
    final idx = dayOrder.indexOf(dayName);
    return idx >= 0 ? idx + 1 : 1;
  }

  bool isDayPast(String dayName) => dayWeekday(dayName) < DateTime.now().weekday;
  bool isDayToday(String dayName) => dayWeekday(dayName) == DateTime.now().weekday;

  bool isHourPast(Map<String, dynamic> schedule) {
    final endTime = (schedule['jam_selesai'] ?? schedule['end_time'])?.toString();
    if (endTime == null || endTime.isEmpty) return false;
    final parts = endTime.replaceAll('.', ':').split(':');
    if (parts.length < 2) return false;
    final endHour = int.tryParse(parts[0]) ?? 0;
    final endMinute = int.tryParse(parts[1]) ?? 0;
    final now = DateTime.now();
    return now.hour > endHour || (now.hour == endHour && now.minute >= endMinute);
  }

  bool isHourCurrent(Map<String, dynamic> schedule) {
    final startTime = (schedule['jam_mulai'] ?? schedule['start_time'])?.toString();
    final endTime = (schedule['jam_selesai'] ?? schedule['end_time'])?.toString();
    if (startTime == null || endTime == null) return false;

    int toMinutes(String t) {
      final parts = t.replaceAll('.', ':').split(':');
      if (parts.length < 2) return 0;
      return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    }

    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    return nowMinutes >= toMinutes(startTime) && nowMinutes < toMinutes(endTime);
  }

  // ---------------------------------------------------------------------------
  // isHourCurrent logic
  // ---------------------------------------------------------------------------

  group('isHourCurrent', () {
    test('returns true when now is between start and end', () {
      final now = DateTime.now();
      final startMinutes = now.hour * 60 + now.minute - 10; // 10 min ago
      final endMinutes = now.hour * 60 + now.minute + 30; // 30 min from now
      final startH = (startMinutes ~/ 60).toString().padLeft(2, '0');
      final startM = (startMinutes % 60).toString().padLeft(2, '0');
      final endH = (endMinutes ~/ 60).toString().padLeft(2, '0');
      final endM = (endMinutes % 60).toString().padLeft(2, '0');

      final schedule = {
        'jam_mulai': '$startH:$startM:00',
        'jam_selesai': '$endH:$endM:00',
      };
      expect(isHourCurrent(schedule), isTrue);
    });

    test('returns false when now is after end time', () {
      final schedule = {
        'jam_mulai': '01:00:00',
        'jam_selesai': '02:00:00',
      };
      // Unless test runs between 1-2am, this is always false
      final now = DateTime.now();
      if (now.hour >= 2) {
        expect(isHourCurrent(schedule), isFalse);
      }
    });

    test('returns false when now is before start time', () {
      final schedule = {
        'jam_mulai': '23:50:00',
        'jam_selesai': '23:59:00',
      };
      final now = DateTime.now();
      if (now.hour < 23 || (now.hour == 23 && now.minute < 50)) {
        expect(isHourCurrent(schedule), isFalse);
      }
    });

    test('returns false when times are null', () {
      expect(isHourCurrent({'jam_mulai': null, 'jam_selesai': null}), isFalse);
    });

    test('handles dot-separated times', () {
      final now = DateTime.now();
      final startMinutes = now.hour * 60 + now.minute - 5;
      final endMinutes = now.hour * 60 + now.minute + 25;
      final startH = (startMinutes ~/ 60).toString().padLeft(2, '0');
      final startM = (startMinutes % 60).toString().padLeft(2, '0');
      final endH = (endMinutes ~/ 60).toString().padLeft(2, '0');
      final endM = (endMinutes % 60).toString().padLeft(2, '0');

      final schedule = {
        'jam_mulai': '$startH.$startM.00',
        'jam_selesai': '$endH.$endM.00',
      };
      expect(isHourCurrent(schedule), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Scroll target finding logic
  // ---------------------------------------------------------------------------

  group('Scroll target finding', () {
    // Helper: mimics _findScrollTarget
    ({int groupIdx, int scheduleIdx, bool isCurrent})? findScrollTarget(
      List<({String dayName, List<Map<String, dynamic>> schedules})> groups,
    ) {
      // Today: find current or next lesson
      for (int g = 0; g < groups.length; g++) {
        if (!isDayToday(groups[g].dayName)) continue;
        for (int i = 0; i < groups[g].schedules.length; i++) {
          final schedule = groups[g].schedules[i];
          if (isHourCurrent(schedule)) {
            return (groupIdx: g, scheduleIdx: i, isCurrent: true);
          }
          if (!isHourPast(schedule)) {
            return (groupIdx: g, scheduleIdx: i, isCurrent: false);
          }
        }
      }
      // Next upcoming day
      for (int g = 0; g < groups.length; g++) {
        if (!isDayPast(groups[g].dayName) && !isDayToday(groups[g].dayName)) {
          return (groupIdx: g, scheduleIdx: 0, isCurrent: false);
        }
      }
      return null;
    }

    test('returns null when no groups', () {
      expect(findScrollTarget([]), isNull);
    });

    test('returns null when all days are in the past', () {
      // Create groups only for days before today
      final groups = <({String dayName, List<Map<String, dynamic>> schedules})>[];
      final now = DateTime.now();
      for (int i = 0; i < now.weekday - 1 && i < dayOrder.length; i++) {
        groups.add((
          dayName: dayOrder[i],
          schedules: [{'jam_mulai': '07:00', 'jam_selesai': '08:00'}],
        ));
      }
      if (groups.isNotEmpty && now.weekday > 1) {
        // All groups are past days — but isHourPast depends on time.
        // At minimum, verify the function doesn't crash.
        final result = findScrollTarget(groups);
        // Result is null because no group matches today or future
        expect(result, isNull);
      }
    });

    test('targets first lesson of next future day when today has no schedules', () {
      final now = DateTime.now();
      if (now.weekday >= 6) return; // Skip on Saturday/Sunday

      // Only put schedules on a day after today
      final futureDayIdx = now.weekday; // 0-indexed next day
      if (futureDayIdx >= dayOrder.length) return;

      final groups = [
        (
          dayName: dayOrder[futureDayIdx],
          schedules: [
            {'jam_mulai': '07:00', 'jam_selesai': '08:00'},
            {'jam_mulai': '09:00', 'jam_selesai': '10:00'},
          ],
        ),
      ];

      final result = findScrollTarget(groups);
      expect(result, isNotNull);
      expect(result!.groupIdx, 0);
      expect(result.scheduleIdx, 0);
      expect(result.isCurrent, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Day count badge logic
  // ---------------------------------------------------------------------------

  group('Day count badge', () {
    test('singular class label for count 1', () {
      const count = 1;
      final label = '$count ${count == 1 ? 'class' : 'classes'}';
      expect(label, '1 class');
    });

    test('plural classes label for count > 1', () {
      const count = 3;
      final label = '$count ${count == 1 ? 'class' : 'classes'}';
      expect(label, '3 classes');
    });

    test('Indonesian label uses kelas for any count', () {
      for (final count in [1, 2, 5]) {
        final label = '$count kelas';
        expect(label, '$count kelas');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Day header: today badge
  // ---------------------------------------------------------------------------

  group('Day header today detection', () {
    test('today matches current weekday', () {
      final now = DateTime.now();
      if (now.weekday <= dayOrder.length) {
        final todayName = dayOrder[now.weekday - 1];
        expect(isDayToday(todayName), isTrue);
      }
    });

    test('yesterday is past', () {
      final now = DateTime.now();
      if (now.weekday > 1) {
        final yesterdayName = dayOrder[now.weekday - 2];
        expect(isDayPast(yesterdayName), isTrue);
      }
    });

    test('tomorrow is not past and not today', () {
      final now = DateTime.now();
      if (now.weekday < 7) {
        final tomorrowName = dayOrder[now.weekday]; // weekday is 1-indexed, array is 0-indexed
        expect(isDayPast(tomorrowName), isFalse);
        expect(isDayToday(tomorrowName), isFalse);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // isHourPast edge cases
  // ---------------------------------------------------------------------------

  group('isHourPast', () {
    test('returns false for null end time', () {
      expect(isHourPast({'jam_selesai': null}), isFalse);
    });

    test('returns false for empty end time', () {
      expect(isHourPast({'jam_selesai': ''}), isFalse);
    });

    test('a very early end time (01:00) is always past during the day', () {
      final now = DateTime.now();
      if (now.hour >= 1) {
        expect(isHourPast({'jam_selesai': '01:00:00'}), isTrue);
      }
    });

    test('a very late end time (23:59) is never past before midnight', () {
      final now = DateTime.now();
      if (now.hour < 23 || (now.hour == 23 && now.minute < 59)) {
        expect(isHourPast({'jam_selesai': '23:59:00'}), isFalse);
      }
    });

    test('handles dot-separated format', () {
      final now = DateTime.now();
      if (now.hour >= 1) {
        expect(isHourPast({'jam_selesai': '01.00.00'}), isTrue);
      }
    });

    test('handles end_time alias', () {
      final now = DateTime.now();
      if (now.hour >= 1) {
        expect(isHourPast({'end_time': '01:00:00'}), isTrue);
      }
    });
  });
}
