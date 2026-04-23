// Tests for AttendanceQuickStatusButton.
// Purely presentational widget — no Riverpod or SharedPreferences needed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_quick_status_button.dart';

void main() {
  Widget buildWidget({
    String status = 'hadir',
    String label = 'H',
    Color color = Colors.green,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: AttendanceQuickStatusButton(
            status: status,
            label: label,
            color: color,
            isSelected: isSelected,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    );
  }

  group('AttendanceQuickStatusButton', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(AttendanceQuickStatusButton), findsOneWidget);
    });

    testWidgets('shows label text', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(label: 'A'));
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('label is white when selected', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(label: 'H', isSelected: true));
      final textWidget = tester.widget<Text>(find.text('H'));
      expect(textWidget.style?.color, equals(Colors.white));
    });

    testWidgets('label uses color when not selected', (
      WidgetTester tester,
    ) async {
      const testColor = Colors.red;
      await tester.pumpWidget(
        buildWidget(label: 'A', color: testColor, isSelected: false),
      );
      final textWidget = tester.widget<Text>(find.text('A'));
      expect(textWidget.style?.color, equals(testColor));
    });

    testWidgets('onTap callback fires when tapped', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(buildWidget(onTap: () => tapped = true));
      await tester.tap(find.byType(GestureDetector));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('container is 36x36', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AttendanceQuickStatusButton),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(container.constraints?.maxWidth, equals(36));
      expect(container.constraints?.maxHeight, equals(36));
    });
  });
}
