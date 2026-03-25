/// app_logger.dart - Centralized logging utility for the app.
/// Like Laravel's `Log::info()`, `Log::error()`, `Log::debug()` facade.
///
/// Replaces scattered `if (kDebugMode) print(...)` calls across 68+ files.
/// Only logs in debug mode — zero overhead in release builds.
library;

import 'package:flutter/foundation.dart';

/// Centralized logger. All methods are no-ops in release builds.
class AppLogger {
  AppLogger._();

  /// Debug-level log. For development tracing.
  /// Like `Log::debug()` in Laravel.
  static void debug(String tag, [String? message]) {
    if (kDebugMode) {
      print('🔍 [$tag] ${message ?? ''}');
    }
  }

  /// Info-level log. For notable events (login, navigation, data loaded).
  /// Like `Log::info()` in Laravel.
  static void info(String tag, [String? message]) {
    if (kDebugMode) {
      print('ℹ️ [$tag] ${message ?? ''}');
    }
  }

  /// Warning-level log. For non-critical issues.
  /// Like `Log::warning()` in Laravel.
  static void warning(String tag, [String? message]) {
    if (kDebugMode) {
      print('⚠️ [$tag] ${message ?? ''}');
    }
  }

  /// Error-level log. For exceptions and failures.
  /// Like `Log::error()` in Laravel.
  static void error(String tag, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('❌ [$tag] $error');
      if (stackTrace != null) {
        print(stackTrace);
      }
    }
  }

  /// Network-level log. For API calls and responses.
  static void network(String method, String url, [int? statusCode]) {
    if (kDebugMode) {
      final status = statusCode != null ? ' → $statusCode' : '';
      print('📡 $method $url$status');
    }
  }
}
