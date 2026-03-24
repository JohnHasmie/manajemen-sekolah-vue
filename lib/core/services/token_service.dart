/// token_service.dart - Token management service for authentication state.
/// Like Laravel's Auth guard + token management combined.
/// - `isTokenValid()` = `Auth::check()`
/// - `getUserData()` = `Auth::user()`
/// - `getToken()` = reading the Bearer token
/// - `logout()` = `Auth::logout()`
/// - `isLoggedIn()` = `Auth::check()` with force-logout flag
///
/// Tokens stored encrypted via SecureStorageService (Keychain/EncryptedSharedPreferences).
library;

import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:manajemensekolah/core/services/analytics_service.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service for managing authentication tokens and login state.
/// Uses SecureStorageService for encrypted token/user storage.
class TokenService {
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  final SecureStorageService _secureStorage = SecureStorageService();

  /// Checks if the stored token is valid and not expired.
  /// Like `Auth::check()` in Laravel.
  Future<bool> isTokenValid() async {
    try {
      final String? token = await _secureStorage.getToken();

      if (token == null || token.isEmpty) {
        return false;
      }

      if (kDebugMode) {
        print('🔐 Checking token validity...');
        print('📝 Token length: ${token.length}');
      }

      if (!_isValidJWTFormat(token)) {
        if (kDebugMode) print('❌ Token format invalid');
        await logout();
        return false;
      }

      // Sanctum tokens (containing '|') — skip local expiration check
      if (token.contains('|')) {
        if (kDebugMode) print('ℹ️ Sanctum token detected, skipping local expiration check');
        return true;
      }

      try {
        bool isExpired = JwtDecoder.isExpired(token);
        if (kDebugMode) {
          print('⏰ Token expired: $isExpired');
          if (!isExpired) {
            final expirationDate = JwtDecoder.getExpirationDate(token);
            print('📅 Token expires at: $expirationDate');
          }
        }

        if (isExpired) {
          await logout();
          return false;
        }
        return true;
      } catch (jwtError) {
        if (kDebugMode) print('❌ JWT Decoder error: $jwtError');
        await logout();
        return false;
      }
    } catch (e) {
      if (kDebugMode) print('❌ Token validation error: $e');
      await logout();
      return false;
    }
  }

  /// Validates token format: Sanctum (contains '|') or JWT (3 dot-separated parts).
  bool _isValidJWTFormat(String token) {
    if (token.contains('|')) return true;
    final parts = token.split('.');
    return parts.length == 3;
  }

  /// Retrieves the cached user data from secure storage.
  /// Like `Auth::user()` in Laravel.
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      return await _secureStorage.getUserData();
    } catch (e) {
      if (kDebugMode) print('❌ Get user data error: $e');
      return null;
    }
  }

  /// Retrieves the raw token string from secure storage.
  Future<String?> getToken() async {
    return await _secureStorage.getToken();
  }

  /// Logs out: revokes backend token, clears FCM, clears cache + secure storage.
  /// Like `Auth::logout()` in Laravel.
  Future<void> logout() async {
    try {
      if (kDebugMode) print('🚪 Logging out user...');

      // Delete FCM token from backend
      try {
        await FCMService().deleteTokenFromBackend();
        await FCMService().clearLocalToken();
        if (kDebugMode) print('✅ FCM token cleaned up');
      } catch (fcmError) {
        if (kDebugMode) print('⚠️ FCM token cleanup failed (non-critical): $fcmError');
      }

      // Revoke backend token
      try {
        await ApiService().post('/auth/logout', {});
        if (kDebugMode) print('✅ Backend token revoked');
      } catch (authError) {
        if (kDebugMode) print('⚠️ Backend token revocation failed (non-critical): $authError');
      }

      // Clear secure storage (token + user data)
      await _secureStorage.clearAll();

      // Also clear SharedPreferences (legacy token/user + cache)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user');

      // Track logout in analytics
      await AnalyticsService.logLogout();

      // Clear local API cache
      await LocalCacheService.clearAll();

      // Set force logout flag
      await _secureStorage.setForceLogout(true);

      if (kDebugMode) print('✅ Logout completed and cache cleared');
    } catch (e) {
      if (kDebugMode) print('❌ Error during logout: $e');
    }
  }

  /// Full login state check: token + user data + validity + no force-logout.
  Future<bool> isLoggedIn() async {
    try {
      // Check force logout flag
      final forceLogout = await _secureStorage.isForceLogout();
      if (forceLogout) {
        if (kDebugMode) print('🚫 Force logout flag detected');
        await _secureStorage.setForceLogout(false);
        return false;
      }

      final token = await getToken();
      final userData = await getUserData();

      if (token == null || token.isEmpty || userData == null) {
        if (kDebugMode) {
          print('🔐 Incomplete login state: token=${token != null}, user=${userData != null}');
        }
        return false;
      }

      final isValid = await isTokenValid();
      if (kDebugMode) print('🔐 Login status: $isValid');
      return isValid;
    } catch (e) {
      if (kDebugMode) print('❌ Login check error: $e');
      return false;
    }
  }

  /// Clears force logout flag (called after successful login).
  Future<void> clearForceLogout() async {
    await _secureStorage.setForceLogout(false);
    if (kDebugMode) print('✅ Force logout flag cleared');
  }
}
