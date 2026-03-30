/// Unit tests for LocalCacheService.
///
/// Uses SharedPreferences.setMockInitialValues() from the shared_preferences
/// package to inject a fake in-memory store without hitting the device.
///
/// Covers:
/// - save: stores JSON with data + timestamp
/// - load: cache hit within TTL, cache miss after TTL, key not found
/// - invalidate: removes single entry
/// - clearAll: removes all api_cache_* entries, leaves others intact
/// - clearStartingWith: removes only keys matching subPrefix
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';

void main() {
  setUp(() {
    // Reset SharedPreferences to a clean state before each test.
    // Like Storage::fake() in Laravel tests.
    SharedPreferences.setMockInitialValues({});
  });

  // ─────────────────────────────────────────────────────────────────────────
  // save + load (cache hit)
  // ─────────────────────────────────────────────────────────────────────────
  group('LocalCacheService.save and load', () {
    test('save then load within default TTL returns same data', () async {
      await LocalCacheService.save('students', [{'id': 1, 'name': 'Ali'}]);
      final result = await LocalCacheService.load('students');
      expect(result, isNotNull);
      expect(result[0]['name'], equals('Ali'));
    });

    test('save then load with explicit long TTL returns data', () async {
      await LocalCacheService.save('teachers', {'total': 5});
      final result = await LocalCacheService.load(
        'teachers',
        ttl: const Duration(hours: 1),
      );
      expect(result, isNotNull);
      expect(result['total'], equals(5));
    });

    test('load with expired TTL returns null and removes entry', () async {
      // Directly inject a cache entry with a timestamp far in the past
      // (2 hours ago → older than 1 hour TTL used below)
      final prefs = await SharedPreferences.getInstance();
      final oldEntry = json.encode({
        'data': 'some_value',
        'timestamp': DateTime.now()
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch,
      });
      await prefs.setString('api_cache_expired_key', oldEntry);

      // Load with a 1 hour TTL — the 2 hour old entry should expire
      final result = await LocalCacheService.load(
        'expired_key',
        ttl: const Duration(hours: 1),
      );
      expect(result, isNull);

      // The key should have been removed (lazy expiration)
      expect(prefs.getString('api_cache_expired_key'), isNull);
    });

    test('load for non-existent key returns null', () async {
      final result = await LocalCacheService.load('missing_key');
      expect(result, isNull);
    });

    test('saves complex nested object and retrieves it correctly', () async {
      final data = {
        'page': 1,
        'items': [
          {'id': 1, 'score': 90.5},
          {'id': 2, 'score': 78.0},
        ],
      };
      await LocalCacheService.save('grades', data);
      final result = await LocalCacheService.load('grades');
      expect(result['page'], equals(1));
      expect(result['items'].length, equals(2));
      expect(result['items'][0]['score'], equals(90.5));
    });

    test('saves string value and retrieves it', () async {
      await LocalCacheService.save('token_test', 'abc123');
      final result = await LocalCacheService.load('token_test');
      expect(result, equals('abc123'));
    });

    test('saves integer value and retrieves it', () async {
      await LocalCacheService.save('count', 42);
      final result = await LocalCacheService.load('count');
      expect(result, equals(42));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // invalidate
  // ─────────────────────────────────────────────────────────────────────────
  group('LocalCacheService.invalidate', () {
    test('invalidate removes the specific key', () async {
      await LocalCacheService.save('students', 'data');
      await LocalCacheService.invalidate('students');
      final result = await LocalCacheService.load('students');
      expect(result, isNull);
    });

    test('invalidate only removes the targeted key', () async {
      await LocalCacheService.save('students', 'students_data');
      await LocalCacheService.save('teachers', 'teachers_data');
      await LocalCacheService.invalidate('students');

      expect(await LocalCacheService.load('students'), isNull);
      expect(await LocalCacheService.load('teachers'), isNotNull);
    });

    test('invalidating a non-existent key does not throw', () async {
      await expectLater(
        LocalCacheService.invalidate('never_saved'),
        completes,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // clearAll
  // ─────────────────────────────────────────────────────────────────────────
  group('LocalCacheService.clearAll', () {
    test('clearAll removes all api_cache_* entries', () async {
      await LocalCacheService.save('key1', 'value1');
      await LocalCacheService.save('key2', 'value2');
      await LocalCacheService.save('key3', 'value3');

      await LocalCacheService.clearAll();

      expect(await LocalCacheService.load('key1'), isNull);
      expect(await LocalCacheService.load('key2'), isNull);
      expect(await LocalCacheService.load('key3'), isNull);
    });

    test('clearAll leaves non-cache keys intact', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_setting', 'dark_mode');

      await LocalCacheService.save('some_key', 'some_value');
      await LocalCacheService.clearAll();

      // Non-cache key is still there
      expect(prefs.getString('user_setting'), equals('dark_mode'));
    });

    test('clearAll on empty cache completes without throwing', () async {
      await expectLater(LocalCacheService.clearAll(), completes);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // clearStartingWith
  // ─────────────────────────────────────────────────────────────────────────
  group('LocalCacheService.clearStartingWith', () {
    test('removes only keys matching the subPrefix', () async {
      await LocalCacheService.save('student_list', 'students');
      await LocalCacheService.save('student_detail_1', 'detail1');
      await LocalCacheService.save('teacher_list', 'teachers');

      await LocalCacheService.clearStartingWith('student_');

      expect(await LocalCacheService.load('student_list'), isNull);
      expect(await LocalCacheService.load('student_detail_1'), isNull);
      expect(await LocalCacheService.load('teacher_list'), isNotNull);
    });

    test('clearStartingWith with no matches completes without throwing', () async {
      await LocalCacheService.save('teacher_list', 'data');
      await expectLater(
        LocalCacheService.clearStartingWith('student_'),
        completes,
      );
      // Unrelated keys remain
      expect(await LocalCacheService.load('teacher_list'), isNotNull);
    });

    test('clearStartingWith empty subPrefix clears all cache entries', () async {
      await LocalCacheService.save('a', 'value_a');
      await LocalCacheService.save('b', 'value_b');
      await LocalCacheService.clearStartingWith('');
      expect(await LocalCacheService.load('a'), isNull);
      expect(await LocalCacheService.load('b'), isNull);
    });
  });
}
