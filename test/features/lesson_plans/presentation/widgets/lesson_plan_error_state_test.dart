// Tests for LessonPlanErrorState — shown on API load failure for RPP list.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_error_state.dart';

Widget _build({
  LanguageProvider? lp,
  String? errorMessage,
  VoidCallback? onRetry,
  Color primaryColor = Colors.blue,
}) {
  final provider = lp ?? LanguageProvider();
  return MaterialApp(
    home: Scaffold(
      body: LessonPlanErrorState(
        languageProvider: provider,
        errorMessage: errorMessage,
        onRetry: onRetry ?? () {},
        primaryColor: primaryColor,
      ),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
  });

  group('LessonPlanErrorState', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.byType(LessonPlanErrorState), findsOneWidget);
    });

    testWidgets('shows error icon', (tester) async {
      await tester.pumpWidget(_build());
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.error_outline_rounded,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows Indonesian heading when language is id', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.text('Terjadi Kesalahan'), findsOneWidget);
    });

    testWidgets('shows English heading when language is en', (tester) async {
      final lp = LanguageProvider()..setLanguage(LanguageProvider.english);
      await tester.pumpWidget(_build(lp: lp));
      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('displays the errorMessage', (tester) async {
      await tester.pumpWidget(_build(errorMessage: 'Connection refused'));
      expect(find.text('Connection refused'), findsOneWidget);
    });

    testWidgets('displays empty string when errorMessage is null', (tester) async {
      await tester.pumpWidget(_build(errorMessage: null));
      // Should not crash; empty text widget rendered
      expect(find.byType(LessonPlanErrorState), findsOneWidget);
    });

    testWidgets('shows Indonesian retry button label when language is id',
        (tester) async {
      await tester.pumpWidget(_build());
      expect(find.text('Coba Lagi'), findsOneWidget);
    });

    testWidgets('shows English retry button label when language is en',
        (tester) async {
      final lp = LanguageProvider()..setLanguage(LanguageProvider.english);
      await tester.pumpWidget(_build(lp: lp));
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('onRetry fires when retry button is tapped', (tester) async {
      var retried = false;
      await tester.pumpWidget(_build(onRetry: () => retried = true));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('retry button uses primaryColor', (tester) async {
      await tester.pumpWidget(_build(primaryColor: Colors.teal));
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final style = btn.style?.backgroundColor?.resolve({});
      expect(style, Colors.teal);
    });

    testWidgets('shows long error message without overflow crash', (tester) async {
      await tester.pumpWidget(_build(
        errorMessage:
            'An unexpected error occurred while loading RPP data from the server. Please check your internet connection and try again.',
      ));
      expect(find.byType(LessonPlanErrorState), findsOneWidget);
    });
  });
}
