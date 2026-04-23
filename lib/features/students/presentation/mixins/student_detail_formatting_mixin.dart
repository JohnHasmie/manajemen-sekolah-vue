import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Provides text formatting utilities for student detail display.
mixin StudentDetailFormattingMixin {
  /// Converts gender code to translated text.
  /// Handles M/L (male), F/P (female), and unknown cases.
  String getGenderText(String? gender, LanguageProvider languageProvider) {
    switch (gender) {
      case 'M':
      case 'L':
        return languageProvider.getTranslatedText({
          'en': 'Male',
          'id': 'Laki-laki',
        });
      case 'F':
      case 'P':
        return languageProvider.getTranslatedText({
          'en': 'Female',
          'id': 'Perempuan',
        });
      default:
        return languageProvider.getTranslatedText({
          'en': 'Unknown',
          'id': 'Tidak Diketahui',
        });
    }
  }

  /// Formats a date string or returns '-' if null.
  String formatDate(String? date) {
    if (date == null) return '-';
    return AppDateUtils.formatDateString(date, format: 'dd/MM/yyyy');
  }
}
