import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service untuk tracking user activities via Firebase Analytics.
/// Berguna untuk closed testing - melihat siapa login dan ngapain aja.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static FirebaseAnalytics? _analytics;
  static FirebaseAnalyticsObserver? _observer;

  /// Initialize analytics - panggil setelah Firebase.initializeApp()
  static Future<void> initialize() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);

      // Enable analytics collection
      await _analytics!.setAnalyticsCollectionEnabled(true);

      if (kDebugMode) {
        print('✅ Firebase Analytics initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Firebase Analytics init failed: $e');
      }
    }
  }

  /// Get the navigator observer for automatic screen tracking
  static FirebaseAnalyticsObserver? get observer => _observer;

  /// Set user identity saat login - agar bisa track per tester
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

      if (kDebugMode) {
        print('📊 Analytics user set: $email ($role)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Analytics setUser failed: $e');
      }
    }
  }

  /// Set user from SharedPreferences (untuk auto-set setelah app restart)
  static Future<void> setUserFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
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
      if (kDebugMode) {
        print('⚠️ Analytics setUserFromPrefs failed: $e');
      }
    }
  }

  /// Clear user saat logout
  static Future<void> clearUser() async {
    try {
      await _analytics?.setUserId(id: null);
      if (kDebugMode) {
        print('📊 Analytics user cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Analytics clearUser failed: $e');
      }
    }
  }

  // ==================== EVENT TRACKING ====================

  /// Track login event
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
      if (kDebugMode) {
        print('📊 Login tracked: $email ($role)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Analytics logLogin failed: $e');
      }
    }
  }

  /// Track logout event
  static Future<void> logLogout() async {
    try {
      await _analytics?.logEvent(name: 'user_logout');
      await clearUser();
      if (kDebugMode) {
        print('📊 Logout tracked');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Analytics logLogout failed: $e');
      }
    }
  }

  /// Track screen view (manual - untuk screen yang tidak pakai Navigator)
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics?.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
      if (kDebugMode) {
        print('📊 Screen view: $screenName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Analytics logScreenView failed: $e');
      }
    }
  }

  /// Track feature usage - untuk tahu fitur mana yang sering dipakai tester
  static Future<void> logFeatureUsed({
    required String featureName,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics?.logEvent(
        name: 'feature_used',
        parameters: {
          'feature_name': featureName,
          ...?parameters,
        },
      );
      if (kDebugMode) {
        print('📊 Feature used: $featureName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Analytics logFeatureUsed failed: $e');
      }
    }
  }

  /// Track API call - untuk tahu endpoint mana yang lambat
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
      if (kDebugMode) {
        print('⚠️ Analytics logApiCall failed: $e');
      }
    }
  }

  /// Track error event
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
      if (kDebugMode) {
        print('⚠️ Analytics logError failed: $e');
      }
    }
  }

  /// Track school switch
  static Future<void> logSchoolSwitch({
    required String schoolName,
    required String role,
  }) async {
    try {
      await _analytics?.logEvent(
        name: 'school_switch',
        parameters: {
          'school_name': schoolName,
          'role': role,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Analytics logSchoolSwitch failed: $e');
      }
    }
  }

  /// Track custom event (generic)
  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics?.logEvent(name: name, parameters: parameters);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Analytics logEvent failed: $e');
      }
    }
  }
}
