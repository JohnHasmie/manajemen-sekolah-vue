// Message handling for FCM service
import 'dart:convert';

import 'package:manajemensekolah/core/services/fcm_notification_router.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Handles cache invalidation for refresh_* message types
class FCMCacheInvalidator {
  static Future<void> handleRefreshMessage(Map<String, dynamic> data) async {
    final type = data['type'] as String?;

    switch (type) {
      case 'refresh_subjects':
        await LocalCacheService.clearStartingWith('subject_');
        AppLogger.debug('fcm', 'Subject cache invalidated');
      case 'refresh_teachers':
        await LocalCacheService.clearStartingWith('teacher_');
        await LocalCacheService.clearStartingWith('class_');
        AppLogger.debug('fcm', 'Teacher & Class cache invalidated');
      case 'refresh_classes':
        await LocalCacheService.clearStartingWith('class_');
        AppLogger.debug('fcm', 'Class cache invalidated');
      case 'refresh_schedules':
        await LocalCacheService.clearStartingWith('schedule_');
        AppLogger.debug('fcm', 'Schedule cache invalidated');
    }
  }

  static bool isRefreshMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    return type?.startsWith('refresh_') ?? false;
  }
}

/// Routes notification taps to appropriate screens
class FCMNotificationHandler {
  final FCMNotificationRouter _router;

  FCMNotificationHandler(this._router);

  void handleTap(Map<String, dynamic> data) {
    AppLogger.debug('fcm', 'Notification tapped with data: $data');

    // Delegate to the single routing helper. It normalizes every backend
    // `type`/`screen` variant (push payloads differ from DB rows) and
    // falls back to the in-app notification list for unknown types.
    _router.route(data);
  }

  void parseAndHandle(String? payload) {
    if (payload == null) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      handleTap(data);
    } catch (e) {
      AppLogger.error('fcm', 'Error parsing notification payload: $e');
    }
  }
}
