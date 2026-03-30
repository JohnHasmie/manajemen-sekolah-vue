// Tests for ParentAttendanceInfoTag — a small icon+text pill badge.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/parent_attendance_info_tag.dart';

Widget _build({
  required IconData icon,
  required String text,
  Color? tagColor,
}) =>
    MaterialApp(
      home: Scaffold(
        body: ParentAttendanceInfoTag(icon: icon, text: text, tagColor: tagColor),
      ),
    );

void main() {
  group('ParentAttendanceInfoTag', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.calendar_today_outlined, text: '10 Mar 2025'));
      expect(find.byType(ParentAttendanceInfoTag), findsOneWidget);
    });

    testWidgets('displays text label', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.access_time_outlined, text: 'Jam 1'));
      expect(find.text('Jam 1'), findsOneWidget);
    });

    testWidgets('displays the icon', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.calendar_today_outlined, text: 'date'));
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.calendar_today_outlined),
        findsOneWidget,
      );
    });

    testWidgets('renders without tagColor (uses default slate color)', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.star, text: 'Default'));
      // Should not crash without tagColor
      expect(find.byType(ParentAttendanceInfoTag), findsOneWidget);
    });

    testWidgets('renders with custom tagColor', (tester) async {
      await tester.pumpWidget(_build(
        icon: Icons.check_circle_outline,
        text: 'Hadir',
        tagColor: Colors.green,
      ));
      expect(find.byType(ParentAttendanceInfoTag), findsOneWidget);
      expect(find.text('Hadir'), findsOneWidget);
    });

    testWidgets('icon size is 10', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.access_time_outlined, text: 'Jam 2'));
      final icon = tester.widget<Icon>(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.access_time_outlined),
      );
      expect(icon.size, 10);
    });

    testWidgets('text size is 10', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.star, text: 'Label'));
      final text = tester.widget<Text>(find.text('Label'));
      expect(text.style?.fontSize, 10);
    });

    testWidgets('shows empty string without crashing', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.star, text: ''));
      expect(find.byType(ParentAttendanceInfoTag), findsOneWidget);
    });

    testWidgets('can render multiple tags in a row', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: [
                ParentAttendanceInfoTag(icon: Icons.calendar_today_outlined, text: '10 Mar'),
                ParentAttendanceInfoTag(icon: Icons.access_time_outlined, text: 'Jam 3'),
                ParentAttendanceInfoTag(
                  icon: Icons.check_circle_outline,
                  text: 'Hadir',
                  tagColor: Colors.green,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(ParentAttendanceInfoTag), findsNWidgets(3));
    });
  });
}
