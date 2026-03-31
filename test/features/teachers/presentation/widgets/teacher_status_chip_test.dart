// Widget tests for TeacherStatusChip.
// Pure StatelessWidget — no providers needed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_status_chip.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('TeacherStatusChip', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        _wrap(TeacherStatusChip(
          label: 'Semua',
          value: null,
          selectedValue: null,
          onSelected: () {},
        )),
      );
      expect(find.text('Semua'), findsOneWidget);
    });

    testWidgets('chip is selected when value equals selectedValue', (tester) async {
      await tester.pumpWidget(
        _wrap(TeacherStatusChip(
          label: 'Aktif',
          value: 'active',
          selectedValue: 'active',
          onSelected: () {},
        )),
      );
      final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
      expect(chip.selected, isTrue);
    });

    testWidgets('chip is not selected when value differs from selectedValue', (tester) async {
      await tester.pumpWidget(
        _wrap(TeacherStatusChip(
          label: 'Aktif',
          value: 'active',
          selectedValue: 'inactive',
          onSelected: () {},
        )),
      );
      final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
      expect(chip.selected, isFalse);
    });

    testWidgets('"All" chip (null value) is selected when selectedValue is also null', (tester) async {
      await tester.pumpWidget(
        _wrap(TeacherStatusChip(
          label: 'Semua',
          value: null,
          selectedValue: null,
          onSelected: () {},
        )),
      );
      final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
      expect(chip.selected, isTrue);
    });

    testWidgets('fires onSelected callback when chip is tapped', (tester) async {
      bool fired = false;
      await tester.pumpWidget(
        _wrap(TeacherStatusChip(
          label: 'Aktif',
          value: 'active',
          selectedValue: null,
          onSelected: () => fired = true,
        )),
      );
      await tester.tap(find.byType(ChoiceChip));
      expect(fired, isTrue);
    });

    testWidgets('selected chip has bold font weight in label style', (tester) async {
      await tester.pumpWidget(
        _wrap(TeacherStatusChip(
          label: 'Aktif',
          value: 'active',
          selectedValue: 'active',
          onSelected: () {},
        )),
      );
      final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
      expect(chip.labelStyle?.fontWeight, FontWeight.w600);
    });
  });
}
