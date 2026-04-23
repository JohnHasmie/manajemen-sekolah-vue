// Token management for FCM
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Manages FCM token lifecycle (fetch, save, send, delete)
class FCMTokenManager {
  final FirebaseMessaging _firebaseMessaging;

  FCMTokenManager(this._firebaseMessaging);

  String? _token;
  String? get token => _token;

  /// Get or fetch the FCM token
  /// Returns null if APNS token unavailable (iOS simulator)
  Future<String?> getToken() async {
    try {
      final apnsToken = await _firebaseMessaging.getAPNSToken();
      if (apnsToken == null) {
        AppLogger.warning(
          'fcm',
          'APNS token not available (simulator?), skipping FCM token',
        );
        return null;
      }

      _token = await _firebaseMessaging.getToken();
      AppLogger.debug('fcm', 'FCM Token: $_token');
      return _token;
    } catch (e) {
      AppLogger.warning('fcm', 'Could not get FCM token: $e');
      return null;
    }
  }

  /// Save token to local preferences
  Future<void> saveTokenLocally(String token) async {
    try {
      _token = token;
      final prefs = PreferencesService();
      await prefs.setString('fcm_token', token);
    } catch (e) {
      AppLogger.error('fcm', 'Error saving token locally: $e');
    }
  }

  /// Retrieve saved token from preferences
  Future<String?> getSavedToken() async {
    try {
      final prefs = PreferencesService();
      return prefs.getString('fcm_token');
    } catch (e) {
      AppLogger.error('fcm', 'Error getting saved token: $e');
      return null;
    }
  }

  /// Clear token from local preferences
  Future<void> clearToken() async {
    try {
      final prefs = PreferencesService();
      await prefs.remove('fcm_token');
      _token = null;
    } catch (e) {
      AppLogger.error('fcm', 'Error clearing local token: $e');
    }
  }

  /// Send token to backend API
  Future<bool> sendToBackend(String token) async {
    try {
      AppLogger.debug('fcm', 'Sending FCM token to backend...');

      final prefs = PreferencesService();
      final authToken = prefs.getString('token');
      if (authToken == null) {
        throw Exception('No auth token found');
      }

      await dioClient.post(
        ApiEndpoints.fcmTokenEndpoint,
        data: {'token': token, 'device_type': 'mobile'},
      );

      AppLogger.info('fcm', 'FCM token sent to backend successfully');
      return true;
    } catch (e) {
      AppLogger.error('fcm', 'Error sending FCM token to backend: $e');
      return false;
    }
  }

  /// Delete token from backend API
  Future<void> deleteFromBackend() async {
    try {
      if (_token == null) return;

      AppLogger.debug('fcm', 'Deleting FCM token from backend...');

      final prefs = PreferencesService();
      final authToken = prefs.getString('token');
      if (authToken == null) {
        throw Exception('No auth token found');
      }

      await dioClient.delete(
        ApiEndpoints.fcmTokenEndpoint,
        data: {'token': _token!},
      );

      AppLogger.info('fcm', 'FCM token deleted from backend');
    } catch (e) {
      AppLogger.error('fcm', 'Error deleting FCM token from backend: $e');
    }
  }

  /// Force refresh token by deleting and requesting new one
  Future<String?> forceRefresh() async {
    try {
      AppLogger.debug('fcm', 'Force refreshing FCM token...');

      // Delete old token
      await _firebaseMessaging.deleteToken();

      // Get new token
      final newToken = await getToken();
      if (newToken == null) return null;

      // Save and send
      await saveTokenLocally(newToken);
      await sendToBackend(newToken);

      return newToken;
    } catch (e) {
      AppLogger.error('fcm', 'Error force refreshing token: $e');
      return null;
    }
  }

  /// Listen to token refresh events
  void listenToRefreshEvents(Function(String) onTokenRefreshed) {
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      AppLogger.debug('fcm', 'FCM Token refreshed: $newToken');
      await saveTokenLocally(newToken);
      onTokenRefreshed(newToken);
    });
  }
}
