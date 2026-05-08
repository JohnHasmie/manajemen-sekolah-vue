// Tests for AttendanceStudentCard — a student row with optional editing
// buttons.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_student_card.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

Student _makeStudent({
  String name = 'Ahmad Fauzi',
  String studentNumber = '2024001',
}) => Student(
  id: 's1',
  name: name,
  className: 'VII-A',
  studentNumber: studentNumber,
  address: 'Jl. Merdeka 1',
  guardianName: 'Bapak Fauzi',
  phoneNumber: '081234567890',
);

Widget _build({
  Student? student,
  int index = 0,
  String currentStatus = 'hadir',
  String statusText = 'Hadir',
  Color statusColor = Colors.green,
  bool isEditing = false,
  String? tempStatus,
  void Function(String)? onStatusChanged,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: AttendanceStudentCard(
        student: student ?? _makeStudent(),
        index: index,
        currentStatus: currentStatus,
        statusText: statusText,
        statusColor: statusColor,
        isEditing: isEditing,
        tempStatus: tempStatus,
        onStatusChanged: onStatusChanged ?? (_) {},
      ),
    ),
  ),
);

void main() {
  group('AttendanceStudentCard', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.byType(AttendanceStudentCard), findsOneWidget);
    });

    testWidgets('displays student name', (tester) async {
      await tester.pumpWidget(
        _build(student: _makeStudent(name: 'Siti Rahayu')),
      );
      expect(find.text('Siti Rahayu'), findsOneWidget);
    });

    testWidgets('displays NIS with prefix', (tester) async {
      await tester.pumpWidget(
        _build(student: _makeStudent(studentNumber: '20240042')),
      );
      expect(find.text('NIS: 20240042'), findsOneWidget);
    });

    testWidgets('displays status text badge', (tester) async {
      await tester.pumpWidget(_build(statusText: 'Sakit'));
      expect(find.text('Sakit'), findsOneWidget);
    });

    testWidgets('shows avatar initial from student name', (tester) async {
      await tester.pumpWidget(_build(student: _makeStudent(name: 'Budi')));
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('shows "?" avatar for empty name', (tester) async {
      await tester.pumpWidget(_build(student: _makeStudent(name: '')));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('does NOT show quick-status buttons when not editing', (
      tester,
    ) async {
      // Use a student name that doesn't start with H/S/I/A to avoid avatar
      // initial clashing with quick-status button labels.
      await tester.pumpWidget(
        _build(student: _makeStudent(name: 'Budi Santoso'), isEditing: false),
      );
      expect(find.text('H'), findsNothing);
      expect(find.text('S'), findsNothing);
      expect(find.text('I'), findsNothing);
      expect(find.text('A'), findsNothing);
    });

    testWidgets('shows four quick-status buttons when isEditing is true', (
      tester,
    ) async {
      // Use a student name whose initial doesn't clash with button labels.
      await tester.pumpWidget(
        _build(student: _makeStudent(name: 'Budi Santoso'), isEditing: true),
      );
      expect(find.text('H'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
      expect(find.text('I'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('tapping H button calls onStatusChanged with "hadir"', (
      tester,
    ) async {
      String? changed;
      await tester.pumpWidget(
        _build(isEditing: true, onStatusChanged: (s) => changed = s),
      );
      await tester.tap(find.text('H'));
      await tester.pump();
      expect(changed, 'hadir');
    });

    testWidgets('tapping S button calls onStatusChanged with "sakit"', (
      tester,
    ) async {
      String? changed;
      await tester.pumpWidget(
        _build(isEditing: true, onStatusChanged: (s) => changed = s),
      );
      await tester.tap(find.text('S'));
      await tester.pump();
      expect(changed, 'sakit');
    });

    testWidgets('tapping I button calls onStatusChanged with "izin"', (
      tester,
    ) async {
      String? changed;
      await tester.pumpWidget(
        _build(isEditing: true, onStatusChanged: (s) => changed = s),
      );
      await tester.tap(find.text('I'));
      await tester.pump();
      expect(changed, 'izin');
    });

    testWidgets('tapping A button calls onStatusChanged with "alpha"', (
      tester,
    ) async {
      String? changed;
      await tester.pumpWidget(
        _build(
          student: _makeStudent(name: 'Budi Santoso'),
          isEditing: true,
          onStatusChanged: (s) => changed = s,
        ),
      );
      await tester.tap(find.text('A'));
      await tester.pump();
      expect(changed, 'alpha');
    });

    testWidgets('different index values render without crashing', (
      tester,
    ) async {
      for (final i in [0, 1, 5, 10, 99]) {
        await tester.pumpWidget(_build(index: i));
        expect(find.byType(AttendanceStudentCard), findsOneWidget);
      }
    });

    testWidgets('long student name is truncated with ellipsis', (tester) async {
      await tester.pumpWidget(
        _build(
          student: _makeStudent(
            name: 'Muhammad Abdullah Bin Hassan Al-Rashidi',
          ),
        ),
      );
      final nameText = tester.widget<Text>(
        find.text('Muhammad Abdullah Bin Hassan Al-Rashidi'),
      );
      expect(nameText.overflow, TextOverflow.ellipsis);
    });
  });
}
