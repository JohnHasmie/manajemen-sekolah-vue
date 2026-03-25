/// secure_storage_service.dart - Encrypted storage for sensitive data (tokens, user info).
/// Like Laravel's encryption service (`Crypt::encrypt/decrypt`) but for client-side storage.
/// In Vue terms, this is like using an encrypted localStorage wrapper instead of plain localStorage.
///
/// Only sensitive auth data is stored here. Non-sensitive data (cache, language prefs,
/// tour state) stays in SharedPreferences for performance.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys for secure storage entries.
class _Keys {
  static const token = 'secure_token';
  static const userData = 'secure_user_data';
  static const forceLogout = 'secure_force_logout';
}

/// Singleton service for encrypted storage of auth-sensitive data.
/// Uses flutter_secure_storage (Keychain on iOS, EncryptedSharedPreferences on Android).
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Saves the auth token securely.
  Future<void> saveToken(String token) async {
    await _storage.write(key: _Keys.token, value: token);
  }

  /// Retrieves the auth token, or null if not stored.
  Future<String?> getToken() async {
    return await _storage.read(key: _Keys.token);
  }

  /// Checks if a token exists in secure storage.
  Future<bool> hasToken() async {
    final token = await _storage.read(key: _Keys.token);
    return token != null && token.isNotEmpty;
  }

  /// Saves user data as encrypted JSON string.
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _storage.write(key: _Keys.userData, value: json.encode(userData));
  }

  /// Retrieves user data as a Map, or null if not stored.
  Future<Map<String, dynamic>?> getUserData() async {
    final jsonStr = await _storage.read(key: _Keys.userData);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return json.decode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to parse secure user data: $e');
      return null;
    }
  }

  /// Retrieves raw user data JSON string (for backward compatibility).
  Future<String?> getUserDataJson() async {
    return await _storage.read(key: _Keys.userData);
  }

  /// Sets the force logout flag.
  Future<void> setForceLogout(bool value) async {
    await _storage.write(key: _Keys.forceLogout, value: value.toString());
  }

  /// Checks if force logout flag is set.
  Future<bool> isForceLogout() async {
    final value = await _storage.read(key: _Keys.forceLogout);
    return value == 'true';
  }

  /// Clears all secure storage entries (used on logout).
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
