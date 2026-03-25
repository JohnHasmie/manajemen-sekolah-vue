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

import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:manajemensekolah/core/services/analytics_service.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/secure_storage_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

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

      AppLogger.debug('auth', 'Checking token validity, length: ${token.length}');

      if (!_isValidJWTFormat(token)) {
        AppLogger.error('auth', 'Token format invalid');
        await logout();
        return false;
      }

      // Sanctum tokens (containing '|') — skip local expiration check
      if (token.contains('|')) {
        AppLogger.info('auth', 'Sanctum token detected, skipping local expiration check');
        return true;
      }

      try {
        bool isExpired = JwtDecoder.isExpired(token);
        AppLogger.debug('auth', 'Token expired: $isExpired');
        if (!isExpired) {
          final expirationDate = JwtDecoder.getExpirationDate(token);
          AppLogger.debug('auth', 'Token expires at: $expirationDate');
        }

        if (isExpired) {
          await logout();
          return false;
        }
        return true;
      } catch (jwtError) {
        AppLogger.error('auth', jwtError);
        await logout();
        return false;
      }
    } catch (e) {
      AppLogger.error('auth', e);
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
      AppLogger.error('auth', e);
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
      AppLogger.info('auth', 'Logging out user...');

      // Delete FCM token from backend
      try {
        await FCMService().deleteTokenFromBackend();
        await FCMService().clearLocalToken();
        AppLogger.info('auth', 'FCM token cleaned up');
      } catch (fcmError) {
        AppLogger.warning('auth', 'FCM token cleanup failed (non-critical): $fcmError');
      }

      // Revoke backend token
      try {
        await ApiService().post('/auth/logout', {});
        AppLogger.info('auth', 'Backend token revoked');
      } catch (authError) {
        AppLogger.warning('auth', 'Backend token revocation failed (non-critical): $authError');
      }

      // Clear secure storage (token + user data)
      await _secureStorage.clearAll();

      // Also clear SharedPreferences (legacy token/user + cache)
      final prefs = PreferencesService();
      await prefs.remove('token');
      await prefs.remove('user');

      // Track logout in analytics
      await AnalyticsService.logLogout();

      // Clear local API cache
      await LocalCacheService.clearAll();

      // Set force logout flag
      await _secureStorage.setForceLogout(true);

      AppLogger.info('auth', 'Logout completed and cache cleared');
    } catch (e) {
      AppLogger.error('auth', e);
    }
  }

  /// Full login state check: token + user data + validity + no force-logout.
  Future<bool> isLoggedIn() async {
    try {
      // Check force logout flag
      final forceLogout = await _secureStorage.isForceLogout();
      if (forceLogout) {
        AppLogger.warning('auth', 'Force logout flag detected');
        await _secureStorage.setForceLogout(false);
        return false;
      }

      final token = await getToken();
      final userData = await getUserData();

      if (token == null || token.isEmpty || userData == null) {
        AppLogger.debug('auth', 'Incomplete login state: token=${token != null}, user=${userData != null}');
        return false;
      }

      final isValid = await isTokenValid();
      AppLogger.debug('auth', 'Login status: $isValid');
      return isValid;
    } catch (e) {
      AppLogger.error('auth', e);
      return false;
    }
  }

  /// Clears force logout flag (called after successful login).
  Future<void> clearForceLogout() async {
    await _secureStorage.setForceLogout(false);
    AppLogger.info('auth', 'Force logout flag cleared');
  }
}
