import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Dedicated service for Announcement API operations.
/// Extracted from the monolithic ApiService to improve modularity.
class AnnouncementService {
  /// Gets the count of unread announcements for badge display.
  /// Returns 0 on error.
  static Future<int> getUnreadAnnouncementCount() async {
    try {
      final response = await dioClient.get(ApiEndpoints.announcementUnreadCount);
      final data = response.data;
      return data['count'] ?? 0;
    } catch (e) {
      AppLogger.error('api', 'Error fetching unread count: $e');
      return 0;
    }
  }

  /// Marks announcements as read by their IDs.
  static Future<bool> markAnnouncementRead(List<String> ids) async {
    try {
      await dioClient.post(ApiEndpoints.announcementMarkRead, data: {'ids': ids});
      return true;
    } catch (e) {
      AppLogger.error('api', 'Error marking announcement read: $e');
      return false;
    }
  }
}
