/// currency_formatter.dart - Indonesian Rupiah (IDR) currency input formatter.
/// Like a Laravel Helper function for currency formatting, combined with a
/// Vue input mask directive (e.g., `v-money` or `vue-currency-input`).
/// Automatically formats numeric input as "Rp 10.000" while typing.
library;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// A [TextInputFormatter] that auto-formats text field input as Indonesian Rupiah.
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
/// Also provides [parseCurrency] to reverse the formatting back to a numeric value
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
    // Jika data kosong, kembalikan kosong
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Hanya ambil angka
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Jika hasil kosong (misal user hapus semua angka), kembalikan kosong
    if (newText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Parse ke integer
    int value = int.parse(newText);

    // Format mata uang
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: symbol,
      decimalDigits: 0,
    );

    String newString = formatter.format(value);

    // Kembalikan value baru dengan cursor di akhir
    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }

  /// Helper untuk membersihkan format currency menjadi angka murni (double)
  /// Contoh: "Rp 10.000" -> 10000.0
  static double parseCurrency(String formattedValue) {
    if (formattedValue.isEmpty) return 0.0;
    String cleanString = formattedValue.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanString.isEmpty) return 0.0;
    return double.parse(cleanString);
  }
}
