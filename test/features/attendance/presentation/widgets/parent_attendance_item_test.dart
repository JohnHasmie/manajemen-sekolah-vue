// Tests for ParentAttendanceItem — a ConsumerWidget card showing a single
// attendance record row for the parent view.
//
// Uses Riverpod languageRiverpod + DateFormat, so we need:
//  - ProviderScope wrapper
//  - initializeDateFormatting for locale data
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/parent_attendance_item.dart';

Attendance _makeRecord({
  String status = 'hadir',
  bool isRead = true,
  String? subjectName,
  String? lessonHourName,
}) =>
    Attendance(
      id: 'a1',
      studentId: 's1',
      date: DateTime(2025, 3, 10),
      status: status,
      isRead: isRead,
      subjectName: subjectName ?? 'Matematika',
      lessonHourName: lessonHourName,
    );

// Override languageRiverpod with a fresh LanguageProvider each time to avoid
// "used after dispose" errors when the ProviderScope is torn down between tests.
Widget _build({
  Attendance? record,
  Color primaryColor = Colors.teal,
  Color statusColor = Colors.green,
  String statusText = 'Hadir',
  IconData statusIcon = Icons.check_circle_outline,
  String normalizedStatus = 'hadir',
}) =>
    ProviderScope(
      overrides: [
        languageRiverpod.overrideWith((_) => LanguageProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ParentAttendanceItem(
            record: record ?? _makeRecord(),
            primaryColor: primaryColor,
            statusColor: statusColor,
            statusText: statusText,
            statusIcon: statusIcon,
            normalizedStatus: normalizedStatus,
          ),
        ),
      ),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
    await initializeDateFormatting('id', null);
    await initializeDateFormatting('en_US', null);
  });

  group('ParentAttendanceItem', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pump();
      expect(find.byType(ParentAttendanceItem), findsOneWidget);
    });

    testWidgets('shows subject name', (tester) async {
      await tester.pumpWidget(_build(record: _makeRecord(subjectName: 'Fisika')));
      await tester.pump();
      expect(find.text('Fisika'), findsOneWidget);
    });

    testWidgets('shows status text tag', (tester) async {
      await tester.pumpWidget(_build(statusText: 'Sakit'));
      await tester.pump();
      expect(find.text('Sakit'), findsOneWidget);
    });

    testWidgets('shows status icon', (tester) async {
      await tester.pumpWidget(_build(statusIcon: Icons.warning_rounded));
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.warning_rounded),
        findsOneWidget,
      );
    });

    testWidgets('shows date box with day number', (tester) async {
      await tester.pumpWidget(_build(record: _makeRecord()));
      await tester.pump();
      // Date is 2025-03-10, so day = "10"
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('shows unread dot when isRead is false', (tester) async {
      await tester.pumpWidget(_build(record: _makeRecord(isRead: false)));
      await tester.pump();
      // Unread dot is a small 8x8 Container with red color
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasSmallRedContainer = containers.any((c) {
        final deco = c.decoration as BoxDecoration?;
        return c.constraints?.maxWidth == 8 && deco?.shape == BoxShape.circle;
      });
      expect(hasSmallRedContainer, isTrue);
    });

    testWidgets('does NOT show unread dot when isRead is true', (tester) async {
      await tester.pumpWidget(_build(record: _makeRecord(isRead: true)));
      await tester.pump();
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasSmallRedContainer = containers.any((c) {
        return c.constraints?.maxWidth == 8;
      });
      expect(hasSmallRedContainer, isFalse);
    });

    testWidgets('shows lessonHourName tag when provided', (tester) async {
      await tester.pumpWidget(_build(
        record: _makeRecord(lessonHourName: 'Jam 2'),
      ));
      await tester.pump();
      expect(find.text('Jam 2'), findsOneWidget);
    });

    testWidgets('does NOT show lesson hour tag when lessonHourName is null',
        (tester) async {
      await tester.pumpWidget(_build(record: _makeRecord(lessonHourName: null)));
      await tester.pump();
      // No lesson hour tag means no 'Jam' prefix text
      expect(find.textContaining('Jam'), findsNothing);
    });

    testWidgets('shows "Absen" status correctly', (tester) async {
      await tester.pumpWidget(_build(
        record: _makeRecord(status: 'alpha'),
        statusText: 'Absen',
        statusColor: Colors.red,
        normalizedStatus: 'alpha',
      ));
      await tester.pump();
      expect(find.text('Absen'), findsOneWidget);
    });

    testWidgets('renders with different primaryColor', (tester) async {
      await tester.pumpWidget(_build(primaryColor: Colors.blue));
      await tester.pump();
      expect(find.byType(ParentAttendanceItem), findsOneWidget);
    });
  });
}
