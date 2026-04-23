// Tests for the EmptyState widget.
//
// Verifies that title, subtitle, icon, and optional button render and behave
// as expected. No Riverpod dependencies — plain widget tests.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';

void main() {
  group('EmptyState', () {
    // Helper that wraps EmptyState in the standard MaterialApp + Scaffold shell.
    Widget buildWidget({
      String title = 'No Data',
      String subtitle = 'Nothing to show here.',
      IconData icon = Icons.people_outline,
      String? buttonText,
      VoidCallback? onPressed,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: EmptyState(
            title: title,
            subtitle: subtitle,
            icon: icon,
            buttonText: buttonText,
            onPressed: onPressed,
          ),
        ),
      );
    }

    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      // If no exception is thrown, the widget tree built successfully.
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('displays the title text', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(title: 'No Students Found'));
      expect(find.text('No Students Found'), findsOneWidget);
    });

    testWidgets('displays the subtitle text', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildWidget(subtitle: 'Add a student to get started.'),
      );
      expect(find.text('Add a student to get started.'), findsOneWidget);
    });

    testWidgets('renders the provided icon', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(icon: Icons.school));
      // The icon should appear inside an Icon widget in the tree.
      final iconFinder = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.school,
      );
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('does not show a button when buttonText is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget(buttonText: null));
      // No ElevatedButton should be in the tree when the button is omitted.
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('default icon is people_outline when none supplied', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(title: 'T', subtitle: 'S'),
          ),
        ),
      );
      final iconFinder = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.people_outline,
      );
      expect(iconFinder, findsOneWidget);
    });
  });
}
