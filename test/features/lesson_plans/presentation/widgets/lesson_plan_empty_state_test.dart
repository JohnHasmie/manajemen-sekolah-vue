// Tests for LessonPlanEmptyState — shown when RPP list is empty.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_empty_state.dart';

Widget _build(LanguageProvider lp) => MaterialApp(
  home: Scaffold(body: LessonPlanEmptyState(languageProvider: lp)),
);

void main() {
  late LanguageProvider langProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
    langProvider = LanguageProvider();
  });

  group('LessonPlanEmptyState', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_build(langProvider));
      expect(find.byType(LessonPlanEmptyState), findsOneWidget);
    });

    testWidgets('shows description icon', (tester) async {
      await tester.pumpWidget(_build(langProvider));
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.description_outlined,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows Indonesian heading when language is id', (tester) async {
      await tester.pumpWidget(_build(langProvider)); // defaults to 'id'
      expect(find.text('Belum ada RPP dibuat'), findsOneWidget);
    });

    testWidgets('shows Indonesian hint text when language is id', (
      tester,
    ) async {
      await tester.pumpWidget(_build(langProvider));
      expect(
        find.text('Klik tombol "+" untuk membuat RPP pertama Anda.'),
        findsOneWidget,
      );
    });

    testWidgets('shows English heading when language is en', (tester) async {
      final lp = LanguageProvider()..setLanguage(LanguageProvider.english);
      await tester.pumpWidget(_build(lp));
      expect(find.text('No RPP created yet'), findsOneWidget);
    });

    testWidgets('shows English hint text when language is en', (tester) async {
      final lp = LanguageProvider()..setLanguage(LanguageProvider.english);
      await tester.pumpWidget(_build(lp));
      expect(
        find.text('Click the "+" button to create your first RPP.'),
        findsOneWidget,
      );
    });

    testWidgets('is centered in the available space', (tester) async {
      await tester.pumpWidget(_build(langProvider));
      expect(find.byType(Center), findsWidgets);
    });
  });
}
