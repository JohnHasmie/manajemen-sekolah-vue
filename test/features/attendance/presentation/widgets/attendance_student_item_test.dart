// Tests for AttendanceStudentItem — single canonical layout (Frame A).
// The descriptive/compact toggle was retired with the in-header density
// switch; this widget now ships only the full-word compact row.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_student_item.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

void main() {
  const testStudent = Student(
    id: 'stu-1',
    name: 'Budi Santoso',
    className: '7A',
    studentNumber: '20240001',
    address: 'Jl. Merdeka 1',
    guardianName: 'Pak Santoso',
    phoneNumber: '081234567890',
  );

  late LanguageProvider langProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
    langProvider = LanguageProvider();
  });

  Widget buildWidget({
    Student student = testStudent,
    String currentStatus = 'hadir',
    int index = 0,
    void Function(String, String)? onStatusChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AttendanceStudentItem(
            student: student,
            currentStatus: currentStatus,
            onStatusChanged: onStatusChanged ?? (_, __) {},
            languageProvider: langProvider,
            index: index,
          ),
        ),
      ),
    );
  }

  group('AttendanceStudentItem', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(AttendanceStudentItem), findsOneWidget);
    });

    testWidgets('shows student name', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('Budi Santoso'), findsOneWidget);
    });

    testWidgets('shows row number', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(index: 2));
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows full-word status labels (Frame A)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      // Frame A row drops Telat/Terlambat — picker handles those.
      for (final label in ['Hadir', 'Sakit', 'Izin', 'Alpa']) {
        expect(find.text(label), findsWidgets);
      }
    });

    testWidgets('onStatusChanged fires with correct studentId and status', (
      WidgetTester tester,
    ) async {
      String? capturedId;
      String? capturedStatus;

      await tester.pumpWidget(
        buildWidget(
          onStatusChanged: (id, status) {
            capturedId = id;
            capturedStatus = status;
          },
        ),
      );

      await tester.tap(find.text('Sakit'));
      await tester.pump();

      expect(capturedId, equals('stu-1'));
      expect(capturedStatus, equals('sakit'));
    });

    testWidgets('avatar shows first letter of student name', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('B'), findsOneWidget);
    });
  });
}
