// Tests for PromotionStatRow — the coloured stat display row in the promotion wizard.
// Pure StatelessWidget with icon, label, value, and color. Like testing a Vue <stat-badge>.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_stat_row.dart';

Widget buildTestable(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('PromotionStatRow', () {
    // ── 1. Shows the label text ────────────────────────────────────────────
    testWidgets('displays the label string', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          PromotionStatRow(
            icon: Icons.people,
            label: 'Total Students',
            value: '30',
            color: Colors.blue,
          ),
        ),
      );

      expect(find.text('Total Students'), findsOneWidget);
    });

    // ── 2. Shows the value text ────────────────────────────────────────────
    testWidgets('displays the value string', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          PromotionStatRow(
            icon: Icons.check,
            label: 'Eligible',
            value: '25',
            color: Colors.green,
          ),
        ),
      );

      expect(find.text('25'), findsOneWidget);
    });

    // ── 3. Renders the icon ────────────────────────────────────────────────
    testWidgets('renders the provided icon', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          PromotionStatRow(
            icon: Icons.trending_up,
            label: 'Promoted',
            value: '20',
            color: Colors.purple,
          ),
        ),
      );

      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });

    // ── 4. Icon uses the color prop ────────────────────────────────────────
    testWidgets('icon is tinted with the color prop', (tester) async {
      const statColor = Colors.orange;

      await tester.pumpWidget(
        buildTestable(
          PromotionStatRow(
            icon: Icons.warning,
            label: 'Not Promoted',
            value: '5',
            color: statColor,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.warning));
      expect(icon.color, statColor);
    });

    // ── 5. Value text uses the color prop ─────────────────────────────────
    testWidgets('value text is tinted with the color prop', (tester) async {
      const statColor = Colors.red;

      await tester.pumpWidget(
        buildTestable(
          PromotionStatRow(
            icon: Icons.block,
            label: 'Retained',
            value: '10',
            color: statColor,
          ),
        ),
      );

      final valueText = tester.widget<Text>(find.text('10'));
      expect(valueText.style?.color, statColor);
    });

    // ── 6. Label and value coexist in the same row ────────────────────────
    testWidgets('label and value both visible in the same widget',
        (tester) async {
      await tester.pumpWidget(
        buildTestable(
          PromotionStatRow(
            icon: Icons.people,
            label: 'All Students',
            value: '40',
            color: Colors.teal,
          ),
        ),
      );

      expect(find.text('All Students'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
    });
  });
}
