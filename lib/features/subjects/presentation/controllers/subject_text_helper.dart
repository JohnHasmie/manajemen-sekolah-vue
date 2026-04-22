/// Helper for text translations and localization.
/// Handles status text rendering and other UI text utilities.
library;

import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Pure text helper — handles translations and text formatting.
class SubjectTextHelper {
  /// Returns a localised status label for a subject's status string.
  /// Like a Vue filter: `{{ subject.status | statusText }}`.
  static String getSubjectStatusText(
    String? status,
    LanguageProvider languageProvider,
  ) {
    switch (status) {
      case 'active':
        return languageProvider.getTranslatedText({
          'en': 'Active',
          'id': 'Aktif',
        });
      case 'inactive':
        return languageProvider.getTranslatedText({
          'en': 'Inactive',
          'id': 'Tidak Aktif',
        });
      default:
        return languageProvider.getTranslatedText({
          'en': 'Unknown',
          'id': 'Tidak Diketahui',
        });
    }
  }
}
