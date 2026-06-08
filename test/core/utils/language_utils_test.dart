/// Unit tests for language_utils.dart.
///
/// Covers:
/// - LanguageProvider: default language, setLanguage/getTranslatedText, fallback
/// - LocalizedString.tr extension: Indonesian and English lookups
/// - AppLocalizations: spot-check key translation pairs
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Initializes PreferencesService (singleton) with a clean mock
// SharedPreferences.
Future<void> _initPrefs() async {
  SharedPreferences.setMockInitialValues({});
  await PreferencesService().init();
}

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // LanguageProvider
  // ─────────────────────────────────────────────────────────────────────────
  group('LanguageProvider', () {
    late LanguageProvider provider;

    setUp(() async {
      await _initPrefs();
      provider = LanguageProvider();
    });

    test('default language is Indonesian ("id")', () {
      expect(provider.currentLanguage, equals(LanguageProvider.indonesian));
    });

    test('getTranslatedText returns Indonesian value by default', () {
      final translations = {'en': 'Hello', 'id': 'Halo'};
      expect(provider.getTranslatedText(translations), equals('Halo'));
    });

    test(
      'getTranslatedText returns English value after switching to en',
      () async {
        await provider.setLanguage(LanguageProvider.english);
        final translations = {'en': 'Hello', 'id': 'Halo'};
        expect(provider.getTranslatedText(translations), equals('Hello'));
      },
    );

    test('setLanguage updates currentLanguage', () async {
      await provider.setLanguage(LanguageProvider.english);
      expect(provider.currentLanguage, equals(LanguageProvider.english));
    });

    test('can switch back to Indonesian after switching to English', () async {
      await provider.setLanguage(LanguageProvider.english);
      await provider.setLanguage(LanguageProvider.indonesian);
      expect(provider.currentLanguage, equals(LanguageProvider.indonesian));
    });

    test(
      'getTranslatedText falls back to Indonesian when language key missing',
      () {
        final translations = {'id': 'Halo'};
        expect(provider.getTranslatedText(translations), equals('Halo'));
      },
    );

    test('getTranslatedText returns empty string when no keys match', () {
      final translations = <String, String>{};
      expect(provider.getTranslatedText(translations), equals(''));
    });

    test(
      'notifyListeners is called on setLanguage (ChangeNotifier fires)',
      () async {
        var notified = false;
        provider.addListener(() => notified = true);
        await provider.setLanguage(LanguageProvider.english);
        expect(notified, isTrue);
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Language-change → server-sync → backend-data refresh ordering.
  //
  // The whole point of the refresh path: the backend resolves locale
  // as (1) the saved `preferred_language` column, then (2) the
  // `Accept-Language` header. So the `PATCH /profile/language` MUST
  // land before the backend-data re-fetch, or the re-fetch could race
  // ahead and read the old locale. These tests lock that contract.
  // ─────────────────────────────────────────────────────────────────────────
  group('LanguageProvider server-sync + refresh ordering', () {
    setUp(() async {
      await _initPrefs();
    });

    tearDown(() {
      // Statics persist across tests — always clear the hooks.
      LanguageProvider.registerServerSync(null);
      LanguageProvider.registerOnLanguageChanged(null);
    });

    test(
      'setLanguage awaits the server-sync PATCH BEFORE firing the '
      'refresh hook',
      () async {
        final order = <String>[];
        var syncResolved = false;

        LanguageProvider.registerServerSync((code) async {
          order.add('sync_start');
          // Simulate the network round-trip resolving on a later
          // microtask — the refresh hook must NOT have run yet.
          await Future<void>.delayed(const Duration(milliseconds: 10));
          syncResolved = true;
          order.add('sync_done');
        });
        LanguageProvider.registerOnLanguageChanged((code) {
          // If this fires before `syncResolved`, the PATCH wasn't
          // awaited and the re-fetch would race the column write.
          expect(
            syncResolved,
            isTrue,
            reason: 'refresh hook ran before the PATCH resolved',
          );
          order.add('refresh');
        });

        final provider = LanguageProvider();
        await provider.setLanguage(LanguageProvider.english);

        expect(order, equals(['sync_start', 'sync_done', 'refresh']));
      },
    );

    test(
      'refresh hook receives the new language code',
      () async {
        String? refreshedWith;
        LanguageProvider.registerServerSync((_) async {});
        LanguageProvider.registerOnLanguageChanged((code) {
          refreshedWith = code;
        });

        final provider = LanguageProvider();
        await provider.setLanguage(LanguageProvider.english);

        expect(refreshedWith, equals(LanguageProvider.english));
      },
    );

    test(
      'a failing PATCH still updates the locale and still fires the '
      'refresh hook (resilient, does not crash)',
      () async {
        var refreshFired = false;
        // Even a *throwing* sync hook (offline / 5xx) must not abort
        // the local locale change or the re-fetch — setLanguage guards
        // the await with try/catch.
        LanguageProvider.registerServerSync((_) async {
          throw Exception('simulated 5xx / offline');
        });
        LanguageProvider.registerOnLanguageChanged((_) {
          refreshFired = true;
        });

        final provider = LanguageProvider();

        // Must not throw even though the sync hook does.
        await provider.setLanguage(LanguageProvider.english);

        expect(provider.currentLanguage, equals(LanguageProvider.english));
        expect(
          refreshFired,
          isTrue,
          reason: 'refresh must still fire after a failed PATCH',
        );
      },
    );

    test(
      'hydrateFromServer (syncToServer:false) does NOT fire server-sync '
      'or refresh hooks',
      () async {
        var syncFired = false;
        var refreshFired = false;
        LanguageProvider.registerServerSync((_) async => syncFired = true);
        LanguageProvider.registerOnLanguageChanged((_) => refreshFired = true);

        final provider = LanguageProvider();
        // hydrateFromServer adopts a server-supplied value; it must not
        // echo a PATCH back nor trigger a redundant re-fetch.
        await provider.hydrateFromServer(LanguageProvider.english);

        expect(provider.currentLanguage, equals(LanguageProvider.english));
        expect(syncFired, isFalse);
        expect(refreshFired, isFalse);
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // LocalizedString.tr extension
  // ─────────────────────────────────────────────────────────────────────────
  group('LocalizedString.tr extension', () {
    setUp(() async {
      await _initPrefs();
      // Reset global singleton to Indonesian before each test
      await languageProvider.setLanguage(LanguageProvider.indonesian);
    });

    test('.tr returns Indonesian text when language is "id"', () {
      final map = {'en': 'Save', 'id': 'Simpan'};
      expect(map.tr, equals('Simpan'));
    });

    test('.tr returns English text when language is "en"', () async {
      await languageProvider.setLanguage(LanguageProvider.english);
      final map = {'en': 'Save', 'id': 'Simpan'};
      expect(map.tr, equals('Save'));
    });

    test('.tr falls back to Indonesian when English key missing', () async {
      await languageProvider.setLanguage(LanguageProvider.english);
      final map = {'id': 'Simpan'};
      expect(map.tr, equals('Simpan'));
    });

    test('.tr returns empty string when map is empty', () async {
      expect(<String, String>{}.tr, equals(''));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // AppLocalizations spot checks
  // ─────────────────────────────────────────────────────────────────────────
  group('AppLocalizations', () {
    test('appTitle has both en and id', () {
      expect(AppLocalizations.appTitle['en'], isNotEmpty);
      expect(AppLocalizations.appTitle['id'], isNotEmpty);
    });

    test('welcome: en = "Welcome,", id = "Selamat datang,"', () {
      expect(AppLocalizations.welcome['en'], equals('Welcome,'));
      expect(AppLocalizations.welcome['id'], equals('Selamat datang,'));
    });

    test('save: en = "Save", id = "Simpan"', () {
      expect(AppLocalizations.save['en'], equals('Save'));
      expect(AppLocalizations.save['id'], equals('Simpan'));
    });

    test('cancel: en = "Cancel", id = "Batal"', () {
      expect(AppLocalizations.cancel['en'], equals('Cancel'));
      expect(AppLocalizations.cancel['id'], equals('Batal'));
    });

    test('logout: en = "Logout", id = "Keluar"', () {
      expect(AppLocalizations.logout['en'], equals('Logout'));
      expect(AppLocalizations.logout['id'], equals('Keluar'));
    });

    test('login: en = "Login", id = "Masuk"', () {
      expect(AppLocalizations.login['en'], equals('Login'));
      expect(AppLocalizations.login['id'], equals('Masuk'));
    });

    test('manageStudents has both translations', () {
      expect(AppLocalizations.manageStudents['en'], isNotEmpty);
      expect(AppLocalizations.manageStudents['id'], isNotEmpty);
    });

    test('finance: en = "Finance", id = "Keuangan"', () {
      expect(AppLocalizations.finance['en'], equals('Finance'));
      expect(AppLocalizations.finance['id'], equals('Keuangan'));
    });

    test('settings: en = "Settings", id = "Pengaturan"', () {
      expect(AppLocalizations.settings['en'], equals('Settings'));
      expect(AppLocalizations.settings['id'], equals('Pengaturan'));
    });

    test('all spot-checked keys have non-null maps', () {
      for (final map in [
        AppLocalizations.appTitle,
        AppLocalizations.welcome,
        AppLocalizations.save,
        AppLocalizations.cancel,
        AppLocalizations.logout,
        AppLocalizations.login,
        AppLocalizations.finance,
        AppLocalizations.settings,
      ]) {
        expect(map, isA<Map<String, String>>());
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Constants
  // ─────────────────────────────────────────────────────────────────────────
  group('LanguageProvider constants', () {
    test('english constant is "en"', () {
      expect(LanguageProvider.english, equals('en'));
    });

    test('indonesian constant is "id"', () {
      expect(LanguageProvider.indonesian, equals('id'));
    });
  });
}
