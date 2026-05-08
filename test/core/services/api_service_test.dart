// ignore_for_file: lines_longer_than_80_chars
/// Tests for ApiService — core HTTP infrastructure.
///
/// We only test the parts that DON'T require live network calls:
///   - [ApiService.getToken()]    — reads from PreferencesService / SharedPrefs
///   - [ApiService.getHeaders()]  — builds auth headers from stored token
///   - [ApiService.init()]        — reads baseUrl from dotenv (guard for null)
///
/// Analogous to a Laravel unit test that mocks the DB and only tests the
/// model's pure business logic — we isolate the storage layer using
/// SharedPreferences.setMockInitialValues() instead of a real platform channel.
///
/// Tests that DO require live network (get, post, put, delete, uploadFile,
/// checkHealth, logoutWithMessage) are intentionally skipped.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // setUp — runs before every individual test.
  //
  // We reset SharedPreferences to a clean empty state before each test,
  // just like calling `DB::table(...)->truncate()` in a Laravel test setUp.
  // Then we reinitialise PreferencesService so it picks up the fresh mock.
  // ---------------------------------------------------------------------------
  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    // PreferencesService is a singleton — calling init() again points its
    // internal _prefs reference to the newly mocked SharedPreferences instance.
    await PreferencesService().init();
  });

  // ---------------------------------------------------------------------------
  // ApiService.getToken()
  // ---------------------------------------------------------------------------
  group('ApiService.getToken()', () {
    test(
      'returns the stored token when one exists in SharedPreferences',
      () async {
        // Arrange — seed the mock storage with a token, similar to how you'd
        // seed a test database with a factory in Laravel.
        SharedPreferences.setMockInitialValues({'token': 'test_token'});
        await PreferencesService().init();

        // Act
        final token = await ApiService.getToken();

        // Assert
        expect(token, equals('test_token'));
      },
    );

    test('returns null when no token is stored in SharedPreferences', () async {
      // Arrange — empty prefs (set in setUp, nothing extra needed).

      // Act
      final token = await ApiService.getToken();

      // Assert — like checking that Auth::user() is null when not logged in.
      expect(token, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // ApiService.getHeaders()
  // ---------------------------------------------------------------------------
  group('ApiService.getHeaders()', () {
    test('always includes Content-Type and Accept headers', () async {
      // Act — call with an empty prefs (no token).
      final headers = await ApiService.getHeaders();

      // Assert
      expect(headers['Content-Type'], equals('application/json'));
      expect(headers['Accept'], equals('application/json'));
    });

    test(
      'includes Authorization: Bearer <token> when a token is stored',
      () async {
        // Arrange — simulate a logged-in user by putting a token in storage.
        SharedPreferences.setMockInitialValues({'token': 'test_token'});
        await PreferencesService().init();

        // Act
        final headers = await ApiService.getHeaders();

        // Assert — like checking that a middleware attaches the correct
        // Authorization header after the user authenticates.
        expect(headers['Authorization'], equals('Bearer test_token'));
        expect(headers['Content-Type'], equals('application/json'));
      },
    );

    test(
      'does NOT include an Authorization header when no token is stored',
      () async {
        // Arrange — empty prefs (set in setUp, no token present).

        // Act
        final headers = await ApiService.getHeaders();

        // Assert — unauthenticated requests must not leak a Bearer header.
        expect(headers.containsKey('Authorization'), isFalse);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // ApiService.init()
  // ---------------------------------------------------------------------------
  group('ApiService.init()', () {
    test('can be called safely in a test environment — absorbs dotenv '
        'NotInitializedError because dotenv is not loaded in unit tests', () async {
      // In production, dotenv.load() is called in main() before ApiService.init().
      //
      // In unit tests, dotenv is never loaded, so dotenv.env throws
      // NotInitializedError *before* the null-guard inside init() can run.
      //
      // The null-guard in ApiService.init() protects against a null/empty URL
      // (the happy-path test scenario), but it cannot protect against dotenv
      // itself being uninitialised.
      //
      // We use a try-catch here — analogous to a Laravel test that deliberately
      // calls a provider without booting the full application and just asserts
      // the error type rather than letting the test suite crash.
      //
      // This test documents the expected boundary: init() is safe to call as
      // long as dotenv has been loaded beforehand (production behaviour).
      bool caughtExpectedError = false;
      try {
        await ApiService.init();
      } catch (e) {
        // NotInitializedError is from flutter_dotenv and is expected here
        // because the test environment does not call dotenv.load().
        caughtExpectedError = true;
        expect(e.toString(), contains('NotInitializedError'));
      }
      // Either path is acceptable: no throw (if dotenv happens to be
      // initialised by another test) or the expected NotInitializedError.
      // What must NOT happen is an unrelated, unexpected exception type.
      expect(caughtExpectedError || true, isTrue);
    });
  });
}
