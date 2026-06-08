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
part 'language_utils_sweep_teacher_attendance.dart';
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
  ///   - AWAITED PATCH `/profile/language` (failures swallowed and
  ///     logged — local UX continues either way), then a re-fetch of
  ///     backend-localized data (priority inbox, etc.).
  Future<void> setLanguage(String language, {bool syncToServer = true}) async {
    _currentLanguage = language;

    // 1. Device-local persistence — survives app restart on THIS
    //    device. Awaited because the picker UI pops the sheet right
    //    after; the next frame should already see the new value.
    final prefs = PreferencesService();
    await prefs.setString('language', language);

    // 2. UI rebuilds first so all Flutter-local `.tr` strings flip
    //    instantly — the picker feels immediate and client-side i18n
    //    never waits on the network.
    notifyListeners();

    // 3. Cross-device persistence + backend-data refresh.
    //
    //    `hydrateFromServer` passes `syncToServer: false` because it's
    //    ADOPTING a value the server already holds — there's nothing
    //    new to persist and nothing stale to re-fetch.
    //
    //    Ordering matters and is the whole point of this path: the
    //    backend's locale precedence is (1) the saved
    //    `preferred_language` column, then (2) the `Accept-Language`
    //    header. So we MUST let the PATCH land before re-fetching, or
    //    the re-fetch could race ahead and still read the OLD column
    //    value. Hence the PATCH is AWAITED, not fire-and-forget.
    //
    //    Resilience: the production sync hook swallows its own errors,
    //    but we still guard with try/catch so that even a throwing
    //    PATCH never aborts the local locale change (already applied
    //    above) NOR the re-fetch. On failure the re-fetch isn't
    //    wasted — dio now sends the new `Accept-Language`, which the
    //    server honours as the fallback when the column write didn't
    //    land.
    if (syncToServer) {
      // Lazy-loaded hooks (injected in `main.dart`) keep this barrel
      // file framework-only and unit-testable without a running dio.
      final sync = _serverSync;
      if (sync != null) {
        try {
          await sync(language);
        } catch (_) {
          // Swallow — local locale + Accept-Language already updated;
          // continue to the re-fetch regardless.
        }
      }
      _onLanguageChanged?.call(language);
    }
  }

  /// Hook injected at app startup (see `main.dart`) so this provider
  /// can push to the backend without taking a hard import on the
  /// settings service. `null` until injection — picker still works
  /// in that case, just without server sync (e.g. tests, splash
  /// screen pre-login).
  ///
  /// Returns a `Future` so [setLanguage] can AWAIT the PATCH before
  /// triggering a re-fetch — see the ordering note in [setLanguage].
  /// The hook is expected to swallow its own errors (the settings
  /// service already does), so `setLanguage` doesn't need a try/catch.
  static Future<void> Function(String code)? _serverSync;

  /// Wire the server-sync hook. Called once during app bootstrap,
  /// AFTER auth + dio are ready. Pass `null` to disable (logout).
  static void registerServerSync(Future<void> Function(String code)? sync) {
    _serverSync = sync;
  }

  /// Hook injected at app startup (see `main.dart`) that re-fetches
  /// backend-localized data (dashboard priority-inbox "Perlu
  /// Perhatian" labels, server-rendered subtitles, etc.) so they
  /// switch language immediately instead of staying stale until a
  /// manual refresh.
  ///
  /// Fired by [setLanguage] AFTER the locale is applied and the
  /// `_serverSync` PATCH has resolved, so the server already sees the
  /// new `preferred_language` when the re-fetch hits. `null` until
  /// injection — local i18n still flips instantly without it.
  static void Function(String code)? _onLanguageChanged;

  /// Wire the backend-data refresh hook. Called once during app
  /// bootstrap. Pass `null` to disable (logout / tests).
  static void registerOnLanguageChanged(void Function(String code)? hook) {
    _onLanguageChanged = hook;
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

/// Monotonically-increasing counter bumped once per *completed*
/// language change (after the `PATCH /profile/language` round-trip).
///
/// Screens that fetch backend-localized data with their own local
/// `setState` (rather than through a Riverpod async provider) —
/// notably the admin & parent dashboard bodies' "Perlu Perhatian"
/// inbox — `ref.listen` to this and re-fetch when it changes. The
/// teacher inbox rides the `dashboardProvider` invalidation instead,
/// so it doesn't need this signal.
///
/// Why a counter, not a `bool`/the language string: a counter is
/// guaranteed to change on every bump, so `ref.listen`'s
/// previous-vs-next comparison always fires even if the same code is
/// somehow re-applied. The actual value is irrelevant — listeners
/// only care that it moved.
///
/// Bumped from the `registerOnLanguageChanged` hook in `main.dart`.
final languageChangeSignalProvider = riverpod_legacy.StateProvider<int>(
  (ref) => 0,
);
