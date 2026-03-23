// performance_service.dart - App performance monitoring via Firebase Performance.
// Like Laravel Telescope's request/query monitoring, or a Vue performance plugin.
// Tracks screen load times, API latency, and custom operation durations.

import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

/// Singleton service wrapping Firebase Performance for monitoring app speed.
/// Like Laravel Telescope or Debugbar for tracking performance metrics,
/// but the data goes to the Firebase console instead of a local dashboard.
///
/// Three main monitoring types:
/// 1. **Custom Traces** - measure duration of any operation (like Telescope's query timing)
/// 2. **Screen Load Traces** - measure how long screens take to load
/// 3. **HTTP Metrics** - detailed tracking of API call performance
///
/// Also provides [trackAsync], a convenience wrapper that automatically
/// traces any async operation -- like wrapping a Laravel job in a timer.
///
/// Uses Singleton pattern (`factory` + `_internal`) just like [AnalyticsService].
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  static FirebasePerformance? _performance;

  /// Initialize Firebase Performance monitoring. Call after `Firebase.initializeApp()`.
  /// Like registering Telescope in Laravel's `AppServiceProvider::register()`.
  static Future<void> initialize() async {
    try {
      _performance = FirebasePerformance.instance;
      await _performance!.setPerformanceCollectionEnabled(true);

      if (kDebugMode) {
        print('✅ Firebase Performance initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Firebase Performance init failed: $e');
      }
    }
  }

  // ==================== CUSTOM TRACES ====================

  /// Start a custom trace to measure the duration of any operation.
  /// Returns a [Trace] object that must be stopped manually via [stopTrace].
  /// Like starting a Laravel Telescope timer: the trace records wall-clock time
  /// between start and stop, plus any attributes you attach.
  /// [name] - identifier for this trace (shows up in Firebase console).
  static Future<Trace?> startTrace(String name) async {
    try {
      final trace = _performance?.newTrace(name);
      await trace?.start();
      if (kDebugMode) {
        print('⏱️ Trace started: $name');
      }
      return trace;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ startTrace failed: $e');
      }
      return null;
    }
  }

  /// Stop a running trace and submit the timing data to Firebase.
  /// Safe to call with null (no-op). Always call this in a `finally` block.
  static Future<void> stopTrace(Trace? trace) async {
    try {
      await trace?.stop();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ stopTrace failed: $e');
      }
    }
  }

  // ==================== SCREEN LOAD TRACES ====================

  /// Track how long a screen takes to load (data fetch + render).
  /// Attaches a 'screen_name' attribute for filtering in Firebase console.
  /// Usage:
  /// ```dart
  /// final trace = await PerformanceService.startScreenTrace('Dashboard');
  /// // ... load data ...
  /// await PerformanceService.stopTrace(trace);
  /// ```
  static Future<Trace?> startScreenTrace(String screenName) async {
    try {
      final trace = _performance?.newTrace('screen_load_$screenName');
      await trace?.start();
      trace?.putAttribute('screen_name', screenName);
      if (kDebugMode) {
        print('⏱️ Screen trace started: $screenName');
      }
      return trace;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ startScreenTrace failed: $e');
      }
      return null;
    }
  }

  // ==================== HTTP METRIC ====================

  /// Create an HTTP metric for detailed API performance tracking.
  /// Firebase auto-tracks HTTP requests, but this allows custom metadata.
  /// Like adding custom tags to a Laravel Telescope HTTP entry.
  /// [url] - the API endpoint URL. [method] - HTTP method (GET, POST, etc.).
  static Future<HttpMetric?> startHttpMetric(
    String url,
    HttpMethod method,
  ) async {
    try {
      final metric = _performance?.newHttpMetric(url, method);
      await metric?.start();
      return metric;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ startHttpMetric failed: $e');
      }
      return null;
    }
  }

  /// Stop an HTTP metric and attach response metadata (status code, payload sizes).
  /// All parameters are optional -- attach whatever info is available.
  static Future<void> stopHttpMetric(
    HttpMetric? metric, {
    int? httpResponseCode,
    int? responsePayloadSize,
    int? requestPayloadSize,
    String? responseContentType,
  }) async {
    try {
      if (metric != null) {
        if (httpResponseCode != null) {
          metric.httpResponseCode = httpResponseCode;
        }
        if (responsePayloadSize != null) {
          metric.responsePayloadSize = responsePayloadSize;
        }
        if (requestPayloadSize != null) {
          metric.requestPayloadSize = requestPayloadSize;
        }
        if (responseContentType != null) {
          metric.responseContentType = responseContentType;
        }
        await metric.stop();
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ stopHttpMetric failed: $e');
      }
    }
  }

  // ==================== CONVENIENCE METHODS ====================

  /// Convenience method to automatically trace any async operation.
  /// Wraps the operation in a start/stop trace with success/error attributes.
  /// Like a Laravel middleware that times controller actions automatically.
  /// The generic type [T] matches the return type of the [operation] callback.
  /// Usage:
  /// ```dart
  /// final result = await PerformanceService.trackAsync(
  ///   'load_students',
  ///   () => apiService.getStudents(),
  /// );
  /// ```
  static Future<T> trackAsync<T>(
    String traceName,
    Future<T> Function() operation, {
    Map<String, String>? attributes,
  }) async {
    final trace = await startTrace(traceName);
    if (attributes != null) {
      for (final entry in attributes.entries) {
        trace?.putAttribute(entry.key, entry.value);
      }
    }
    try {
      final result = await operation();
      trace?.putAttribute('status', 'success');
      return result;
    } catch (e) {
      trace?.putAttribute('status', 'error');
      trace?.putAttribute(
        'error',
        e.toString().length > 100 ? e.toString().substring(0, 100) : e.toString(),
      );
      rethrow;
    } finally {
      await stopTrace(trace);
    }
  }
}
