/// Tests for LocalCacheService — TTL-based caching via SharedPreferences.
///
/// Like testing a Laravel Cache facade: we verify put/get, expiration, and
/// tag-based clearing — but using SharedPreferences mock instead of Redis.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';

void main() {
  setUp(() {
    // Reset SharedPreferences to a clean state before every test.
    // Equivalent to flushing the cache store in a Laravel test setUp.
    SharedPreferences.setMockInitialValues({});
  });

  // ── Cache hit / miss ──────────────────────────────────────────────────────

  group('save and load', () {
    test('save then load returns the saved data (cache hit)', () async {
      await LocalCacheService.save('students', {'page': 1, 'total': 30});

      final result = await LocalCacheService.load('students');

      expect(result, isNotNull);
      expect(result['page'], 1);
      expect(result['total'], 30);
    });

    test('load on missing key returns null', () async {
      final result = await LocalCacheService.load('nonexistent_key');
      expect(result, isNull);
    });
  });

  // ── TTL expiration ────────────────────────────────────────────────────────

  group('TTL expiration', () {
    test('load after TTL expired returns null and removes the key', () async {
      // Manually write a cache entry with a timestamp far in the past
      // (2 hours ago) so it looks expired to the service.
      // This is like manually back-dating a Laravel cache entry.
      final prefs = await SharedPreferences.getInstance();
      final twoHoursAgoMs =
          DateTime.now().millisecondsSinceEpoch - const Duration(hours: 2).inMilliseconds;
      final expired = json.encode({'data': 'stale_data', 'timestamp': twoHoursAgoMs});
      await prefs.setString('api_cache_old_data', expired);

      // Load with a 1-hour TTL — the entry is 2 hours old, so it should expire.
      final result = await LocalCacheService.load('old_data', ttl: const Duration(hours: 1));

      expect(result, isNull);
      // The expired key must also be removed from storage (lazy eviction).
      expect(prefs.containsKey('api_cache_old_data'), isFalse);
    });

    test('load within TTL returns data', () async {
      await LocalCacheService.save('fresh_data', 'still valid');

      // Default TTL is 24 h; loading immediately should succeed.
      final result = await LocalCacheService.load('fresh_data');

      expect(result, 'still valid');
    });
  });

  // ── invalidate ────────────────────────────────────────────────────────────

  group('invalidate', () {
    test('invalidate removes a specific key so load returns null', () async {
      await LocalCacheService.save('classes', [1, 2, 3]);

      await LocalCacheService.invalidate('classes');

      final result = await LocalCacheService.load('classes');
      expect(result, isNull);
    });

    test('invalidate does not affect other keys', () async {
      await LocalCacheService.save('key_a', 'value_a');
      await LocalCacheService.save('key_b', 'value_b');

      await LocalCacheService.invalidate('key_a');

      // key_b must survive
      final result = await LocalCacheService.load('key_b');
      expect(result, 'value_b');
    });
  });

  // ── clearAll ──────────────────────────────────────────────────────────────

  group('clearAll', () {
    test('removes all api_cache_* keys but leaves other keys intact', () async {
      final prefs = await SharedPreferences.getInstance();

      // Seed two cache entries and one unrelated key.
      await LocalCacheService.save('teachers', ['Alice', 'Bob']);
      await LocalCacheService.save('subjects', ['Math', 'Science']);
      await prefs.setString('app_language', 'id'); // non-cache key

      await LocalCacheService.clearAll();

      // Both cache entries must be gone.
      expect(await LocalCacheService.load('teachers'), isNull);
      expect(await LocalCacheService.load('subjects'), isNull);

      // The unrelated key must still be present.
      expect(prefs.getString('app_language'), 'id');
    });
  });

  // ── clearStartingWith ─────────────────────────────────────────────────────

  group('clearStartingWith', () {
    test("clearStartingWith('subject_') removes only api_cache_subject_* keys", () async {
      await LocalCacheService.save('subject_math', {'lessons': 12});
      await LocalCacheService.save('subject_science', {'lessons': 8});
      await LocalCacheService.save('teacher_list', ['Alice']);

      await LocalCacheService.clearStartingWith('subject_');

      // Subject entries must be cleared.
      expect(await LocalCacheService.load('subject_math'), isNull);
      expect(await LocalCacheService.load('subject_science'), isNull);

      // Teacher entry must still be present.
      expect(await LocalCacheService.load('teacher_list'), isNotNull);
    });
  });

  // ── Data type handling ────────────────────────────────────────────────────

  group('data type handling', () {
    test('save and load a Map', () async {
      final map = {'id': 42, 'name': 'Budi', 'active': true};
      await LocalCacheService.save('map_key', map);

      final result = await LocalCacheService.load('map_key');

      expect(result, isA<Map>());
      expect(result['id'], 42);
      expect(result['name'], 'Budi');
    });

    test('save and load a List', () async {
      final list = [1, 'two', true, {'nested': 'ok'}];
      await LocalCacheService.save('list_key', list);

      final result = await LocalCacheService.load('list_key');

      expect(result, isA<List>());
      expect(result[0], 1);
      expect(result[1], 'two');
      expect(result[2], true);
    });

    test('save and load a String', () async {
      await LocalCacheService.save('string_key', 'hello world');

      final result = await LocalCacheService.load('string_key');

      expect(result, isA<String>());
      expect(result, 'hello world');
    });
  });
}
