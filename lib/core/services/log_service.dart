/// log_service.dart - Sends client-side error logs to a centralized logging backend.
/// Like Laravel's Log facade sending to a remote log aggregator / Vue's error handler.
///
/// This service posts error details (message, stack trace, user context, platform)
/// to a separate logging microservice running on port 5009. It is fire-and-forget:
/// failures to log are silently caught to avoid cascading errors.
///
/// Similar to how you might use Sentry or Bugsnag in a Laravel/Vue app,
/// but with a custom backend endpoint.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for sending client-side error logs to the logging backend.
/// Like Laravel's `Log::error()` but sends to a remote API instead of local files.
/// Runs on a different port (5009) than the main API -- like a separate
/// microservice in your Docker Compose stack.
class LogService {
  /// Port for the logging microservice. Separate from the main API.
  static const String _logApiPort = '5009';

  /// Constructs the log API URL by taking the main API host and swapping the port.
  /// Like constructing a sibling service URL in a microservice architecture.
  static String get _logApiUrl {
    // Use the same host as the main ApiService but with port 5009
    final apiBase = ApiService.baseUrl;
    final uri = Uri.parse(apiBase);
    return '${uri.scheme}://${uri.host}:$_logApiPort/api/logs';
  }

  /// Sends an error log to the remote logging service. Fire-and-forget.
  /// [error] - The error/exception to log.
  /// [stackTrace] - Optional stack trace for debugging.
  ///
  /// Automatically includes user context (ID, email) from SharedPreferences,
  /// platform info (Android/iOS/web), and a timestamp.
  /// Like calling `Log::error($message, ['user' => auth()->user()])` in Laravel.
  ///
  /// Side effects: HTTP POST to logging service. Silently fails on error
  /// (5-second timeout) to avoid breaking the app.
  static Future<void> sendError(dynamic error, StackTrace? stackTrace) async {
    try {
      if (kDebugMode) {
        print('📤 Sending error log to backend: $error');
      }

      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      String? userId;
      String? userEmail;

      if (userJson != null) {
        try {
          final user = json.decode(userJson);
          userId = user['id']?.toString();
          userEmail = user['email'];
        } catch (_) {}
      }

      final body = {
        'source': kIsWeb
            ? 'frontend_web'
            : (Platform.isAndroid ? 'frontend_android' : 'frontend_ios'),
        'level': 'error',
        'message': error.toString(),
        'trace': stackTrace?.toString(),
        'user_id': userId,
        'user_email': userEmail,
        'meta': {
          'timestamp': DateTime.now().toIso8601String(),
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        },
      };

      final token = prefs.getString('token');

      await http
          .post(
            Uri.parse(_logApiUrl),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to send error log: $e');
      }
    }
  }
}
