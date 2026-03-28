/// preferences_service.dart - Centralized wrapper for SharedPreferences.
/// Like Laravel's `config()` helper or Vue's Pinia persisted state.
///
/// All non-sensitive data (cache, language, tour flags) goes through this service.
/// Sensitive data (tokens, user info) goes through SecureStorageService instead.
///
/// Initialized once at app startup via [init()], then accessed synchronously.
/// This avoids the repeated `await SharedPreferences.getInstance()` pattern
/// found across 29+ files.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Singleton wrapper for SharedPreferences.
/// Must call [init()] before first use (during app startup).
class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  late SharedPreferences _prefs;
  bool _initialized = false;

  /// Initialize SharedPreferences. Call once in main() before runApp().
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// Direct access to the underlying SharedPreferences instance.
  /// Use sparingly — prefer the typed methods below.
  SharedPreferences get prefs {
    assert(_initialized, 'PreferencesService.init() must be called first');
    return _prefs;
  }

  // ── String ──

  String? getString(String key) => _prefs.getString(key);

  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  // ── Bool ──

  bool? getBool(String key) => _prefs.getBool(key);

  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  // ── Int ──

  int? getInt(String key) => _prefs.getInt(key);

  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  // ── JSON (Map) ──

  Map<String, dynamic>? getJson(String key) {
    final jsonStr = _prefs.getString(key);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return json.decode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<bool> setJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, json.encode(value));

  // ── Remove / Clear ──

  Future<bool> remove(String key) => _prefs.remove(key);

  Future<bool> clear() => _prefs.clear();

  bool containsKey(String key) => _prefs.containsKey(key);
}
