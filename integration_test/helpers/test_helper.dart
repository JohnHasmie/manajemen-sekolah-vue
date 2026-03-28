import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/main.dart';

bool _initialized = false;
late IntegrationTestWidgetsFlutterBinding _binding;

/// Call this once in main() before any tests.
void initBinding() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

/// Initialize the app for integration testing.
/// Safe to call multiple times - only runs once for heavy init.
/// Recreates disposed providers each time.
Future<void> initializeTestApp() async {
  if (!_initialized) {
    try {
      await dotenv.load(fileName: ".env");
    } catch (_) {}
    await PreferencesService().init();
    await ApiService.init();
    createDioClient(ApiService.baseUrl);
    await setupServiceLocator();
    await initializeDateFormatting('id_ID', null);
    _initialized = true;
  }

  // Recreate the global LanguageProvider before each test
  languageProvider = LanguageProvider();
  await languageProvider.loadSavedLanguage();
}

/// Pump the app widget and wait for it to render.
/// Creates a fresh LanguageProvider to avoid "used after disposed" errors.
Future<void> pumpApp(WidgetTester tester) async {
  // Create a fresh provider each time to avoid disposal issues
  final freshLangProvider = LanguageProvider();
  await freshLangProvider.loadSavedLanguage();
  languageProvider = freshLangProvider;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        languageRiverpod.overrideWith((_) => freshLangProvider),
      ],
      child: SchoolManagementApp(),
    ),
  );
  await tester.pump();
  await _settle(tester);
}

/// Take a screenshot and save it to integration_test/screenshots/.
/// Use this for capturing evidence or debugging failures.
Future<void> takeScreenshot(WidgetTester tester, String name) async {
  await tester.pump();
  try {
    await _binding.takeScreenshot(name);
  } catch (e) {
    // Fallback: capture via RepaintBoundary if binding screenshot fails
    debugPrint('Screenshot via binding failed: $e, trying fallback...');
  }
}

/// Capture a screenshot when a test fails. Call this in a try/catch around
/// your test body or in addTearDown.
/// Saves to integration_test/screenshots/failures/
Future<void> captureFailureScreenshot(WidgetTester tester, String testName) async {
  try {
    final sanitized = testName.replaceAll(RegExp(r'[^\w]'), '_');
    await takeScreenshot(tester, 'failure_$sanitized');
  } catch (_) {
    debugPrint('Could not capture failure screenshot for $testName');
  }
}

/// Wraps a test body with automatic screenshot capture on failure.
/// Usage:
///   testWidgets('TC001 - My test', screenshotOnFailure((tester) async {
///     await pumpApp(tester);
///     // ... test code
///   }));
WidgetTesterCallback screenshotOnFailure(
  Future<void> Function(WidgetTester tester) testBody,
) {
  return (WidgetTester tester) async {
    // Get the test description from the current test
    final testName = tester.testDescription;
    bool failed = false;

    try {
      await testBody(tester);
    } catch (e) {
      failed = true;
      // Take screenshot before rethrowing
      await captureFailureScreenshot(tester, testName);
      rethrow;
    }

    if (!failed) {
      // Optionally take a success screenshot too
      final sanitized = testName.replaceAll(RegExp(r'[^\w]'), '_');
      await takeScreenshot(tester, 'pass_$sanitized');
    }
  };
}

/// Login with demo account (no OTP required).
Future<void> loginAsAdmin(WidgetTester tester) async {
  await _login(tester, 'Admin');
}

Future<void> loginAsTeacher(WidgetTester tester) async {
  await _login(tester, 'Guru');
}

Future<void> loginAsParent(WidgetTester tester) async {
  await _login(tester, 'Wali Murid');
}

Future<void> _login(WidgetTester tester, String role) async {
  // Wait until TextField widgets are actually rendered on screen
  bool foundTextField = false;
  for (int i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.byType(TextField).evaluate().isNotEmpty) {
      foundTextField = true;
      debugPrint('✅ Found TextField after ${(i + 1) * 500}ms');
      break;
    }
    if (i % 5 == 0) {
      debugPrint('⏳ Waiting for TextField... ${(i + 1) * 500}ms');
    }
  }

  if (!foundTextField) {
    debugPrint('❌ TextField NOT found after 15 seconds! Dumping widget tree:');
    debugDumpApp();
    throw StateError('Login screen TextField not found after 15 seconds');
  }

  // Find and fill email
  final emailField = find.byType(TextField).first;
  await tester.tap(emailField);
  await tester.enterText(emailField, 'yahyahasymi@gmail.com');
  await tester.pump();

  // Find and fill password
  final passwordFields = find.byType(TextField);
  final passwordField = passwordFields.at(1);
  await tester.tap(passwordField);
  await tester.enterText(passwordField, 'password');
  await tester.pump();

  // Tap LOGIN button
  final loginButton = find.text('LOGIN');
  await tester.tap(loginButton);

  // Wait for API response
  await _settle(tester, timeout: 10);

  // Handle school selection if it appears
  if (find.text('Pilih Sekolah').evaluate().isNotEmpty) {
    final firstSchool = find.byType(ListTile).first;
    await tester.tap(firstSchool);
    await _settle(tester, timeout: 5);
  }

  // Handle role selection if it appears
  if (find.text('Akses sebagai').evaluate().isNotEmpty) {
    final roleOption = find.text(role);
    if (roleOption.evaluate().isNotEmpty) {
      await tester.tap(roleOption);
    } else {
      final firstRole = find.byType(ListTile).first;
      await tester.tap(firstRole);
    }
    await _settle(tester, timeout: 5);
  }

  // Wait for dashboard to load
  await _settle(tester, timeout: 5);
}

/// Try pumpAndSettle with a timeout. If it times out (due to continuous
/// animations like shimmer), fall back to a simple pump.
Future<void> _settle(WidgetTester tester, {int timeout = 3}) async {
  try {
    await tester.pumpAndSettle(Duration(seconds: timeout));
  } catch (_) {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// Navigate to a menu item from admin dashboard.
Future<void> navigateToMenu(WidgetTester tester, String menuText) async {
  final menu = find.text(menuText);
  if (menu.evaluate().isEmpty) {
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
    await _settle(tester);
  }
  await tester.tap(find.text(menuText));
  await _settle(tester, timeout: 5);
}

/// Go back using the back button or Navigator.pop
Future<void> goBack(WidgetTester tester) async {
  final backButton = find.byType(BackButton);
  if (backButton.evaluate().isNotEmpty) {
    await tester.tap(backButton.first);
  } else {
    final iconBack = find.byIcon(Icons.arrow_back);
    if (iconBack.evaluate().isNotEmpty) {
      await tester.tap(iconBack.first);
    }
  }
  await _settle(tester);
}

/// Tap a floating action button (add button).
Future<void> tapFAB(WidgetTester tester) async {
  final fab = find.byType(FloatingActionButton);
  if (fab.evaluate().isNotEmpty) {
    await tester.tap(fab.first);
    await _settle(tester);
  } else {
    final addIcon = find.byIcon(Icons.add);
    if (addIcon.evaluate().isNotEmpty) {
      await tester.tap(addIcon.first);
      await _settle(tester);
    }
  }
}

/// Tap save button (Simpan).
Future<void> tapSave(WidgetTester tester) async {
  final save = find.text('Simpan');
  if (save.evaluate().isNotEmpty) {
    await tester.tap(save.first);
    await _settle(tester, timeout: 5);
  }
}

/// Assert a widget with text exists.
void assertVisible(String text) {
  expect(find.textContaining(text), findsWidgets);
}

/// Assert no widget with text exists.
void assertNotVisible(String text) {
  expect(find.text(text), findsNothing);
}

/// Scroll down in the current view.
Future<void> scrollDown(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
  await _settle(tester);
}

/// Scroll up in the current view.
Future<void> scrollUp(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
  await _settle(tester);
}
