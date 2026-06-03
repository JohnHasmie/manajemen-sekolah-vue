/// local_cache_service.dart - Provides TTL-based local caching via
/// SharedPreferences.
/// Like Laravel's Cache facade (with file/database driver) / Vue's localStorage helper.
///
/// This is the Flutter equivalent of Laravel's `Cache::put()` / `Cache::get()` with
/// expiration. Uses SharedPreferences (key-value storage on device) instead of
/// Redis.
/// All API service classes use this to cache paginated responses for offline
/// support
/// and performance. Keys are prefixed with `api_cache_` to avoid collision.
///
/// Key differences from Laravel Cache:
/// - No tags support -- uses prefix-based clearing (`clearStartingWith`)
/// - TTL is checked on read (lazy expiration), not background eviction
/// - Data is JSON-serialized into a single string value
library;

import 'dart:convert';

import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local cache service using SharedPreferences with TTL (time-to-live).
/// Think of this as a simplified `Cache` facade from Laravel, but client-side.
///
/// In Vue terms, this is like a reusable composable that wraps localStorage
/// with automatic expiration and JSON serialization.
///
/// Usage pattern (from other services):
/// ```dart
/// final cached = await LocalCacheService.load('my_key');
/// if (cached != null) return cached; // cache hit
/// final data = await fetchFromApi();
/// await LocalCacheService.save('my_key', data); // cache miss -> save
/// ```
class LocalCacheService {
  /// Prefix for all cache keys to avoid collision with other SharedPreferences
  /// data.
  /// Like Laravel's `cache.prefix` config.
  static const String _prefix = 'api_cache_';

  /// Default time-to-live for cached data. Like Laravel's `cache.ttl` config.
  static const Duration _defaultTTL = Duration(hours: 24);

  /// Clears all cache entries starting with our prefix
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith(_prefix))
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Clears all cache entries starting with a specific sub-prefix (after the
  /// main prefix)
  /// Example: clearStartingWith('subject_') will remove api_cache_subject_...
  static Future<void> clearStartingWith(String subPrefix) async {
    final prefs = await SharedPreferences.getInstance();
    final fullPrefix = '$_prefix$subPrefix';
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith(fullPrefix))
        .toList();

    AppLogger.debug('cache', 'Clearing cache keys starting with: $fullPrefix');
    AppLogger.debug('cache', 'Found ${keys.length} keys to clear');

    for (final key in keys) {
      AppLogger.debug('cache', 'Removing cache key: $key');
      await prefs.remove(key);
    }
  }

  /// Removes a specific cache entry by key (e.g. when data changes)
  static Future<void> invalidate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }

  /// Saves API response data to cache
  static Future<void> save(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString('$_prefix$key', json.encode(cacheData));
    } catch (e) {
      AppLogger.error('cache', 'Error saving to local cache ($key): $e');
    }
  }

  /// Loads data from cache if still within the time-to-live (TTL) period
  static Future<dynamic> load(String key, {Duration? ttl}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString('$_prefix$key');

      if (cachedString == null) return null;

      final cachedMap = json.decode(cachedString);
      final timestamp = cachedMap['timestamp'] as int;
      final expiry = ttl ?? _defaultTTL;

      if (DateTime.now().millisecondsSinceEpoch - timestamp >
          expiry.inMilliseconds) {
        // Cache expired
        await prefs.remove('$_prefix$key');
        return null;
      }

      return cachedMap['data'];
    } catch (e) {
      AppLogger.error('cache', 'Error loading from local cache ($key): $e');
      return null;
    }
  }
}
