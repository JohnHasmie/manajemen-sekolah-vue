/// class_activity_export_helper.dart - Export and notification operations for
/// class activities.
library;

import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Helper class for export and notification operations on class activities.
class ExportHelper {
  /// Exports class activities to a downloadable format.
  /// Like Laravel's export endpoint that returns a file response.
  /// Returns raw Response so the caller can handle the file bytes.
  Future<Response> exportClassActivities(
    List<Map<String, dynamic>> activities,
  ) async {
    final response = await dioClient.post<List<int>>(
      '/export/class-activities',
      data: {'activities': activities},
      options: Options(responseType: ResponseType.bytes),
    );
    return response;
  }

  /// Gets the count of unread class activities for badge display.
  /// Like a Laravel notification count endpoint. Returns 0 on error.
  Future<int> getUnreadCount() async {
    try {
      final response = await dioClient.get('/class-activity/unread-count');

      final result = response.data;
      if (result is Map && result.containsKey('count')) {
        return int.tryParse(result['count'].toString()) ?? 0;
      }
      return 0;
    } catch (e) {
      AppLogger.error('class_activity', e);
      return 0;
    }
  }

  /// Marks specific class activities as read (like Laravel's notification
  /// markAsRead).
  /// [activityIds] - List of activity UUIDs to mark. Returns true on
  /// success.
  Future<bool> markAsRead(List<String> activityIds) async {
    try {
      final response = await dioClient.post(
        '/class-activity/mark-read',
        data: {'activity_ids': activityIds},
      );

      final result = response.data;
      return result is Map && result['success'] == true;
    } catch (e) {
      AppLogger.error('class_activity', e);
      return false;
    }
  }
}
