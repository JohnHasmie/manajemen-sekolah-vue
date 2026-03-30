/// Tests for CurrencyInputFormatter — verifies Indonesian Rupiah formatting
/// and parsing round-trips correctly.
///
/// Like testing a Laravel Helper such as `number_format()` and its inverse:
/// confirm "Rp 10.000" ↔ 10000.0 without data loss.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyInputFormatter.parseCurrency', () {
    test('strips "Rp " prefix and dot separators, returns double', () {
      expect(CurrencyInputFormatter.parseCurrency('Rp 10.000'), 10000.0);
    });

    test('handles large values with multiple dot separators', () {
      expect(
        CurrencyInputFormatter.parseCurrency('Rp 1.500.000'),
        1500000.0,
      );
    });

    test('returns 0.0 for empty string', () {
      expect(CurrencyInputFormatter.parseCurrency(''), 0.0);
    });

    test('returns 0.0 for non-numeric string', () {
      expect(CurrencyInputFormatter.parseCurrency('abc'), 0.0);
    });

    test('returns 0.0 for symbol-only string with no digits', () {
      expect(CurrencyInputFormatter.parseCurrency('Rp '), 0.0);
    });

    test('plain digits without prefix are returned as-is', () {
      expect(CurrencyInputFormatter.parseCurrency('5000'), 5000.0);
    });

    test('single digit returns correct double', () {
      expect(CurrencyInputFormatter.parseCurrency('7'), 7.0);
    });
  });

  group('CurrencyInputFormatter.formatEditUpdate', () {
    late CurrencyInputFormatter formatter;

    setUp(() {
      formatter = CurrencyInputFormatter();
    });

    /// Helper: simulates typing [text] into a text field and returns
    /// the formatted result string. Like calling a Vue input mask handler.
    String format(String text) {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        TextEditingValue(text: text),
      );
      return result.text;
    }

    test('formats "10000" as "Rp 10.000"', () {
      expect(format('10000'), 'Rp 10.000');
    });

    test('formats "1500000" as "Rp 1.500.000"', () {
      expect(format('1500000'), 'Rp 1.500.000');
    });

    test('formats single digit "5" as "Rp 5"', () {
      expect(format('5'), 'Rp 5');
    });

    test('returns empty string when new value is empty', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: 'Rp 5'),
        const TextEditingValue(text: ''),
      );
      expect(result.text, '');
    });

    test('returns empty string when all non-digit characters are entered', () {
      // Entering only letters/symbols should strip to empty
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: 'abc'),
      );
      expect(result.text, '');
    });

    test('cursor is placed at end of formatted string', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '10000'),
      );
      expect(result.selection.baseOffset, result.text.length);
      expect(result.selection.extentOffset, result.text.length);
    });

    test('re-formats already-formatted "Rp 10.000" correctly', () {
      // Simulates paste of an already-formatted string — digits are preserved.
      expect(format('Rp 10.000'), 'Rp 10.000');
    });
  });
}
