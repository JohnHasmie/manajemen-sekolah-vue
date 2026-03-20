/// api_notification_service.dart - Handles push notification and in-app notification management.
/// Like Laravel's Notification system / Vue's notification store module.
///
/// Manages fetching, reading, and deleting user notifications.
/// Unlike most other services, this uses instance methods (not static)
/// because it holds an [ApiService] instance -- similar to injecting
/// a service via Laravel's constructor DI.
library;

import 'package:manajemensekolah/services/api_services.dart';

/// Service for notification-related API calls.
/// Uses instance methods with a private [_apiService] -- like a Laravel service
/// class that receives `ApiService` via constructor injection.
///
/// In Vue terms, this is like a Pinia store that wraps an Axios instance
/// for all notification endpoints.
class ApiNotificationService {
  /// The underlying HTTP client instance. Like injecting `Http` in a Laravel service.
  final ApiService _apiService = ApiService();

  /// Fetches paginated notifications, optionally filtered by user role.
  /// Like `Notification::where('user_id', auth()->id)->paginate()` in Laravel.
  /// [page] - Page number for pagination (server-side).
  /// [role] - Optional role filter (e.g., 'guru', 'siswa', 'admin').
  /// Returns the 'data' array from the paginated response.
  Future<List<dynamic>> getNotifications({int page = 1, String? role}) async {
    try {
      final url = role != null
          ? '/notifications?page=$page&role=$role'
          : '/notifications?page=$page';
      final response = await _apiService.get(url);
      return response['data'] ?? [];
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches today's schedule as notification items.
  /// Like a Laravel endpoint that returns a student/teacher's schedule for today.
  /// Returns an empty list on error (fail-safe, does not rethrow).
  Future<List<dynamic>> getTodaySchedule() async {
    try {
      return await _apiService.get('/notifications/today-schedule');
    } catch (e) {
      return [];
    }
  }

  /// Marks a single notification as read by ID.
  /// Like `$notification->markAsRead()` in Laravel's Notification system.
  Future<void> markAsRead(String id) async {
    try {
      await _apiService.put('/notifications/$id', {'is_read': true});
    } catch (e) {
      rethrow;
    }
  }

  /// Marks all notifications as read for the current user.
  /// Like `auth()->user()->unreadNotifications->markAsRead()` in Laravel.
  Future<void> markAllRead() async {
    try {
      await _apiService.post('/notifications/mark-all-read', {});
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes a notification by ID.
  /// Like `Notification::find($id)->delete()` in Laravel.
  Future<void> deleteNotification(String id) async {
    try {
      await _apiService.delete('/notifications/$id');
    } catch (e) {
      rethrow;
    }
  }
}
