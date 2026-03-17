import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

/// Service untuk monitoring performa aplikasi via Firebase Performance.
/// Track loading speed, network latency, dan bottleneck.
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  static FirebasePerformance? _performance;

  /// Initialize performance monitoring
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

  /// Start a custom trace - untuk ukur durasi operasi tertentu
  /// Returns Trace yang harus di-stop manual
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

  /// Stop a trace
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

  /// Track screen load time
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

  /// Create HTTP metric untuk track API performance secara detail
  /// Firebase Performance sudah auto-track HTTP requests,
  /// tapi ini untuk custom tracking dengan metadata tambahan.
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

  /// Stop HTTP metric with response info
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

  /// Track durasi sebuah async operation
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
