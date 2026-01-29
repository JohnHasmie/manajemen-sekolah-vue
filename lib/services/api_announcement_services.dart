import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiAnnouncementService {
  static String get baseUrl => ApiService.baseUrl;

  // Helper to safely print response bodies for debugging (truncated)
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

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    // If token missing, trigger global logout/redirect to login so app
    // doesn't stay on an error screen without navigating the user.
    if (token == null || token.isEmpty) {
      // Use ApiService helper to clear state and redirect to login
      try {
        await ApiService.logoutWithMessage(
          'Authentication required. Please login.',
        );
      } catch (e) {
        // ignore navigation errors here
      }

      // Return headers without Authorization to avoid sending 'Bearer null'
      return {'Content-Type': 'application/json'};
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

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

      // If unauthorized or forbidden -> force logout + redirect
      if (response.statusCode == 401 || response.statusCode == 403) {
        try {
          ApiService.logoutWithMessage(
            'Session expired or unauthorized. Please login again.',
          );
        } catch (_) {}
      }

      throw Exception(
        serverMessage ?? 'Request failed with status: ${response.statusCode}',
      );
    }
  }

  // Get Filter Options for Announcement Filters
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

  // Get Announcements with Pagination & Filters (Recommended)
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

  // Legacy method (keep for backward compatibility)
  // Now handles paginated response from backend
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

  // Create Announcement (with optional file)
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

  // Update Announcement (with optional file)
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
