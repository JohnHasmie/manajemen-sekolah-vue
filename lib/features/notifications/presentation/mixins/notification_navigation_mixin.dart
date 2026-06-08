import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/services/fcm_notification_router.dart';
import 'package:manajemensekolah/features/notifications/domain/models/notification_item.dart';

/// Mixin for notification tap-to-navigate logic (in-app inbox list).
///
/// Both notification entry points — a tapped PUSH and a tapped IN-APP list
/// row — now funnel through the same [FCMNotificationRouter] so they always
/// land on the same destination. Previously this mixin had its own divergent
/// switch (only handled `bill`/`class_activity`/`announcement`, always pushed
/// the *Parent* screen regardless of role, and pushed onto the current
/// navigator instead of the correct tab), which is why in-app taps did not
/// land on the right page.
mixin NotificationNavigationMixin {
  BuildContext get context;
  String get role;

  /// Shared router instance — the single source of truth for
  /// "notification → destination" (see fcm_notification_router.dart).
  final FCMNotificationRouter _router = FCMNotificationRouter();

  void handleTap(NotificationItem notif) {
    // Rebuild the minimal `data` map the router understands from the tapped
    // in-app row. The router normalizes the `type` (DB rows and FCM pushes
    // use different strings) and resolves the role itself, so this works
    // identically to a push tap.
    _router.route(<String, dynamic>{'type': notif.type});
  }
}
