// FCM (Firebase Cloud Messaging) service for push notifications
// Like Laravel's notification system + Vue event bus.
// Handles: permissions, token mgmt, foreground/background/terminated states,
// cache invalidation, navigation routing, and real-time UI sync.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:manajemensekolah/core/services/fcm_local_notifications.dart';
import 'package:manajemensekolah/core/services/fcm_message_handler.dart';
import 'package:manajemensekolah/core/services/fcm_notification_router.dart';
import 'package:manajemensekolah/core/services/fcm_permissions.dart';
import 'package:manajemensekolah/core/services/fcm_token_manager.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Background message handler (runs in separate isolate)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.debug('fcm', 'Background message: ${message.messageId}');

  if (FCMCacheInvalidator.isRefreshMessage(message.data)) {
    await FCMCacheInvalidator.handleRefreshMessage(message.data);
    return;
  }

  // Show notification for regular messages
  await FCMLocalNotificationsManager.showBackgroundNotification(message);
}

/// Singleton FCM service managing push notifications lifecycle
/// Public API:
/// - initialize(): Setup permissions, token, handlers
/// - isInitialized: bool check
/// - initError: String? for error details
/// - fcmToken: String? getter
/// - syncTrigger: ValueNotifier for UI sync
/// - sendTokenToBackend(token): Send to API
/// - deleteTokenFromBackend(): Delete from API
/// - getSavedToken(): Retrieve local token
/// - clearLocalToken(): Clear local storage
/// - forceRefreshToken(): Rotate token
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  late final FCMTokenManager _tokenManager;
  late final FCMPermissions _permissions;
  late final FCMLocalNotificationsManager _localNotifications;
  late final FCMNotificationRouter _router;
  late final FCMNotificationHandler _messageHandler;

  bool _isInitialized = false;
  String? _initError;

  bool get isInitialized => _isInitialized;
  String? get initError => _initError;
  String? get fcmToken => _tokenManager.token;

  /// UI components listen to this for data refresh triggers
  final ValueNotifier<Map<String, dynamic>?> syncTrigger =
      ValueNotifier<Map<String, dynamic>?>(null);

  /// Initialize FCM: permissions, token, handlers, local notifications
  Future<void> initialize() async {
    try {
      AppLogger.debug('fcm', 'Initializing FCM Service...');

      // Setup components
      _tokenManager = FCMTokenManager(_firebaseMessaging);
      _permissions = FCMPermissions(_firebaseMessaging);
      _localNotifications = FCMLocalNotificationsManager(
        FlutterLocalNotificationsPlugin(),
      );
      _router = FCMNotificationRouter();
      _messageHandler = FCMNotificationHandler(_router);

      // Request permissions
      final hasPermission = await _permissions.requestPermission();
      if (!hasPermission) {
        _initError = 'Notification permission denied';
        AppLogger.error('fcm', _initError!);
        return;
      }

      // Initialize local notifications
      await _localNotifications.initialize(_onNotificationTapped);

      // Get token
      final token = await _tokenManager.getToken();
      if (token != null) {
        await _tokenManager.saveTokenLocally(token);
      }

      // Setup token refresh listener
      _tokenManager.listenToRefreshEvents((newToken) async {
        await sendTokenToBackend(newToken);
      });

      // Setup message handlers
      _setupMessageHandlers();

      // Set background handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      _isInitialized = true;
      AppLogger.info('fcm', 'FCM Service initialized successfully');
    } catch (e) {
      _initError = 'Error initializing FCM: $e';
      AppLogger.error('fcm', _initError!);
    }
  }

  /// Setup listeners for foreground, background (opened), and initial
  /// message scenarios
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background messages (app opened by notification tap)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      AppLogger.debug('fcm', 'Background message opened: ${message.messageId}');
      _messageHandler.handleTap(message.data);
    });

    // Initial message (app opened from terminated state)
    _firebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        AppLogger.debug('fcm', 'Initial message: ${message.messageId}');
        _messageHandler.handleTap(message.data);
      }
    });
  }

  /// Handle foreground message: cache invalidation or local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    AppLogger.debug('fcm', 'Foreground message: ${message.data}');

    if (FCMCacheInvalidator.isRefreshMessage(message.data)) {
      await FCMCacheInvalidator.handleRefreshMessage(message.data);
      _triggerSync(message.data['type'] as String);
      return;
    }

    // Show local notification
    await _localNotifications.showNotification(message);
  }

  /// Trigger sync and reset after delay
  void _triggerSync(String syncType) {
    syncTrigger.value = {'type': syncType};
    Future.delayed(const Duration(milliseconds: 100), () {
      syncTrigger.value = null;
    });
  }

  /// Callback when user taps local notification
  void _onNotificationTapped(NotificationResponse response) {
    _messageHandler.parseAndHandle(response.payload);
  }

  /// Send token to backend API
  Future<bool> sendTokenToBackend(String token) async {
    return _tokenManager.sendToBackend(token);
  }

  /// Register the device's CURRENT FCM token with the backend.
  ///
  /// This is the entry point to call right after auth is established
  /// (login success, or app-start once a stored session is restored).
  /// Why it's needed: FCM tokens are stable per app-install, so they do
  /// NOT rotate on re-login/reopen. The only places that previously
  /// pushed a token to the server were the rare `onTokenRefresh` event
  /// and the Attendance retry button — so whatever token sits in the DB
  /// goes stale and the device silently stops receiving pushes. The
  /// backend's `RegisterFcmTokenAction` dedupes (deletes prior tokens for
  /// the same user+device_type, inserts the current one), so calling this
  /// on every login self-heals stale rows.
  ///
  /// Resilient + non-blocking by contract:
  /// - Ensures FCM is initialized first (initializes if not).
  /// - Resolves the token via `getSavedToken()`, falling back to a live
  ///   `getToken()` if nothing is cached yet.
  /// - Never throws — all failures are caught and logged so login/app-
  ///   start UX is never blocked or broken by FCM.
  ///
  /// MUST be called AFTER the bearer token is stored: the POST /fcm/token
  /// carries the auth header (see [FCMTokenManager.sendToBackend], which
  /// short-circuits if no auth token is present).
  ///
  /// Returns true if a token was successfully sent to the backend.
  Future<bool> registerTokenWithBackend() async {
    try {
      // Make sure FCM is set up. On app start `initialize()` runs pre-auth,
      // but if it failed/was skipped we re-attempt here so a login can still
      // register the device.
      if (!_isInitialized) {
        AppLogger.debug(
          'fcm',
          'registerTokenWithBackend: not initialized yet, initializing...',
        );
        await initialize();
      }

      // Prefer the cached token; fall back to a live fetch (e.g. APNS only
      // became available after the initial pre-auth attempt).
      var token = await getSavedToken();
      token ??= await _tokenManager.getToken();

      if (token == null || token.isEmpty) {
        AppLogger.warning(
          'fcm',
          'registerTokenWithBackend: no FCM token available to register',
        );
        return false;
      }

      // Keep local cache in sync, then push to the backend (deduped
      // server-side).
      await _tokenManager.saveTokenLocally(token);
      final sent = await sendTokenToBackend(token);
      if (sent) {
        AppLogger.info('fcm', 'FCM token registered with backend on auth');
      }
      return sent;
    } catch (e) {
      // Never let FCM registration break the login / app-start flow.
      AppLogger.error('fcm', 'registerTokenWithBackend failed: $e');
      return false;
    }
  }

  /// Delete token from backend API
  Future<void> deleteTokenFromBackend() async {
    await _tokenManager.deleteFromBackend();
  }

  /// Get saved token from local preferences
  Future<String?> getSavedToken() async {
    return _tokenManager.getSavedToken();
  }

  /// Clear token from local preferences
  Future<void> clearLocalToken() async {
    await _tokenManager.clearToken();
  }

  /// Force refresh token
  Future<String?> forceRefreshToken() async {
    return _tokenManager.forceRefresh();
  }
}
