// Tests for AttendanceStudentItem with compact and descriptive modes.
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
    bool compactMode = false,
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
            compactMode: compactMode,
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

    testWidgets('descriptive mode shows full status labels', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget(compactMode: false));
      // Default language is 'id', so labels are Indonesian
      for (final label in ['Hadir', 'Terlambat', 'Sakit', 'Izin', 'Alpha']) {
        expect(find.text(label), findsWidgets);
      }
    });

    testWidgets('compact mode shows letter labels', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget(compactMode: true));
      for (final label in ['H', 'T', 'S', 'I', 'A']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets(
      'onStatusChanged fires with correct studentId and status (descriptive)',
      (WidgetTester tester) async {
        String? capturedId;
        String? capturedStatus;

        await tester.pumpWidget(
          buildWidget(
            compactMode: false,
            onStatusChanged: (id, status) {
              capturedId = id;
              capturedStatus = status;
            },
          ),
        );

        // Tap the "Sakit" button in descriptive mode.
        await tester.tap(find.text('Sakit'));
        await tester.pump();

        expect(capturedId, equals('stu-1'));
        expect(capturedStatus, equals('sakit'));
      },
    );

    testWidgets(
      'onStatusChanged fires with correct studentId and status (compact)',
      (WidgetTester tester) async {
        String? capturedId;
        String? capturedStatus;

        await tester.pumpWidget(
          buildWidget(
            compactMode: true,
            onStatusChanged: (id, status) {
              capturedId = id;
              capturedStatus = status;
            },
          ),
        );

        // Tap the "S" button in compact mode.
        await tester.tap(find.text('S'));
        await tester.pump();

        expect(capturedId, equals('stu-1'));
        expect(capturedStatus, equals('sakit'));
      },
    );

    testWidgets('avatar shows first letter of student name', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('B'), findsOneWidget);
    });
  });
}
