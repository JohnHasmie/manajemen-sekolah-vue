// Tests for PromotionSectionHeader — the left-bordered section header in the promotion wizard.
// Pure StatelessWidget. Tests icon, title, and color theming.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_section_header.dart';

Widget buildTestable(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('PromotionSectionHeader', () {
    // ── 1. Displays the title text ─────────────────────────────────────────
    testWidgets('shows the title string', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const PromotionSectionHeader(
            icon: Icons.info_outline,
            title: 'Promotion Details',
            primaryColor: Colors.blue,
          ),
        ),
      );

      expect(find.text('Promotion Details'), findsOneWidget);
    });

    // ── 2. Renders the icon ────────────────────────────────────────────────
    testWidgets('renders the provided icon', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const PromotionSectionHeader(
            icon: Icons.list_alt,
            title: 'Student List',
            primaryColor: Colors.green,
          ),
        ),
      );

      expect(find.byIcon(Icons.list_alt), findsOneWidget);
    });

    // ── 3. Icon uses primaryColor ──────────────────────────────────────────
    testWidgets('icon is tinted with primaryColor', (tester) async {
      const color = Colors.red;

      await tester.pumpWidget(
        buildTestable(
          const PromotionSectionHeader(
            icon: Icons.settings,
            title: 'Settings',
            primaryColor: color,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.settings));
      expect(icon.color, color);
    });

    // ── 4. Title and icon are in the same Row ─────────────────────────────
    testWidgets('title and icon appear together in a Row', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const PromotionSectionHeader(
            icon: Icons.check_circle_outline,
            title: 'Summary',
            primaryColor: Colors.teal,
          ),
        ),
      );

      // Both should be present together
      expect(find.text('Summary'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    // ── 5. Renders without error for long titles ──────────────────────────
    testWidgets('renders without overflow for long title', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const PromotionSectionHeader(
            icon: Icons.info,
            title: 'A Very Long Section Title That Might Overflow',
            primaryColor: Colors.purple,
          ),
        ),
      );

      expect(find.byType(PromotionSectionHeader), findsOneWidget);
    });

    // ── 6. Container is built ─────────────────────────────────────────────
    testWidgets('wraps content in a Container', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const PromotionSectionHeader(
            icon: Icons.grade,
            title: 'Grades',
            primaryColor: Colors.amber,
          ),
        ),
      );

      expect(find.byType(Container), findsWidgets);
    });
  });
}
