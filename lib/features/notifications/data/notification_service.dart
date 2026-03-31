/// api_notification_service.dart - Handles push notification and in-app notification management.
/// Like Laravel's Notification system / Vue's notification store module.
///
/// Manages fetching, reading, and deleting user notifications.
/// Uses dioClient directly for all HTTP calls -- the AuthInterceptor and
/// ErrorInterceptor handle headers and error responses automatically.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';

/// Service for notification-related API calls.
/// Uses instance methods for API compatibility with existing callers.
///
/// In Vue terms, this is like a Pinia store that wraps an Axios instance
/// for all notification endpoints.
class ApiNotificationService {
  /// Fetches paginated notifications, optionally filtered by user role.
  /// Like `Notification::where('user_id', auth()->id)->paginate()` in Laravel.
  /// [page] - Page number for pagination (server-side).
  /// [role] - Optional role filter (e.g., 'guru', 'siswa', 'admin').
  /// Returns the 'data' array from the paginated response.
  Future<List<dynamic>> getNotifications({int page = 1, String? role}) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        if (role != null) 'role': role,
      };
      final response = await dioClient.get(
        '/notifications',
        queryParameters: queryParams,
      );
      return response.data['data'] ?? [];
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches today's schedule as notification items.
  /// Like a Laravel endpoint that returns a student/teacher's schedule for today.
  /// Returns an empty list on error (fail-safe, does not rethrow).
  Future<List<dynamic>> getTodaySchedule() async {
    try {
      final response = await dioClient.get('/notifications/today-schedule');
      return response.data;
    } catch (e) {
      return [];
    }
  }

  /// Marks a single notification as read by deleting it.
  /// The API exposes DELETE /notifications/{id} — there is no PUT/PATCH route.
  Future<void> markAsRead(String id) async {
    try {
      await dioClient.delete('/notifications/$id');
    } catch (e) {
      rethrow;
    }
  }

  /// Marks all notifications as read for the current user.
  /// Like `auth()->user()->unreadNotifications->markAsRead()` in Laravel.
  Future<void> markAllRead() async {
    try {
      await dioClient.post('/notifications/mark-all-read', data: {});
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes a notification by ID.
  /// Like `Notification::find($id)->delete()` in Laravel.
  Future<void> deleteNotification(String id) async {
    try {
      await dioClient.delete('/notifications/$id');
    } catch (e) {
      rethrow;
    }
  }
}
