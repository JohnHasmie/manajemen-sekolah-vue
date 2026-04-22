/// language_utils.dart - Internationalization (i18n) barrel file.
/// Exports the reactive language provider, translation system, and utilities.
///
/// Core components:
/// - [LanguageProvider]: Manages the current language and persists to
///   SharedPreferences.
/// - [LocalizedString]: Extension for inline translation via `.tr` getter.
/// - [languageRiverpod]: Riverpod provider for reactive language changes.
/// - [AppLocalizations]: Static translation dictionary (exported from part
///   files).
///
/// Usage: `AppLocalizations.welcome.tr` or `ref.watch(languageRiverpod)`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart' as riverpod_legacy;
import 'package:manajemensekolah/core/services/preferences_service.dart';

part 'language_utils_core_localizations.dart';
part 'language_utils_common_localizations.dart';
part 'language_utils_lesson_plans.dart';
part 'language_utils_parent_dashboard.dart';
part 'language_utils_settings_auth.dart';
part 'language_utils_settings_auth_2.dart';

/// Manages the app's current language and notifies listeners on change.
/// Like a Vuex store module - holds reactive global state that widgets can
/// listen to.
///
/// Persists the selected language to SharedPreferences (like Laravel storing
/// locale in the session). Supports English ('en') and Indonesian ('id').
///
/// Usage: Wrap the app with
/// `ChangeNotifierProvider<LanguageProvider>`, then use
/// `ref.watch(languageRiverpod)` to rebuild widgets when language changes.
class LanguageProvider with ChangeNotifier {
  static const String english = 'en';
  static const String indonesian = 'id';

  String _currentLanguage = indonesian;

  /// The currently active language code ('en' or 'id').
  String get currentLanguage => _currentLanguage;

  /// Changes the app language and persists the choice to
  /// SharedPreferences.
  /// Like setting `App::setLocale()` in Laravel's middleware.
  ///
  /// [language] - The language code to switch to ('en' or 'id').
  /// Side effects: Saves to SharedPreferences, calls [notifyListeners] to
  /// trigger UI rebuilds across the app.
  Future<void> setLanguage(String language) async {
    _currentLanguage = language;

    // Save to shared preferences
    final prefs = PreferencesService();
    await prefs.setString('language', language);

    notifyListeners(); // Notify all listeners about the change
  }

  /// Loads the previously saved language preference from
  /// SharedPreferences.
  /// Called once at app startup. Defaults to Indonesian if no preference is
  /// saved.
  /// Like reading `session('locale')` in Laravel.
  Future<void> loadSavedLanguage() async {
    final prefs = PreferencesService();
    final savedLanguage = prefs.getString('language') ?? indonesian;
    _currentLanguage = savedLanguage;
    notifyListeners();
  }

  /// Resolves a translation from a map of `{languageCode: text}`.
  /// Like Laravel's `__('messages.welcome')` but using a map instead of
  /// file-based keys.
  ///
  /// [translations] - A map like `{'en': 'Hello', 'id': 'Halo'}`.
  /// Returns the string for the current language, falling back to
  /// Indonesian.
  String getTranslatedText(Map<String, String> translations) {
    return translations[_currentLanguage] ?? translations[indonesian] ?? '';
  }
}

/// Global singleton instance of [LanguageProvider].
/// Used by the `.tr` extension and injected into the Provider tree in
/// `main.dart`.
LanguageProvider languageProvider = LanguageProvider();

/// Convenience extension on `Map<String, String>` for inline
/// translations.
/// Like Laravel's `__()` helper or Vue-i18n's `$t()`.
///
/// Usage: `AppLocalizations.welcome.tr` returns "Selamat datang," or
/// "Welcome," depending on the current language.
extension LocalizedString on Map<String, String> {
  /// Returns the translated string for the current language.
  String get tr {
    return languageProvider.getTranslatedText(this);
  }
}

/// Riverpod provider for [LanguageProvider].
/// Uses the existing global singleton instance to stay in sync with
/// the `.tr` extension and old Provider-based widgets.
///
/// Usage: `ref.watch(languageRiverpod)` for reactive language changes
final languageRiverpod =
    riverpod_legacy.ChangeNotifierProvider<LanguageProvider>((ref) {
      return languageProvider; // Global singleton from language_utils.dart
    });
