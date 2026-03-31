// add_activity_action_bar_test.dart — widget tests for AddActivityActionBar.
//
// AddActivityActionBar is a plain StatelessWidget that accepts bool, Color,
// LanguageProvider, and a VoidCallback. No Riverpod needed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/add_activity_action_bar.dart';

// ---------------------------------------------------------------------------
// Helper — builds AddActivityActionBar inside MaterialApp > Scaffold.
// ---------------------------------------------------------------------------
Widget _buildActionBar({
  bool isSubmitting = false,
  bool isEditMode = false,
  Color primaryColor = Colors.blue,
  String language = LanguageProvider.english,
  VoidCallback? onSubmit,
}) {
  final lp = LanguageProvider()
    ..setLanguage(language); // ignore: discarded_futures
  return MaterialApp(
    home: Scaffold(
      body: AddActivityActionBar(
        isSubmitting: isSubmitting,
        isEditMode: isEditMode,
        primaryColor: primaryColor,
        languageProvider: lp,
        onSubmit: onSubmit ?? () {},
      ),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
  });

  group('AddActivityActionBar', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_buildActionBar());
      expect(find.byType(AddActivityActionBar), findsOneWidget);
    });

    testWidgets('shows Cancel and Add buttons in add mode (English)',
        (tester) async {
      await tester.pumpWidget(_buildActionBar(isEditMode: false));
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('shows Update button in edit mode (English)', (tester) async {
      await tester.pumpWidget(_buildActionBar(isEditMode: true));
      expect(find.text('Update'), findsOneWidget);
    });

    testWidgets('onSubmit callback fires when submit button is tapped',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _buildActionBar(onSubmit: () => tapped = true),
      );
      await tester.tap(find.text('Add'));
      expect(tapped, isTrue);
    });

    testWidgets('submit button is disabled when isSubmitting is true',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _buildActionBar(isSubmitting: true, onSubmit: () => tapped = true),
      );
      // Button shows a CircularProgressIndicator instead of text when submitting
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Add'), findsNothing);
      // Attempt tap on the ElevatedButton area — should be a no-op
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      expect(tapped, isFalse);
    });

    testWidgets('shows Indonesian labels when language is id', (tester) async {
      final lp = LanguageProvider(); // defaults to 'id'
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddActivityActionBar(
              isSubmitting: false,
              isEditMode: false,
              primaryColor: Colors.blue,
              languageProvider: lp,
              onSubmit: () {},
            ),
          ),
        ),
      );
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Tambah'), findsOneWidget);
    });
  });
}
