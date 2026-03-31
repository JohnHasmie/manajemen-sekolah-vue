// announcement_delete_dialog_test.dart — widget tests for AnnouncementDeleteDialog.
//
// AnnouncementDeleteDialog is a plain StatelessWidget that receives a
// LanguageProvider (plain ChangeNotifier, no Riverpod). No ProviderScope needed.
// Each test wraps the widget in MaterialApp > Scaffold so that Navigator and
// Theme are available (Dialog needs Navigator to pop).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_delete_dialog.dart';

// ---------------------------------------------------------------------------
// Helper — builds AnnouncementDeleteDialog inside a navigable MaterialApp.
// ---------------------------------------------------------------------------
Widget _buildDialog({String language = LanguageProvider.english}) {
  final lp = LanguageProvider()
    ..setLanguage(language); // ignore: discarded_futures
  return MaterialApp(
    home: Scaffold(
      body: AnnouncementDeleteDialog(languageProvider: lp),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
  });

  group('AnnouncementDeleteDialog', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_buildDialog());
      expect(find.byType(AnnouncementDeleteDialog), findsOneWidget);
    });

    testWidgets('shows "Delete Announcement" title in English', (tester) async {
      await tester.pumpWidget(_buildDialog());
      expect(find.text('Delete Announcement'), findsOneWidget);
    });

    testWidgets('shows warning subtitle in English', (tester) async {
      await tester.pumpWidget(_buildDialog());
      expect(find.text('This action cannot be undone'), findsOneWidget);
    });

    testWidgets('shows Cancel and Delete buttons', (tester) async {
      await tester.pumpWidget(_buildDialog());
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('shows Indonesian text when language is id', (tester) async {
      final lp = LanguageProvider(); // defaults to 'id'
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnouncementDeleteDialog(languageProvider: lp),
          ),
        ),
      );
      expect(find.text('Hapus Pengumuman'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Hapus'), findsOneWidget);
    });

    testWidgets('displays delete_outline icon in header', (tester) async {
      await tester.pumpWidget(_buildDialog());
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });
}
