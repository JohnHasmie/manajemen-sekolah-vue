// Tests for GradeRecapSearchBar — a search input with clear button.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_search_bar.dart';

Widget _build({
  TextEditingController? controller,
  String hintText = 'Search...',
  ValueChanged<String>? onChanged,
  VoidCallback? onClear,
}) {
  final ctrl = controller ?? TextEditingController();
  return MaterialApp(
    home: Scaffold(
      body: GradeRecapSearchBar(
        controller: ctrl,
        hintText: hintText,
        onChanged: onChanged ?? (_) {},
        onClear: onClear ?? () {},
      ),
    ),
  );
}

void main() {
  group('GradeRecapSearchBar', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.byType(GradeRecapSearchBar), findsOneWidget);
    });

    testWidgets('shows hint text', (tester) async {
      await tester.pumpWidget(_build(hintText: 'Cari kelas...'));
      expect(find.text('Cari kelas...'), findsOneWidget);
    });

    testWidgets('shows search icon', (tester) async {
      await tester.pumpWidget(_build());
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.search),
        findsOneWidget,
      );
    });

    testWidgets('does not show clear button when text is empty', (tester) async {
      await tester.pumpWidget(_build());
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.clear),
        findsNothing,
      );
    });

    testWidgets('shows clear button when controller has text', (tester) async {
      final ctrl = TextEditingController(text: 'VII');
      await tester.pumpWidget(_build(controller: ctrl));
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.clear),
        findsOneWidget,
      );
    });

    testWidgets('onChanged fires as user types', (tester) async {
      final values = <String>[];
      await tester.pumpWidget(_build(onChanged: values.add));
      await tester.enterText(find.byType(TextField), 'VII');
      expect(values, contains('VII'));
    });

    testWidgets('onClear fires when clear button tapped', (tester) async {
      var cleared = false;
      final ctrl = TextEditingController(text: 'VII-A');
      await tester.pumpWidget(_build(controller: ctrl, onClear: () => cleared = true));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      expect(cleared, isTrue);
    });

    testWidgets('accepts Indonesian hint text', (tester) async {
      await tester.pumpWidget(_build(hintText: 'Cari mata pelajaran...'));
      expect(find.text('Cari mata pelajaran...'), findsOneWidget);
    });

    testWidgets('accepts English hint text', (tester) async {
      await tester.pumpWidget(_build(hintText: 'Search subjects...'));
      expect(find.text('Search subjects...'), findsOneWidget);
    });

    testWidgets('onChanged reports empty string when field cleared', (tester) async {
      final values = <String>[];
      await tester.pumpWidget(_build(onChanged: values.add));
      await tester.enterText(find.byType(TextField), 'ABC');
      await tester.enterText(find.byType(TextField), '');
      expect(values.last, '');
    });
  });
}
