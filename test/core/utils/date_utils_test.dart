/// Tests for AppDateUtils — verifies date parsing is timezone-safe and
/// formatting produces the expected strings for API and display use.
///
/// Like testing a Laravel Carbon helper: confirm that parsing "2024-01-15"
/// never drifts to "2024-01-14" due to a UTC/local offset bug.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';

void main() {
  // Initialize the 'id_ID' locale data once before any test in this file runs.
  // Like running `app()->setLocale('id')` in a Laravel test setUp — required
  // before DateFormat('dd MMMM yyyy', 'id_ID') can produce Indonesian month names.
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  // ─── parseLocalDate ───────────────────────────────────────────────────────

  group('AppDateUtils.parseLocalDate', () {
    test('parses year, month, day correctly', () {
      final date = AppDateUtils.parseLocalDate('2024-01-15');
      expect(date.year, 2024);
      expect(date.month, 1);
      expect(date.day, 15);
    });

    test('result is local time, not UTC', () {
      final date = AppDateUtils.parseLocalDate('2024-01-15');
      expect(date.isUtc, false);
    });

    test('parses end-of-month date without overflow', () {
      final date = AppDateUtils.parseLocalDate('2024-02-29'); // 2024 is a leap year
      expect(date.year, 2024);
      expect(date.month, 2);
      expect(date.day, 29);
    });

    test('falls back to today when given an unparseable string', () {
      // The exact date doesn't matter; we just confirm it doesn't throw.
      final date = AppDateUtils.parseLocalDate('not-a-date');
      expect(date, isA<DateTime>());
    });
  });

  // ─── formatDateForApi ─────────────────────────────────────────────────────

  group('AppDateUtils.formatDateForApi', () {
    test('produces yyyy-MM-dd string', () {
      final date = DateTime(2024, 1, 15);
      expect(AppDateUtils.formatDateForApi(date), '2024-01-15');
    });

    test('zero-pads single-digit month and day', () {
      final date = DateTime(2024, 3, 5);
      expect(AppDateUtils.formatDateForApi(date), '2024-03-05');
    });
  });

  // ─── formatDateReadable ───────────────────────────────────────────────────

  group('AppDateUtils.formatDateReadable', () {
    test('produces dd/MM/yyyy string', () {
      final date = DateTime(2024, 1, 15);
      expect(AppDateUtils.formatDateReadable(date), '15/01/2024');
    });

    test('zero-pads day and month', () {
      final date = DateTime(2024, 3, 5);
      expect(AppDateUtils.formatDateReadable(date), '05/03/2024');
    });
  });

  // ─── formatDateIndonesian ─────────────────────────────────────────────────

  group('AppDateUtils.formatDateIndonesian', () {
    test('produces "dd MMMM yyyy" with Indonesian month name', () {
      final date = DateTime(2024, 1, 15);
      expect(AppDateUtils.formatDateIndonesian(date), '15 Januari 2024');
    });

    test('uses Indonesian month name for December', () {
      final date = DateTime(2024, 12, 1);
      expect(AppDateUtils.formatDateIndonesian(date), '01 Desember 2024');
    });
  });

  // ─── formatDateFull ───────────────────────────────────────────────────────

  group('AppDateUtils.formatDateFull', () {
    test('produces "EEEE, dd MMMM yyyy" with Indonesian day name', () {
      // 2024-01-15 is a Monday → "Senin" in Indonesian
      final date = DateTime(2024, 1, 15);
      expect(AppDateUtils.formatDateFull(date), 'Senin, 15 Januari 2024');
    });
  });

  // ─── parseApiDate ─────────────────────────────────────────────────────────

  group('AppDateUtils.parseApiDate', () {
    test('returns null for null input', () {
      expect(AppDateUtils.parseApiDate(null), isNull);
    });

    test('parses plain YYYY-MM-DD string as local date', () {
      final date = AppDateUtils.parseApiDate('2024-01-15');
      expect(date, isNotNull);
      expect(date!.year, 2024);
      expect(date.month, 1);
      expect(date.day, 15);
      expect(date.isUtc, false);
    });

    test('parses ISO timestamp containing "T" and converts to local', () {
      // An ISO string with an explicit UTC offset; result must not be UTC.
      final date = AppDateUtils.parseApiDate('2024-01-15T10:30:00Z');
      expect(date, isNotNull);
      expect(date!.isUtc, false);
    });

    test('returns a DateTime input unchanged', () {
      final input = DateTime(2024, 6, 20);
      final result = AppDateUtils.parseApiDate(input);
      expect(result, same(input));
    });

    test('returns a DateTime (today fallback) for a completely unparseable string', () {
      // The default branch calls parseLocalDate, which catches any parse error
      // and returns DateTime.now() rather than null — same safety net as
      // Carbon::parse() falling back to the current timestamp in Laravel.
      final result = AppDateUtils.parseApiDate('garbage');
      expect(result, isNotNull);
      expect(result, isA<DateTime>());
    });
  });

  // ─── formatDateString ─────────────────────────────────────────────────────

  group('AppDateUtils.formatDateString', () {
    test('returns "-" for null input', () {
      expect(AppDateUtils.formatDateString(null), '-');
    });

    test('returns "-" for empty string', () {
      expect(AppDateUtils.formatDateString(''), '-');
    });

    test('formats a valid date string with the default dd/MM/yyyy pattern', () {
      expect(AppDateUtils.formatDateString('2024-01-15'), '15/01/2024');
    });

    test('formats with a custom format pattern', () {
      expect(
        AppDateUtils.formatDateString('2024-01-15', format: 'yyyy/MM/dd'),
        '2024/01/15',
      );
    });
  });
}
