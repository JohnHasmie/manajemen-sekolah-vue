import 'package:manajemensekolah/features/notifications/domain/models/notification_item.dart';

/// Mixin for unread state detection logic.
///
/// The heterogeneous `is_read` normalization (bool / int / missing) now lives
/// in [NotificationItem._standardizeJson]; this mixin simply reads the derived
/// [NotificationItem.isUnread] flag.
mixin NotificationReadStateMixin {
  bool isUnread(NotificationItem n) => n.isUnread;

  int unreadCount(List<NotificationItem> notifications) =>
      notifications.where(isUnread).length;

  bool hasUnread(List<NotificationItem> notifications) =>
      notifications.any(isUnread);
}
