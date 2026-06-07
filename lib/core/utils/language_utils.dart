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
part 'language_utils_sweep_lesson_plans.dart';
part 'language_utils_sweep_finance.dart';
part 'language_utils_sweep_schedule.dart';
part 'language_utils_sweep_class_activity.dart';
part 'language_utils_sweep_attendance.dart';
part 'language_utils_sweep_grades.dart';
part 'language_utils_sweep_report_cards.dart';
part 'language_utils_sweep_classrooms.dart';
part 'language_utils_sweep_recommendations.dart';
part 'language_utils_sweep_announcements.dart';
part 'language_utils_sweep_settings.dart';
part 'language_utils_sweep_subjects.dart';
part 'language_utils_sweep_materials.dart';
part 'language_utils_sweep_dashboard.dart';
part 'language_utils_sweep_students.dart';
part 'language_utils_sweep_teachers.dart';
part 'language_utils_sweep_auth.dart';
part 'language_utils_sweep_notifications.dart';
part 'language_utils_sweep_account.dart';
part 'language_utils_sweep_core_widgets.dart';
part 'language_utils_sweep_core_shell.dart';
part 'language_utils_sweep_legacy_aliases.dart';

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
  /// SharedPreferences (immediate, device-local) AND to the backend
  /// (best-effort, cross-device).
  /// Like setting `App::setLocale()` in Laravel's middleware AND
  /// updating `users.preferred_language` so subsequent API calls
  /// from any device see the same locale.
  ///
  /// [language] - The language code to switch to ('en' or 'id').
  /// [syncToServer] - When false, skip the backend round-trip. The
  ///   server-side hydration path uses this to apply a value that
  ///   ALREADY came from the server, avoiding an immediate echo
  ///   PATCH on every cold start.
  ///
  /// Side effects:
  ///   - SharedPreferences write (synchronous, awaited).
  ///   - `notifyListeners` fires so widgets rebuild with the new
  ///     `.tr` resolutions.
  ///   - Fire-and-forget PATCH `/profile/language` (failures swallowed
  ///     and logged — local UX continues either way).
  Future<void> setLanguage(String language, {bool syncToServer = true}) async {
    _currentLanguage = language;

    // 1. Device-local persistence — survives app restart on THIS
    //    device. Awaited because the picker UI pops the sheet right
    //    after; the next frame should already see the new value.
    final prefs = PreferencesService();
    await prefs.setString('language', language);

    // 2. UI rebuilds first so the picker feels instant.
    notifyListeners();

    // 3. Cross-device persistence — push to backend so the user gets
    //    the same locale on a phone, tablet, or fresh browser. Fire
    //    and forget; the local change is the source of truth for now,
    //    and a failing PATCH (offline, 5xx) will retry on the next
    //    explicit pick. We import the service lazily to keep this
    //    barrel file's dependency graph minimal — `language_utils.dart`
    //    is imported almost everywhere via `.tr`, so adding a hard
    //    dependency on the settings service here would balloon the
    //    cycle count.
    if (syncToServer) {
      // Lazy-load the symbol via a deferred top-level hook so this
      // file remains framework-only and unit-testable without a
      // running dio.
      _serverSync?.call(language);
    }
  }

  /// Hook injected at app startup (see `main.dart`) so this provider
  /// can push to the backend without taking a hard import on the
  /// settings service. `null` until injection — picker still works
  /// in that case, just without server sync (e.g. tests, splash
  /// screen pre-login).
  static void Function(String code)? _serverSync;

  /// Wire the server-sync hook. Called once during app bootstrap,
  /// AFTER auth + dio are ready. Pass `null` to disable (logout).
  static void registerServerSync(void Function(String code)? sync) {
    _serverSync = sync;
  }

  /// Apply a server-supplied preference without echoing it back to
  /// the server. Called when `/profile` returns `preferred_language`
  /// after login or refresh — we adopt the server value as the source
  /// of truth without immediately PATCHing the same value back.
  ///
  /// No-op if [code] is null, empty, or unsupported, so callers can
  /// pipe profile-response fields straight in without pre-validation.
  Future<void> hydrateFromServer(String? code) async {
    if (code == null) return;
    if (code != english && code != indonesian) return;
    if (code == _currentLanguage) return;
    await setLanguage(code, syncToServer: false);
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
