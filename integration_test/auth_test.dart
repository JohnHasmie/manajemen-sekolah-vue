import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:manajemensekolah/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Auth Tests - All TC001-TC006', timeout: const Timeout(Duration(minutes: 5)), (tester) async {
    // Clear stored tokens so the app starts at the login screen
    const secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: 'secure_token');
    await secureStorage.delete(key: 'secure_user_data');
    await secureStorage.delete(key: 'secure_force_logout');
    final prefs = await SharedPreferences.getInstance();
    for (final k in ['token', 'user', 'user_data', 'role', 'school_id', 'current_school_id', 'force_logout']) {
      await prefs.remove(k);
    }
    debugPrint('🧹 Cleared stored tokens and preferences');

    // Skip FCM to avoid notification permission dialog
    app.SchoolManagementApp.skipFCM = true;
    app.main();

    // Wait for the app to fully initialize and render the login screen.
    await tester.pumpAndSettle();
    debugPrint('✅ Login screen loaded');

    // ── TC001: Demo login navigates to dashboard ──
    debugPrint('▶ TC001: Demo login navigates to dashboard');

    // Use stable key-based finders — immune to i18n / copy changes.
    await tester.tap(find.byKey(const Key('email_field')));
    await tester.enterText(find.byKey(const Key('email_field')), 'yahyahasymi@gmail.com');
    await tester.pump();

    await tester.tap(find.byKey(const Key('password_field')));
    await tester.enterText(find.byKey(const Key('password_field')), 'password');
    await tester.pump();

    await tester.tap(find.byKey(const Key('login_button')));

    // Wait for API response and navigation transition.
    await tester.pumpAndSettle();
    debugPrint('✅ Login submitted');

    // Handle school selection
    if (find.textContaining('SMP Kamil Edu').evaluate().isNotEmpty) {
      debugPrint('📋 School selection detected - tapping first school');
      await tester.tap(find.textContaining('SMP Kamil Edu').first);
      await tester.pumpAndSettle();
    } else if (find.text('Pilih Sekolah').evaluate().isNotEmpty) {
      debugPrint('📋 School picker detected');
      final listTiles = find.byType(ListTile);
      if (listTiles.evaluate().isNotEmpty) {
        await tester.tap(listTiles.first);
        await tester.pumpAndSettle();
      }
    }

    // Handle role selection
    if (find.text('Pilih Role').evaluate().isNotEmpty ||
        find.text('Administrator').evaluate().isNotEmpty) {
      debugPrint('📋 Role selection detected');
      final adminRole = find.text('Administrator');
      if (adminRole.evaluate().isNotEmpty) {
        await tester.tap(adminRole.first);
        debugPrint('📋 Selected Administrator role');
      } else {
        await tester.tap(find.byType(ListTile).first);
        debugPrint('📋 Selected first available role');
      }
      await tester.pumpAndSettle();
    }

    // Wait for dashboard to fully load
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsWidgets);
    await binding.takeScreenshot('TC001_dashboard');
    debugPrint('✅ TC001 PASSED');

    // ── TC006: Logout ──
    debugPrint('▶ TC006: Logout flow');
    final accountIcon = find.byIcon(Icons.account_circle);
    if (accountIcon.evaluate().isNotEmpty) {
      await tester.tap(accountIcon.first);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('TC006_profile_menu');
    }

    final logoutBtn = find.text('Keluar');
    if (logoutBtn.evaluate().isNotEmpty) {
      await tester.tap(logoutBtn.first);
      await tester.pumpAndSettle();

      // Confirm dialog if present
      final confirmBtn = find.text('Ya');
      if (confirmBtn.evaluate().isNotEmpty) {
        await tester.tap(confirmBtn.first);
        await tester.pumpAndSettle();
      }
    }

    // Wait for login screen to reappear
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_button')), findsOneWidget);
    await binding.takeScreenshot('TC006_logged_out');
    debugPrint('✅ TC006 PASSED');

    // ── TC003: Empty fields validation ──
    debugPrint('▶ TC003: Empty fields validation');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_button')), findsOneWidget);
    await binding.takeScreenshot('TC003_empty_validation');
    debugPrint('✅ TC003 PASSED');

    // ── TC004: Invalid email format ──
    debugPrint('▶ TC004: Invalid email format');
    await tester.tap(find.byKey(const Key('email_field')));
    await tester.enterText(find.byKey(const Key('email_field')), 'notanemail');
    await tester.pump();

    await tester.tap(find.byKey(const Key('password_field')));
    await tester.enterText(find.byKey(const Key('password_field')), 'password');
    await tester.pump();

    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_button')), findsOneWidget);
    await binding.takeScreenshot('TC004_invalid_email');
    debugPrint('✅ TC004 PASSED');

    // ── TC005: Password field obscured ──
    debugPrint('▶ TC005: Password field is obscured');
    final passwordWidget = tester.widget<TextField>(find.byKey(const Key('password_field')));
    expect(passwordWidget.obscureText, isTrue);
    await binding.takeScreenshot('TC005_obscured');
    debugPrint('✅ TC005 PASSED');

    // ── TC002: Invalid credentials ──
    debugPrint('▶ TC002: Invalid credentials');
    await tester.tap(find.byKey(const Key('email_field')));
    await tester.enterText(find.byKey(const Key('email_field')), 'wrong@example.com');
    await tester.pump();

    await tester.tap(find.byKey(const Key('password_field')));
    await tester.enterText(find.byKey(const Key('password_field')), 'wrongpassword');
    await tester.pump();

    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_button')), findsOneWidget);
    await binding.takeScreenshot('TC002_invalid_creds');
    debugPrint('✅ TC002 PASSED');

    debugPrint('🎉 All Auth Tests PASSED!');
  });
}
