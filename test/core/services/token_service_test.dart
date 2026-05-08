// ignore_for_file: lines_longer_than_80_chars
/// Tests for TokenService — authentication state management.
///
/// TokenService wraps SecureStorageService (FlutterSecureStorage) and
/// PreferencesService (SharedPreferences). We mock both platform channels
/// so no real storage or native code is involved.
///
/// Like testing a Laravel Auth guard: we set up the underlying token store
/// directly, then verify the service's public API responds correctly.
///
/// NOTE: logout() is intentionally NOT tested here because it calls
/// ApiService, FCMService, and AnalyticsService which require live
/// platform plugins (Firebase, HTTP, etc.).
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/core/services/token_service.dart';
import 'package:manajemensekolah/core/services/secure_storage_service.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

/// A minimal valid 3-part JWT that is NOT expired.
/// Header: {"alg":"HS256","typ":"JWT"}
/// Payload: {"sub":"1","exp":9999999999}  ← expiry year ~2286
/// (Signature part is a placeholder — JwtDecoder only checks the payload.)
const _validJwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
    '.eyJzdWIiOiIxIiwiZXhwIjo5OTk5OTk5OTk5fQ'
    '.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

// ── Test suite
// ────────────────────────────────────────────────────────────────

void main() {
  // In-memory store that backs the FlutterSecureStorage mock.
  // Shared between TokenService and SecureStorageService because both are
  // singletons using the same MethodChannel under the hood.
  late Map<String, String> mockSecureStore;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Fresh secure storage for every test.
    mockSecureStore = {};

    // Mock the FlutterSecureStorage MethodChannel.
    // This intercepts all read/write calls that SecureStorageService makes.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (MethodCall call) async {
            switch (call.method) {
              case 'write':
                final key = call.arguments['key'] as String;
                final value = call.arguments['value'] as String;
                mockSecureStore[key] = value;
                return null;
              case 'read':
                final key = call.arguments['key'] as String;
                return mockSecureStore[key];
              case 'delete':
                final key = call.arguments['key'] as String;
                mockSecureStore.remove(key);
                return null;
              case 'deleteAll':
                mockSecureStore.clear();
                return null;
              default:
                return null;
            }
          },
        );

    // Fresh SharedPreferences for every test (used by PreferencesService
    // and LocalCacheService inside logout — but logout is not tested here).
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  // ── isTokenValid ────────────────────────────────────────────────────────

  group('isTokenValid', () {
    test('returns false when no token is stored', () async {
      final service = TokenService();
      final result = await service.isTokenValid();
      expect(result, isFalse);
    });

    test('returns true for a Sanctum token (contains "|")', () async {
      // Sanctum personal access tokens look like: "<id>|<hash>"
      // TokenService skips local JWT expiration for these.
      await SecureStorageService().saveToken('123|abcdefghijklmnopqrstuvwxyz');

      final result = await TokenService().isTokenValid();
      expect(result, isTrue);
    });

    test('returns true for a valid 3-part JWT that is not expired', () async {
      await SecureStorageService().saveToken(_validJwt);

      final result = await TokenService().isTokenValid();
      expect(result, isTrue);
    });
  });

  // ── isLoggedIn ──────────────────────────────────────────────────────────

  group('isLoggedIn', () {
    test('returns false when force-logout flag is set', () async {
      // Simulate a previous logout that left the force-logout flag behind.
      // Like Laravel setting a session flash that forces re-auth on next request.
      //
      await SecureStorageService().setForceLogout(true);

      final result = await TokenService().isLoggedIn();
      expect(result, isFalse);
    });

    test('returns false when no token is stored', () async {
      // No token, no user data → not logged in.
      final result = await TokenService().isLoggedIn();
      expect(result, isFalse);
    });
  });

  // ── getToken ────────────────────────────────────────────────────────────

  group('getToken', () {
    test('returns null when nothing is stored', () async {
      final token = await TokenService().getToken();
      expect(token, isNull);
    });

    test(
      'returns the stored token after saving via SecureStorageService',
      () async {
        await SecureStorageService().saveToken('my_saved_token');

        final token = await TokenService().getToken();
        expect(token, 'my_saved_token');
      },
    );
  });

  // ── getUserData ─────────────────────────────────────────────────────────

  group('getUserData', () {
    test('returns null when nothing is stored', () async {
      final data = await TokenService().getUserData();
      expect(data, isNull);
    });

    test('returns data after saving via SecureStorageService', () async {
      await SecureStorageService().saveUserData({
        'id': 1,
        'name': 'Budi',
        'role': 'student',
      });

      final data = await TokenService().getUserData();

      expect(data, isNotNull);
      expect(data!['id'], 1);
      expect(data['name'], 'Budi');
      expect(data['role'], 'student');
    });
  });

  // ── clearForceLogout ────────────────────────────────────────────────────

  group('clearForceLogout', () {
    test('sets force-logout flag to false', () async {
      // First set the flag so we have something to clear.
      await SecureStorageService().setForceLogout(true);
      expect(await SecureStorageService().isForceLogout(), isTrue);

      await TokenService().clearForceLogout();

      expect(await SecureStorageService().isForceLogout(), isFalse);
    });
  });
}
