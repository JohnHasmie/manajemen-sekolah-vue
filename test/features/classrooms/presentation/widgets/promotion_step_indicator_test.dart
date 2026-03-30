// Tests for PromotionStepIndicator — the horizontal multi-step progress bar in the promotion wizard.
// Pure StatelessWidget. Verifies step labels, current step highlighting, completed step icons,
// and that it renders correctly for different step counts.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_step_indicator.dart';

Widget buildTestable(Widget child) {
  return MaterialApp(home: Scaffold(body: SizedBox(width: 400, child: child)));
}

const steps = ['Select', 'Students', 'Review', 'Summary'];

void main() {
  group('PromotionStepIndicator', () {
    // ── 1. Renders all step labels ─────────────────────────────────────────
    testWidgets('renders all step labels', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          PromotionStepIndicator(
            currentStep: 0,
            totalSteps: steps.length,
            steps: steps,
            primaryColor: Colors.blue,
          ),
        ),
      );

      for (final step in steps) {
        expect(find.text(step), findsOneWidget);
      }
    });

    // ── 2. Active step circle uses primaryColor ────────────────────────────
    testWidgets('active step circle uses primaryColor as background',
        (tester) async {
      const color = Colors.indigo;

      await tester.pumpWidget(
        buildTestable(
          PromotionStepIndicator(
            currentStep: 1,
            totalSteps: steps.length,
            steps: steps,
            primaryColor: color,
          ),
        ),
      );

      // There must be at least one Container whose decoration has color == primaryColor
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasActiveCircle = containers.any((c) {
        final dec = c.decoration;
        if (dec is BoxDecoration) return dec.color == color;
        return false;
      });
      expect(hasActiveCircle, isTrue);
    });

    // ── 3. Completed steps show a check icon ──────────────────────────────
    testWidgets('completed steps display a check icon', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          PromotionStepIndicator(
            currentStep: 2, // steps 0 and 1 are completed
            totalSteps: steps.length,
            steps: steps,
            primaryColor: Colors.green,
          ),
        ),
      );

      // Two steps (0 & 1) are completed — each shows Icons.check_rounded
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    });

    // ── 4. First step shows "1" in its circle ─────────────────────────────
    testWidgets('current step circle shows its step number', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          PromotionStepIndicator(
            currentStep: 0,
            totalSteps: steps.length,
            steps: steps,
            primaryColor: Colors.teal,
          ),
        ),
      );

      // Step numbers '2', '3', '4' appear (step 1 is active, displayed as number inside circle)
      expect(find.text('1'), findsOneWidget);
    });

    // ── 5. No check icons when on first step ──────────────────────────────
    testWidgets('no completed check icons on the first step', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          PromotionStepIndicator(
            currentStep: 0,
            totalSteps: steps.length,
            steps: steps,
            primaryColor: Colors.blue,
          ),
        ),
      );

      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    // ── 6. Renders without error for 2-step wizard ────────────────────────
    testWidgets('renders correctly for a minimal 2-step wizard', (tester) async {
      const twoSteps = ['Step 1', 'Step 2'];

      await tester.pumpWidget(
        buildTestable(
          PromotionStepIndicator(
            currentStep: 0,
            totalSteps: twoSteps.length,
            steps: twoSteps,
            primaryColor: Colors.purple,
          ),
        ),
      );

      expect(find.text('Step 1'), findsOneWidget);
      expect(find.text('Step 2'), findsOneWidget);
    });
  });
}
