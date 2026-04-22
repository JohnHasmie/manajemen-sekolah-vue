// add_activity_header_test.dart — widget tests for AddActivityHeader.
//
// AddActivityHeader is a plain StatelessWidget accepting String, bool, Color,
// and LanguageProvider. No Riverpod needed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/add_activity_header.dart';

// ---------------------------------------------------------------------------
// Helper — builds AddActivityHeader inside MaterialApp > Scaffold.
// ---------------------------------------------------------------------------
Widget _buildHeader({
  String activityType = 'tugas',
  bool isEditMode = false,
  Color primaryColor = Colors.blue,
  String language = LanguageProvider.english,
}) {
  final lp = LanguageProvider()
    ..setLanguage(language); // ignore: discarded_futures
  return MaterialApp(
    home: Scaffold(
      body: AddActivityHeader(
        activityType: activityType,
        isEditMode: isEditMode,
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

  group('AddActivityHeader', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_buildHeader());
      expect(find.byType(AddActivityHeader), findsOneWidget);
    });

    testWidgets('shows "Add Assignment" for tugas / add mode in English', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHeader(
          activityType: 'tugas',
          isEditMode: false,
          language: LanguageProvider.english,
        ),
      );
      expect(find.text('Add Assignment'), findsOneWidget);
    });

    testWidgets('shows "Edit Assignment" for tugas / edit mode in English', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHeader(
          activityType: 'tugas',
          isEditMode: true,
          language: LanguageProvider.english,
        ),
      );
      expect(find.text('Edit Assignment'), findsOneWidget);
    });

    testWidgets('shows "Add Material" for non-tugas activity type', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHeader(
          activityType: 'materi',
          isEditMode: false,
          language: LanguageProvider.english,
        ),
      );
      expect(find.text('Add Material'), findsOneWidget);
    });

    testWidgets('shows "Edit Material" for non-tugas / edit mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHeader(
          activityType: 'materi',
          isEditMode: true,
          language: LanguageProvider.english,
        ),
      );
      expect(find.text('Edit Material'), findsOneWidget);
    });

    testWidgets('shows close icon button', (tester) async {
      await tester.pumpWidget(_buildHeader());
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });
}
