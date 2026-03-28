import 'dart:io';

import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Service for announcement-related API calls.
/// Like a Laravel Resource Controller (index, store, update) combined with
/// a Vue composable/store that handles announcement state.
class ApiAnnouncementService {
  /// Fetches available filter options (priority, target, status) for announcement listing.
  Future<Map<String, dynamic>> getAnnouncementFilterOptions() async {
    try {
      final response = await dioClient.get('/announcement/filter-options');
      final result = response.data;
      if (result is Map<String, dynamic>) return result;
      return {
        'success': false,
        'data': {
          'prioritas_options': [],
          'target_options': [],
          'status_options': [],
        },
      };
    } catch (e) {
      AppLogger.error(
        'announcement',
        'Error getting announcement filter options: $e',
      );
      rethrow;
    }
  }

  /// Fetches announcements with server-side pagination and filters.
  Future<Map<String, dynamic>> getAnnouncementsPaginated({
    int page = 1,
    int limit = 10,
    String? prioritas,
    String? roleTarget,
    String? status,
    String? search,
  }) async {
    final Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (prioritas != null && prioritas.isNotEmpty)
      queryParams['priority'] = prioritas;
    if (roleTarget != null && roleTarget.isNotEmpty)
      queryParams['role_target'] = roleTarget;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final String queryString = Uri(queryParameters: queryParams).query;

    try {
      final response = await dioClient.get('/announcement?$queryString');
      final result = response.data;
      if (result is Map<String, dynamic>) {
        if (result.containsKey('data') && result.containsKey('current_page')) {
          return {
            'success': true,
            'data': result['data'],
            'pagination': {
              'total_items': result['total'] ?? 0,
              'total_pages': result['last_page'] ?? 1,
              'current_page': result['current_page'] ?? 1,
              'per_page': result['per_page'] ?? limit,
              'has_next_page':
                  (result['current_page'] ?? 1) < (result['last_page'] ?? 1),
              'has_prev_page': (result['current_page'] ?? 1) > 1,
            },
          };
        }
        return result;
      }
      return {
        'success': true,
        'data': result is List ? result : [],
        'pagination': {
          'total_items': result is List ? result.length : 0,
          'total_pages': 1,
          'current_page': 1,
          'per_page': limit,
          'has_next_page': false,
          'has_prev_page': false,
        },
      };
    } catch (e) {
      AppLogger.error(
        'announcement',
        'Error getting paginated announcements: $e',
      );
      rethrow;
    }
  }

  /// Legacy method for backward compatibility.
  Future<List<dynamic>> getAnnouncements() async {
    final result = await ApiService().get('/announcement');
    if (result is Map<String, dynamic>) return result['data'] ?? [];
    return result is List ? result : [];
  }

  /// Creates a new announcement with optional file attachment.
  Future<dynamic> createAnnouncement(
    Map<String, String> data,
    File? file,
  ) async {
    try {
      final Map<String, dynamic> formMap = Map<String, dynamic>.from(data);
      if (file != null) {
        formMap['file'] = await MultipartFile.fromFile(
          file.path,
          contentType: DioMediaType.parse(_getMimeType(file.path)),
        );
      }
      final formData = FormData.fromMap(formMap);
      final response = await dioClient.post('/announcement', data: formData);
      return response.data;
    } catch (e) {
      AppLogger.error('announcement', 'Error creating announcement: $e');
      rethrow;
    }
  }

  /// Updates an existing announcement.
  Future<dynamic> updateAnnouncement(
    String id,
    Map<String, String> data,
    File? file,
  ) async {
    try {
      data['_method'] = 'PUT';
      final Map<String, dynamic> formMap = Map<String, dynamic>.from(data);
      if (file != null) {
        formMap['file'] = await MultipartFile.fromFile(
          file.path,
          contentType: DioMediaType.parse(_getMimeType(file.path)),
        );
      }
      final formData = FormData.fromMap(formMap);
      final response = await dioClient.post(
        '/announcement/$id',
        data: formData,
      );
      return response.data;
    } catch (e) {
      AppLogger.error('announcement', 'Error updating announcement: $e');
      rethrow;
    }
  }

  String _getMimeType(String path) {
    if (path.toLowerCase().endsWith('.jpg') ||
        path.toLowerCase().endsWith('.jpeg'))
      return 'image/jpeg';
    if (path.toLowerCase().endsWith('.png')) return 'image/png';
    if (path.toLowerCase().endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }
}

/// Consolidated class for Announcement API operations.
/// Holds static methods for global access (unread count, mark as read)
/// and acts as the concrete implementation of [ApiAnnouncementService].
class AnnouncementService extends ApiAnnouncementService {
  /// Gets the count of unread announcements for badge display.
  static Future<int> getUnreadAnnouncementCount() async {
    try {
      final response = await dioClient.get(
        ApiEndpoints.announcementUnreadCount,
      );
      return response.data['count'] ?? 0;
    } catch (e) {
      AppLogger.error('api', 'Error fetching unread count: $e');
      return 0;
    }
  }

  /// Marks announcements as read by their IDs.
  static Future<bool> markAnnouncementRead(List<String> ids) async {
    try {
      await dioClient.post(
        ApiEndpoints.announcementMarkRead,
        data: {'ids': ids},
      );
      return true;
    } catch (e) {
      AppLogger.error('api', 'Error marking announcement read: $e');
      return false;
    }
  }
}
