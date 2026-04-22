// Tests for AttendanceStatCard.
// This widget is purely presentational — it takes a label, count, color, and
// icon and renders them. No Riverpod or SharedPreferences involved.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_stat_card.dart';

void main() {
  // Helper: wraps the widget in a minimal MaterialApp + Scaffold so it has
  // the required BuildContext and can measure itself.
  Widget buildWidget({
    String label = 'Hadir',
    int count = 20,
    Color color = Colors.green,
    IconData icon = Icons.check_circle_outline,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AttendanceStatCard(
          label: label,
          count: count,
          color: color,
          icon: icon,
        ),
      ),
    );
  }

  group('AttendanceStatCard', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(AttendanceStatCard), findsOneWidget);
    });

    testWidgets('displays the count as text', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(count: 42));
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('displays the label text', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(label: 'Absent'));
      expect(find.text('Absent'), findsOneWidget);
    });

    testWidgets('renders the provided icon', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(icon: Icons.cancel_outlined));
      final iconFinder = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.cancel_outlined,
      );
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('count zero is displayed as "0"', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(count: 0));
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('color is applied to the icon widget', (
      WidgetTester tester,
    ) async {
      const testColor = Colors.red;
      await tester.pumpWidget(buildWidget(color: testColor, icon: Icons.close));
      final iconWidget = tester.widget<Icon>(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.close),
      );
      expect(iconWidget.color, equals(testColor));
    });
  });
}
