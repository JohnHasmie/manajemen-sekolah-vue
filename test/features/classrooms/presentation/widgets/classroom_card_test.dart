// ignore_for_file: lines_longer_than_80_chars
// classroom_card_test.dart — widget tests for ClassroomCard.
//
// ClassroomCard is a ConsumerWidget (reads languageRiverpod +
// academicYearRiverpod),
// so every test wraps it in ProviderScope. Both providers are overridden with
// fresh instances so the global LanguageProvider singleton is never disposed
// between tests and no real API calls are made.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/classroom_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/providers/academic_year_provider.dart';

// ---------------------------------------------------------------------------
// Fake AcademicYearProvider — controls isReadOnly without any network calls.
// ---------------------------------------------------------------------------
class _FakeAcademicYearProvider extends AcademicYearProvider {
  _FakeAcademicYearProvider({bool readOnly = false}) : _readOnly = readOnly;

  final bool _readOnly;

  @override
  bool get isReadOnly => _readOnly;
}

// ---------------------------------------------------------------------------
// Helper — builds the ClassroomCard inside ProviderScope > MaterialApp >
// Scaffold.
// ---------------------------------------------------------------------------
Widget _buildCard({
  required Map<String, dynamic> classData,
  int index = 0,
  String gradeText = 'Grade 7 SMP',
  VoidCallback? onTap,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  bool readOnly = false,
}) {
  return ProviderScope(
    overrides: [
      // Fresh LanguageProvider per test so the global singleton is never
      // disposed between tests (languageRiverpod normally shares the singleton).
      //
      languageRiverpod.overrideWith((_) => LanguageProvider()),
      academicYearRiverpod.overrideWith(
        (_) => _FakeAcademicYearProvider(readOnly: readOnly),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ClassroomCard(
          classData: classData,
          index: index,
          gradeText: gradeText,
          onTap: onTap ?? () {},
          onEdit: onEdit ?? () {},
          onDelete: onDelete ?? () {},
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Sample classroom data — mirrors the Laravel ClassroomResource API response.
// ---------------------------------------------------------------------------
const _classroom = <String, dynamic>{
  'name': 'Class 7A',
  'student_count': 30,
  'homeroom_teacher_name': 'Mr. Ahmad',
};

const _classroomWithTeacherList = <String, dynamic>{
  'name': 'Class 8B',
  'student_count': 28,
  'homeroom_teacher': [
    {'name': 'Ms. Sari'},
  ],
};

const _classroomWithTeacherMap = <String, dynamic>{
  'name': 'Class 9C',
  'student_count': 25,
  'homeroom_teacher': {'name': 'Mr. Budi'},
};

void main() {
  group('ClassroomCard', () {
    // ── Basic rendering ──────────────────────────────────────────────────────

    testWidgets('renders classroom name', (tester) async {
      await tester.pumpWidget(_buildCard(classData: _classroom));
      expect(find.text('Class 7A'), findsOneWidget);
    });

    testWidgets('renders grade text and student count in top meta', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCard(classData: _classroom, gradeText: 'Grade 7 SMP'),
      );
      // SS2 redesign: the top meta line combines grade + student count.
      // Default language is 'id', so the count reads "30 siswa".
      expect(find.text('Grade 7 SMP · 30 siswa'), findsOneWidget);
    });

    testWidgets('renders avatar initials from class name', (tester) async {
      await tester.pumpWidget(_buildCard(classData: _classroom));
      // InitialsAvatar shows two-letter initials of "Class 7A" → 'C7'.
      expect(find.text('C7'), findsAtLeastNWidgets(1));
    });

    // ── Homeroom teacher name resolution ─────────────────────────────────────

    testWidgets(
      'renders homeroom teacher from flat homeroom_teacher_name key',
      (tester) async {
        await tester.pumpWidget(_buildCard(classData: _classroom));
        // SS2 redesign: the homeroom teacher appears in the inline status
        // as "Wali: <name>" (id default).
        expect(find.text('Wali: Mr. Ahmad'), findsOneWidget);
      },
    );

    testWidgets(
      'renders homeroom teacher from homeroom_teacher List pivot shape',
      (tester) async {
        await tester.pumpWidget(
          _buildCard(classData: _classroomWithTeacherList),
        );
        expect(find.text('Wali: Ms. Sari'), findsOneWidget);
      },
    );

    testWidgets(
      'renders homeroom teacher from homeroom_teacher Map relation shape',
      (tester) async {
        await tester.pumpWidget(
          _buildCard(classData: _classroomWithTeacherMap),
        );
        expect(find.text('Wali: Mr. Budi'), findsOneWidget);
      },
    );

    testWidgets(
      'shows "Belum ada wali" when no homeroom teacher is assigned',
      (tester) async {
        const noTeacher = <String, dynamic>{
          'name': 'Class 10A',
          'student_count': 20,
          // no homeroom_teacher or homeroom_teacher_name keys
        };
        await tester.pumpWidget(_buildCard(classData: noTeacher));
        // Default language is 'id'; status shows the warning label.
        expect(find.text('Belum ada wali'), findsOneWidget);
      },
    );

    // ── Trailing CTA ──────────────────────────────────────────────────────────
    //
    // The SS2 redesign replaced the inline edit/delete icon buttons with a
    // "Detail →" trailing CTA. Editing is now triggered via long-press
    // (wired to onEdit when not read-only).

    testWidgets('shows Detail CTA in the trailing slot', (tester) async {
      await tester.pumpWidget(
        _buildCard(classData: _classroom, readOnly: false),
      );
      expect(find.text('Detail →'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    // ── Callbacks ─────────────────────────────────────────────────────────────
    //

    testWidgets('calls onTap when card is tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _buildCard(classData: _classroom, onTap: () => tapped = true),
      );
      await tester.tap(find.text('Class 7A'));
      expect(tapped, isTrue);
    });

    testWidgets('calls onEdit on long-press when NOT read-only', (
      tester,
    ) async {
      bool edited = false;
      await tester.pumpWidget(
        _buildCard(
          classData: _classroom,
          readOnly: false,
          onEdit: () => edited = true,
        ),
      );
      await tester.longPress(find.text('Class 7A'));
      expect(edited, isTrue);
    });

    testWidgets('does not call onEdit on long-press when read-only', (
      tester,
    ) async {
      bool edited = false;
      await tester.pumpWidget(
        _buildCard(
          classData: _classroom,
          readOnly: true,
          onEdit: () => edited = true,
        ),
      );
      await tester.longPress(find.text('Class 7A'));
      expect(edited, isFalse);
    });

    // ── Edge cases ────────────────────────────────────────────────────────────
    //

    testWidgets('falls back to "Class" and avatar "C" when name is null', (
      tester,
    ) async {
      const noName = <String, dynamic>{'student_count': 5};
      await tester.pumpWidget(_buildCard(classData: noName));
      expect(find.text('Class'), findsOneWidget);
      expect(find.text('C'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows zero student count', (tester) async {
      const empty = <String, dynamic>{
        'name': 'Empty Class',
        'student_count': 0,
      };
      await tester.pumpWidget(
        _buildCard(classData: empty, gradeText: 'Grade 7 SMP'),
      );
      // Combined top meta line: "<grade> · 0 siswa".
      expect(find.text('Grade 7 SMP · 0 siswa'), findsOneWidget);
    });
  });
}
