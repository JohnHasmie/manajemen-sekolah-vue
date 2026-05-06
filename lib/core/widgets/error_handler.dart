// Global error handler for the application.
//
// Like Laravel's `App\Exceptions\Handler` class that catches all unhandled
// exceptions. In Laravel you override `render()` and `report()` methods;
// here we hook into Flutter's `FlutterError.onError` and Dart's
// `PlatformDispatcher.onError` to catch and log all uncaught errors.
// Also broadcasts errors via a Stream (like Laravel's event system).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:manajemensekolah/core/services/log_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Singleton global error handler. Like Laravel's `App\Exceptions\Handler`
/// combined with a logging middleware.
///
/// Uses the singleton pattern (like Laravel's `app()` container binding).
/// - [setupErrorHandling] - registers error handlers (like `Handler::register()`)
/// - [errorStream] - broadcasts errors (like Laravel Events / broadcasting)
/// - [_logError] - logs to backend (like `Handler::report()` sending to Sentry)
/// - [dispose] - cleans up the stream controller
class AppErrorHandler {
  static final AppErrorHandler _instance = AppErrorHandler._internal();
  factory AppErrorHandler() => _instance;
  AppErrorHandler._internal();

  static final StreamController<Exception> _errorController =
      StreamController<Exception>.broadcast();
  static Stream<Exception> get errorStream => _errorController.stream;

  /// Registers global error handlers for Flutter and Dart runtime errors.
  /// Like `Handler::register()` in Laravel where you define how to
  /// report and render exceptions. Call this once at app startup.
  static void setupErrorHandling() {
    // Handle Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exception.toString();

      // Skip debug-only semantics assertions that cascade infinitely.
      // The parentDataDirty / !_debugUltimatePreviousSiblingOf errors come
      // from Stack(clipBehavior: Clip.none) + Positioned in dashboard
      // heroes — harmless in release, but in debug they re-trigger on
      // every frame and flood the error stream + log service.
      if (kDebugMode &&
          (msg.contains('parentDataDirty') ||
           msg.contains('_debugUltimatePreviousSiblingOf') ||
           msg.contains('_history.isNotEmpty'))) {
        return; // swallow entirely — breaks the infinite cascade
      }

      if (kDebugMode) {
        FlutterError.presentError(details);
      }

      // Send error to stream
      _errorController.add(Exception(msg));

      // Log error
      _logError('Flutter Error', details.exception, details.stack);
    };

    // Handle Dart errors
    PlatformDispatcher.instance.onError = (error, stack) {
      final msg = error.toString();

      // Skip network errors from LogService itself — prevents infinite
      // loop when the logging backend is unreachable.
      if (msg.contains('SocketException') ||
          msg.contains('Connection refused')) {
        if (kDebugMode) {
          AppLogger.debug('error', 'Suppressed network error: $msg');
        }
        return true;
      }

      AppLogger.error('error', error);
      AppLogger.debug('error', 'Stack: $stack');

      // Send error to stream
      _errorController.add(Exception(msg));

      // Log error
      _logError('Dart Error', error, stack);

      return true;
    };
  }

  /// Logs an error to the console (debug) and sends it to the remote logging
  /// backend. Like Laravel's `Handler::report()` sending to Sentry/Bugsnag.
  static void _logError(String type, dynamic error, StackTrace? stack) {
    AppLogger.error('error', error);
    AppLogger.debug('error', 'Stack: $stack');

    // Send to Logging Backend
    LogService.sendError(error, stack);
  }

  /// Closes the error stream controller. Call during app shutdown.
  static void dispose() {
    _errorController.close();
  }
}
