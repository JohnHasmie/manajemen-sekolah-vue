// Tests for OverviewCard — the compact "Today's Overview" metric card.
// Like testing a Vue <OverviewCard> component with various prop combinations.
// Verifies value, title, subtitle text, icon, tap callback, and no-tap variant.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/overview_card.dart';

Widget buildTestable(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('OverviewCard', () {
    // ── 1. Displays value text ─────────────────────────────────────────────
    testWidgets('shows the value string', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          OverviewCard(
            title: 'Classes Today',
            value: '5',
            subtitle: 'Scheduled for today',
            icon: Icons.class_,
            accentColor: Colors.blue,
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
    });

    // ── 2. Displays title text ─────────────────────────────────────────────
    testWidgets('shows the title string', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          OverviewCard(
            title: 'Classes Today',
            value: '5',
            subtitle: 'Scheduled for today',
            icon: Icons.class_,
            accentColor: Colors.blue,
          ),
        ),
      );

      expect(find.text('Classes Today'), findsOneWidget);
    });

    // ── 3. Displays subtitle text ──────────────────────────────────────────
    testWidgets('shows the subtitle string', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          OverviewCard(
            title: 'Attendance',
            value: '95%',
            subtitle: 'Average this month',
            icon: Icons.check_circle_outline,
            accentColor: Colors.green,
          ),
        ),
      );

      expect(find.text('Average this month'), findsOneWidget);
    });

    // ── 4. Renders the icon ────────────────────────────────────────────────
    testWidgets('renders the provided icon', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          OverviewCard(
            title: 'Students',
            value: '120',
            subtitle: 'Enrolled students',
            icon: Icons.people_outline,
            accentColor: Colors.purple,
          ),
        ),
      );

      expect(find.byIcon(Icons.people_outline), findsOneWidget);
    });

    // ── 5. onTap callback fires when provided ─────────────────────────────
    testWidgets('fires onTap when the card is tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildTestable(
          OverviewCard(
            title: 'Tasks',
            value: '3',
            subtitle: 'Pending tasks',
            icon: Icons.task,
            accentColor: Colors.orange,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(InkWell).first);
      expect(tapped, isTrue);
    });

    // ── 6. Renders without error when onTap is null ────────────────────────
    testWidgets('renders correctly when onTap is null', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const OverviewCard(
            title: 'Events',
            value: '2',
            subtitle: 'Upcoming events',
            icon: Icons.event,
            accentColor: Colors.teal,
            onTap: null,
          ),
        ),
      );

      expect(find.text('Events'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });
  });
}
