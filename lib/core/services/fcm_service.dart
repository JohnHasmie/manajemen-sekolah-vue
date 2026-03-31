// fcm_service.dart - Firebase Cloud Messaging (push notifications) service.
// Like Laravel's notification system (Notification + NotificationChannel) combined
// with a Vue event bus for real-time UI updates. Handles push notification
// receiving, display, tap navigation, token management, and cache invalidation.

import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart'; // Required for MaterialPageRoute
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:manajemensekolah/main.dart'; // Import navigatorKey
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/parent_attendance_screen.dart';
import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Top-level background message handler. Must be a top-level function (not a
/// class method) because it runs in a separate isolate when the app is killed.
/// Like a Laravel Queue Worker that processes jobs independently of the main app.
/// Handles cache invalidation for 'refresh_*' message types and shows local
/// notifications for regular messages.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.debug('fcm', 'Background message received: ${message.messageId}');
  AppLogger.debug('fcm', 'Title: ${message.notification?.title}');
  AppLogger.debug('fcm', 'Body: ${message.notification?.body}');
  AppLogger.debug('fcm', 'Data: ${message.data}');

  if (message.data['type'] == 'refresh_subjects') {
    await LocalCacheService.clearStartingWith('subject_');
    AppLogger.debug('fcm', 'Subject cache invalidated in background');
    return;
  }

  if (message.data['type'] == 'refresh_teachers') {
    await LocalCacheService.clearStartingWith('teacher_');
    await LocalCacheService.clearStartingWith('class_');
    AppLogger.debug('fcm', 'Teacher & Class cache invalidated in background');
    return;
  }

  if (message.data['type'] == 'refresh_classes') {
    await LocalCacheService.clearStartingWith('class_');
    AppLogger.debug('fcm', 'Class cache invalidated in background');
    return;
  }
  if (message.data['type'] == 'refresh_schedules') {
    await LocalCacheService.clearStartingWith('schedule_');
    AppLogger.debug('fcm', 'Schedule cache invalidated in background');
    return;
  }

  // Show notification when app is in background
  if (message.notification != null) {
    final FlutterLocalNotificationsPlugin localNotifications =
        FlutterLocalNotificationsPlugin();

    // Initialize with basic settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await localNotifications.initialize(settings);

    // Show notification
    await localNotifications.show(
      message.notification.hashCode,
      message.notification!.title,
      message.notification!.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );

    AppLogger.info('fcm', 'Background notification displayed');
  }
}

/// Singleton service managing Firebase Cloud Messaging (FCM) push notifications.
/// Like Laravel's notification system combined with a broadcasting channel:
/// - FCM = Laravel's `DatabaseNotification` + `BroadcastChannel`
/// - Local notifications = the "mail" channel (shows visible alerts)
/// - [syncTrigger] = a Vue reactive ref / Laravel Event that UI listens to
///
/// Handles three app states:
/// 1. Foreground: show local notification + trigger cache invalidation
/// 2. Background: handled by top-level [_firebaseMessagingBackgroundHandler]
/// 3. Terminated: check initial message when app opens
///
/// Key properties:
/// - [_fcmToken] : device token sent to backend (like a device ID in Laravel's `fcm_tokens` table)
/// - [syncTrigger] : ValueNotifier that UI widgets listen to for real-time data refresh
///   (similar to Vue's `watch()` or Laravel Echo's `.listen()`)
/// - [_localNotifications] : plugin for showing OS-level notification banners
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Whether FCM initialization completed successfully.
  /// Check this after `initialize()` to detect broken notification setup.
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// The error that caused FCM initialization to fail, if any.
  String? _initError;
  String? get initError => _initError;

  /// ValueNotifier that UI components observe for background data changes.
  /// When a 'refresh_*' push notification arrives, this emits the message type
  /// so screens can reload their data. Like Vue's `watch()` on a reactive store,
  /// or listening to a Laravel Echo channel event.
  final ValueNotifier<Map<String, dynamic>?> syncTrigger =
      ValueNotifier<Map<String, dynamic>?>(null);

  /// Initialize FCM: request permissions, get token, set up message handlers.
  /// Like registering a Laravel service provider that sets up notification
  /// channels, broadcast drivers, and event listeners all at once.
  /// Must be called once at app startup (in main.dart after Firebase.initializeApp).
  Future<void> initialize() async {
    try {
      AppLogger.debug('fcm', 'Initializing FCM Service...');

      // Request permission
      final NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );

      AppLogger.info(
        'fcm',
        'Permission status: ${settings.authorizationStatus}',
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Initialize local notifications
        await _initializeLocalNotifications();

        // Get FCM token (on iOS, APNS token must be available first)
        try {
          final apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken != null) {
            _fcmToken = await _firebaseMessaging.getToken();
            AppLogger.debug('fcm', 'FCM Token: $_fcmToken');
          } else {
            AppLogger.warning('fcm', 'APNS token not available (simulator?), skipping FCM token fetch');
          }
        } catch (e) {
          AppLogger.warning('fcm', 'Could not get FCM token: $e');
        }

        // Save token locally
        if (_fcmToken != null) {
          final prefs = PreferencesService();
          await prefs.setString('fcm_token', _fcmToken!);
        }

        // Listen to token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) async {
          AppLogger.debug('fcm', 'FCM Token refreshed: $newToken');
          _fcmToken = newToken;
          final prefs = PreferencesService();
          await prefs.setString('fcm_token', newToken);

          // Send updated token to backend
          await sendTokenToBackend(newToken);
        });

        // Setup message handlers
        _setupMessageHandlers();

        // Set background message handler
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );

        _isInitialized = true;
        AppLogger.info('fcm', 'FCM Service initialized successfully');
      } else {
        _initError = 'Notification permission denied';
        AppLogger.error('fcm', _initError!);
      }
    } catch (e) {
      _initError = 'Error initializing FCM: $e';
      AppLogger.error('fcm', _initError!);
    }
  }

  /// Set up the local notifications plugin for showing OS-level notification
  /// banners when the app is in the foreground. Like configuring a Laravel
  /// notification channel (mail, SMS, etc.) -- here it's the device's notification tray.
  /// Creates an Android notification channel with high importance.
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Register listeners for all three message reception scenarios.
  /// Like setting up Laravel Echo listeners for different event types:
  /// - `onMessage` (foreground) = Echo `.listen()` while app is active
  /// - `onMessageOpenedApp` (background tap) = user clicks a notification
  /// - `getInitialMessage` (terminated tap) = app opened from a killed state
  ///
  /// 'refresh_*' messages invalidate local caches and trigger UI sync
  /// without showing a visible notification (silent push, like a Laravel job).
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      AppLogger.debug('fcm', 'Data: ${message.data}');

      if (message.data['type'] == 'refresh_subjects') {
        await LocalCacheService.clearStartingWith('subject_');
        syncTrigger.value = {'type': 'refresh_subjects'};
        // Reset to allow future triggers
        Future.delayed(const Duration(milliseconds: 100), () {
          syncTrigger.value = null;
        });
        AppLogger.debug('fcm', 'Subject cache invalidated in foreground');
        return;
      }

      if (message.data['type'] == 'refresh_teachers') {
        await LocalCacheService.clearStartingWith('teacher_');
        await LocalCacheService.clearStartingWith('class_');
        syncTrigger.value = {'type': 'refresh_teachers'};
        // Reset to allow future triggers
        Future.delayed(const Duration(milliseconds: 100), () {
          syncTrigger.value = null;
        });
        AppLogger.debug(
          'fcm',
          'Teacher & Class cache invalidated in foreground',
        );
        return;
      }

      if (message.data['type'] == 'refresh_classes') {
        await LocalCacheService.clearStartingWith('class_');
        syncTrigger.value = {'type': 'refresh_classes'};
        // Reset to allow future triggers
        Future.delayed(const Duration(milliseconds: 100), () {
          syncTrigger.value = null;
        });
        AppLogger.debug('fcm', 'Class cache invalidated in foreground');
        return;
      }
      if (message.data['type'] == 'refresh_schedules') {
        await LocalCacheService.clearStartingWith('schedule_');
        syncTrigger.value = {'type': 'refresh_schedules'};
        // Reset to allow future triggers
        Future.delayed(const Duration(milliseconds: 100), () {
          syncTrigger.value = null;
        });
        AppLogger.debug('fcm', 'Schedule cache invalidated in foreground');
        return;
      }

      // Show local notification when app is in foreground
      _showLocalNotification(message);
    });

    // Background messages (when app is in background but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      AppLogger.debug('fcm', 'Background message opened: ${message.messageId}');
      _handleNotificationTap(message.data);
    });

    // Check for initial message (when app is opened from terminated state)
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        AppLogger.debug('fcm', 'Initial message: ${message.messageId}');
        _handleNotificationTap(message.data);
      }
    });
  }

  /// Display a local notification banner when a message arrives in the foreground.
  /// FCM only auto-displays notifications when the app is backgrounded; in the
  /// foreground, we must explicitly show them using the local notifications plugin.
  /// The message payload is encoded as JSON in the notification's `payload` field
  /// so it can be parsed when the user taps the notification.
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;
    final AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription:
                'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Callback when a local notification is tapped. Parses the JSON payload
  /// and delegates to [_handleNotificationTap] for navigation.
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _handleNotificationTap(data);
      } catch (e) {
        AppLogger.error('fcm', 'Error parsing notification payload: $e');
      }
    }
  }

  /// Route notification taps to the appropriate screen based on the `type` field.
  /// Like a Laravel notification's `toArray()` method defining the action URL,
  /// or a Vue router that maps notification types to route names.
  /// Supported types: absensi, class_activity, pengumuman, tagihan, grade.
  void _handleNotificationTap(Map<String, dynamic> data) {
    AppLogger.debug('fcm', 'Notification tapped with data: $data');

    // You can navigate to specific screens based on notification type
    final type = data['type'];

    if (type == 'absensi' || type == 'attendance') {
      _navigateToPresenceScreen(data);
      AppLogger.info(
        'fcm',
        'Navigate to absensi screen for siswa: ${data['student_id']}',
      );
    } else if (type == 'class_activity' || type == 'class_activity_detail') {
      _navigateToClassActivityScreen();
      AppLogger.info(
        'fcm',
        'Navigate to class activity for kegiatan: ${data['activity_id']}',
      );
    } else if (type == 'pengumuman' || type == 'announcement') {
      // Navigate to announcement screen
      AppLogger.info('fcm', 'navigating to announcement screen');

      _navigateToAnnouncementScreen();

      AppLogger.info(
        'fcm',
        'Navigate to pengumuman: ${data['announcement_id']}',
      );
      AppLogger.debug(
        'fcm',
        'Title: ${data['title']}, Priority: ${data['priority']}',
      );
      AppLogger.debug(
        'fcm',
        'Target: ${data['target_role']}, Class: ${data['class_name']}',
      );
    } else if (type == 'tagihan') {
      // Navigate to tagihan (billing) screen
      // This will be handled by the app's navigation system
      AppLogger.info('fcm', 'Navigate to tagihan: ${data['bill_id']}');
      AppLogger.debug('fcm', 'Siswa: ${data['student_name']}');
      AppLogger.debug('fcm', 'Jenis: ${data['payment_type_name']}');
      AppLogger.debug('fcm', 'Jumlah: Rp ${data['amount']}');
      AppLogger.debug('fcm', 'Jatuh Tempo: ${data['due_date']}');
    } else if (type == 'grade') {
      _navigateToGradeScreen();
      AppLogger.info('fcm', 'Navigate to grade for: ${data['grade_id']}');
    }
  }

  /// Send the FCM device token to the backend so it can target this device.
  /// Like storing a device token in Laravel's `fcm_tokens` table via
  /// `POST /api/fcm-token`. Returns true on success, false on failure.
  Future<bool> sendTokenToBackend(String token) async {
    try {
      AppLogger.debug('fcm', 'Sending FCM token to backend...');

      final prefs = PreferencesService();
      final authToken = prefs.getString('token');
      if (authToken == null) {
        throw Exception('No auth token found');
      }

      await dioClient.post(
        ApiEndpoints.fcmTokenEndpoint,
        data: {'token': token, 'device_type': 'mobile'},
      );

      AppLogger.info('fcm', 'FCM token sent to backend successfully');
      return true;
    } catch (e) {
      AppLogger.error('fcm', 'Error sending FCM token to backend: $e');
      return false;
    }
  }

  /// Delete the FCM token from the backend on logout so the device
  /// stops receiving notifications. Like `DELETE /api/fcm-token/{token}` in Laravel.
  Future<void> deleteTokenFromBackend() async {
    try {
      if (_fcmToken != null) {
        AppLogger.debug('fcm', 'Deleting FCM token from backend...');

        final prefs = PreferencesService();
        final authToken = prefs.getString('token');
        if (authToken == null) {
          throw Exception('No auth token found');
        }

        await dioClient.delete(
          ApiEndpoints.fcmTokenEndpoint,
          data: {'token': _fcmToken!},
        );

        AppLogger.info('fcm', 'FCM token deleted from backend');
      }
    } catch (e) {
      AppLogger.error('fcm', 'Error deleting FCM token from backend: $e');
    }
  }

  /// Retrieve the saved FCM token from SharedPreferences (local storage).
  /// Like reading from Laravel's session or cache: `Cache::get('fcm_token')`.
  Future<String?> getSavedToken() async {
    try {
      final prefs = PreferencesService();
      return prefs.getString('fcm_token');
    } catch (e) {
      AppLogger.error('fcm', 'Error getting saved token: $e');
      return null;
    }
  }

  /// Clear the locally stored FCM token. Called during logout cleanup.
  Future<void> clearLocalToken() async {
    try {
      final prefs = PreferencesService();
      await prefs.remove('fcm_token');
      _fcmToken = null;
    } catch (e) {
      AppLogger.error('fcm', 'Error clearing local token: $e');
    }
  }

  /// Force-refresh the FCM token by deleting the old one and requesting a new one.
  /// Useful when push notifications stop working. Like rotating an API key.
  /// Side effects: saves new token locally and sends it to the backend.
  Future<String?> forceRefreshToken() async {
    try {
      AppLogger.debug('fcm', 'Force refreshing FCM token...');

      // Delete the old token
      await _firebaseMessaging.deleteToken();

      // Get new token (check APNS on iOS first)
      final apnsToken = await _firebaseMessaging.getAPNSToken();
      if (apnsToken == null) {
        AppLogger.warning('fcm', 'APNS token not available, cannot refresh FCM token');
        return null;
      }
      _fcmToken = await _firebaseMessaging.getToken();

      AppLogger.debug('fcm', 'New FCM Token: $_fcmToken');

      // Save new token locally
      if (_fcmToken != null) {
        final prefs = PreferencesService();
        await prefs.setString('fcm_token', _fcmToken!);

        // Send to backend
        await sendTokenToBackend(_fcmToken!);
      }

      return _fcmToken;
    } catch (e) {
      AppLogger.error('fcm', 'Error force refreshing token: $e');
      return null;
    }
  }

  /// Navigate to the announcement screen based on user role (admin vs parent/teacher).
  /// Uses the global [navigatorKey] to push routes without a BuildContext.
  /// Like a Laravel redirect that checks the user's role before choosing the view.
  Future<void> _navigateToAnnouncementScreen() async {
    try {
      final prefs = PreferencesService();
      final userDataStr = prefs.getString('user');
      String role = 'wali'; // Default

      if (userDataStr != null) {
        final userData = jsonDecode(userDataStr);
        role = userData['role'] ?? 'wali';
      }

      if (navigatorKey.currentState != null) {
        if (role == 'admin') {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => const AdminAnnouncementScreen(),
            ),
          );
        } else {
          // For guru, wali, staff
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (context) => const AnnouncementScreen()),
          );
        }
      }
    } catch (e) {
      AppLogger.error('fcm', 'Error navigating to announcement screen: $e');
    }
  }

  /// Navigate to the parent class activity screen from a notification tap.
  Future<void> _navigateToClassActivityScreen() async {
    try {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => const ParentClassActivityScreen(),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('fcm', 'Error navigating to class activity screen: $e');
    }
  }

  /// Navigate to the parent grade screen from a notification tap.
  Future<void> _navigateToGradeScreen() async {
    try {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (context) => const ParentGradeScreen()),
        );
      }
    } catch (e) {
      AppLogger.error('fcm', 'Error navigating to grade screen: $e');
    }
  }

  /// Navigate to the parent presence/attendance screen for a specific student.
  /// Reads user data from SharedPreferences and passes the student_id from
  /// the notification payload. Like a Laravel redirect with route parameters.
  Future<void> _navigateToPresenceScreen(Map<String, dynamic> data) async {
    try {
      if (navigatorKey.currentState != null) {
        final prefs = PreferencesService();
        final userDataString = prefs.getString('user');
        if (userDataString == null) return;

        final userData = json.decode(userDataString);
        final studentId = data['student_id']?.toString();

        if (studentId == null) return;

        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) =>
                PresenceParentPage(parent: userData, studentId: studentId),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('fcm', 'Error navigating to presence screen: $e');
    }
  }
}
