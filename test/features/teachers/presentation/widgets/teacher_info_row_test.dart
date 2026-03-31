// Widget tests for TeacherInfoRow.
// Pure StatelessWidget — no providers needed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_info_row.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('TeacherInfoRow', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        _wrap(const TeacherInfoRow(label: 'Nama', value: 'Budi Santoso')),
      );
      expect(find.text('Nama'), findsOneWidget);
    });

    testWidgets('renders string value text', (tester) async {
      await tester.pumpWidget(
        _wrap(const TeacherInfoRow(label: 'Email', value: 'budi@example.com')),
      );
      expect(find.text('budi@example.com'), findsOneWidget);
    });

    testWidgets('shows "Tidak ada" when string value is empty', (tester) async {
      await tester.pumpWidget(
        _wrap(const TeacherInfoRow(label: 'NIP', value: '')),
      );
      expect(find.text('Tidak ada'), findsOneWidget);
    });

    testWidgets('renders each item as a chip when value is List<String>', (tester) async {
      await tester.pumpWidget(
        _wrap(TeacherInfoRow(
          label: 'Mata Pelajaran',
          value: <String>['Matematika', 'Fisika'],
        )),
      );
      expect(find.text('Matematika'), findsOneWidget);
      expect(find.text('Fisika'), findsOneWidget);
    });

    testWidgets('uses known icon for "Email" label', (tester) async {
      await tester.pumpWidget(
        _wrap(const TeacherInfoRow(label: 'Email', value: 'x@y.com')),
      );
      expect(find.byIcon(Icons.email), findsOneWidget);
    });

    testWidgets('falls back to Icons.info for unknown label', (tester) async {
      await tester.pumpWidget(
        _wrap(const TeacherInfoRow(label: 'Custom Field', value: 'something')),
      );
      expect(find.byIcon(Icons.info), findsOneWidget);
    });
  });
}
