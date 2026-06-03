// Tests for AttendanceSummaryCard.
// Uses LanguageProvider + PreferencesService, so we mock SharedPreferences.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_summary_item.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_summary_card.dart';

void main() {
  late LanguageProvider langProvider;

  AttendanceSummaryItem makeSummary({
    String subjectName = 'Matematika',
    int totalStudent = 30,
    int present = 25,
    int absent = 5,
    String? className = 'VII-A',
    String? lessonHourName = 'Jam 1',
  }) {
    return AttendanceSummaryItem(
      subjectId: 'sub-1',
      subjectName: subjectName,
      date: DateTime(2025, 3, 10),
      totalStudent: totalStudent,
      present: present,
      absent: absent,
      className: className,
      lessonHourName: lessonHourName,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
    await initializeDateFormatting('id', null);
    langProvider = LanguageProvider();
  });

  Widget buildWidget({
    AttendanceSummaryItem? summary,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AttendanceSummaryCard(
            summary: summary ?? makeSummary(),
            primaryColor: Colors.blue,
            languageProvider: langProvider,
            onTap: onTap ?? () {},
            onLongPress: onLongPress,
          ),
        ),
      ),
    );
  }

  group('AttendanceSummaryCard', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(AttendanceSummaryCard), findsOneWidget);
    });

    testWidgets('shows subject name in the class · subject chip', (
      WidgetTester tester,
    ) async {
      // Redesign: the chip combines "<class> · <subject>".
      await tester.pumpWidget(buildWidget());
      expect(find.text('VII-A · Matematika'), findsOneWidget);
    });

    testWidgets('shows present and absent counts', (
      WidgetTester tester,
    ) async {
      // Redesign: counts are bare numbers next to icons (no "Hadir"/"Absen"
      // text labels).
      await tester.pumpWidget(buildWidget());
      expect(find.text('25'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('shows total student count', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('30'), findsOneWidget);
    });

    testWidgets('long-press fires onLongPress callback', (
      WidgetTester tester,
    ) async {
      var triggered = false;
      await tester.pumpWidget(buildWidget(onLongPress: () => triggered = true));

      await tester.longPress(find.byType(AttendanceSummaryCard));
      await tester.pump();

      expect(triggered, isTrue);
    });

    testWidgets('tapping the card fires onTap callback', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(buildWidget(onTap: () => tapped = true));
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('shows circular attendance-rate indicator', (
      WidgetTester tester,
    ) async {
      // Redesign: the leading slot is a circular percentage indicator
      // (25/30 = 83%), replacing the old book icon.
      await tester.pumpWidget(buildWidget());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('83%'), findsOneWidget);
    });

    // --- Additional edge case scenarios ---

    testWidgets('shows zero present count', (WidgetTester tester) async {
      // present=0 is the only zero value, so the bare '0' is unique.
      await tester.pumpWidget(
        buildWidget(summary: makeSummary(present: 0, absent: 30)),
      );
      expect(find.text('0'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget); // 0/30 → 0%
    });

    testWidgets('shows zero absent count', (WidgetTester tester) async {
      // absent=0 is the only zero value, so the bare '0' is unique.
      await tester.pumpWidget(
        buildWidget(summary: makeSummary(present: 30, absent: 0)),
      );
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('shows zero total students', (WidgetTester tester) async {
      // All three counts are 0; rate falls back to 0%.
      await tester.pumpWidget(
        buildWidget(
          summary: makeSummary(totalStudent: 0, present: 0, absent: 0),
        ),
      );
      expect(find.text('0'), findsNWidgets(3));
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('shows custom subject name in the class · subject chip', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(summary: makeSummary(subjectName: 'Bahasa Indonesia')),
      );
      expect(find.text('VII-A · Bahasa Indonesia'), findsOneWidget);
    });

    testWidgets('shows className in the class · subject chip', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(summary: makeSummary(className: 'IX-C')),
      );
      expect(find.text('IX-C · Matematika'), findsOneWidget);
    });

    testWidgets('renders correctly without className (null)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(summary: makeSummary(className: null)),
      );
      expect(find.byType(AttendanceSummaryCard), findsOneWidget);
    });

    testWidgets('renders correctly without lessonHourName (null)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(summary: makeSummary(lessonHourName: null)),
      );
      expect(find.byType(AttendanceSummaryCard), findsOneWidget);
    });

    testWidgets('shows lessonHourName when provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(summary: makeSummary(lessonHourName: 'Jam 3')),
      );
      expect(find.text('Jam 3'), findsOneWidget);
    });

    testWidgets('renders with a different primaryColor', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AttendanceSummaryCard(
                summary: makeSummary(),
                primaryColor: Colors.green,
                languageProvider: langProvider,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.byType(AttendanceSummaryCard), findsOneWidget);
    });

    testWidgets('large student count renders without overflow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          summary: makeSummary(totalStudent: 999, present: 997, absent: 2),
        ),
      );
      expect(find.text('999'), findsOneWidget);
      expect(find.text('997'), findsOneWidget);
    });
  });
}
