// Tests for LessonPlanMetaRow — label + TextField two-column row.
//
// Key scenarios:
// - Renders label text on the left
// - Renders ' : ' separator
// - Renders TextField controlled by the passed TextEditingController
// - Controller text appears in the TextField
// - Entering text updates the controller
//
// Like testing a Vue <FormRow label="..."> — purely display with one input.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_meta_row.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _build({
  required String label,
  required TextEditingController controller,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: LessonPlanMetaRow(label: label, controller: controller),
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('LessonPlanMetaRow — rendering', () {
    testWidgets('renders label text', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(_build(
        label: 'Satuan Pendidikan',
        controller: ctrl,
      ));
      expect(find.text('Satuan Pendidikan'), findsOneWidget);
    });

    testWidgets('renders separator " : "', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(_build(label: 'Kelas', controller: ctrl));
      expect(find.text(' : '), findsOneWidget);
    });

    testWidgets('renders TextField', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(_build(label: 'Mata Pelajaran', controller: ctrl));
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('TextField shows initial controller text', (tester) async {
      final ctrl = TextEditingController(text: 'SMP Negeri 1');
      await tester.pumpWidget(_build(label: 'Sekolah', controller: ctrl));
      expect(find.text('SMP Negeri 1'), findsOneWidget);
    });
  });

  group('LessonPlanMetaRow — input interaction', () {
    testWidgets('entering text updates controller', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(_build(label: 'Kelas', controller: ctrl));
      await tester.enterText(find.byType(TextField), 'Kelas 7A');
      expect(ctrl.text, 'Kelas 7A');
    });

    testWidgets('different labels render independently', (tester) async {
      final ctrl1 = TextEditingController(text: 'SMP Merdeka');
      final ctrl2 = TextEditingController(text: 'Kelas 8B');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                LessonPlanMetaRow(label: 'Sekolah', controller: ctrl1),
                LessonPlanMetaRow(label: 'Kelas', controller: ctrl2),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Sekolah'), findsOneWidget);
      expect(find.text('Kelas'), findsOneWidget);
      expect(find.text('SMP Merdeka'), findsOneWidget);
      expect(find.text('Kelas 8B'), findsOneWidget);
    });
  });
}
