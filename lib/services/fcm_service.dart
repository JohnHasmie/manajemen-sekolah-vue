// fcm_service.dart - Firebase Cloud Messaging (push notifications) service.
// Like Laravel's notification system (Notification + NotificationChannel) combined
// with a Vue event bus for real-time UI updates. Handles push notification
// receiving, display, tap navigation, token management, and cache invalidation.

import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Required for MaterialPageRoute
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:manajemensekolah/main.dart'; // Import navigatorKey
import 'package:manajemensekolah/screen/admin/admin_announcement.dart';
import 'package:manajemensekolah/screen/walimurid/announcement_screen.dart';
import 'package:manajemensekolah/screen/walimurid/parent_class_activity.dart';
import 'package:manajemensekolah/screen/walimurid/parent_grade_screen.dart';
import 'package:manajemensekolah/screen/walimurid/presence_parent.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/local_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Top-level background message handler. Must be a top-level function (not a
/// class method) because it runs in a separate isolate when the app is killed.
/// Like a Laravel Queue Worker that processes jobs independently of the main app.
/// Handles cache invalidation for 'refresh_*' message types and shows local
/// notifications for regular messages.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('🔔 Background message received: ${message.messageId}');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');
  }

  if (message.data['type'] == 'refresh_subjects') {
    await LocalCacheService.clearStartingWith('subject_');
    if (kDebugMode) {
      print('♻️ Subject cache invalidated in background');
    }
    return;
  }

  if (message.data['type'] == 'refresh_teachers') {
    await LocalCacheService.clearStartingWith('teacher_');
    await LocalCacheService.clearStartingWith('class_');
    if (kDebugMode) {
      print('♻️ Teacher & Class cache invalidated in background');
    }
    return;
  }

  if (message.data['type'] == 'refresh_classes') {
    await LocalCacheService.clearStartingWith('class_');
    if (kDebugMode) {
      print('♻️ Class cache invalidated in background');
    }
    return;
  }
  if (message.data['type'] == 'refresh_schedules') {
    await LocalCacheService.clearStartingWith('schedule_');
    if (kDebugMode) {
      print('♻️ Schedule cache invalidated in background');
    }
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

    if (kDebugMode) {
      print('✅ Background notification displayed');
    }
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
      if (kDebugMode) {
        print('🔧 Initializing FCM Service...');
      }

      // Request permission
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );

      if (kDebugMode) {
        print('✅ Permission status: ${settings.authorizationStatus}');
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Initialize local notifications
        await _initializeLocalNotifications();

        // Get FCM token
        _fcmToken = await _firebaseMessaging.getToken();
        if (kDebugMode) {
          print('📱 FCM Token: $_fcmToken');
        }

        // Save token locally
        if (_fcmToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fcm_token', _fcmToken!);
        }

        // Listen to token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) async {
          if (kDebugMode) {
            print('🔄 FCM Token refreshed: $newToken');
          }
          _fcmToken = newToken;
          final prefs = await SharedPreferences.getInstance();
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

        if (kDebugMode) {
          print('✅ FCM Service initialized successfully');
        }
      } else {
        if (kDebugMode) {
          print('❌ Notification permission denied');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing FCM: $e');
      }
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
      if (kDebugMode) {
        print('Data: ${message.data}');
      }

      if (message.data['type'] == 'refresh_subjects') {
        await LocalCacheService.clearStartingWith('subject_');
        syncTrigger.value = {'type': 'refresh_subjects'};
        // Reset to allow future triggers
        Future.delayed(const Duration(milliseconds: 100), () {
          syncTrigger.value = null;
        });
        if (kDebugMode) {
          print('♻️ Subject cache invalidated in foreground');
        }
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
        if (kDebugMode) {
          print('♻️ Teacher & Class cache invalidated in foreground');
        }
        return;
      }

      if (message.data['type'] == 'refresh_classes') {
        await LocalCacheService.clearStartingWith('class_');
        syncTrigger.value = {'type': 'refresh_classes'};
        // Reset to allow future triggers
        Future.delayed(const Duration(milliseconds: 100), () {
          syncTrigger.value = null;
        });
        if (kDebugMode) {
          print('♻️ Class cache invalidated in foreground');
        }
        return;
      }
      if (message.data['type'] == 'refresh_schedules') {
        await LocalCacheService.clearStartingWith('schedule_');
        syncTrigger.value = {'type': 'refresh_schedules'};
        // Reset to allow future triggers
        Future.delayed(const Duration(milliseconds: 100), () {
          syncTrigger.value = null;
        });
        if (kDebugMode) {
          print('♻️ Schedule cache invalidated in foreground');
        }
        return;
      }

      // Show local notification when app is in foreground
      _showLocalNotification(message);
    });

    // Background messages (when app is in background but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('🔔 Background message opened: ${message.messageId}');
      }
      _handleNotificationTap(message.data);
    });

    // Check for initial message (when app is opened from terminated state)
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        if (kDebugMode) {
          print('🔔 Initial message: ${message.messageId}');
        }
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
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

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
        if (kDebugMode) {
          print('Error parsing notification payload: $e');
        }
      }
    }
  }

  /// Route notification taps to the appropriate screen based on the `type` field.
  /// Like a Laravel notification's `toArray()` method defining the action URL,
  /// or a Vue router that maps notification types to route names.
  /// Supported types: absensi, class_activity, pengumuman, tagihan, grade.
  void _handleNotificationTap(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('🔔 Notification tapped with data: $data');
    }

    // You can navigate to specific screens based on notification type
    final type = data['type'];

    if (type == 'absensi' || type == 'attendance') {
      _navigateToPresenceScreen(data);
      if (kDebugMode) {
        print('Navigate to absensi screen for siswa: ${data['student_id']}');
      }
    } else if (type == 'class_activity' || type == 'class_activity_detail') {
      _navigateToClassActivityScreen();
      if (kDebugMode) {
        print(
          'Navigate to class activity for kegiatan: ${data['activity_id']}',
        );
      }
    } else if (type == 'pengumuman' || type == 'announcement') {
      // Navigate to announcement screen
      if (kDebugMode) {
        print('navigating to announcement screen');
      }

      _navigateToAnnouncementScreen();

      if (kDebugMode) {
        print('Navigate to pengumuman: ${data['announcement_id']}');
        print('Title: ${data['title']}, Priority: ${data['priority']}');
        print('Target: ${data['target_role']}, Class: ${data['class_name']}');
      }
    } else if (type == 'tagihan') {
      // Navigate to tagihan (billing) screen
      // This will be handled by the app's navigation system
      if (kDebugMode) {
        print('Navigate to tagihan: ${data['bill_id']}');
        print('Siswa: ${data['student_name']}');
        print('Jenis: ${data['payment_type_name']}');
        print('Jumlah: Rp ${data['amount']}');
        print('Jatuh Tempo: ${data['due_date']}');
      }
    } else if (type == 'grade') {
      _navigateToGradeScreen();
      if (kDebugMode) {
        print('Navigate to grade for: ${data['grade_id']}');
      }
    }
  }

  /// Send the FCM device token to the backend so it can target this device.
  /// Like storing a device token in Laravel's `fcm_tokens` table via
  /// `POST /api/fcm-token`. Returns true on success, false on failure.
  Future<bool> sendTokenToBackend(String token) async {
    try {
      if (kDebugMode) {
        print('📤 Sending FCM token to backend...');
      }

      await ApiService.sendFCMToken(token, 'mobile');

      if (kDebugMode) {
        print('✅ FCM token sent to backend successfully');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending FCM token to backend: $e');
      }
      return false;
    }
  }

  /// Delete the FCM token from the backend on logout so the device
  /// stops receiving notifications. Like `DELETE /api/fcm-token/{token}` in Laravel.
  Future<void> deleteTokenFromBackend() async {
    try {
      if (_fcmToken != null) {
        if (kDebugMode) {
          print('🗑️ Deleting FCM token from backend...');
        }

        await ApiService.deleteFCMToken(_fcmToken!);

        if (kDebugMode) {
          print('✅ FCM token deleted from backend');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting FCM token from backend: $e');
      }
    }
  }

  /// Retrieve the saved FCM token from SharedPreferences (local storage).
  /// Like reading from Laravel's session or cache: `Cache::get('fcm_token')`.
  Future<String?> getSavedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('fcm_token');
    } catch (e) {
      if (kDebugMode) {
        print('Error getting saved token: $e');
      }
      return null;
    }
  }

  /// Clear the locally stored FCM token. Called during logout cleanup.
  Future<void> clearLocalToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
      _fcmToken = null;
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing local token: $e');
      }
    }
  }

  /// Force-refresh the FCM token by deleting the old one and requesting a new one.
  /// Useful when push notifications stop working. Like rotating an API key.
  /// Side effects: saves new token locally and sends it to the backend.
  Future<String?> forceRefreshToken() async {
    try {
      if (kDebugMode) {
        print('🔄 Force refreshing FCM token...');
      }

      // Delete the old token
      await _firebaseMessaging.deleteToken();

      // Get new token
      _fcmToken = await _firebaseMessaging.getToken();

      if (kDebugMode) {
        print('📱 New FCM Token: $_fcmToken');
      }

      // Save new token locally
      if (_fcmToken != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);

        // Send to backend
        await sendTokenToBackend(_fcmToken!);
      }

      return _fcmToken;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error force refreshing token: $e');
      }
      return null;
    }
  }

  /// Navigate to the announcement screen based on user role (admin vs parent/teacher).
  /// Uses the global [navigatorKey] to push routes without a BuildContext.
  /// Like a Laravel redirect that checks the user's role before choosing the view.
  Future<void> _navigateToAnnouncementScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('user');
      String role = 'wali'; // Default

      if (userDataStr != null) {
        final userData = jsonDecode(userDataStr);
        role = userData['role'] ?? 'wali';
      }

      if (navigatorKey.currentState != null) {
        if (role == 'admin') {
          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (context) => const AdminAnnouncementScreen(),
            ),
          );
        } else {
          // For guru, wali, staff
          navigatorKey.currentState!.push(
            MaterialPageRoute(builder: (context) => const AnnouncementScreen()),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error navigating to announcement screen: $e');
      }
    }
  }

  /// Navigate to the parent class activity screen from a notification tap.
  Future<void> _navigateToClassActivityScreen() async {
    try {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) => const ParentClassActivityScreen(),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error navigating to class activity screen: $e');
      }
    }
  }

  /// Navigate to the parent grade screen from a notification tap.
  Future<void> _navigateToGradeScreen() async {
    try {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (context) => const ParentGradeScreen()),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error navigating to grade screen: $e');
      }
    }
  }

  /// Navigate to the parent presence/attendance screen for a specific student.
  /// Reads user data from SharedPreferences and passes the student_id from
  /// the notification payload. Like a Laravel redirect with route parameters.
  Future<void> _navigateToPresenceScreen(Map<String, dynamic> data) async {
    try {
      if (navigatorKey.currentState != null) {
        final prefs = await SharedPreferences.getInstance();
        final userDataString = prefs.getString('user');
        if (userDataString == null) return;

        final userData = json.decode(userDataString);
        final studentId = data['student_id']?.toString();

        if (studentId == null) return;

        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (context) =>
                PresenceParentPage(parent: userData, studentId: studentId),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error navigating to presence screen: $e');
      }
    }
  }
}
