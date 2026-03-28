// analytics_service.dart - User activity tracking via Firebase Analytics.
// Like Laravel's event logging (Event/Listener) combined with a tracking
// service, or similar to Vue's analytics plugin (vue-gtag). Centralizes all
// analytics calls so the rest of the app never touches Firebase directly.

import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'dart:convert';

/// Singleton service that wraps Firebase Analytics for the entire app.
/// Like Laravel's `App\Services\AnalyticsService` -- a single class you
/// call from controllers (here: screens/providers) to log events.
///
/// Uses the Singleton pattern via a private constructor + factory,
/// similar to Laravel's `app()->singleton(AnalyticsService::class, ...)`.
///
/// Key properties:
/// - [_analytics] : The Firebase Analytics instance (like the GA client in Laravel).
/// - [_observer]  : A navigator observer for automatic route/screen tracking.
///
/// All methods are static for convenience -- call `AnalyticsService.logLogin(...)`
/// from anywhere, like calling a Laravel Facade (`Analytics::logLogin(...)`).
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static FirebaseAnalytics? _analytics;
  static FirebaseAnalyticsObserver? _observer;

  /// Initialize the analytics engine. Must be called after `Firebase.initializeApp()`.
  /// Like registering a service provider in Laravel's `AppServiceProvider::boot()`.
  /// Side effect: enables analytics collection globally.
  static Future<void> initialize() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);

      // Enable analytics collection
      await _analytics!.setAnalyticsCollectionEnabled(true);

      AppLogger.info('analytics', 'Firebase Analytics initialized');
    } catch (e) {
      AppLogger.warning('analytics', 'Firebase Analytics init failed: $e');
    }
  }

  /// Get the navigator observer for automatic screen tracking.
  /// Attach this to `MaterialApp.navigatorObservers` -- like adding
  /// a middleware in Laravel that logs every route hit automatically.
  static FirebaseAnalyticsObserver? get observer => _observer;

  /// Set user identity on login so events are attributed to a specific tester.
  /// Like Laravel's `Auth::login($user)` but for analytics context.
  /// Parameters: [userId], [email], [role] are required; [name], [schoolName] optional.
  /// Side effect: sets Firebase user properties (similar to session data in Laravel).
  static Future<void> setUser({
    required String userId,
    required String email,
    required String role,
    String? name,
    String? schoolName,
  }) async {
    try {
      await _analytics?.setUserId(id: userId);
      await _analytics?.setUserProperty(name: 'user_email', value: email);
      await _analytics?.setUserProperty(name: 'user_role', value: role);
      if (name != null) {
        await _analytics?.setUserProperty(name: 'user_name', value: name);
      }
      if (schoolName != null) {
        await _analytics?.setUserProperty(
          name: 'school_name',
          value: schoolName,
        );
      }
      await _analytics?.setUserProperty(
        name: 'platform',
        value: kIsWeb ? 'web' : Platform.operatingSystem,
      );

      AppLogger.info('analytics', 'Analytics user set: $email ($role)');
    } catch (e) {
      AppLogger.warning('analytics', 'Analytics setUser failed: $e');
    }
  }

  /// Restore user identity from SharedPreferences after app restart.
  /// Like Laravel's session-based auth that persists across requests --
  /// SharedPreferences is Flutter's equivalent of `session()` / cookies.
  static Future<void> setUserFromPrefs() async {
    try {
      final prefs = PreferencesService();
      final userJson = prefs.getString('user');
      if (userJson != null) {
        final user = json.decode(userJson);
        await setUser(
          userId: user['id']?.toString() ?? '',
          email: user['email'] ?? '',
          role: user['role'] ?? '',
          name: user['name'] ?? user['nama'],
          schoolName: user['school_name'] ?? user['nama_sekolah'],
        );
      }
    } catch (e) {
      AppLogger.warning('analytics', 'Analytics setUserFromPrefs failed: $e');
    }
  }

  /// Clear user identity on logout. Like `Auth::logout()` in Laravel.
  /// Side effect: resets the Firebase userId so subsequent events are anonymous.
  static Future<void> clearUser() async {
    try {
      await _analytics?.setUserId(id: null);
      AppLogger.info('analytics', 'Analytics user cleared');
    } catch (e) {
      AppLogger.warning('analytics', 'Analytics clearUser failed: $e');
    }
  }

  // ==================== EVENT TRACKING ====================

  /// Track a login event with method, email, and role.
  /// Like firing a Laravel Event: `event(new UserLoggedIn($user))`.
  /// Logs both the built-in Firebase login event and a custom detail event.
  static Future<void> logLogin({
    required String method,
    required String email,
    required String role,
  }) async {
    try {
      await _analytics?.logLogin(loginMethod: method);
      await _analytics?.logEvent(
        name: 'user_login_detail',
        parameters: {
          'email': email,
          'role': role,
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      AppLogger.info('analytics', 'Login tracked: $email ($role)');
    } catch (e) {
      AppLogger.warning('analytics', 'Analytics logLogin failed: $e');
    }
  }

  /// Track logout event and clear the user identity.
  /// Side effect: also calls [clearUser] to disassociate future events.
  static Future<void> logLogout() async {
    try {
      await _analytics?.logEvent(name: 'user_logout');
      await clearUser();
      AppLogger.info('analytics', 'Logout tracked');
    } catch (e) {
      AppLogger.warning('analytics', 'Analytics logLogout failed: $e');
    }
  }

  /// Manually track a screen view for screens not using the Navigator.
  /// The [observer] handles Navigator-based screens automatically; use this
  /// for dialogs, bottom sheets, or tab switches. Like logging a page view
  /// in a Vue SPA router guard (`router.afterEach`).
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics?.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
      AppLogger.info('analytics', 'Screen view: $screenName');
    } catch (e) {
      AppLogger.warning('analytics', 'Analytics logScreenView failed: $e');
    }
  }

  /// Track which features testers use most. Like a Laravel `feature_used`
  /// event dispatched in controllers. [featureName] identifies the feature;
  /// optional [parameters] carry extra metadata (e.g., filters applied).
  static Future<void> logFeatureUsed({
    required String featureName,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics?.logEvent(
        name: 'feature_used',
        parameters: {'feature_name': featureName, ...?parameters},
      );
      AppLogger.info('analytics', 'Feature used: $featureName');
    } catch (e) {
      AppLogger.warning('analytics', 'Analytics logFeatureUsed failed: $e');
    }
  }

  /// Track an API call's endpoint, HTTP method, status code, and duration.
  /// Helps identify slow endpoints, similar to Laravel Telescope's request
  /// monitoring or a custom HTTP middleware that logs response times.
  static Future<void> logApiCall({
    required String endpoint,
    required String method,
    required int statusCode,
    required int durationMs,
  }) async {
    try {
      await _analytics?.logEvent(
        name: 'api_call',
        parameters: {
          'endpoint': endpoint,
          'method': method,
          'status_code': statusCode,
          'duration_ms': durationMs,
        },
      );
    } catch (e) {
      AppLogger.warning('analytics', 'Analytics logApiCall failed: $e');
    }
  }

  /// Track an error event. Like Laravel's `Log::error()` or a custom
  /// exception handler that reports to an external service.
  /// [message] is truncated to 100 chars to respect Firebase limits.
  static Future<void> logError({
    required String errorType,
    required String message,
    String? screen,
  }) async {
    try {
      await _analytics?.logEvent(
        name: 'app_error',
        parameters: {
          'error_type': errorType,
          'message': message.length > 100 ? message.substring(0, 100) : message,
          if (screen != null) 'screen': screen,
        },
      );
    } catch (e) {
      AppLogger.warning('analytics', 'Analytics logError failed: $e');
    }
  }

  /// Track when a user switches schools (multi-tenancy context).
  /// Like logging a tenant switch in a Laravel multi-tenant app.
  static Future<void> logSchoolSwitch({
    required String schoolName,
    required String role,
  }) async {
    try {
      await _analytics?.logEvent(
        name: 'school_switch',
        parameters: {'school_name': schoolName, 'role': role},
      );
    } catch (e) {
      AppLogger.warning('analytics', 'Analytics logSchoolSwitch failed: $e');
    }
  }

  /// Track a custom/generic event by [name] with optional [parameters].
  /// Catch-all for events that don't fit the specific methods above.
  /// Like Laravel's `Event::dispatch($name, $payload)`.
  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics?.logEvent(name: name, parameters: parameters);
    } catch (e) {
      AppLogger.warning('analytics', 'Analytics logEvent failed: $e');
    }
  }
}
