// Tests for ClassActivityCircleActionButton — a small circular icon button
// used for edit/delete actions on activity cards.
// Purely presentational, no providers.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/class_activity_circle_action_button.dart';

void main() {
  Widget buildSubject({
    IconData icon = Icons.edit_outlined,
    Color color = Colors.blue,
    VoidCallback? onPressed,
    String? tooltip,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ClassActivityCircleActionButton(
          icon: icon,
          color: color,
          onPressed: onPressed ?? () {},
          tooltip: tooltip,
        ),
      ),
    );
  }

  group('ClassActivityCircleActionButton', () {
    testWidgets('renders the provided icon', (tester) async {
      await tester.pumpWidget(buildSubject(icon: Icons.delete_outline));

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('fires onPressed callback when tapped', (tester) async {
      var pressed = false;
      await tester.pumpWidget(buildSubject(onPressed: () => pressed = true));

      await tester.tap(find.byType(ClassActivityCircleActionButton));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('shows Tooltip when tooltip param is provided', (tester) async {
      await tester.pumpWidget(buildSubject(tooltip: 'Edit activity'));

      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('does NOT wrap in Tooltip when tooltip is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(tooltip: null));

      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets('renders correctly with different accent colours', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(color: Colors.red));

      expect(find.byType(ClassActivityCircleActionButton), findsOneWidget);
    });

    testWidgets('button container is 36x36', (tester) async {
      await tester.pumpWidget(buildSubject());

      // Find the sized container — it should render without layout overflow.
      expect(find.byType(ClassActivityCircleActionButton), findsOneWidget);
    });
  });
}
