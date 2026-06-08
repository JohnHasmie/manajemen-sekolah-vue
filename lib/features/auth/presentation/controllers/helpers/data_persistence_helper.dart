import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/services/secure_storage_service.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/services/analytics_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/auth/domain/models/user.dart';

class DataPersistenceHelper {
  /// Hook that registers the device's current FCM token with the backend.
  ///
  /// Defaults to [FCMService.registerTokenWithBackend]. Exposed as an
  /// overridable function so tests can assert that login success triggers
  /// FCM registration without standing up Firebase plugins. Production code
  /// never reassigns this.
  static Future<bool> Function() registerFcmToken =
      () => FCMService().registerTokenWithBackend();

  Future<void> saveLoginData(Map<String, dynamic> responseData) async {
    final secureStorage = SecureStorageService();
    // Token may be null when the backend reuses the existing token (e.g.
    // school/role switch). In that case keep the previously stored token.
    final token = responseData['token'];
    if (token != null) {
      await secureStorage.saveToken(token.toString());
    }
    await secureStorage.saveUserData(
      responseData['user'] as Map<String, dynamic>,
    );
    await secureStorage.setForceLogout(false);

    final prefs = PreferencesService();
    if (token != null) {
      await prefs.setString('token', token.toString());
    }
    await prefs.setString('user', json.encode(responseData['user']));
    await prefs.setBool('force_logout', false);

    _logUserAndAnalytics(responseData);
    sendFcmTokenAsync();
  }

  void _logUserAndAnalytics(Map<String, dynamic> responseData) {
    final userMap = responseData['user'] as Map<String, dynamic>?;
    if (userMap != null) {
      final user = User.fromJson(userMap);
      AnalyticsService.setUser(
        userId: user.id,
        email: user.email,
        role: user.role,
        name: user.name,
        schoolName: user.schoolName ?? '',
      );
      AnalyticsService.logLogin(
        method: 'app_login',
        email: user.email,
        role: user.role,
      );
    }
  }

  /// Register the device's current FCM token with the backend on login
  /// success.
  ///
  /// Fire-and-forget so it never blocks the login UX. The heavy lifting
  /// (init guard, token resolution, error handling) lives in
  /// [FCMService.registerTokenWithBackend], which is fully resilient and
  /// never throws. This runs AFTER the bearer token has been persisted
  /// above, so the POST /fcm/token carries the auth header.
  ///
  /// FCM tokens are stable per app-install (they don't rotate on
  /// re-login), so without this the server keeps whatever token it last
  /// saw — which can be stale. The backend dedupes on insert, so
  /// re-registering on every login self-heals stale rows.
  @visibleForTesting
  void sendFcmTokenAsync() {
    Future(() async {
      try {
        await registerFcmToken();
      } catch (e) {
        AppLogger.error('login', 'Failed to send FCM token: $e');
      }
    });
  }
}
