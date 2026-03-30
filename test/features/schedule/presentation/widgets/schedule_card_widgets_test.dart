// Tests for the three small schedule card widgets in schedule_card_widgets.dart:
//   ScheduleFilterSectionHeader — section header with icon + title
//   ScheduleInfoTag             — pill badge with icon + text
//   ScheduleCircleActionButton  — circular icon button
//
// Like testing Blade components: purely presentational, no providers needed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_card_widgets.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

// ---------------------------------------------------------------------------
// ScheduleFilterSectionHeader
// ---------------------------------------------------------------------------
void main() {
  group('ScheduleFilterSectionHeader', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(
        _wrap(ScheduleFilterSectionHeader(
          title: 'Kelas',
          icon: Icons.class_outlined,
        )),
      );
      expect(find.text('Kelas'), findsOneWidget);
    });

    testWidgets('renders leading icon', (tester) async {
      await tester.pumpWidget(
        _wrap(ScheduleFilterSectionHeader(
          title: 'Guru',
          icon: Icons.person_outline,
        )),
      );
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });

    testWidgets('renders without crashing for long title', (tester) async {
      await tester.pumpWidget(
        _wrap(ScheduleFilterSectionHeader(
          title: 'Filter Berdasarkan Hari dan Jam Pelajaran',
          icon: Icons.today_outlined,
        )),
      );
      expect(find.text('Filter Berdasarkan Hari dan Jam Pelajaran'),
          findsOneWidget);
    });

    testWidgets('does not render onPressed — purely decorative', (tester) async {
      await tester.pumpWidget(
        _wrap(ScheduleFilterSectionHeader(
          title: 'Semester',
          icon: Icons.calendar_month_outlined,
        )),
      );
      // No GestureDetector wrapping — just a Padding+Row
      expect(find.byType(GestureDetector), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // ScheduleInfoTag
  // -------------------------------------------------------------------------
  group('ScheduleInfoTag', () {
    testWidgets('renders icon and text', (tester) async {
      await tester.pumpWidget(
        _wrap(ScheduleInfoTag(
          icon: Icons.school_outlined,
          text: 'Kelas 7A',
        )),
      );
      expect(find.text('Kelas 7A'), findsOneWidget);
      expect(find.byIcon(Icons.school_outlined), findsOneWidget);
    });

    testWidgets('text has maxLines 1 and ellipsis overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(ScheduleInfoTag(
          icon: Icons.today_outlined,
          text: 'Nama kelas yang sangat panjang',
        )),
      );
      final textWidget =
          tester.widget<Text>(find.text('Nama kelas yang sangat panjang'));
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('renders with time range text', (tester) async {
      await tester.pumpWidget(
        _wrap(ScheduleInfoTag(
          icon: Icons.access_time_outlined,
          text: '07:00 - 08:30',
        )),
      );
      expect(find.text('07:00 - 08:30'), findsOneWidget);
    });

    testWidgets('renders with day label text', (tester) async {
      await tester.pumpWidget(
        _wrap(ScheduleInfoTag(
          icon: Icons.today_outlined,
          text: 'Senin, Rabu',
        )),
      );
      expect(find.text('Senin, Rabu'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // ScheduleCircleActionButton
  // -------------------------------------------------------------------------
  group('ScheduleCircleActionButton', () {
    testWidgets('renders icon', (tester) async {
      await tester.pumpWidget(
        _wrap(ScheduleCircleActionButton(
          icon: Icons.edit_outlined,
          color: Colors.blue,
          onPressed: () {},
        )),
      );
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('fires onPressed when tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(ScheduleCircleActionButton(
          icon: Icons.edit_outlined,
          color: Colors.blue,
          onPressed: () => tapped = true,
        )),
      );
      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isTrue);
    });

    testWidgets('delete button fires its own callback', (tester) async {
      bool deleteTapped = false;
      await tester.pumpWidget(
        _wrap(ScheduleCircleActionButton(
          icon: Icons.delete_outline,
          color: Colors.red,
          onPressed: () => deleteTapped = true,
        )),
      );
      await tester.tap(find.byType(GestureDetector));
      expect(deleteTapped, isTrue);
    });

    testWidgets('renders delete icon', (tester) async {
      await tester.pumpWidget(
        _wrap(ScheduleCircleActionButton(
          icon: Icons.delete_outline,
          color: Colors.red,
          onPressed: () {},
        )),
      );
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('different callback instances fire independently', (tester) async {
      int editCount = 0;
      int deleteCount = 0;

      await tester.pumpWidget(
        _wrap(Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScheduleCircleActionButton(
              icon: Icons.edit_outlined,
              color: Colors.blue,
              onPressed: () => editCount++,
            ),
            ScheduleCircleActionButton(
              icon: Icons.delete_outline,
              color: Colors.red,
              onPressed: () => deleteCount++,
            ),
          ],
        )),
      );

      final detectors = find.byType(GestureDetector);
      await tester.tap(detectors.at(0)); // edit
      await tester.tap(detectors.at(1)); // delete

      expect(editCount, 1);
      expect(deleteCount, 1);
    });
  });
}
