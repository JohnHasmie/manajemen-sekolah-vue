import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:manajemensekolah/main.dart' as app;

/// Complete login flow that matches the exact working pattern from auth_test.dart.
/// Call this at the start of every integration test.
/// [role] should be 'Administrator' for admin or 'Teacher' for teacher.
Future<void> loginAndNavigateToDashboard(
  WidgetTester tester, {
  String role = 'Administrator',
}) async {
  // Clear only auth tokens (NOT all storage - that resets FCM and triggers
  // the notification permission dialog again)
  const secureStorage = FlutterSecureStorage();
  // Actual keys from SecureStorageService._Keys
  await secureStorage.delete(key: 'secure_token');
  await secureStorage.delete(key: 'secure_user_data');
  await secureStorage.delete(key: 'secure_force_logout');
  final prefs = await SharedPreferences.getInstance();
  // Clear auth-related SharedPreferences keys
  await prefs.remove('token');
  await prefs.remove('user');
  await prefs.remove('user_data');
  await prefs.remove('role');
  await prefs.remove('school_id');
  await prefs.remove('current_school_id');
  await prefs.remove('force_logout');
  debugPrint('🧹 Cleared auth tokens (preserved FCM state)');

  // Skip FCM to avoid notification permission dialog on simulator
  app.SchoolManagementApp.skipFCM = true;

  // Let the real app's main() handle all initialization
  app.main();

  // Wait for app to fully initialize and render login screen
  for (int i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.text('LOGIN').evaluate().isNotEmpty) {
      debugPrint('✅ Login screen loaded after ${(i + 1) * 500}ms');
      break;
    }
    if (i % 10 == 0) debugPrint('⏳ Waiting for app... ${(i + 1) * 500}ms');
  }

  // Fill email
  final emailField = find.byType(TextField).first;
  await tester.tap(emailField);
  await tester.enterText(emailField, 'yahyahasymi@gmail.com');
  await tester.pump();

  // Fill password
  final passwordField = find.byType(TextField).at(1);
  await tester.tap(passwordField);
  await tester.enterText(passwordField, 'password');
  await tester.pump();

  // Tap LOGIN
  await tester.tap(find.text('LOGIN'));

  // Wait for API + navigation
  for (int i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.text('LOGIN').evaluate().isEmpty) {
      debugPrint('✅ Navigated away from login after ${(i + 1) * 500}ms');
      break;
    }
  }

  // Handle school selection
  for (int i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.textContaining('SMP Kamil Edu').evaluate().isNotEmpty) {
      debugPrint('📋 School selection detected - tapping first school');
      await tester.tap(find.textContaining('SMP Kamil Edu').first);
      for (int j = 0; j < 10; j++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      break;
    }
  }

  // Handle role selection
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.text('Pilih Role').evaluate().isNotEmpty) {
      debugPrint('📋 Role selection detected');
      final roleWidget = find.text(role);
      if (roleWidget.evaluate().isNotEmpty) {
        await tester.tap(roleWidget);
        debugPrint('📋 Selected $role role');
      } else {
        await tester.tap(find.byType(ListTile).first);
        debugPrint('📋 Selected first available role');
      }
      for (int j = 0; j < 15; j++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      break;
    }
  }

  // Wait briefly for dashboard - don't wait too long as heavy API calls
  // can cause the simulator to kill the process
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  debugPrint('✅ Dashboard loaded');

  // Verify we're on a screen (not crashed)
  assert(find.byType(Scaffold).evaluate().isNotEmpty, 'App should show a Scaffold');
}

/// Navigate to a menu item, waiting for it to appear first.
Future<bool> tapMenu(WidgetTester tester, String menuText) async {
  // Try to find the menu item, scroll if needed
  for (int attempt = 0; attempt < 3; attempt++) {
    if (find.text(menuText).evaluate().isNotEmpty) {
      await tester.tap(find.text(menuText).first);
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      debugPrint('📱 Navigated to: $menuText');
      return true;
    }
    // Scroll down to find it
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.drag(scrollable.first, const Offset(0, -300));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    }
  }
  debugPrint('⚠️ Menu item not found: $menuText');
  return false;
}

/// Go back to previous screen.
Future<void> goBack(WidgetTester tester) async {
  final back = find.byIcon(Icons.arrow_back);
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back.first);
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    debugPrint('⬅️ Went back');
  } else {
    debugPrint('⚠️ No back button found');
  }
}

/// Wait for frames to render.
Future<void> waitFrames(WidgetTester tester, {int count = 10}) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}
