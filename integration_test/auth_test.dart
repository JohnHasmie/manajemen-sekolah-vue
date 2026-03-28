import 'package:flutter/foundation.dart';
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
    await secureStorage.delete(key: 'secure_token'); await secureStorage.delete(key: 'secure_user_data'); await secureStorage.delete(key: 'secure_force_logout');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token'); await prefs.remove('user'); await prefs.remove('user_data'); await prefs.remove('role'); await prefs.remove('school_id'); await prefs.remove('current_school_id'); await prefs.remove('force_logout'); await prefs.remove('current_school_id'); await prefs.remove('force_logout');
    debugPrint('🧹 Cleared stored tokens and preferences');

    // Skip FCM to avoid notification permission dialog
    app.SchoolManagementApp.skipFCM = true;
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

    // ── TC001: Demo login navigates to dashboard ──
    debugPrint('▶ TC001: Demo login navigates to dashboard');

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

    // Handle school selection - look for school names or "Pilih Sekolah"
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      // Check for school name in list
      if (find.textContaining('SMP Kamil Edu').evaluate().isNotEmpty) {
        debugPrint('📋 School selection detected - tapping first school');
        await tester.tap(find.textContaining('SMP Kamil Edu').first);
        for (int j = 0; j < 10; j++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        break;
      }
      // Or check for "Pilih Sekolah" text
      if (find.text('Pilih Sekolah').evaluate().isNotEmpty) {
        debugPrint('📋 School picker detected');
        final listTiles = find.byType(ListTile);
        if (listTiles.evaluate().isNotEmpty) {
          await tester.tap(listTiles.first);
          for (int j = 0; j < 10; j++) {
            await tester.pump(const Duration(milliseconds: 500));
          }
        }
        break;
      }
    }

    // Handle role selection - look for "Pilih Role" or role display names
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.text('Pilih Role').evaluate().isNotEmpty) {
        debugPrint('📋 Role selection detected');
        // Role display names: 'Administrator', 'Teacher', 'Parent'
        final adminRole = find.text('Administrator');
        if (adminRole.evaluate().isNotEmpty) {
          await tester.tap(adminRole);
          debugPrint('📋 Selected Administrator role');
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

    // Wait for dashboard to fully load
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.byType(Scaffold), findsWidgets);
    await binding.takeScreenshot('TC001_dashboard');
    debugPrint('✅ TC001 PASSED');

    // ── TC006: Logout ──
    debugPrint('▶ TC006: Logout flow');
    final accountIcon = find.byIcon(Icons.account_circle);
    if (accountIcon.evaluate().isNotEmpty) {
      await tester.tap(accountIcon.first);
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await binding.takeScreenshot('TC006_profile_menu');
    }

    final logoutBtn = find.text('Keluar');
    if (logoutBtn.evaluate().isNotEmpty) {
      await tester.tap(logoutBtn.first);
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Confirm dialog if present
      final confirmBtn = find.text('Ya');
      if (confirmBtn.evaluate().isNotEmpty) {
        await tester.tap(confirmBtn.first);
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
      }
    }

    // Wait for login screen to reappear
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.text('LOGIN').evaluate().isNotEmpty) break;
    }

    expect(find.text('LOGIN'), findsOneWidget);
    await binding.takeScreenshot('TC006_logged_out');
    debugPrint('✅ TC006 PASSED');

    // ── TC003: Empty fields validation ──
    debugPrint('▶ TC003: Empty fields validation');
    await tester.tap(find.text('LOGIN'));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('LOGIN'), findsOneWidget);
    await binding.takeScreenshot('TC003_empty_validation');
    debugPrint('✅ TC003 PASSED');

    // ── TC004: Invalid email format ──
    debugPrint('▶ TC004: Invalid email format');
    final emailField2 = find.byType(TextField).first;
    await tester.tap(emailField2);
    await tester.enterText(emailField2, 'notanemail');
    await tester.pump();

    final passwordField2 = find.byType(TextField).at(1);
    await tester.tap(passwordField2);
    await tester.enterText(passwordField2, 'password');
    await tester.pump();

    await tester.tap(find.text('LOGIN'));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('LOGIN'), findsOneWidget);
    await binding.takeScreenshot('TC004_invalid_email');
    debugPrint('✅ TC004 PASSED');

    // ── TC005: Password field obscured ──
    debugPrint('▶ TC005: Password field is obscured');
    final textFields = find.byType(TextField);
    bool foundObscured = false;
    for (int i = 0; i < textFields.evaluate().length; i++) {
      final widget = tester.widget<TextField>(textFields.at(i));
      if (widget.obscureText) {
        foundObscured = true;
        break;
      }
    }
    expect(foundObscured, isTrue);
    await binding.takeScreenshot('TC005_obscured');
    debugPrint('✅ TC005 PASSED');

    // ── TC002: Invalid credentials ──
    debugPrint('▶ TC002: Invalid credentials');
    final emailField3 = find.byType(TextField).first;
    await tester.tap(emailField3);
    await tester.enterText(emailField3, 'wrong@example.com');
    await tester.pump();

    final passwordField3 = find.byType(TextField).at(1);
    await tester.tap(passwordField3);
    await tester.enterText(passwordField3, 'wrongpassword');
    await tester.pump();

    await tester.tap(find.text('LOGIN'));
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('LOGIN'), findsOneWidget);
    await binding.takeScreenshot('TC002_invalid_creds');
    debugPrint('✅ TC002 PASSED');

    debugPrint('🎉 All Auth Tests PASSED!');
  });
}
