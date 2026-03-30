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
    VoidCallback? onDelete,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AttendanceSummaryCard(
            summary: summary ?? makeSummary(),
            primaryColor: Colors.blue,
            languageProvider: langProvider,
            onTap: onTap ?? () {},
            onDelete: onDelete ?? () {},
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

    testWidgets('shows subject name', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('Matematika'), findsOneWidget);
    });

    testWidgets('shows present and absent counts in tags',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('25 Hadir'), findsOneWidget);
      expect(find.text('5 Absen'), findsOneWidget);
    });

    testWidgets('shows total student count tag', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('30 Siswa'), findsOneWidget);
    });

    testWidgets('delete button fires onDelete callback',
        (WidgetTester tester) async {
      bool deleted = false;
      await tester.pumpWidget(buildWidget(onDelete: () => deleted = true));

      final deleteIcon = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.delete_outline,
      );
      expect(deleteIcon, findsOneWidget);
      await tester.tap(deleteIcon);
      await tester.pump();

      expect(deleted, isTrue);
    });

    testWidgets('tapping the card fires onTap callback',
        (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(buildWidget(onTap: () => tapped = true));
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('shows book icon for subject', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      final bookIcon = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.book_outlined,
      );
      expect(bookIcon, findsOneWidget);
    });
  });
}
