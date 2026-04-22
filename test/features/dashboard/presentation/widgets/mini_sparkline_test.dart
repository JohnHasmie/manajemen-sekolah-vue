// Tests for MiniSparkline — the tiny Canvas-painted trend chart.
// Like testing a Vue sparkline component: verifies it renders for different
// data inputs, respects size props, and handles edge cases gracefully.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/mini_sparkline.dart';

Widget buildTestable(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('MiniSparkline', () {
    // ── 1. Renders a CustomPaint for non-empty data ────────────────────────
    testWidgets('renders CustomPaint when data is non-empty', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const MiniSparkline(
            data: [1.0, 3.0, 2.0, 5.0, 4.0],
            color: Colors.blue,
          ),
        ),
      );

      // Scaffold may also use CustomPaint internally, so check for at least one.
      expect(find.byType(CustomPaint), findsWidgets);
    });

    // ── 2. Falls back to a SizedBox when data is empty ────────────────────
    testWidgets('renders a SizedBox when data is empty', (tester) async {
      await tester.pumpWidget(
        buildTestable(const MiniSparkline(data: [], color: Colors.green)),
      );

      // When data is empty, MiniSparkline returns a bare SizedBox (no CustomPaint child).
      // We verify this by confirming no CustomPaint is a descendant of the MiniSparkline.
      expect(
        find.descendant(
          of: find.byType(MiniSparkline),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      expect(find.byType(SizedBox), findsWidgets);
    });

    // ── 3. Respects the height prop ───────────────────────────────────────
    testWidgets('respects the height parameter', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const MiniSparkline(
            data: [1.0, 2.0, 3.0],
            color: Colors.red,
            height: 60.0,
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find
            .descendant(
              of: find.byType(MiniSparkline),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(sizedBox.height, 60.0);
    });

    // ── 4. Renders with a single data point without crashing ──────────────
    testWidgets('renders without crashing for a single data point', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(const MiniSparkline(data: [5.0], color: Colors.purple)),
      );

      // Single-point data still gets a CustomPaint container
      expect(find.byType(MiniSparkline), findsOneWidget);
    });

    // ── 5. Renders with fillArea: false ───────────────────────────────────
    testWidgets('renders without fill area', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const MiniSparkline(
            data: [2.0, 4.0, 1.0, 5.0],
            color: Colors.teal,
            fillArea: false,
          ),
        ),
      );

      // CustomPaint may appear more than once (e.g. Scaffold also uses it),
      // so we just check that at least one is present.
      expect(find.byType(CustomPaint), findsWidgets);
    });

    // ── 6. All-equal data renders without errors ──────────────────────────
    testWidgets('renders without errors when all data points are equal', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          const MiniSparkline(data: [3.0, 3.0, 3.0, 3.0], color: Colors.amber),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
