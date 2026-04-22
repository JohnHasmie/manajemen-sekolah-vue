import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Helper for formatting grade-related data.
class GradeFormatHelper {
  /// Formats a raw grade value for display (strips trailing .0).
  static String formatGradeValue(dynamic value) {
    if (value == null) return '';
    final double? numVal = double.tryParse(value.toString());
    if (numVal == null) return '';
    if (numVal % 1 == 0) return numVal.toInt().toString();
    return numVal.toString();
  }

  /// Formats a `yyyy-MM-dd` date string into `dd/MM/yyyy` for display.
  static String formatDateDisplay(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  /// Returns the human-readable label for a grade type key.
  static String getGradeTypeLabel(
    String type,
    LanguageProvider languageProvider,
  ) {
    switch (type) {
      case 'uh':
        return languageProvider.getTranslatedText({
          'en': 'Daily/Quiz',
          'id': 'UH/Ulangan',
        });
      case 'tugas':
        return languageProvider.getTranslatedText({
          'en': 'Assignment',
          'id': 'Tugas',
        });
      case 'uts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm',
          'id': 'UTS',
        });
      case 'uas':
        return languageProvider.getTranslatedText({'en': 'Final', 'id': 'UAS'});
      case 'pts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm Exam',
          'id': 'PTS',
        });
      case 'pas':
        return languageProvider.getTranslatedText({
          'en': 'Final Exam',
          'id': 'PAS',
        });
      default:
        return type.toUpperCase();
    }
  }
}
