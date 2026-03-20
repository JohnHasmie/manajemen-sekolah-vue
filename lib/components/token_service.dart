// Token management service for authentication state.
//
// Like Laravel's Auth guard + token management combined. In a Laravel app,
// authentication state is managed by `Auth::check()`, `Auth::user()`, and
// `Auth::logout()`. This service provides the Flutter equivalent:
// - `isTokenValid()` = `Auth::check()` (validates the JWT/Sanctum token)
// - `getUserData()` = `Auth::user()` (retrieves the cached user data)
// - `getToken()` = reading the Bearer token from the session/cookie
// - `logout()` = `Auth::logout()` (revokes token, clears session, cleans FCM)
// - `isLoggedIn()` = `Auth::check()` with additional force-logout flag support
//
// Tokens are stored in SharedPreferences (like Laravel's session storage).
// Supports both JWT tokens (decoded with jwt_decoder) and Laravel Sanctum
// tokens (plain text with `id|hash` format).
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:manajemensekolah/services/analytics_service.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/fcm_service.dart';
import 'package:manajemensekolah/services/local_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service for managing authentication tokens and login state.
///
/// Like Laravel's Auth guard + token management. Uses the singleton pattern
/// (similar to `app('auth')` in the Laravel container).
///
/// Key methods (Laravel equivalents):
/// - [isTokenValid] - `Auth::check()` + token expiration validation
/// - [getUserData] - `Auth::user()` (from SharedPreferences cache)
/// - [getToken] - reads the stored Bearer token
/// - [logout] - `Auth::logout()` + FCM cleanup + cache clearing
/// - [isLoggedIn] - full login state check with force-logout flag
/// - [clearForceLogout] - resets the force-logout flag after successful login
class TokenService {
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  static const String _tokenKey = 'token';
  static const String _userKey = 'user';

  /// Checks if the stored token is valid and not expired.
  /// Like `Auth::check()` in Laravel -- returns false if no token, invalid
  /// format, or expired. For Sanctum tokens (containing '|'), skips JWT
  /// expiration check since Sanctum manages expiration server-side.
  Future<bool> isTokenValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString(_tokenKey);

      if (token == null || token.isEmpty) {
        return false;
      }

      // Debug logging
      if (kDebugMode) {
        print('🔐 Checking token validity...');
        print('📝 Token length: ${token.length}');
      }

      // Check if token is a valid JWT format first
      if (!_isValidJWTFormat(token)) {
        if (kDebugMode) {
          print('❌ Token format invalid');
        }
        await logout();
        return false;
      }

      // Check if token is expired using jwt_decoder
      // Skip this check for Sanctum tokens (containing '|')
      if (token.contains('|')) {
        if (kDebugMode) {
          print('ℹ️ Sanctum token detected, skipping local expiration check');
        }
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
        if (kDebugMode) {
          print('❌ JWT Decoder error: $jwtError');
        }
        // Jika gagal decode, anggap token invalid
        await logout();
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Token validation error: $e');
      }
      await logout();
      return false;
    }
  }

  /// Validates the token format: either a Sanctum token (contains '|')
  /// or a standard JWT (3 dot-separated parts). Like middleware validation.
  bool _isValidJWTFormat(String token) {
    // Allow Sanctum tokens (id|hashed_token) or JWT (3 parts)
    if (token.contains('|')) return true;

    // Basic JWT format validation (3 parts separated by dots)
    final parts = token.split('.');
    return parts.length == 3;
  }

  /// Retrieves the cached user data from SharedPreferences.
  /// Like `Auth::user()` in Laravel -- returns the user as a Map, or null.
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userString = prefs.getString(_userKey);

      if (userString == null || userString.isEmpty) {
        return null;
      }

      return json.decode(userString);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Get user data error: $e');
      }
      return null;
    }
  }

  /// Retrieves the raw token string from SharedPreferences.
  /// Like reading the Bearer token from a Laravel session/cookie.
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Logs out the user: revokes backend token, clears FCM, clears cache.
  /// Like `Auth::logout()` in Laravel + clearing the session + revoking
  /// the Sanctum token via `/auth/logout` API call.
  Future<void> logout() async {
    try {
      if (kDebugMode) {
        print('🚪 Logging out user...');
      }

      // Delete FCM token from backend before logout
      try {
        await FCMService().deleteTokenFromBackend();
        await FCMService().clearLocalToken();
        if (kDebugMode) {
          print('✅ FCM token cleaned up');
        }
      } catch (fcmError) {
        if (kDebugMode) {
          print('⚠️ FCM token cleanup failed (non-critical): $fcmError');
        }
      }

      // Revoke backend token
      try {
        await ApiService().post('/auth/logout', {});
        if (kDebugMode) {
          print('✅ Backend token revoked');
        }
      } catch (authError) {
        if (kDebugMode) {
          print(
            '⚠️ Backend token revocation failed (non-critical): $authError',
          );
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);

      // Track logout in analytics
      await AnalyticsService.logLogout();

      // Clear local API cache
      await LocalCacheService.clearAll();

      // Set force logout flag untuk mencegah loop
      await prefs.setBool('force_logout', true);

      if (kDebugMode) {
        print('✅ Logout completed and cache cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during logout: $e');
      }
    }
  }

  /// Full login state check: verifies token exists, user data exists, token
  /// is valid, and no force-logout flag is set. Like `Auth::check()` in Laravel
  /// with additional safeguards against stale sessions.
  Future<bool> isLoggedIn() async {
    try {
      // Check force logout flag first
      final prefs = await SharedPreferences.getInstance();
      final forceLogout = prefs.getBool('force_logout') ?? false;
      if (forceLogout) {
        if (kDebugMode) {
          print('🚫 Force logout flag detected');
        }
        await prefs.setBool('force_logout', false);
        return false;
      }

      final token = await getToken();
      final userData = await getUserData();

      // Check if both token and user data exist
      if (token == null || token.isEmpty || userData == null) {
        if (kDebugMode) {
          print(
            '🔐 Incomplete login state: token=${token != null}, user=${userData != null}',
          );
        }
        return false;
      }

      // Check token validity
      final isValid = await isTokenValid();

      if (kDebugMode) {
        print('🔐 Login status: $isValid');
      }

      return isValid;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Login check error: $e');
      }
      return false;
    }
  }

  // Method untuk clear force logout flag (dipanggil setelah login sukses)
  Future<void> clearForceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('force_logout', false);
    if (kDebugMode) {
      print('✅ Force logout flag cleared');
    }
  }
}
