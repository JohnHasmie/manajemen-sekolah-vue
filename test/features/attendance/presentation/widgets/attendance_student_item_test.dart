// Tests for AttendanceStudentItem.
// The widget needs a LanguageProvider, which reads from SharedPreferences, so
// we initialise PreferencesService via mock values before each test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_student_item.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

void main() {
  // Minimal Student fixture — all required fields satisfied.
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

    testWidgets('shows student NIS', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('NIS: 20240001'), findsOneWidget);
    });

    testWidgets('shows all five quick-status button labels',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      for (final label in ['H', 'T', 'S', 'I', 'A']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('onStatusChanged fires with correct studentId and status',
        (WidgetTester tester) async {
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

      // Tap the "S" (sakit) button.
      await tester.tap(find.text('S'));
      await tester.pump();

      expect(capturedId, equals('stu-1'));
      expect(capturedStatus, equals('sakit'));
    });

    testWidgets('avatar shows first letter of student name',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      // 'B' is the uppercase first letter of "Budi Santoso".
      expect(find.text('B'), findsOneWidget);
    });
  });
}
