import 'dart:convert';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/services/secure_storage_service.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/services/analytics_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/auth/domain/models/user.dart';

class DataPersistenceHelper {
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
    _sendFcmTokenAsync();
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

  void _sendFcmTokenAsync() {
    Future(() async {
      try {
        final fcmService = FCMService();
        final token = fcmService.fcmToken ?? await fcmService.getSavedToken();
        if (token != null) {
          await fcmService.sendTokenToBackend(token);
        }
      } catch (e) {
        AppLogger.error('login', 'Failed to send FCM token: $e');
      }
    });
  }
}
