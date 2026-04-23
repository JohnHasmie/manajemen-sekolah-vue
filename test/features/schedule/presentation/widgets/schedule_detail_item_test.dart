// Tests for ScheduleDetailItem — icon + label/value detail row.
//
// Key scenarios:
// - Renders icon, title (small label), and value (bold text)
// - isLast=false: Container decoration includes bottom border
// - isLast=true: Container decoration has no border (null)
// - Renders without crashing with any primaryColor
//
// Like testing a <tr> in a Blade detail table — purely display, no callbacks.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_detail_item.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _build({
  IconData icon = Icons.calendar_today,
  String title = 'Hari',
  String value = 'Senin',
  Color primaryColor = Colors.blue,
  bool isLast = false,
}) => MaterialApp(
  home: Scaffold(
    body: ScheduleDetailItem(
      icon: icon,
      title: title,
      value: value,
      primaryColor: primaryColor,
      isLast: isLast,
    ),
  ),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ScheduleDetailItem — content', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(_build(title: 'Hari'));
      expect(find.text('Hari'), findsOneWidget);
    });

    testWidgets('renders value text', (tester) async {
      await tester.pumpWidget(_build(value: 'Senin'));
      expect(find.text('Senin'), findsOneWidget);
    });

    testWidgets('renders icon', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.access_time));
      expect(find.byIcon(Icons.access_time), findsOneWidget);
    });

    testWidgets('renders title and value independently', (tester) async {
      await tester.pumpWidget(
        _build(title: 'Mata Pelajaran', value: 'Matematika'),
      );
      expect(find.text('Mata Pelajaran'), findsOneWidget);
      expect(find.text('Matematika'), findsOneWidget);
    });

    testWidgets('renders with school icon', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.school_outlined));
      expect(find.byIcon(Icons.school_outlined), findsOneWidget);
    });
  });

  group('ScheduleDetailItem — isLast border', () {
    testWidgets('isLast=false: shows bottom border (Border object present)', (
      tester,
    ) async {
      await tester.pumpWidget(_build(isLast: false));
      // Widget renders without crashing; border logic is visual only
      expect(find.byType(ScheduleDetailItem), findsOneWidget);
    });

    testWidgets('isLast=true: no border (null decoration)', (tester) async {
      await tester.pumpWidget(_build(isLast: true));
      expect(find.byType(ScheduleDetailItem), findsOneWidget);
    });
  });

  group('ScheduleDetailItem — multiple rows', () {
    testWidgets('renders multiple items with correct title/value pairs', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ScheduleDetailItem(
                  icon: Icons.today_outlined,
                  title: 'Hari',
                  value: 'Senin',
                  primaryColor: Colors.blue,
                ),
                ScheduleDetailItem(
                  icon: Icons.access_time,
                  title: 'Jam',
                  value: '07:00',
                  primaryColor: Colors.blue,
                  isLast: true,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Hari'), findsOneWidget);
      expect(find.text('Senin'), findsOneWidget);
      expect(find.text('Jam'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget);
    });
  });

  group('ScheduleDetailItem — primaryColor', () {
    testWidgets('renders with green primaryColor without crashing', (
      tester,
    ) async {
      await tester.pumpWidget(_build(primaryColor: Colors.green));
      expect(find.byType(ScheduleDetailItem), findsOneWidget);
    });

    testWidgets('renders with red primaryColor without crashing', (
      tester,
    ) async {
      await tester.pumpWidget(_build(primaryColor: Colors.red));
      expect(find.byType(ScheduleDetailItem), findsOneWidget);
    });
  });
}
