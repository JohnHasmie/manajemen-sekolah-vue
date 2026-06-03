import 'dart:io';

import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/cache_invalidation_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Service for announcement-related API calls.
/// Like a Laravel Resource Controller (index, store, update) combined with
/// a Vue composable/store that handles announcement state.
class ApiAnnouncementService {
  /// Fetches available filter options (priority, target, status) for
  /// announcement listing.
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
    if (prioritas != null && prioritas.isNotEmpty) {
      queryParams['priority'] = prioritas;
    }
    if (roleTarget != null && roleTarget.isNotEmpty) {
      queryParams['role_target'] = roleTarget;
    }
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
        AppLogger.warning(
          'announcement',
          'API response is Map but missing pagination keys. Using raw data.',
        );
        return result;
      }
      AppLogger.warning(
        'announcement',
        'API response is not a Map (type: ${result.runtimeType}). Returning as list if possible.',
      );
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
      await CacheInvalidationService.onAnnouncementChanged();
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
      await CacheInvalidationService.onAnnouncementChanged();
      return response.data;
    } catch (e) {
      AppLogger.error('announcement', 'Error updating announcement: $e');
      rethrow;
    }
  }

  String _getMimeType(String path) {
    if (path.toLowerCase().endsWith('.jpg') ||
        path.toLowerCase().endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (path.toLowerCase().endsWith('.png')) return 'image/png';
    if (path.toLowerCase().endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }
}

/// Consolidated class for Announcement API operations.
/// Holds static methods for global access (unread count, mark as read)
/// and acts as the concrete implementation of [ApiAnnouncementService].
class AnnouncementService extends ApiAnnouncementService {
  /// Fetches announcement summary grouped by month + priority.
  /// Returns list of { month_key, total, priorities: { normal: N, high: N, ...
  /// } }.
  /// Backend canonical priorities: `low` / `normal` / `high` / `urgent`
  /// (was `biasa` / `penting`).
  static Future<List<Map<String, dynamic>>> getAnnouncementSummary({
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await dioClient.get(
        '/announcements/summary',
        queryParameters: queryParams,
      );
      final result = response.data;
      if (result is Map<String, dynamic>) {
        final data = result['data'];
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      AppLogger.error('announcement', 'Error fetching summary: $e');
      return [];
    }
  }

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

  // ── Pengumuman + Acara ──────────────────────────────────────────

  /// GET /announcements/upcoming-events
  ///
  /// Returns the next N (default 3) announcements with a future
  /// event_at, scoped to the viewer's audience. Drives the dashboard
  /// "Acara Mendatang" hero strip across admin / guru / wali.
  static Future<List<Map<String, dynamic>>> fetchUpcomingEvents({
    int limit = 3,
  }) async {
    try {
      final response = await dioClient.get(
        '/announcements/upcoming-events',
        queryParameters: {'limit': limit},
      );
      final result = response.data;
      if (result is Map<String, dynamic>) {
        final data = result['data'];
        if (data is List) {
          return data.whereType<Map>().map((m) {
            return Map<String, dynamic>.from(m);
          }).toList();
        }
      }
      return const [];
    } catch (e) {
      AppLogger.error('announcement', 'Error fetching upcoming events: $e');
      return const [];
    }
  }

  /// POST /announcements/{id}/personal-reminder
  ///
  /// Stores a per-user reminder offset. Idempotent — re-posting the
  /// same offset returns the existing row. Returns the reminder row
  /// on success, null on any failure.
  static Future<Map<String, dynamic>?> setPersonalReminder({
    required String announcementId,
    required int offsetMinutes,
  }) async {
    try {
      final response = await dioClient.post(
        '/announcements/$announcementId/personal-reminder',
        data: {'offset_minutes': offsetMinutes},
      );
      final result = response.data;
      if (result is Map<String, dynamic> && result['success'] == true) {
        final data = result['data'];
        if (data is Map) return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      AppLogger.error('announcement', 'Error setting personal reminder: $e');
      return null;
    }
  }

  /// DELETE /announcements/{id}/personal-reminder/{reminderId}
  static Future<bool> deletePersonalReminder({
    required String announcementId,
    required String reminderId,
  }) async {
    try {
      final response = await dioClient.delete(
        '/announcements/$announcementId/personal-reminder/$reminderId',
      );
      final result = response.data;
      return result is Map && result['success'] == true;
    } catch (e) {
      AppLogger.error('announcement', 'Error deleting personal reminder: $e');
      return false;
    }
  }

  /// Index filter — pass through to the regular paginated endpoint
  /// with has_event / event_from / event_to params for the admin
  /// kalender screen.
  static Future<Map<String, dynamic>> fetchEventsForCalendar({
    required DateTime from,
    required DateTime to,
    int limit = 100,
  }) async {
    try {
      final response = await dioClient.get(
        '/announcements',
        queryParameters: {
          'has_event': 1,
          'event_from': from.toIso8601String(),
          'event_to': to.toIso8601String(),
          'limit': limit,
        },
      );
      final result = response.data;
      if (result is Map<String, dynamic>) {
        return result;
      }
      return {'data': []};
    } catch (e) {
      AppLogger.error('announcement', 'Error fetching kalender events: $e');
      return {'data': []};
    }
  }
}
