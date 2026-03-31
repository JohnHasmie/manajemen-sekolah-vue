// Tests for ActivityDetailRow — the icon+label+value metadata row.
// This widget is purely presentational: no providers, no state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_detail_row.dart';

void main() {
  // Helper: wraps the widget in the minimal Material scaffold required by tests.
  Widget buildSubject({
    IconData icon = Icons.calendar_today_outlined,
    String label = 'Date',
    String value = '01/01/2025',
    Color primaryColor = Colors.blue,
    Color? iconColor,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ActivityDetailRow(
          icon: icon,
          label: label,
          value: value,
          primaryColor: primaryColor,
          iconColor: iconColor,
        ),
      ),
    );
  }

  group('ActivityDetailRow', () {
    testWidgets('renders label and value text', (tester) async {
      await tester.pumpWidget(buildSubject(label: 'Teacher', value: 'Mr. Ali'));

      expect(find.text('Teacher'), findsOneWidget);
      expect(find.text('Mr. Ali'), findsOneWidget);
    });

    testWidgets('renders the provided icon', (tester) async {
      await tester.pumpWidget(buildSubject(icon: Icons.person_outline));

      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });

    testWidgets('uses primaryColor when iconColor is null', (tester) async {
      // The widget should still render without errors when iconColor is omitted.
      await tester.pumpWidget(
        buildSubject(primaryColor: Colors.green, iconColor: null),
      );

      expect(find.byType(ActivityDetailRow), findsOneWidget);
    });

    testWidgets('uses iconColor override when provided', (tester) async {
      // Both paths must build without error.
      await tester.pumpWidget(
        buildSubject(primaryColor: Colors.blue, iconColor: Colors.red),
      );

      expect(find.byType(ActivityDetailRow), findsOneWidget);
    });

    testWidgets('icon and text are in the same Row', (tester) async {
      await tester.pumpWidget(buildSubject(label: 'Subject', value: 'Math'));

      // The outer Row should exist and contain our texts.
      expect(find.byType(Row), findsWidgets);
      expect(find.text('Subject'), findsOneWidget);
    });

    testWidgets('renders with empty value without crashing', (tester) async {
      await tester.pumpWidget(buildSubject(label: 'Notes', value: ''));

      expect(find.text('Notes'), findsOneWidget);
    });
  });
}
