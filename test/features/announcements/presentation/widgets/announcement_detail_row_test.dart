// Tests for AnnouncementDetailRow — icon + label + value metadata row
// used inside the announcement detail dialog. Purely presentational.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_detail_row.dart';

void main() {
  Widget buildSubject({
    IconData icon = Icons.person_outline,
    String label = 'Created by',
    String value = 'Admin',
    Color primaryColor = Colors.blue,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AnnouncementDetailRow(
          icon: icon,
          label: label,
          value: value,
          primaryColor: primaryColor,
        ),
      ),
    );
  }

  group('AnnouncementDetailRow', () {
    testWidgets('renders label and value text', (tester) async {
      await tester.pumpWidget(
        buildSubject(label: 'Target Role', value: 'Semua'),
      );

      expect(find.text('Target Role'), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
    });

    testWidgets('renders the provided icon', (tester) async {
      await tester.pumpWidget(buildSubject(icon: Icons.group_outlined));

      expect(find.byIcon(Icons.group_outlined), findsOneWidget);
    });

    testWidgets('renders without error for different primary colours', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(primaryColor: Colors.purple));

      expect(find.byType(AnnouncementDetailRow), findsOneWidget);
    });

    testWidgets('label and value are both in the widget tree', (tester) async {
      await tester.pumpWidget(buildSubject(label: 'Date', value: '01/06/2025'));

      expect(find.text('Date'), findsOneWidget);
      expect(find.text('01/06/2025'), findsOneWidget);
    });

    testWidgets('renders without error when value is empty', (tester) async {
      await tester.pumpWidget(buildSubject(value: ''));

      expect(find.byType(AnnouncementDetailRow), findsOneWidget);
    });
  });
}
