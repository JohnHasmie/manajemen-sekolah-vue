// Tests for QuickActionButton — the horizontal-scroll shortcut button on the dashboard.
// Like testing a Vue <QuickAction> in isolation: label text, icon, tap callback, badge.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/quick_action_button.dart';

Widget buildTestable(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('QuickActionButton', () {
    // ── 1. Shows label text ────────────────────────────────────────────────
    testWidgets('displays the label', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          QuickActionButton(
            label: 'Attendance',
            icon: Icons.check_circle_outline,
            onTap: () {},
            color: Colors.blue,
          ),
        ),
      );

      expect(find.text('Attendance'), findsOneWidget);
    });

    // ── 2. Shows the icon ──────────────────────────────────────────────────
    testWidgets('renders the icon', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          QuickActionButton(
            label: 'Grades',
            icon: Icons.grade,
            onTap: () {},
            color: Colors.green,
          ),
        ),
      );

      expect(find.byIcon(Icons.grade), findsOneWidget);
    });

    // ── 3. onTap fires ─────────────────────────────────────────────────────
    testWidgets('fires onTap when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildTestable(
          QuickActionButton(
            label: 'Schedule',
            icon: Icons.schedule,
            onTap: () => tapped = true,
            color: Colors.orange,
          ),
        ),
      );

      await tester.tap(find.byType(InkWell).first);
      expect(tapped, isTrue);
    });

    // ── 4. Badge visible when badgeCount > 0 ──────────────────────────────
    testWidgets('shows badge text when badgeCount is positive', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          QuickActionButton(
            label: 'Messages',
            icon: Icons.message,
            onTap: () {},
            color: Colors.purple,
            badgeCount: 5,
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
    });

    // ── 5. Badge shows "9+" when count exceeds 9 ──────────────────────────
    testWidgets('shows "9+" when badgeCount is > 9', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          QuickActionButton(
            label: 'Notifications',
            icon: Icons.notifications,
            onTap: () {},
            color: Colors.red,
            badgeCount: 12,
          ),
        ),
      );

      expect(find.text('9+'), findsOneWidget);
    });

    // ── 6. No badge shown when badgeCount is null ─────────────────────────
    testWidgets('no badge rendered when badgeCount is null', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          QuickActionButton(
            label: 'Finance',
            icon: Icons.attach_money,
            onTap: () {},
            color: Colors.teal,
          ),
        ),
      );

      // Only one text widget — the label
      expect(find.text('Finance'), findsOneWidget);
      expect(find.text('9+'), findsNothing);
    });
  });
}
