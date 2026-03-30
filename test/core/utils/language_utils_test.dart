/// Tests for LanguageProvider, AppLocalizations, and the .tr extension.
///
/// LanguageProvider is a ChangeNotifier singleton (like a Vuex store module)
/// that holds the current locale and persists it via SharedPreferences.
/// Because SharedPreferences touches a platform channel, we mock the channel
/// before any call that would hit it — just like swapping a Laravel facade
/// in a unit test via `Facade::shouldReceive(...)`.
///
/// The global `languageProvider` singleton carries state between tests, so we
/// reset it to the default Indonesian locale in setUp/tearDown.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── main ─────────────────────────────────────────────────────────────────────

void main() {
  // TestWidgetsFlutterBinding must be initialised before any platform-channel
  // interaction.  Calling ensureInitialized() is idempotent — safe to call more
  // than once.  Like booting the Laravel application container before tests.
  TestWidgetsFlutterBinding.ensureInitialized();

  // Before every test: set up a mock in-memory SharedPreferences (no platform
  // channel needed), initialise the PreferencesService singleton so its late
  // `_prefs` field is ready, then reset the language singleton to the default
  // Indonesian locale.  This mirrors Laravel's RefreshDatabase pattern —
  // each test starts from a clean, known state.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
    languageProvider = LanguageProvider();
  });

  tearDown(() {
    languageProvider = LanguageProvider();
  });

  // ─── LanguageProvider.getTranslatedText ─────────────────────────────────

  group('LanguageProvider.getTranslatedText', () {
    test('returns the English value when language is set to "en"', () async {
      await languageProvider.setLanguage('en');

      final result = languageProvider.getTranslatedText({
        'en': 'Hello',
        'id': 'Halo',
      });

      expect(result, 'Hello');
    });

    test('returns the Indonesian value when language is "id" (default)', () {
      // No setLanguage call needed — default is already Indonesian.
      expect(languageProvider.currentLanguage, 'id');

      final result = languageProvider.getTranslatedText({
        'en': 'Hello',
        'id': 'Halo',
      });

      expect(result, 'Halo');
    });

    test('falls back to "id" value when the current-language key is missing', () async {
      // Simulate a map that has no 'en' key — the provider should fall back to
      // the Indonesian string rather than returning null or throwing.
      // Like Laravel's trans_choice() gracefully falling back to the default locale.
      await languageProvider.setLanguage('en');

      final result = languageProvider.getTranslatedText({
        'id': 'Halo',
        // 'en' key deliberately omitted
      });

      expect(result, 'Halo');
    });
  });

  // ─── LanguageProvider.setLanguage ────────────────────────────────────────

  group('LanguageProvider.setLanguage', () {
    test('currentLanguage updates to "en" after setLanguage("en")', () async {
      await languageProvider.setLanguage('en');

      expect(languageProvider.currentLanguage, 'en');
    });

    test('currentLanguage updates to "id" after setLanguage("id")', () async {
      // First switch to English, then back to Indonesian to exercise both paths.
      await languageProvider.setLanguage('en');
      await languageProvider.setLanguage('id');

      expect(languageProvider.currentLanguage, 'id');
    });
  });

  // ─── AppLocalizations getters ─────────────────────────────────────────────

  group('AppLocalizations — save / cancel', () {
    test('save has en: "Save" and id: "Simpan"', () {
      final map = AppLocalizations.save;
      expect(map['en'], 'Save');
      expect(map['id'], 'Simpan');
    });

    test('cancel has en: "Cancel" and id: "Batal"', () {
      final map = AppLocalizations.cancel;
      expect(map['en'], 'Cancel');
      expect(map['id'], 'Batal');
    });
  });

  group('AppLocalizations — feature-specific keys', () {
    test('lessonPlan has non-empty "en" and "id" values', () {
      final map = AppLocalizations.lessonPlan;
      expect(map.containsKey('en'), isTrue);
      expect(map.containsKey('id'), isTrue);
      expect(map['en'], isNotEmpty);
      expect(map['id'], isNotEmpty);
    });

    test('academicTerm has non-empty "en" and "id" values', () {
      final map = AppLocalizations.academicTerm;
      expect(map.containsKey('en'), isTrue);
      expect(map.containsKey('id'), isTrue);
      expect(map['en'], isNotEmpty);
      expect(map['id'], isNotEmpty);
    });

    test('eReportCard has non-empty "en" and "id" values', () {
      final map = AppLocalizations.eReportCard;
      expect(map.containsKey('en'), isTrue);
      expect(map.containsKey('id'), isTrue);
      expect(map['en'], isNotEmpty);
      expect(map['id'], isNotEmpty);
    });
  });

  // ─── .tr extension ───────────────────────────────────────────────────────

  group('LocalizedString .tr extension', () {
    test('returns Indonesian translation when language is "id"', () {
      // The global singleton is already "id" (reset in setUp).
      // We verify via getTranslatedText directly — same behaviour as .tr.
      final map = {'en': 'Hello', 'id': 'Halo'};
      expect(languageProvider.getTranslatedText(map), 'Halo');
    });

    test('returns English translation when language is "en"', () async {
      await languageProvider.setLanguage('en');

      final map = {'en': 'Hello', 'id': 'Halo'};
      // After setLanguage the singleton is updated, so .tr and
      // getTranslatedText must both agree.
      expect(languageProvider.getTranslatedText(map), 'Hello');
      expect(map.tr, 'Hello');
    });

    test('.tr on AppLocalizations.save returns "Simpan" in Indonesian', () {
      // Default language is 'id'.
      expect(AppLocalizations.save.tr, 'Simpan');
    });

    test('.tr on AppLocalizations.save returns "Save" in English', () async {
      await languageProvider.setLanguage('en');

      expect(AppLocalizations.save.tr, 'Save');
    });
  });
}
