/// currency_formatter.dart - Indonesian Rupiah (IDR) currency input formatter.
/// Like a Laravel Helper function for currency formatting, combined with a
/// Vue input mask directive (e.g., `v-money` or `vue-currency-input`).
/// Automatically formats numeric input as "Rp 10.000" while typing.
library;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// A [TextInputFormatter] that auto-formats text field input as Indonesian
/// Rupiah.
/// Like a Laravel Helper function combined with a Vue input mask/directive.
///
/// Attach to a `TextField` via its `inputFormatters` parameter:
/// ```dart
/// TextField(inputFormatters: [CurrencyInputFormatter()])
/// ```
///
/// As the user types digits, this formatter strips non-numeric characters,
/// parses the number, and reformats it with the "Rp " prefix and thousands
/// separators (e.g., "Rp 1.500.000").
///
/// Also provides [parseCurrency] to reverse the formatting back to a numeric
/// value
/// for API submission.
class CurrencyInputFormatter extends TextInputFormatter {
  /// The currency symbol prefix prepended to all formatted values.
  static const String symbol = 'Rp ';

  /// Called automatically by Flutter on every text change in the input field.
  /// Strips non-digits, parses to integer, and reformats with "Rp " prefix
  /// and Indonesian locale thousands separators (dots).
  ///
  /// [oldValue] - The previous text field state (not used here).
  /// [newValue] - The new text field state to format.
  /// Returns a [TextEditingValue] with formatted text and cursor at the end.
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // If data is empty, return empty
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Extract only digits
    final String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // If result is empty (e.g. user deleted all digits), return empty
    if (newText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Parse to integer
    final int value = int.parse(newText);

    // Format currency
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: symbol,
      decimalDigits: 0,
    );

    final String newString = formatter.format(value);

    // Return new value with cursor at the end
    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }

  /// Helper to clean currency format into a raw number (double)
  /// Example: "Rp 10.000" -> 10000.0
  static double parseCurrency(String formattedValue) {
    if (formattedValue.isEmpty) return 0.0;
    final String cleanString = formattedValue.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanString.isEmpty) return 0.0;
    return double.parse(cleanString);
  }
}
