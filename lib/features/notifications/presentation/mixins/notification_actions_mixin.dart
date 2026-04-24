import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/notifications/presentation/controllers/notification_controller.dart';

/// Mixin for notification API operations (load, mark read, delete).
mixin NotificationActionsMixin {
  WidgetRef get ref;
  String get role;

  Future<void> loadData() async {
    await ref.read(notificationProvider.notifier).fetchNotifications(role);
  }

  Future<void> markAsRead(String id) async {
    await ref.read(notificationProvider.notifier).markAsRead(id);
  }

  Future<void> deleteNotification(String id) async {
    await ref.read(notificationProvider.notifier).deleteNotification(id);
  }

  Future<void> markAllRead() async {
    await ref.read(notificationProvider.notifier).markAllRead();
  }
}
