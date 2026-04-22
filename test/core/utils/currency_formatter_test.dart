/// Unit tests for CurrencyInputFormatter.
///
/// Covers:
/// - formatEditUpdate: empty input, digits-only, mixed input, large numbers
/// - parseCurrency: empty, formatted strings, plain digits, non-numeric
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/utils/currency_formatter.dart';

// Helper: simulate a user typing text into a field.
TextEditingValue _input(String text) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
);

TextEditingValue _format(String input) {
  final formatter = CurrencyInputFormatter();
  return formatter.formatEditUpdate(
    const TextEditingValue(text: ''),
    _input(input),
  );
}

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // formatEditUpdate
  // ─────────────────────────────────────────────────────────────────────────
  group('CurrencyInputFormatter.formatEditUpdate', () {
    test('empty string returns empty', () {
      final formatter = CurrencyInputFormatter();
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: ''),
      );
      expect(result.text, isEmpty);
    });

    test('all non-digits returns empty', () {
      expect(_format('abc').text, isEmpty);
    });

    test('single digit formats with Rp prefix', () {
      expect(_format('5').text, contains('Rp'));
      expect(_format('5').text, contains('5'));
    });

    test('1000 formats as "Rp 1.000"', () {
      expect(_format('1000').text, equals('Rp 1.000'));
    });

    test('1500000 formats as "Rp 1.500.000"', () {
      expect(_format('1500000').text, equals('Rp 1.500.000'));
    });

    test('10000000 formats as "Rp 10.000.000"', () {
      expect(_format('10000000').text, equals('Rp 10.000.000'));
    });

    test('strips non-digit characters before formatting', () {
      // User might paste "Rp 10.000" – strip to "10000", reformat
      expect(_format('Rp 10.000').text, equals('Rp 10.000'));
    });

    test('cursor placed at end of formatted text', () {
      final result = _format('5000');
      expect(result.selection.baseOffset, equals(result.text.length));
    });

    test('0 formats with Rp prefix', () {
      expect(_format('0').text, contains('Rp'));
    });

    test('large number 999999999 formats correctly', () {
      final result = _format('999999999');
      expect(result.text, contains('Rp'));
      expect(result.text, contains('999'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // parseCurrency
  // ─────────────────────────────────────────────────────────────────────────
  group('CurrencyInputFormatter.parseCurrency', () {
    test('empty string returns 0.0', () {
      expect(CurrencyInputFormatter.parseCurrency(''), equals(0.0));
    });

    test('"Rp 10.000" → 10000.0', () {
      expect(
        CurrencyInputFormatter.parseCurrency('Rp 10.000'),
        equals(10000.0),
      );
    });

    test('"Rp 1.500.000" → 1500000.0', () {
      expect(
        CurrencyInputFormatter.parseCurrency('Rp 1.500.000'),
        equals(1500000.0),
      );
    });

    test('plain digits "12345" → 12345.0', () {
      expect(CurrencyInputFormatter.parseCurrency('12345'), equals(12345.0));
    });

    test('"Rp 0" → 0.0', () {
      expect(CurrencyInputFormatter.parseCurrency('Rp 0'), equals(0.0));
    });

    test('only non-digits → 0.0', () {
      expect(CurrencyInputFormatter.parseCurrency('Rp '), equals(0.0));
    });

    test('round-trip: format then parse returns original value', () {
      const originalValue = 750000;
      final formatted = _format(originalValue.toString()).text;
      final parsed = CurrencyInputFormatter.parseCurrency(formatted);
      expect(parsed, equals(originalValue.toDouble()));
    });

    test('round-trip for 1 → 1.0', () {
      final formatted = _format('1').text;
      expect(CurrencyInputFormatter.parseCurrency(formatted), equals(1.0));
    });
  });
}
