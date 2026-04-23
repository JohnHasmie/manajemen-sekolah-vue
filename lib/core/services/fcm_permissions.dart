// Permission and initialization for FCM
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Handles FCM permission requests and initialization
class FCMPermissions {
  final FirebaseMessaging _firebaseMessaging;

  FCMPermissions(this._firebaseMessaging);

  /// Request notification permissions from user
  /// Returns true if permission granted (authorized or provisional)
  Future<bool> requestPermission() async {
    try {
      AppLogger.debug('fcm', 'Requesting notification permissions...');

      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      AppLogger.info(
        'fcm',
        'Permission status: ${settings.authorizationStatus}',
      );

      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      AppLogger.error('fcm', 'Error requesting permissions: $e');
      return false;
    }
  }
}
