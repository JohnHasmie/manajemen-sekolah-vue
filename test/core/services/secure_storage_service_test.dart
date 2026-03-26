/// Tests for SecureStorageService — verifies the public API behavior
/// by mocking the FlutterSecureStorage platform channel.
///
/// Like testing a Laravel encryption service where we mock the underlying
/// crypto driver and verify the service API works correctly.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/services/secure_storage_service.dart';

void main() {
  late SecureStorageService service;

  /// In-memory store simulating the platform's encrypted storage.
  late Map<String, String> mockStore;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    service = SecureStorageService();
    mockStore = {};

    // Mock the FlutterSecureStorage platform channel.
    // FlutterSecureStorage uses MethodChannel('plugins.it_nomads.com/flutter_secure_storage')
    // to communicate with the native platform.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'write':
            final key = methodCall.arguments['key'] as String;
            final value = methodCall.arguments['value'] as String;
            mockStore[key] = value;
            return null;
          case 'read':
            final key = methodCall.arguments['key'] as String;
            return mockStore[key];
          case 'delete':
            final key = methodCall.arguments['key'] as String;
            mockStore.remove(key);
            return null;
          case 'deleteAll':
            mockStore.clear();
            return null;
          case 'containsKey':
            final key = methodCall.arguments['key'] as String;
            return mockStore.containsKey(key) ? 'true' : 'false';
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  group('Token operations', () {
    test('getToken returns null when nothing is saved', () async {
      final token = await service.getToken();
      expect(token, isNull);
    });

    test('saveToken then getToken round-trip', () async {
      await service.saveToken('test-jwt-token-123');
      final token = await service.getToken();
      expect(token, 'test-jwt-token-123');
    });

    test('saveToken overwrites previous token', () async {
      await service.saveToken('old-token');
      await service.saveToken('new-token');
      final token = await service.getToken();
      expect(token, 'new-token');
    });
  });

  group('hasToken', () {
    test('returns false when no token stored', () async {
      final result = await service.hasToken();
      expect(result, isFalse);
    });

    test('returns true after saving a token', () async {
      await service.saveToken('my-token');
      final result = await service.hasToken();
      expect(result, isTrue);
    });
  });

  group('User data operations', () {
    test('getUserData returns null when nothing is saved', () async {
      final data = await service.getUserData();
      expect(data, isNull);
    });

    test('saveUserData then getUserData round-trip', () async {
      final userData = {'id': 1, 'name': 'Budi', 'role': 'admin'};
      await service.saveUserData(userData);
      final result = await service.getUserData();

      expect(result, isNotNull);
      expect(result!['name'], 'Budi');
      expect(result['role'], 'admin');
    });

    test('getUserDataJson returns raw JSON string', () async {
      final userData = {'id': 1, 'name': 'Budi'};
      await service.saveUserData(userData);
      final json = await service.getUserDataJson();

      expect(json, isNotNull);
      expect(json, contains('"name"'));
      expect(json, contains('Budi'));
    });
  });

  group('Force logout flag', () {
    test('isForceLogout returns false by default', () async {
      final result = await service.isForceLogout();
      expect(result, isFalse);
    });

    test('setForceLogout true then isForceLogout returns true', () async {
      await service.setForceLogout(true);
      final result = await service.isForceLogout();
      expect(result, isTrue);
    });

    test('setForceLogout false then isForceLogout returns false', () async {
      await service.setForceLogout(true);
      await service.setForceLogout(false);
      final result = await service.isForceLogout();
      expect(result, isFalse);
    });
  });

  group('clearAll', () {
    test('removes all stored data', () async {
      await service.saveToken('token-123');
      await service.saveUserData({'id': 1});
      await service.setForceLogout(true);

      await service.clearAll();

      expect(await service.getToken(), isNull);
      expect(await service.getUserData(), isNull);
      expect(await service.isForceLogout(), isFalse);
    });

    test('hasToken returns false after clearAll', () async {
      await service.saveToken('token-123');
      await service.clearAll();
      final result = await service.hasToken();
      expect(result, isFalse);
    });
  });

  group('Singleton pattern', () {
    test('factory constructor returns same instance', () {
      final a = SecureStorageService();
      final b = SecureStorageService();
      expect(identical(a, b), isTrue);
    });
  });
}
