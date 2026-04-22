// Tests for AdminActivityDetailItem — icon badge + label + value metadata row.
// Purely presentational, no providers.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/admin_activity_detail_item.dart';

void main() {
  Widget buildSubject({
    IconData icon = Icons.calendar_today_outlined,
    String label = 'Hari',
    String value = 'Senin',
    Color primaryColor = Colors.indigo,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AdminActivityDetailItem(
          icon: icon,
          label: label,
          value: value,
          primaryColor: primaryColor,
        ),
      ),
    );
  }

  group('AdminActivityDetailItem', () {
    testWidgets('renders label and value text', (tester) async {
      await tester.pumpWidget(
        buildSubject(label: 'Tanggal', value: '15/06/2025'),
      );

      expect(find.text('Tanggal'), findsOneWidget);
      expect(find.text('15/06/2025'), findsOneWidget);
    });

    testWidgets('renders the provided icon', (tester) async {
      await tester.pumpWidget(buildSubject(icon: Icons.book_outlined));

      expect(find.byIcon(Icons.book_outlined), findsOneWidget);
    });

    testWidgets('renders correctly with different primary colours', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(primaryColor: Colors.teal));

      expect(find.byType(AdminActivityDetailItem), findsOneWidget);
    });

    testWidgets('label and value are in the widget tree', (tester) async {
      await tester.pumpWidget(buildSubject(label: 'Kelas', value: '10A'));

      final labelWidget = find.text('Kelas');
      final valueWidget = find.text('10A');
      expect(labelWidget, findsOneWidget);
      expect(valueWidget, findsOneWidget);
    });

    testWidgets('renders without error when value is empty', (tester) async {
      await tester.pumpWidget(buildSubject(value: ''));

      expect(find.byType(AdminActivityDetailItem), findsOneWidget);
    });
  });
}
