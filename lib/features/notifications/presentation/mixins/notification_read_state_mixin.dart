/// Mixin for unread state detection logic.
mixin NotificationReadStateMixin {
  bool isUnread(dynamic n) {
    if (n is! Map<String, dynamic>) return true;
    if (n['is_read'] is bool) return !(n['is_read'] as bool);
    if (n['is_read'] is int) return n['is_read'] != 1;
    return true;
  }

  int unreadCount(List<dynamic> notifications) =>
      notifications.where(isUnread).length;

  bool hasUnread(List<dynamic> notifications) => notifications.any(isUnread);
}
