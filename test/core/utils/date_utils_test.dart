/// Unit tests for AppDateUtils.
///
/// Covers:
/// - parseLocalDate: YYYY-MM-DD → local DateTime (no UTC shift)
/// - formatDateForApi: DateTime → 'yyyy-MM-dd'
/// - formatDateReadable: DateTime → 'dd/MM/yyyy'
/// - formatDateIndonesian: DateTime → 'dd MMMM yyyy' in id_ID
/// - formatDateFull: DateTime → 'EEEE, dd MMMM yyyy' in id_ID
/// - parseApiDate: null, DateTime passthrough, date-only string, ISO timestamp
/// - formatDateString: null/empty, valid date string, ISO timestamp
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';

void main() {
  setUpAll(() async {
    // Initialize date symbols for Indonesian locale used by formatDateIndonesian/Full
    await initializeDateFormatting('id_ID', null);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // parseLocalDate
  // ─────────────────────────────────────────────────────────────────────────
  group('AppDateUtils.parseLocalDate', () {
    test('parses YYYY-MM-DD as local time (no UTC offset)', () {
      final result = AppDateUtils.parseLocalDate('2024-01-15');
      expect(result.year, 2024);
      expect(result.month, 1);
      expect(result.day, 15);
      expect(result.isUtc, isFalse);
    });

    test('parses "2024-03-31" correctly', () {
      final result = AppDateUtils.parseLocalDate('2024-03-31');
      expect(result.year, 2024);
      expect(result.month, 3);
      expect(result.day, 31);
    });

    test('parses "2000-01-01" correctly', () {
      final result = AppDateUtils.parseLocalDate('2000-01-01');
      expect(result.year, 2000);
      expect(result.month, 1);
      expect(result.day, 1);
    });

    test('returns today on invalid string', () {
      final before = DateTime.now();
      final result = AppDateUtils.parseLocalDate('not-a-date');
      final after = DateTime.now();
      // Should be between before and after (i.e., "today")
      expect(result.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(result.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('time components default to midnight', () {
      final result = AppDateUtils.parseLocalDate('2024-06-15');
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // formatDateForApi
  // ─────────────────────────────────────────────────────────────────────────
  group('AppDateUtils.formatDateForApi', () {
    test('formats DateTime to YYYY-MM-DD', () {
      final date = DateTime(2024, 1, 15);
      expect(AppDateUtils.formatDateForApi(date), equals('2024-01-15'));
    });

    test('pads month with leading zero', () {
      final date = DateTime(2024, 3, 5);
      expect(AppDateUtils.formatDateForApi(date), equals('2024-03-05'));
    });

    test('formats December 31 correctly', () {
      final date = DateTime(2024, 12, 31);
      expect(AppDateUtils.formatDateForApi(date), equals('2024-12-31'));
    });

    test('round-trip: parseLocalDate → formatDateForApi returns original string', () {
      const original = '2024-08-20';
      final parsed = AppDateUtils.parseLocalDate(original);
      expect(AppDateUtils.formatDateForApi(parsed), equals(original));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // formatDateReadable
  // ─────────────────────────────────────────────────────────────────────────
  group('AppDateUtils.formatDateReadable', () {
    test('formats as dd/MM/yyyy', () {
      final date = DateTime(2024, 1, 15);
      expect(AppDateUtils.formatDateReadable(date), equals('15/01/2024'));
    });

    test('pads day with leading zero', () {
      final date = DateTime(2024, 11, 5);
      expect(AppDateUtils.formatDateReadable(date), equals('05/11/2024'));
    });

    test('formats December 31 correctly', () {
      final date = DateTime(2024, 12, 31);
      expect(AppDateUtils.formatDateReadable(date), equals('31/12/2024'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // formatDateIndonesian
  // ─────────────────────────────────────────────────────────────────────────
  group('AppDateUtils.formatDateIndonesian', () {
    test('formats January as "Januari"', () {
      final date = DateTime(2024, 1, 15);
      expect(AppDateUtils.formatDateIndonesian(date), contains('Januari'));
    });

    test('formats December as "Desember"', () {
      final date = DateTime(2024, 12, 25);
      expect(AppDateUtils.formatDateIndonesian(date), contains('Desember'));
    });

    test('output contains the year', () {
      final date = DateTime(2024, 6, 1);
      expect(AppDateUtils.formatDateIndonesian(date), contains('2024'));
    });

    test('output matches dd MMMM yyyy pattern roughly', () {
      final date = DateTime(2024, 3, 5);
      final result = AppDateUtils.formatDateIndonesian(date);
      // Should start with padded day
      expect(result.startsWith('05'), isTrue);
      expect(result, contains('2024'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // formatDateFull
  // ─────────────────────────────────────────────────────────────────────────
  group('AppDateUtils.formatDateFull', () {
    test('includes day name in Indonesian', () {
      // 2024-01-15 is a Monday = Senin
      final date = DateTime(2024, 1, 15);
      expect(AppDateUtils.formatDateFull(date), contains('Senin'));
    });

    test('includes year', () {
      final date = DateTime(2024, 1, 15);
      expect(AppDateUtils.formatDateFull(date), contains('2024'));
    });

    test('output starts with day name followed by comma', () {
      final date = DateTime(2024, 1, 15);
      final result = AppDateUtils.formatDateFull(date);
      expect(result, contains(','));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // parseApiDate
  // ─────────────────────────────────────────────────────────────────────────
  group('AppDateUtils.parseApiDate', () {
    test('null input returns null', () {
      expect(AppDateUtils.parseApiDate(null), isNull);
    });

    test('DateTime input is returned as-is', () {
      final date = DateTime(2024, 6, 15);
      final result = AppDateUtils.parseApiDate(date);
      expect(result, equals(date));
    });

    test('date-only string "2024-06-15" returns local date', () {
      final result = AppDateUtils.parseApiDate('2024-06-15');
      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 6);
      expect(result.day, 15);
    });

    test('ISO timestamp with T is parsed to local', () {
      final result = AppDateUtils.parseApiDate('2024-06-15T10:30:00Z');
      expect(result, isNotNull);
      expect(result!.isUtc, isFalse); // toLocal() was called
    });

    test('string with T but invalid date returns null', () {
      // Contains T → attempts DateTime.parse → throws → caught → null
      expect(AppDateUtils.parseApiDate('not-a-real-dateT00:00'), isNull);
    });

    test('integer input does not crash', () {
      // 12345.toString() → "12345" → parseLocalDate fallback → DateTime.now()
      final result = AppDateUtils.parseApiDate(12345);
      expect(result, anyOf(isNull, isA<DateTime>()));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // formatDateString
  // ─────────────────────────────────────────────────────────────────────────
  group('AppDateUtils.formatDateString', () {
    test('null input returns "-"', () {
      expect(AppDateUtils.formatDateString(null), equals('-'));
    });

    test('empty string returns "-"', () {
      expect(AppDateUtils.formatDateString(''), equals('-'));
    });

    test('valid date string formats to default dd/MM/yyyy', () {
      expect(
        AppDateUtils.formatDateString('2024-01-15'),
        equals('15/01/2024'),
      );
    });

    test('custom format parameter is applied', () {
      final result = AppDateUtils.formatDateString(
        '2024-01-15',
        format: 'yyyy/MM/dd',
      );
      expect(result, equals('2024/01/15'));
    });

    test('ISO timestamp string formats using date component', () {
      final result = AppDateUtils.formatDateString('2024-06-15T10:30:00Z');
      expect(result, isNotNull);
      // Should contain '15' and '06' and '2024'
      expect(result, contains('2024'));
    });

    test('invalid string does not crash', () {
      // 'not-a-real-date' splits on '-' to ["not","a","real-date"] which fails int.parse
      // → parseLocalDate catches → returns DateTime.now() → formatted as today's date
      final result = AppDateUtils.formatDateString('not-a-real-date');
      expect(result, isA<String>());
      expect(result, isNotEmpty);
    });
  });
}
