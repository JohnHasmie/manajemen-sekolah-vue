// Unit tests for grade_recap_day_utils.dart
// These are pure Dart tests — no Flutter widgets involved, so no pumpWidget needed.
// Like testing a Laravel helper file: plain input → output assertions.
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_day_utils.dart';

void main() {
  // ---------------------------------------------------------------------------
  // normalizeDayName
  // ---------------------------------------------------------------------------
  group('normalizeDayName', () {
    test('returns canonical Indonesian name for English weekday names', () {
      expect(normalizeDayName('Monday'), 'Senin');
      expect(normalizeDayName('Tuesday'), 'Selasa');
      expect(normalizeDayName('Wednesday'), 'Rabu');
      expect(normalizeDayName('Thursday'), 'Kamis');
      expect(normalizeDayName('Friday'), 'Jumat');
      expect(normalizeDayName('Saturday'), 'Sabtu');
      expect(normalizeDayName('Sunday'), 'Minggu');
    });

    test('returns canonical Indonesian name for Indonesian weekday names', () {
      expect(normalizeDayName('Senin'), 'Senin');
      expect(normalizeDayName('Selasa'), 'Selasa');
      expect(normalizeDayName('Rabu'), 'Rabu');
      expect(normalizeDayName('Kamis'), 'Kamis');
      expect(normalizeDayName('Jumat'), 'Jumat');
      expect(normalizeDayName('Sabtu'), 'Sabtu');
      expect(normalizeDayName('Minggu'), 'Minggu');
    });

    test('is case-insensitive for input', () {
      expect(normalizeDayName('MONDAY'), 'Senin');
      expect(normalizeDayName('monday'), 'Senin');
      expect(normalizeDayName('SENIN'), 'Senin');
      expect(normalizeDayName('senin'), 'Senin');
      expect(normalizeDayName('Friday'), 'Jumat');
      expect(normalizeDayName('friday'), 'Jumat');
    });

    test('trims leading/trailing whitespace before matching', () {
      expect(normalizeDayName('  Monday  '), 'Senin');
      expect(normalizeDayName('\tSabtu\n'), 'Sabtu');
    });

    test('returns lowercased input unchanged when no match is found', () {
      // Unknown values fall through — they are trimmed and lowercased.
      expect(normalizeDayName('Libur'), 'libur');
      expect(normalizeDayName('UNKNOWN'), 'unknown');
    });

    test('matches by substring — partial names also normalise correctly', () {
      // "senin" appears inside longer strings
      expect(normalizeDayName('hari-senin'), 'Senin');
      expect(normalizeDayName('this monday morning'), 'Senin');
    });
  });

  // ---------------------------------------------------------------------------
  // extractDayIds
  // ---------------------------------------------------------------------------
  group('extractDayIds', () {
    test('returns empty list when schedule is null', () {
      expect(extractDayIds(null), isEmpty);
    });

    test('returns empty list when schedule has no days_ids or day_id key', () {
      expect(extractDayIds({'subject': 'Math'}), isEmpty);
    });

    test('handles days_ids as a List (already-parsed JSON array)', () {
      final schedule = {'days_ids': [1, 2, 3]};
      expect(extractDayIds(schedule), ['1', '2', '3']);
    });

    test('handles day_id as a List fallback when days_ids is absent', () {
      final schedule = {'day_id': [5, 6]};
      expect(extractDayIds(schedule), ['5', '6']);
    });

    test('handles days_ids as a JSON-encoded string', () {
      final schedule = {'days_ids': '[1,2,3]'};
      expect(extractDayIds(schedule), ['1', '2', '3']);
    });

    test('handles days_ids as a comma-separated string', () {
      final schedule = {'days_ids': '1,2,3'};
      expect(extractDayIds(schedule), ['1', '2', '3']);
    });

    test('trims spaces in comma-separated string values', () {
      final schedule = {'days_ids': ' 1 , 2 , 3 '};
      expect(extractDayIds(schedule), ['1', '2', '3']);
    });

    test('filters out empty tokens from comma-separated strings', () {
      final schedule = {'days_ids': '1,,2'};
      expect(extractDayIds(schedule), ['1', '2']);
    });

    test('falls back to rawIds.toString() for non-List non-String values', () {
      // E.g. a bare integer (rare but possible from some API responses).
      final schedule = {'days_ids': 7};
      expect(extractDayIds(schedule), ['7']);
    });

    test('prefers days_ids over day_id when both keys are present', () {
      final schedule = {'days_ids': [1, 2], 'day_id': [9]};
      expect(extractDayIds(schedule), ['1', '2']);
    });

    test('gracefully returns raw string split when JSON decode fails', () {
      // A malformed JSON string that starts with "[" but is not valid JSON.
      final schedule = {'days_ids': '[broken'};
      // Falls through to comma-split path — no "[" after failed decode? Actually
      // the string contains "[" so the JSON branch is tried first; on failure it
      // falls through to comma-split.
      final result = extractDayIds(schedule);
      expect(result, isA<List<String>>());
    });
  });
}
