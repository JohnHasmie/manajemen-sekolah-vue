// Widget tests for FilterChoiceChip.
// Pure StatelessWidget — no providers needed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/filter_choice_chip.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('FilterChoiceChip', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        _wrap(FilterChoiceChip(
          label: 'Semua',
          value: null,
          selectedValue: null,
          onSelected: () {},
          primaryColor: Colors.blue,
        )),
      );
      expect(find.text('Semua'), findsOneWidget);
    });

    testWidgets('is selected when value matches selectedValue', (tester) async {
      await tester.pumpWidget(
        _wrap(FilterChoiceChip(
          label: 'Aktif',
          value: 'active',
          selectedValue: 'active',
          onSelected: () {},
          primaryColor: Colors.blue,
        )),
      );
      final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
      expect(chip.selected, isTrue);
    });

    testWidgets('is not selected when value differs from selectedValue', (tester) async {
      await tester.pumpWidget(
        _wrap(FilterChoiceChip(
          label: 'Aktif',
          value: 'active',
          selectedValue: 'inactive',
          onSelected: () {},
          primaryColor: Colors.blue,
        )),
      );
      final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
      expect(chip.selected, isFalse);
    });

    testWidgets('"All" chip (null/null) is selected', (tester) async {
      await tester.pumpWidget(
        _wrap(FilterChoiceChip(
          label: 'Semua',
          value: null,
          selectedValue: null,
          onSelected: () {},
          primaryColor: Colors.blue,
        )),
      );
      final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
      expect(chip.selected, isTrue);
    });

    testWidgets('fires onSelected callback when tapped', (tester) async {
      bool fired = false;
      await tester.pumpWidget(
        _wrap(FilterChoiceChip(
          label: 'Laki-Laki',
          value: 'M',
          selectedValue: null,
          onSelected: () => fired = true,
          primaryColor: Colors.indigo,
        )),
      );
      await tester.tap(find.byType(ChoiceChip));
      expect(fired, isTrue);
    });

    testWidgets('selected label style uses bold font weight', (tester) async {
      await tester.pumpWidget(
        _wrap(FilterChoiceChip(
          label: 'Aktif',
          value: 'active',
          selectedValue: 'active',
          onSelected: () {},
          primaryColor: Colors.teal,
        )),
      );
      final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
      expect(chip.labelStyle?.fontWeight, FontWeight.bold);
    });
  });
}
