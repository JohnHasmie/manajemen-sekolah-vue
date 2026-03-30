// Tests for the ErrorScreen widget.
//
// Verifies error message display, the retry button label, and that the
// onRetry callback fires when the button is tapped. No Riverpod dependencies.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';

void main() {
  group('ErrorScreen', () {
    Widget buildWidget({
      String errorMessage = 'Something went wrong.',
      VoidCallback? onRetry,
    }) {
      return MaterialApp(
        home: ErrorScreen(
          errorMessage: errorMessage,
          onRetry: onRetry ?? () {},
        ),
      );
    }

    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(ErrorScreen), findsOneWidget);
    });

    testWidgets('displays the error message text', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildWidget(errorMessage: 'Network connection failed.'),
      );
      expect(find.text('Network connection failed.'), findsOneWidget);
    });

    testWidgets('shows the fixed header text', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      // The widget always shows this Indonesian error header.
      expect(find.text('Oops! Terjadi Kesalahan'), findsOneWidget);
    });

    testWidgets('shows the retry button with label "Coba Lagi"', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('Coba Lagi'), findsOneWidget);
    });

    testWidgets('fires onRetry callback when retry button is tapped', (
      WidgetTester tester,
    ) async {
      int callCount = 0;
      await tester.pumpWidget(buildWidget(onRetry: () => callCount++));
      await tester.tap(find.text('Coba Lagi'));
      await tester.pump();
      expect(callCount, 1);
    });

    testWidgets('displays the error outline icon', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      final iconFinder = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.error_outline_rounded,
      );
      expect(iconFinder, findsOneWidget);
    });
  });
}
