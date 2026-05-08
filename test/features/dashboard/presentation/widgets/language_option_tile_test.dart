// Tests for LanguageOptionTile — the tappable language-selection tile in the
// picker dialog.
// LanguageProvider is a plain ChangeNotifier (no WidgetRef / Riverpod tree needed here).
// We instantiate it directly and pass it as a prop — just like passing a Vue
// prop.
//
// setUp initialises SharedPreferences mock so that
// LanguageProvider.setLanguage()
// (which calls PreferencesService.setString) doesn't throw.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/language_option_tile.dart';

Widget buildTestable(Widget child) {
  return MaterialApp(
    // Wrap in a Navigator so AppNavigator.pop() can call context.pop()
    home: Scaffold(body: child),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
  });

  group('LanguageOptionTile', () {
    // ── 1. Displays the language name ─────────────────────────────────────
    testWidgets('displays the language name', (tester) async {
      final provider = LanguageProvider();

      await tester.pumpWidget(
        buildTestable(
          LanguageOptionTile(
            languageProvider: provider,
            language: 'English',
            code: 'en',
            color: Colors.blue,
          ),
        ),
      );

      expect(find.text('English'), findsOneWidget);
    });

    // ── 2. Shows checkmark for active language ─────────────────────────────
    testWidgets('shows checkmark when language is active', (tester) async {
      final provider = LanguageProvider();
      // Default language is 'id'; manually set to 'en'
      await provider.setLanguage('en');

      await tester.pumpWidget(
        buildTestable(
          LanguageOptionTile(
            languageProvider: provider,
            language: 'English',
            code: 'en',
            color: Colors.blue,
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    // ── 3. Hides checkmark for inactive language ───────────────────────────
    testWidgets('hides checkmark when language is not active', (tester) async {
      final provider = LanguageProvider(); // default 'id'

      await tester.pumpWidget(
        buildTestable(
          LanguageOptionTile(
            languageProvider: provider,
            language: 'English',
            code: 'en',
            color: Colors.blue,
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    // ── 4. Language icon is always present ────────────────────────────────
    testWidgets('always shows the language globe icon', (tester) async {
      final provider = LanguageProvider();

      await tester.pumpWidget(
        buildTestable(
          LanguageOptionTile(
            languageProvider: provider,
            language: 'Indonesia',
            code: 'id',
            color: Colors.green,
          ),
        ),
      );

      expect(find.byIcon(Icons.language), findsOneWidget);
    });

    // ── 5. Color is applied to the Icon ───────────────────────────────────
    testWidgets('applies the accent color to the language icon', (
      tester,
    ) async {
      const accentColor = Colors.red;
      final provider = LanguageProvider();

      await tester.pumpWidget(
        buildTestable(
          LanguageOptionTile(
            languageProvider: provider,
            language: 'English',
            code: 'en',
            color: accentColor,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.language));
      expect(icon.color, accentColor);
    });

    // ── 6. Tile is rendered as an InkWell (tappable) ──────────────────────
    testWidgets('wraps content in an InkWell', (tester) async {
      final provider = LanguageProvider();

      await tester.pumpWidget(
        buildTestable(
          LanguageOptionTile(
            languageProvider: provider,
            language: 'Indonesia',
            code: 'id',
            color: Colors.green,
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);
    });
  });
}
