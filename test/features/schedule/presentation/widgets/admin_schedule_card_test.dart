// Tests for AdminScheduleCard — the admin list view schedule entry card.
//
// Key scenarios:
// - Shows subject, teacher, class from schedule map
// - Shows dayLabel and timeLabel from constructor
// - isReadOnly=true hides edit/delete buttons
// - isReadOnly=false shows edit/delete buttons
// - onTap fires on card body tap
// - onEdit fires on edit button tap
// - onDelete fires on delete button tap
// - Falls back to 'No Subject'/'-' when map keys are missing
//
// Like testing a Vue card component: all data flows in via props.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/admin_schedule_card.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _schedule({
  String subject = 'Matematika',
  String teacher = 'Pak Ahmad',
  String className = 'Kelas 7A',
}) => {
  'mata_pelajaran_nama': subject,
  'guru_nama': teacher,
  'kelas_nama': className,
};

Widget _build({
  Map<String, dynamic>? schedule,
  int index = 0,
  bool isReadOnly = false,
  Color primaryColor = Colors.blue,
  String dayLabel = 'Senin',
  String timeLabel = '07:00 - 08:30',
  VoidCallback? onTap,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) {
  return MaterialApp(
    home: Scaffold(
      body: AdminScheduleCard(
        schedule: schedule ?? _schedule(),
        index: index,
        isReadOnly: isReadOnly,
        primaryColor: primaryColor,
        dayLabel: dayLabel,
        timeLabel: timeLabel,
        onTap: onTap ?? () {},
        onEdit: onEdit ?? () {},
        onDelete: onDelete ?? () {},
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AdminScheduleCard — content rendering', () {
    testWidgets('shows subject name from schedule map', (tester) async {
      await tester.pumpWidget(_build(schedule: _schedule(subject: 'Fisika')));
      expect(find.text('Fisika'), findsOneWidget);
    });

    testWidgets('shows teacher name in the inline status', (tester) async {
      // SS2 redesign: the inline status combines "<teacher> · <class>".
      await tester.pumpWidget(_build(schedule: _schedule(teacher: 'Bu Sari')));
      expect(find.text('Bu Sari · Kelas 7A'), findsOneWidget);
    });

    testWidgets('shows class name in the inline status', (tester) async {
      await tester.pumpWidget(
        _build(schedule: _schedule(className: 'Kelas 8B')),
      );
      expect(find.text('Pak Ahmad · Kelas 8B'), findsOneWidget);
    });

    testWidgets('shows dayLabel in the top meta', (tester) async {
      // SS2 redesign: the top meta combines "<day> · <time>".
      await tester.pumpWidget(_build(dayLabel: 'Selasa, Kamis'));
      expect(find.text('Selasa, Kamis · 07:00 - 08:30'), findsOneWidget);
    });

    testWidgets('shows timeLabel in the top meta', (tester) async {
      await tester.pumpWidget(_build(timeLabel: '09:00 - 10:30'));
      expect(find.text('Senin · 09:00 - 10:30'), findsOneWidget);
    });

    testWidgets('falls back to "No Subject" when mata_pelajaran_nama absent', (
      tester,
    ) async {
      await tester.pumpWidget(_build(schedule: {}));
      expect(find.text('No Subject'), findsOneWidget);
    });

    testWidgets('falls back to "-" for teacher when guru_nama absent', (
      tester,
    ) async {
      await tester.pumpWidget(_build(schedule: {'mata_pelajaran_nama': 'IPA'}));
      // Teacher and class both fall back to '-', combined in the status.
      expect(find.text('- · -'), findsOneWidget);
    });
  });

  group('AdminScheduleCard — isReadOnly', () {
    // The SS2 redesign replaced the inline edit/delete icon buttons with a
    // "Detail →" trailing CTA. Editing is now triggered via long-press
    // (wired to onEdit when not read-only); deletion happens off-card.

    testWidgets('never shows inline edit/delete icons', (tester) async {
      await tester.pumpWidget(_build(isReadOnly: false));
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.text('Detail →'), findsOneWidget);
    });
  });

  group('AdminScheduleCard — callbacks', () {
    testWidgets('fires onTap when card InkWell is tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_build(onTap: () => tapped = true));
      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });

    testWidgets('fires onEdit on long-press when NOT read-only', (
      tester,
    ) async {
      bool edited = false;
      await tester.pumpWidget(
        _build(isReadOnly: false, onEdit: () => edited = true),
      );
      await tester.longPress(find.text('Matematika'));
      expect(edited, isTrue);
    });

    testWidgets('does not fire onEdit on long-press when read-only', (
      tester,
    ) async {
      bool edited = false;
      await tester.pumpWidget(
        _build(isReadOnly: true, onEdit: () => edited = true),
      );
      await tester.longPress(find.text('Matematika'));
      expect(edited, isFalse);
    });
  });

  group('AdminScheduleCard — index-based color', () {
    testWidgets('renders with index 0 without crashing', (tester) async {
      await tester.pumpWidget(_build(index: 0));
      expect(find.byType(AdminScheduleCard), findsOneWidget);
    });

    testWidgets('renders with index 5 without crashing', (tester) async {
      await tester.pumpWidget(_build(index: 5));
      expect(find.byType(AdminScheduleCard), findsOneWidget);
    });
  });
}
