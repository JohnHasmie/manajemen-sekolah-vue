/// announcement_delete_dialog_test.dart — unit + widget tests for
/// AnnouncementDeleteDialog.
///
/// AnnouncementDeleteDialog is NOT a Widget — it is a plain class with a
/// static [show] method that delegates to ActionConfirmSheet.show(). Tests
/// verify:
///   1. The class can be instantiated with a LanguageProvider.
///   2. The static show() method renders an ActionConfirmSheet bottom-sheet
///      with the expected translated title, message, and button labels.
///   3. Tapping Delete returns true; tapping Cancel returns false.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_delete_dialog.dart';

// ---------------------------------------------------------------------------
// Helper — opens the dialog inside a navigable MaterialApp.
// ---------------------------------------------------------------------------
Widget _buildApp({
  required String language,
  required ValueNotifier<bool?> resultNotifier,
}) {
  final lp = LanguageProvider()
    ..setLanguage(language); // ignore: discarded_futures
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            final result = await AnnouncementDeleteDialog.show(context, lp);
            resultNotifier.value = result;
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
  });

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  group('AnnouncementDeleteDialog constructor', () {
    test('can be instantiated with a LanguageProvider', () {
      final lp = LanguageProvider();
      final dialog = AnnouncementDeleteDialog(languageProvider: lp);
      expect(dialog.languageProvider, same(lp));
    });
  });

  // ---------------------------------------------------------------------------
  // Static show() — English
  // ---------------------------------------------------------------------------

  group('AnnouncementDeleteDialog.show (English)', () {
    testWidgets('renders title and delete button', (tester) async {
      final result = ValueNotifier<bool?>(null);
      await tester.pumpWidget(
        _buildApp(language: LanguageProvider.english, resultNotifier: result),
      );

      // Open the dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Announcement'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('tapping Delete returns true', (tester) async {
      final result = ValueNotifier<bool?>(null);
      await tester.pumpWidget(
        _buildApp(language: LanguageProvider.english, resultNotifier: result),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(result.value, isTrue);
    });

    testWidgets('tapping Batal (cancel) returns false', (tester) async {
      final result = ValueNotifier<bool?>(null);
      await tester.pumpWidget(
        _buildApp(language: LanguageProvider.english, resultNotifier: result),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Cancel button defaults to 'Batal' from ActionConfirmSheet
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(result.value, isFalse);
    });

    testWidgets('shows delete_rounded icon', (tester) async {
      final result = ValueNotifier<bool?>(null);
      await tester.pumpWidget(
        _buildApp(language: LanguageProvider.english, resultNotifier: result),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_rounded), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Static show() — Indonesian
  // ---------------------------------------------------------------------------

  group('AnnouncementDeleteDialog.show (Indonesian)', () {
    testWidgets('renders Indonesian title and buttons', (tester) async {
      final result = ValueNotifier<bool?>(null);
      await tester.pumpWidget(
        _buildApp(
          language: LanguageProvider.indonesian,
          resultNotifier: result,
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Hapus Pengumuman'), findsOneWidget);
      expect(find.text('Hapus'), findsOneWidget);
    });
  });
}
