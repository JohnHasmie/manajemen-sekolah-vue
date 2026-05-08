// Tests for MenuItemCard — the dashboard navigation card.
// Like testing a Vue <MenuItemCard> component via mount() with various prop
// combos.
// Verifies title display, badge rendering, tap callback, emoji icon support,
// etc.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/menu_item_card.dart';

Widget buildTestable(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('MenuItemCard', () {
    // ── 1. Renders title ──────────────────────────────────────────────────
    testWidgets('displays the title text', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          MenuItemCard(
            title: 'Students',
            icon: Icons.people_outline,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Students'), findsOneWidget);
    });

    // ── 2. Renders IconData icon ───────────────────────────────────────────
    testWidgets('renders an IconData icon', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          MenuItemCard(
            title: 'Schedule',
            icon: Icons.calendar_today,
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    // ── 3. Renders emoji String icon ───────────────────────────────────────
    testWidgets('renders an emoji string icon', (tester) async {
      await tester.pumpWidget(
        buildTestable(MenuItemCard(title: 'Finance', icon: '💰', onTap: () {})),
      );

      expect(find.text('💰'), findsOneWidget);
    });

    // ── 4. onTap callback fires ────────────────────────────────────────────
    testWidgets('fires onTap when the card is tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildTestable(
          MenuItemCard(
            title: 'Reports',
            icon: Icons.bar_chart,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(InkWell).first);
      expect(tapped, isTrue);
    });

    // ── 5. Badge shown when badgeCount > 0 ────────────────────────────────
    testWidgets('shows badge text when badgeCount is positive', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          MenuItemCard(
            title: 'Announcements',
            icon: Icons.announcement,
            onTap: () {},
            badgeCount: 3,
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
    });

    // ── 6. Badge hidden when badgeCount is null ────────────────────────────
    testWidgets('hides badge when badgeCount is null', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          MenuItemCard(
            title: 'Grades',
            icon: Icons.grade,
            onTap: () {},
            badgeCount: null,
          ),
        ),
      );

      // Only the title text should be present; no numeric badge text
      expect(find.text('Grades'), findsOneWidget);
      // No extra badge container with a number
      expect(find.text('0'), findsNothing);
    });
  });
}
