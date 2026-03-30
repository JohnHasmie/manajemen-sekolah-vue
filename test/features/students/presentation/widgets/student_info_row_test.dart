// Widget tests for StudentInfoRow.
// Pure StatelessWidget — no providers needed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_info_row.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('StudentInfoRow', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        _wrap(StudentInfoRow(
          label: 'Kelas',
          value: '10A',
          primaryColor: Colors.blue,
        )),
      );
      expect(find.text('Kelas'), findsOneWidget);
    });

    testWidgets('renders value text', (tester) async {
      await tester.pumpWidget(
        _wrap(StudentInfoRow(
          label: 'NIS',
          value: '12345',
          primaryColor: Colors.teal,
        )),
      );
      expect(find.text('12345'), findsOneWidget);
    });

    testWidgets('shows "Tidak ada" when value is empty', (tester) async {
      await tester.pumpWidget(
        _wrap(StudentInfoRow(
          label: 'Alamat',
          value: '',
          primaryColor: Colors.teal,
        )),
      );
      expect(find.text('Tidak ada'), findsOneWidget);
    });

    testWidgets('uses known icon for "Kelas" label when no icon provided', (tester) async {
      await tester.pumpWidget(
        _wrap(StudentInfoRow(
          label: 'Kelas',
          value: '10B',
          primaryColor: Colors.blue,
        )),
      );
      expect(find.byIcon(Icons.school), findsOneWidget);
    });

    testWidgets('uses explicit icon parameter when supplied', (tester) async {
      await tester.pumpWidget(
        _wrap(StudentInfoRow(
          label: 'Custom',
          value: 'data',
          primaryColor: Colors.purple,
          icon: Icons.star,
        )),
      );
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('value text maxLines is 3 when isMultiline is true', (tester) async {
      await tester.pumpWidget(
        _wrap(StudentInfoRow(
          label: 'Catatan',
          value: 'Long text',
          primaryColor: Colors.blue,
          isMultiline: true,
        )),
      );
      final valueText = tester.widget<Text>(find.text('Long text'));
      expect(valueText.maxLines, 3);
    });
  });
}
