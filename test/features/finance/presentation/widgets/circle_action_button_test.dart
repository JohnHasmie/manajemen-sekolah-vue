// Tests for CircleActionButton — small rounded action button with icon.
//
// Key scenarios:
// - Renders icon
// - Fires onPressed on tap
// - Tooltip shown when tooltip param is provided
// - No Tooltip widget when tooltip is null
//
// Pure display widget — no state, no providers.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/circle_action_button.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _build({
  IconData icon = Icons.edit_rounded,
  Color color = Colors.blue,
  VoidCallback? onPressed,
  String? tooltip,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: CircleActionButton(
            icon: icon,
            color: color,
            onPressed: onPressed ?? () {},
            tooltip: tooltip,
          ),
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CircleActionButton — rendering', () {
    testWidgets('renders icon', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.edit_rounded));
      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    });

    testWidgets('renders delete icon', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.delete_rounded));
      expect(find.byIcon(Icons.delete_rounded), findsOneWidget);
    });

    testWidgets('renders autorenew icon', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.autorenew_rounded));
      expect(find.byIcon(Icons.autorenew_rounded), findsOneWidget);
    });
  });

  group('CircleActionButton — callbacks', () {
    testWidgets('fires onPressed when tapped', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(_build(onPressed: () => pressed = true));
      await tester.tap(find.byType(InkWell));
      expect(pressed, isTrue);
    });

    testWidgets('fires onPressed multiple times on multiple taps',
        (tester) async {
      int count = 0;
      await tester.pumpWidget(_build(onPressed: () => count++));
      await tester.tap(find.byType(InkWell));
      await tester.tap(find.byType(InkWell));
      expect(count, 2);
    });
  });

  group('CircleActionButton — tooltip', () {
    testWidgets('no Tooltip widget when tooltip is null', (tester) async {
      await tester.pumpWidget(_build(tooltip: null));
      expect(find.byType(Tooltip), findsNothing);
    });

    testWidgets('wraps in Tooltip when tooltip is provided', (tester) async {
      await tester.pumpWidget(_build(tooltip: 'Edit'));
      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('Tooltip has correct message', (tester) async {
      await tester.pumpWidget(_build(tooltip: 'Hapus'));
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Hapus');
    });
  });
}
