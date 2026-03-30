// Tests for PromotionInfoRow — the labelled key-value display row in the promotion wizard.
// Pure StatelessWidget, no providers. Like testing a Vue <info-field> component.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_info_row.dart';

Widget buildTestable(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('PromotionInfoRow', () {
    // ── 1. Displays the label ──────────────────────────────────────────────
    testWidgets('shows the label text', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          PromotionInfoRow(
            icon: Icons.class_,
            label: 'Source Class',
            value: 'Grade 7A',
            primaryColor: Colors.blue,
          ),
        ),
      );

      expect(find.text('Source Class'), findsOneWidget);
    });

    // ── 2. Displays the value ──────────────────────────────────────────────
    testWidgets('shows the value text', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          PromotionInfoRow(
            icon: Icons.class_,
            label: 'Target Class',
            value: 'Grade 8A',
            primaryColor: Colors.green,
          ),
        ),
      );

      expect(find.text('Grade 8A'), findsOneWidget);
    });

    // ── 3. Renders the icon ────────────────────────────────────────────────
    testWidgets('renders the provided icon', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          PromotionInfoRow(
            icon: Icons.school,
            label: 'School',
            value: 'SMA Negeri 1',
            primaryColor: Colors.indigo,
          ),
        ),
      );

      expect(find.byIcon(Icons.school), findsOneWidget);
    });

    // ── 4. Icon uses the primaryColor ─────────────────────────────────────
    testWidgets('icon uses the primaryColor', (tester) async {
      const color = Colors.purple;

      await tester.pumpWidget(
        buildTestable(
          PromotionInfoRow(
            icon: Icons.person,
            label: 'Teacher',
            value: 'Budi',
            primaryColor: color,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.person));
      expect(icon.color, color);
    });

    // ── 5. Renders both label and value in the same widget tree ───────────
    testWidgets('label and value coexist in the same widget', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          PromotionInfoRow(
            icon: Icons.date_range,
            label: 'Academic Year',
            value: '2024/2025',
            primaryColor: Colors.teal,
          ),
        ),
      );

      expect(find.text('Academic Year'), findsOneWidget);
      expect(find.text('2024/2025'), findsOneWidget);
    });

    // ── 6. Renders without error for long value strings ───────────────────
    testWidgets('renders without overflow for a long value string',
        (tester) async {
      await tester.pumpWidget(
        buildTestable(
          PromotionInfoRow(
            icon: Icons.notes,
            label: 'Notes',
            value: 'This is a very long value string that tests overflow handling',
            primaryColor: Colors.orange,
          ),
        ),
      );

      expect(find.text('Notes'), findsOneWidget);
    });
  });
}
