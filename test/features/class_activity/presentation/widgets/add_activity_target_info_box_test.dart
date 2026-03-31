// add_activity_target_info_box_test.dart — widget tests for AddActivityTargetInfoBox.
//
// AddActivityTargetInfoBox is a plain StatelessWidget that accepts a String,
// Color, and LanguageProvider. No Riverpod needed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/add_activity_target_info_box.dart';

// ---------------------------------------------------------------------------
// Helper — builds AddActivityTargetInfoBox inside MaterialApp > Scaffold.
// ---------------------------------------------------------------------------
Widget _buildInfoBox({
  String initialTarget = 'khusus',
  Color primaryColor = Colors.indigo,
  String language = LanguageProvider.english,
}) {
  final lp = LanguageProvider()
    ..setLanguage(language); // ignore: discarded_futures
  return MaterialApp(
    home: Scaffold(
      body: AddActivityTargetInfoBox(
        initialTarget: initialTarget,
        primaryColor: primaryColor,
        languageProvider: lp,
      ),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
  });

  group('AddActivityTargetInfoBox', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_buildInfoBox());
      expect(find.byType(AddActivityTargetInfoBox), findsOneWidget);
    });

    testWidgets('shows SPECIFIC message when target is "khusus" (English)',
        (tester) async {
      await tester.pumpWidget(_buildInfoBox(
        initialTarget: 'khusus',
        language: LanguageProvider.english,
      ));
      expect(
        find.textContaining('SPECIFIC'),
        findsOneWidget,
      );
    });

    testWidgets('shows GENERAL message when target is not "khusus" (English)',
        (tester) async {
      await tester.pumpWidget(_buildInfoBox(
        initialTarget: 'umum',
        language: LanguageProvider.english,
      ));
      expect(find.textContaining('GENERAL'), findsOneWidget);
    });

    testWidgets('shows people icon for "khusus" target', (tester) async {
      await tester.pumpWidget(_buildInfoBox(initialTarget: 'khusus'));
      expect(find.byIcon(Icons.people), findsOneWidget);
    });

    testWidgets('shows schedule icon for non-khusus target', (tester) async {
      await tester.pumpWidget(_buildInfoBox(initialTarget: 'umum'));
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('shows Indonesian KHUSUS text when language is id',
        (tester) async {
      final lp = LanguageProvider(); // defaults to 'id'
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddActivityTargetInfoBox(
              initialTarget: 'khusus',
              primaryColor: Colors.teal,
              languageProvider: lp,
            ),
          ),
        ),
      );
      expect(find.textContaining('KHUSUS'), findsOneWidget);
    });
  });
}
