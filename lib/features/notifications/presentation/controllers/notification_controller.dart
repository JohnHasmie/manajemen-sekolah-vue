import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/notifications/data/notification_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

class NotificationNotifier extends AsyncNotifier<List<dynamic>> {
  late final ApiNotificationService _apiService;

  @override
  Future<List<dynamic>> build() async {
    _apiService = getIt<ApiNotificationService>();
    // Default to fetching for the current role if we can determine it,
    // but typically we pass it or use a separate provider for current role.
    // For now, we'll keep it flexible.
    return [];
  }

  Future<void> fetchNotifications(String role) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await _apiService.getNotifications(role: role);
    });
  }

  Future<void> markAsRead(String id) async {
    try {
      await _apiService.markAsRead(id);
      final currentList = state.value ?? [];
      state = AsyncValue.data(
        currentList.where((n) => n['id'].toString() != id).toList(),
      );
    } catch (e) {
      AppLogger.error('notification_controller', 'Failed to mark as read: $e');
      // We don't necessarily want to change the state to error for a single
      // item failure
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _apiService.deleteNotification(id);
      final currentList = state.value ?? [];
      state = AsyncValue.data(
        currentList.where((n) => n['id'].toString() != id).toList(),
      );
    } catch (e) {
      AppLogger.error(
        'notification_controller',
        'Failed to delete notification: $e',
      );
    }
  }

  Future<void> markAllRead() async {
    try {
      await _apiService.markAllRead();
      state = const AsyncValue.data([]);
    } catch (e) {
      AppLogger.error(
        'notification_controller',
        'Failed to mark all as read: $e',
      );
    }
  }
}

final notificationProvider =
    AsyncNotifierProvider<NotificationNotifier, List<dynamic>>(
      NotificationNotifier.new,
      isAutoDispose: true,
    );
