import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:manajemensekolah/main.dart' as app;

/// Complete login flow used at the start of every integration test.
///
/// [role] should be the display name shown in the role-selection list, e.g.
/// `'Administrator'` or `'Teacher'`.
Future<void> loginAndNavigateToDashboard(
  WidgetTester tester, {
  String role = 'Administrator',
}) async {
  // Clear auth tokens (preserved FCM state to avoid permission dialogs).
  const secureStorage = FlutterSecureStorage();
  await secureStorage.delete(key: 'secure_token');
  await secureStorage.delete(key: 'secure_user_data');
  await secureStorage.delete(key: 'secure_force_logout');
  final prefs = await SharedPreferences.getInstance();
  for (final k in [
    'token',
    'user',
    'user_data',
    'role',
    'school_id',
    'current_school_id',
    'force_logout',
  ]) {
    await prefs.remove(k);
  }
  debugPrint('🧹 Cleared auth tokens (preserved FCM state)');

  app.SchoolManagementApp.skipFCM = true;
  app.main();

  // Wait for the login screen to fully render (animations, health check, etc.).
  await tester.pumpAndSettle();
  debugPrint('✅ Login screen ready');

  // Use stable Key-based finders — immune to i18n or copy changes.
  await tester.tap(find.byKey(const Key('email_field')));
  await tester.enterText(
    find.byKey(const Key('email_field')),
    'yahyahasymi@gmail.com',
  );
  await tester.pump();

  await tester.tap(find.byKey(const Key('password_field')));
  await tester.enterText(find.byKey(const Key('password_field')), 'password');
  await tester.pump();

  await tester.tap(find.byKey(const Key('login_button')));

  // Wait for the API response and navigation transition to complete.
  await tester.pumpAndSettle();
  debugPrint('✅ Login submitted, waiting for school/role selection...');

  // ── School selection ──
  if (find.textContaining('SMP Kamil Edu').evaluate().isNotEmpty) {
    debugPrint('📋 School selection detected - tapping SMP Kamil Edu');
    await tester.tap(find.textContaining('SMP Kamil Edu').first);
    await tester.pumpAndSettle();
  } else if (find.byType(ListTile).evaluate().isNotEmpty) {
    debugPrint('📋 School selection detected - tapping first tile');
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
  }

  // ── Role selection ──
  final roleWidget = find.text(role);
  if (roleWidget.evaluate().isNotEmpty) {
    debugPrint('📋 Selecting role: $role');
    await tester.tap(roleWidget.first);
    await tester.pumpAndSettle();
  } else if (find.byType(ListTile).evaluate().isNotEmpty) {
    debugPrint('📋 Role "$role" not found, selecting first available role');
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
  }

  // Final settle for dashboard data to load.
  await tester.pumpAndSettle();
  debugPrint('✅ Dashboard loaded');

  assert(
    find.byType(Scaffold).evaluate().isNotEmpty,
    'App should show a Scaffold after login',
  );
}

/// Scrolls to and taps a menu item by its [menuText] label.
///
/// Returns `true` if the item was found and tapped; `false` otherwise.
Future<bool> tapMenu(WidgetTester tester, String menuText) async {
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isNotEmpty) {
    // Try scrolling up first (most common layout), then down as fallback.
    for (final direction in [const Offset(0, -300), const Offset(0, 300)]) {
      try {
        await tester.dragUntilVisible(
          find.text(menuText),
          scrollable.first,
          direction,
        );
        break;
      } catch (_) {
        // This direction didn't reveal the target — try the other.
      }
    }
    await tester.pumpAndSettle();
  }

  if (find.text(menuText).evaluate().isEmpty) {
    debugPrint('⚠️ Menu item not found: $menuText');
    return false;
  }

  await tester.tap(find.text(menuText).first);
  await tester.pumpAndSettle();
  debugPrint('📱 Navigated to: $menuText');
  return true;
}

/// Taps the back button and waits for the navigation transition to settle.
Future<void> goBack(WidgetTester tester) async {
  final backButton = find.byType(BackButton);
  final arrowBack = find.byIcon(Icons.arrow_back);
  final arrowBackIos = find.byIcon(Icons.arrow_back_ios);

  if (backButton.evaluate().isNotEmpty) {
    await tester.tap(backButton.first);
  } else if (arrowBack.evaluate().isNotEmpty) {
    await tester.tap(arrowBack.first);
  } else if (arrowBackIos.evaluate().isNotEmpty) {
    await tester.tap(arrowBackIos.first);
  } else {
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pop();
  }

  await tester.pumpAndSettle();
  debugPrint('⬅️ Went back');
}

/// Waits for all pending frames and animations to settle.
///
/// The [count] parameter is accepted for API compatibility but ignored —
/// [pumpAndSettle] dynamically waits for the UI to become idle.
Future<void> waitFrames(WidgetTester tester, {int count = 10}) async {
  await tester.pumpAndSettle();
}
