// Tests for HeroStatCell — the individual KPI tile inside the dashboard hero banner.
// Like testing a Vue sub-component in isolation via `mount(<HeroStatCell />)`.
// All props are passed directly; no providers or state needed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/hero_stat_cell.dart';

/// Wraps a widget in a minimal MaterialApp so Text styles resolve correctly.
Widget buildTestable(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('HeroStatCell', () {
    // ── 1. Renders value text ──────────────────────────────────────────────
    testWidgets('displays the value string', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const HeroStatCell(
            icon: Icons.people_outline,
            value: '120',
            label: 'Students',
          ),
        ),
      );

      expect(find.text('120'), findsOneWidget);
    });

    // ── 2. Renders label text ──────────────────────────────────────────────
    testWidgets('displays the label string', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const HeroStatCell(
            icon: Icons.people_outline,
            value: '42',
            label: 'Siswa',
          ),
        ),
      );

      expect(find.text('Siswa'), findsOneWidget);
    });

    // ── 3. Renders the icon ────────────────────────────────────────────────
    testWidgets('renders the provided icon', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const HeroStatCell(icon: Icons.class_, value: '5', label: 'Classes'),
        ),
      );

      expect(find.byIcon(Icons.class_), findsOneWidget);
    });

    // ── 4. Value text is white ─────────────────────────────────────────────
    testWidgets('value text uses white color', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const HeroStatCell(
            icon: Icons.people_outline,
            value: '99',
            label: 'Total',
          ),
        ),
      );

      final valueText = tester.widget<Text>(find.text('99'));
      expect(valueText.style?.color, Colors.white);
    });

    // ── 5. Icon is white ───────────────────────────────────────────────────
    testWidgets('icon is white', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const HeroStatCell(icon: Icons.school, value: '10', label: 'Schools'),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.school));
      expect(icon.color, Colors.white);
    });

    // ── 6. Layout is a Column ──────────────────────────────────────────────
    testWidgets('wraps content in a Column', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const HeroStatCell(
            icon: Icons.people_outline,
            value: '7',
            label: 'Guru',
          ),
        ),
      );

      // Column is the root widget returned by HeroStatCell.build
      expect(find.byType(Column), findsWidgets);
    });
  });
}
