import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  static const String _prefix = 'api_cache_';
  static const Duration _defaultTTL = Duration(hours: 24);

  /// Menghapus semua cache yang diawali dengan prefix kita
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

  /// Menghapus cache spesifik berdasarkan key (misal saat ada perubahan data)
  static Future<void> invalidate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }

  /// Menyimpan data hasil API ke cache
  static Future<void> save(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString('$_prefix$key', json.encode(cacheData));
    } catch (e) {
      if (kDebugMode) {
        print('Error saving to local cache ($key): $e');
      }
    }
  }

  /// Memuat data dari cache jika masih dalam masa berlaku (TTL)
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
      if (kDebugMode) {
        print('Error loading from local cache ($key): $e');
      }
      return null;
    }
  }
}
