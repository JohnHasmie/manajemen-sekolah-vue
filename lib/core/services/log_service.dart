/// log_service.dart - Sends client-side error logs to a centralized logging backend.
/// Like Laravel's Log facade sending to a remote log aggregator / Vue's error handler.
///
/// This service posts error details (message, stack trace, user context, platform)
/// to a separate logging microservice running on port 5009. It is fire-and-forget:
/// failures to log are silently caught to avoid cascading errors.
///
/// Similar to how you might use Sentry or Bugsnag in a Laravel/Vue app,
/// but with a custom backend endpoint.
///
/// NOTE: This service uses its own Dio instance (not the global dioClient)
/// because it targets a different microservice on port 5009, not the main API.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

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
  static Future<void> sendError(dynamic error, StackTrace? stackTrace) async {
    await _log('error', error.toString(), trace: stackTrace?.toString());
  }

  /// Logs information.
  void info(String message) {
    AppLogger.info('app', message);
    _log('info', message);
  }

  /// Logs a warning.
  void warning(String message) {
    AppLogger.warning('app', message);
    _log('warning', message);
  }

  /// Logs an error.
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    AppLogger.error('app', '$message: $error');
    _log('error', '$message: ${error?.toString() ?? ""}', trace: stackTrace?.toString());
  }

  static Future<void> _log(String level, String message, {String? trace}) async {
    try {
      final prefs = PreferencesService();
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
        'level': level,
        'message': message,
        'trace': trace,
        'user_id': userId,
        'user_email': userEmail,
        'meta': {
          'timestamp': DateTime.now().toIso8601String(),
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        },
      };

      final token = prefs.getString('token');

      final logDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      await logDio.post(_logApiUrl, data: body);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Connection refused') || msg.contains('SocketException')) {
        return;
      }
    }
  }
}
