// Tests for GradeRecapEditableCell — a number TextField with history button.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_editable_cell.dart';

Widget _build({
  TextEditingController? controller,
  ValueChanged<double>? onChanged,
  VoidCallback? onHistoryTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: GradeRecapEditableCell(
        controller: controller ?? TextEditingController(),
        onChanged: onChanged ?? (_) {},
        onHistoryTap: onHistoryTap ?? () {},
      ),
    ),
  );
}

void main() {
  group('GradeRecapEditableCell', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.byType(GradeRecapEditableCell), findsOneWidget);
    });

    testWidgets('shows a TextField', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows history / bulk-select affordance icon',
        (tester) async {
      await tester.pumpWidget(_build());
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.keyboard_arrow_down_rounded,
        ),
        findsOneWidget,
      );
    });

    testWidgets('initial value from controller is displayed', (tester) async {
      final ctrl = TextEditingController(text: '85');
      await tester.pumpWidget(_build(controller: ctrl));
      expect(find.text('85'), findsOneWidget);
    });

    testWidgets('onChanged fires with parsed double when user types a number',
        (tester) async {
      final values = <double>[];
      await tester.pumpWidget(_build(onChanged: values.add));
      await tester.enterText(find.byType(TextField), '90');
      expect(values, contains(90.0));
    });

    testWidgets('onChanged returns 0.0 for non-numeric input', (tester) async {
      final values = <double>[];
      await tester.pumpWidget(_build(onChanged: values.add));
      await tester.enterText(find.byType(TextField), 'abc');
      expect(values, contains(0.0));
    });

    testWidgets('onChanged returns 0.0 when field is cleared', (tester) async {
      // enterText('') on an empty field fires no event; type a value first
      // then clear to trigger onChanged with an empty string → 0.0.
      final values = <double>[];
      await tester.pumpWidget(_build(onChanged: values.add));
      await tester.enterText(find.byType(TextField), '50');
      await tester.enterText(find.byType(TextField), '');
      expect(values, contains(0.0));
    });

    testWidgets('onChanged parses decimal values correctly', (tester) async {
      final values = <double>[];
      await tester.pumpWidget(_build(onChanged: values.add));
      await tester.enterText(find.byType(TextField), '87.5');
      expect(values, contains(87.5));
    });

    testWidgets('onHistoryTap fires when affordance icon is tapped',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(_build(onHistoryTap: () => tapped = true));
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('text field is constrained to 40px wide', (tester) async {
      await tester.pumpWidget(_build());
      // The first explicit SizedBox wraps the TextField.
      final sizedBox = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .firstWhere((s) => s.width == 40, orElse: () => const SizedBox());
      expect(sizedBox.width, 40);
    });

    testWidgets('keyboard type is numeric with decimal', (tester) async {
      await tester.pumpWidget(_build());
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(
        tf.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
    });

    testWidgets('text is center-aligned', (tester) async {
      await tester.pumpWidget(_build());
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.textAlign, TextAlign.center);
    });
  });
}
