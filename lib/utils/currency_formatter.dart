import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  static const String symbol = 'Rp ';

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
