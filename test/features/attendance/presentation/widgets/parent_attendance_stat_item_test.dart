// Tests for ParentAttendanceStatItem.
// Purely presentational — label, count, color. No Riverpod or SharedPreferences.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/parent_attendance_stat_item.dart';

void main() {
  Widget buildWidget({
    String label = 'Hadir',
    int count = 15,
    Color color = Colors.green,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ParentAttendanceStatItem(
            label: label,
            count: count,
            color: color,
          ),
        ),
      ),
    );
  }

  group('ParentAttendanceStatItem', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(ParentAttendanceStatItem), findsOneWidget);
    });

    testWidgets('shows count as text', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(count: 7));
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('shows label text', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(label: 'Terlambat'));
      expect(find.text('Terlambat'), findsOneWidget);
    });

    testWidgets('count text uses the provided color', (WidgetTester tester) async {
      const testColor = Colors.orange;
      await tester.pumpWidget(buildWidget(color: testColor, count: 3));
      final countText = tester.widget<Text>(find.text('3'));
      expect(countText.style?.color, equals(testColor));
    });

    testWidgets('count zero is shown as "0"', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(count: 0));
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('circle container is present', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      // The circle is a Container with BoxShape.circle decoration.
      final circleContainer = find.byWidgetPredicate((w) {
        if (w is Container) {
          final dec = w.decoration;
          if (dec is BoxDecoration) return dec.shape == BoxShape.circle;
        }
        return false;
      });
      expect(circleContainer, findsOneWidget);
    });
  });
}
