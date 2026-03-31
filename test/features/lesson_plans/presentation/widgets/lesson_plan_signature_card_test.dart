// Tests for LessonPlanSignatureCard — the RPP signature block.
//
// Key scenarios:
// - Always renders "Kepala Sekolah" and "Guru Mata Pelajaran" columns
// - isAiGenerated=false: no AI notice text rendered
// - isAiGenerated=true: AI notice text is rendered
// - Renders dotted signature lines
//
// Purely presentational — no providers, no callbacks.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_signature_card.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _build({
  required bool isAiGenerated,
  Color primaryColor = Colors.blue,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LessonPlanSignatureCard(
            isAiGenerated: isAiGenerated,
            primaryColor: primaryColor,
          ),
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('LessonPlanSignatureCard — always-visible content', () {
    testWidgets('renders "Kepala Sekolah" label', (tester) async {
      await tester.pumpWidget(_build(isAiGenerated: false));
      expect(find.text('Kepala Sekolah'), findsOneWidget);
    });

    testWidgets('renders "Guru Mata Pelajaran" label', (tester) async {
      await tester.pumpWidget(_build(isAiGenerated: false));
      expect(find.text('Guru Mata Pelajaran'), findsOneWidget);
    });

    testWidgets('renders "Mengetahui" header for principal column',
        (tester) async {
      await tester.pumpWidget(_build(isAiGenerated: false));
      expect(find.text('Mengetahui'), findsOneWidget);
    });

    testWidgets('renders NIP lines for both signature columns', (tester) async {
      await tester.pumpWidget(_build(isAiGenerated: false));
      // Two columns, each has a NIP line
      expect(find.text('NIP ..............................'), findsWidgets);
    });
  });

  group('LessonPlanSignatureCard — isAiGenerated=false', () {
    testWidgets('does NOT show AI notice when isAiGenerated=false',
        (tester) async {
      await tester.pumpWidget(_build(isAiGenerated: false));
      expect(
        find.text('RPP ini digenerate secara otomatis menggunakan AI'),
        findsNothing,
      );
    });

    testWidgets('no Divider when isAiGenerated=false', (tester) async {
      await tester.pumpWidget(_build(isAiGenerated: false));
      expect(find.byType(Divider), findsNothing);
    });
  });

  group('LessonPlanSignatureCard — isAiGenerated=true', () {
    testWidgets('shows AI notice when isAiGenerated=true', (tester) async {
      await tester.pumpWidget(_build(isAiGenerated: true));
      expect(
        find.text('RPP ini digenerate secara otomatis menggunakan AI'),
        findsOneWidget,
      );
    });

    testWidgets('shows Divider above AI notice', (tester) async {
      await tester.pumpWidget(_build(isAiGenerated: true));
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  group('LessonPlanSignatureCard — renders without crashing', () {
    testWidgets('renders with different primaryColor', (tester) async {
      await tester.pumpWidget(
        _build(isAiGenerated: true, primaryColor: Colors.green),
      );
      expect(find.byType(LessonPlanSignatureCard), findsOneWidget);
    });
  });
}
