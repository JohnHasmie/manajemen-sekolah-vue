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
      if (kDebugMode) {
        FlutterError.presentError(details);
      }

      // Kirim error ke stream
      _errorController.add(Exception(details.exception.toString()));

      // Log error
      _logError('Flutter Error', details.exception, details.stack);
    };

    // Handle Dart errors
    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) {
        print('Dart Error: $error');
        print('Stack: $stack');
      }

      // Kirim error ke stream
      _errorController.add(Exception(error.toString()));

      // Log error
      _logError('Dart Error', error, stack);

      return true;
    };
  }

  /// Logs an error to the console (debug) and sends it to the remote logging
  /// backend. Like Laravel's `Handler::report()` sending to Sentry/Bugsnag.
  static void _logError(String type, dynamic error, StackTrace? stack) {
    if (kDebugMode) {
      print('$type: $error');
      if (stack != null) {
        print('Stack: $stack');
      }
    }

    // Send to Logging Backend
    LogService.sendError(error, stack);
  }

  /// Closes the error stream controller. Call during app shutdown.
  static void dispose() {
    _errorController.close();
  }
}
