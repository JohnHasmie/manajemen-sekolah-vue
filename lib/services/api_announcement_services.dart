/// api_announcement_services.dart - Handles school announcement CRUD with file uploads.
/// Like Laravel's AnnouncementController / Vue's announcement store module.
///
/// Supports paginated listing, filtering by priority/role/status,
/// creating and updating announcements with optional file attachments
/// (multipart upload). Uses Laravel's `_method=PUT` trick for file updates.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:manajemensekolah/services/api_services.dart';

/// Service for announcement-related API calls.
/// Like a Laravel Resource Controller (index, store, update) combined with
/// a Vue composable/store that handles announcement state.
///
/// Key patterns:
/// - Multipart file uploads (similar to Laravel's `$request->file('file')`)
/// - Paginated responses transformed from Laravel's `LengthAwarePaginator`
/// - 401/403 error handling triggers automatic logout (like Laravel middleware)
class ApiAnnouncementService {
  /// Base URL from central config. Like `config('app.url')` in Laravel.
  static String get baseUrl => ApiService.baseUrl;

  /// Safely prints truncated response bodies for debugging.
  /// Only active in debug mode -- like Laravel's `Log::debug()`.
  static void _debugResponse(http.Response response, {String? label}) {
    try {
      final raw = response.body;
      final safe = raw.length > 1000
          ? '${raw.substring(0, 1000)}... [truncated]'
          : raw;
      if (kDebugMode) {
        print(
          '${label ?? 'HTTP Response'} - Status: ${response.statusCode} - Body: $safe',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error printing response debug: $e');
      }
    }
  }

  /// Auth headers with Bearer token. Like Laravel's `Http::withToken()`.
  static Future<Map<String, String>> _getHeaders() => ApiService.getHeaders();

  /// Parses JSON response, handles 401/403 with auto-logout.
  /// Like a Laravel middleware that catches auth exceptions globally,
  /// or an Axios interceptor that redirects to /login on 401.
  static dynamic _handleResponse(http.Response response) {
    dynamic responseBody;
    try {
      responseBody = json.decode(response.body);
    } catch (e) {
      // If server returns non-json (or empty), log raw body for debugging
      try {
        final raw = response.body;
        final safe = raw.length > 1000
            ? '${raw.substring(0, 1000)}... [truncated]'
            : raw;
        if (kDebugMode) {
          print(
            '❌ Invalid JSON response (status ${response.statusCode}): $safe',
          );
        }
      } catch (_) {}

      throw Exception('Invalid server response: ${response.statusCode}');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    } else {
      final serverMessage =
          responseBody is Map && responseBody.containsKey('error')
          ? responseBody['error']
          : null;

      // If unauthorized → force logout + redirect
      if (response.statusCode == 401) {
        try {
          ApiService.logoutWithMessage(
            'Session expired or unauthorized. Please login again.',
          );
        } catch (_) {}
      } else if (response.statusCode == 403) {
        // Check if this is a school context error (SEC-18) vs real forbidden
        final is403SchoolContext =
            responseBody is Map &&
            (responseBody['error'] ?? '').toString().contains(
              'Anda tidak memiliki akses ke sekolah ini',
            );
        if (is403SchoolContext) {
          throw Exception('SCHOOL_ACCESS_DENIED: ${responseBody['error']}');
        } else {
          try {
            ApiService.logoutWithMessage(
              'Access forbidden. Please login again.',
            );
          } catch (_) {}
        }
      }

      throw Exception(
        serverMessage ?? 'Request failed with status: ${response.statusCode}',
      );
    }
  }

  /// Fetches available filter options (priority, target, status) for announcement listing.
  /// Like a Laravel endpoint that returns dropdown options for a Vue filter component.
  /// Similar to a Vuex action that populates filter select options.
  static Future<Map<String, dynamic>> getAnnouncementFilterOptions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/announcement/filter-options'),
        headers: await _getHeaders(),
      );

      // Debug print response body
      _debugResponse(response, label: 'GET /announcement/filter-options');

      final result = _handleResponse(response);

      if (result is Map<String, dynamic>) {
        return result;
      }

      // Fallback
      return {
        'success': false,
        'data': {
          'prioritas_options': [],
          'target_options': [],
          'status_options': [],
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting announcement filter options: $e');
      }
      rethrow;
    }
  }

  /// Fetches announcements with server-side pagination and filters.
  /// Like `Announcement::filter($request)->paginate()` in Laravel.
  /// Transforms Laravel's standard `LengthAwarePaginator` JSON into a
  /// frontend-friendly format with `pagination.has_next_page` etc.
  /// Similar to a Vuex action that calls `api.get('/announcements', { params })`.
  static Future<Map<String, dynamic>> getAnnouncementsPaginated({
    int page = 1,
    int limit = 10,
    String? prioritas,
    String? roleTarget,
    String? status,
    String? search,
  }) async {
    // Build query parameters
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (prioritas != null && prioritas.isNotEmpty) {
      queryParams['priority'] = prioritas;
    }
    if (roleTarget != null && roleTarget.isNotEmpty) {
      queryParams['role_target'] = roleTarget;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    // Build query string
    String queryString = Uri(queryParameters: queryParams).query;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/announcement?$queryString'),
        headers: await _getHeaders(),
      );

      // Debug response body (truncated)
      _debugResponse(response, label: 'GET /announcement?$queryString');

      final result = _handleResponse(response);

      if (result is Map<String, dynamic>) {
        // Transform Laravel Standard Pagination to Frontend Expected Format
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

      // Fallback untuk backward compatibility
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
      if (kDebugMode) {
        print('Error getting paginated announcements: $e');
      }
      rethrow;
    }
  }

  /// Legacy method to fetch all announcements as a flat list.
  /// Kept for backward compatibility -- new code should use [getAnnouncementsPaginated].
  /// Handles both old (List) and new (paginated Map) response formats.
  /// Like a deprecated Laravel route that still works but points to the new controller.
  static Future<List<dynamic>> getAnnouncements() async {
    final result = await ApiService().get('/announcement');

    // Debug legacy result shape
    try {
      if (result is List) {
        if (kDebugMode) {
          print('Legacy getAnnouncements: List with ${result.length} items');
        }
      } else if (result is Map) {
        if (kDebugMode) {
          print('Legacy getAnnouncements: Map keys = ${result.keys.toList()}');
        }
      } else {
        if (kDebugMode) {
          print(
            'Legacy getAnnouncements: unexpected type ${result.runtimeType}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error logging legacy getAnnouncements result: $e');
      }
    }

    // Handle new pagination format
    if (result is Map<String, dynamic>) {
      return result['data'] ?? [];
    }

    // Handle old format (List)
    return result is List ? result : [];
  }

  /// Creates a new announcement with optional file attachment.
  /// Uses multipart/form-data upload -- like Laravel's `$request->file('file')`
  /// on the backend. Similar to a Vue form submission with `FormData`.
  /// [data] - String key-value pairs for the announcement fields.
  /// [file] - Optional file attachment (image, PDF, doc).
  static Future<dynamic> createAnnouncement(
    Map<String, String> data,
    File? file,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/announcement'),
      );

      final headers = await _getHeaders();
      request.headers.addAll(headers);

      request.fields.addAll(data);

      if (file != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            contentType: MediaType.parse(_getMimeType(file.path)),
          ),
        );
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      _debugResponse(
        http.Response(responseBody, response.statusCode),
        label: 'POST /announcement',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(responseBody);
      } else {
        throw Exception(
          'Failed to create announcement: ${response.statusCode} - $responseBody',
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error creating announcement: $e');
      rethrow;
    }
  }

  /// Updates an existing announcement with optional new file attachment.
  /// Uses POST with `_method=PUT` (Laravel's method spoofing for multipart)
  /// because HTML/HTTP multipart forms cannot send PUT directly with files.
  /// This is the same pattern as `@method('PUT')` in a Laravel Blade form.
  static Future<dynamic> updateAnnouncement(
    String id,
    Map<String, String> data,
    File? file,
  ) async {
    try {
      // Use POST with _method=PUT for file uploads in Laravel
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/announcement/$id'),
      );

      data['_method'] = 'PUT';

      final headers = await _getHeaders();
      request.headers.addAll(headers);

      request.fields.addAll(data);

      if (file != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            contentType: MediaType.parse(_getMimeType(file.path)),
          ),
        );
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      _debugResponse(
        http.Response(responseBody, response.statusCode),
        label: 'POST (PUT) /announcement/$id',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(responseBody);
      } else {
        throw Exception(
          'Failed to update announcement: ${response.statusCode} - $responseBody',
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error updating announcement: $e');
      rethrow;
    }
  }

  /// Maps file extension to MIME type for multipart uploads.
  /// Like Laravel's `$file->getMimeType()` but done client-side.
  static String _getMimeType(String path) {
    if (path.toLowerCase().endsWith('.jpg') ||
        path.toLowerCase().endsWith('.jpeg'))
      return 'image/jpeg';
    if (path.toLowerCase().endsWith('.png')) return 'image/png';
    if (path.toLowerCase().endsWith('.pdf')) return 'application/pdf';
    if (path.toLowerCase().endsWith('.doc')) return 'application/msword';
    if (path.toLowerCase().endsWith('.docx'))
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    return 'application/octet-stream';
  }
}
