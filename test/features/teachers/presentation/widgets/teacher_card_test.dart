// teacher_card_test.dart — widget tests for TeacherCard.
//
// TeacherCard is a ConsumerWidget (reads languageRiverpod + academicYearRiverpod),
// so every test wraps it in ProviderScope. Both providers are overridden with
// fresh instances so the global LanguageProvider singleton is never disposed
// between tests and no real API calls are made.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/providers/academic_year_provider.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_card.dart';

// ---------------------------------------------------------------------------
// Fake AcademicYearProvider — controls isReadOnly without any network calls.
// Like a Laravel test fake/stub: same interface, controlled behaviour.
// ---------------------------------------------------------------------------
class _FakeAcademicYearProvider extends AcademicYearProvider {
  _FakeAcademicYearProvider({bool readOnly = false}) : _readOnly = readOnly;

  final bool _readOnly;

  // Override the computed getter so the widget sees the value we want.
  @override
  bool get isReadOnly => _readOnly;
}

// ---------------------------------------------------------------------------
// Helper — builds the widget under test inside the minimal widget tree it
// needs: ProviderScope (for Riverpod) > MaterialApp > Scaffold.
// Equivalent to mounting a Vue component with a mocked Vuex store.
// ---------------------------------------------------------------------------
Widget _buildCard({
  required Map<String, dynamic> teacher,
  int index = 0,
  VoidCallback? onTap,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  bool readOnly = false,
}) {
  return ProviderScope(
    overrides: [
      // Fresh LanguageProvider per test so the global singleton is never
      // disposed between tests (languageRiverpod normally shares the singleton).
      languageRiverpod.overrideWith((_) => LanguageProvider()),
      // Replace the real provider with our fake so tests are hermetic.
      academicYearRiverpod.overrideWith(
        (_) => _FakeAcademicYearProvider(readOnly: readOnly),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: TeacherCard(
          teacher: teacher,
          index: index,
          onTap: onTap ?? () {},
          onEdit: onEdit ?? () {},
          onDelete: onDelete ?? () {},
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Sample teacher data — mirrors the shape of the Laravel TeacherResource.
// ---------------------------------------------------------------------------
const _teacher = <String, dynamic>{
  'name': 'John Doe',
  'user': {'email': 'john@example.com'},
  'homeroom_class': null, // no homeroom → shows "Active" badge
};

const _homeroomTeacher = <String, dynamic>{
  'name': 'Jane Smith',
  'user': {'email': 'jane@example.com'},
  'homeroom_class': {'name': 'Class 7A'}, // Map shape → shows "Wali Kelas" badge
};

void main() {
  group('TeacherCard', () {
    // ── Basic rendering ──────────────────────────────────────────────────────

    testWidgets('renders teacher name', (tester) async {
      await tester.pumpWidget(_buildCard(teacher: _teacher));
      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('renders teacher email', (tester) async {
      await tester.pumpWidget(_buildCard(teacher: _teacher));
      expect(find.text('john@example.com'), findsOneWidget);
    });

    testWidgets('renders avatar initial from teacher name', (tester) async {
      await tester.pumpWidget(_buildCard(teacher: _teacher));
      // Avatar shows first letter of name, uppercased.
      expect(find.text('J'), findsAtLeastNWidgets(1));
    });

    // ── Status badge — conditional on homeroom_class ─────────────────────────

    testWidgets('shows Active badge when teacher has no homeroom class',
        (tester) async {
      await tester.pumpWidget(_buildCard(teacher: _teacher));
      // Default language is 'id', so the Indonesian label is rendered.
      expect(find.text('Aktif'), findsOneWidget);
    });

    testWidgets('shows Homeroom badge when teacher has a homeroom class',
        (tester) async {
      await tester.pumpWidget(_buildCard(teacher: _homeroomTeacher));
      // Default language is 'id'.
      expect(find.text('Wali Kelas'), findsOneWidget);
    });

    testWidgets(
        'renders homeroom class name tag when teacher has a homeroom class',
        (tester) async {
      await tester.pumpWidget(_buildCard(teacher: _homeroomTeacher));
      expect(find.text('Class 7A'), findsOneWidget);
    });

    testWidgets(
        'does NOT render homeroom class name tag for a non-homeroom teacher',
        (tester) async {
      await tester.pumpWidget(_buildCard(teacher: _teacher));
      expect(find.text('Class 7A'), findsNothing);
    });

    // ── Edit / delete action icons ────────────────────────────────────────────

    testWidgets('shows edit and delete icons when NOT read-only', (tester) async {
      await tester.pumpWidget(_buildCard(teacher: _teacher, readOnly: false));
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('hides edit and delete icons when read-only', (tester) async {
      await tester.pumpWidget(_buildCard(teacher: _teacher, readOnly: true));
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    // ── Callbacks ─────────────────────────────────────────────────────────────

    testWidgets('calls onTap when card is tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _buildCard(teacher: _teacher, onTap: () => tapped = true),
      );
      await tester.tap(find.text('John Doe'));
      expect(tapped, isTrue);
    });

    testWidgets('calls onEdit when edit icon is tapped', (tester) async {
      bool edited = false;
      await tester.pumpWidget(
        _buildCard(
          teacher: _teacher,
          readOnly: false,
          onEdit: () => edited = true,
        ),
      );
      await tester.tap(find.byIcon(Icons.edit_outlined));
      expect(edited, isTrue);
    });

    testWidgets('calls onDelete when delete icon is tapped', (tester) async {
      bool deleted = false;
      await tester.pumpWidget(
        _buildCard(
          teacher: _teacher,
          readOnly: false,
          onDelete: () => deleted = true,
        ),
      );
      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(deleted, isTrue);
    });

    // ── Edge cases ────────────────────────────────────────────────────────────

    testWidgets('falls back to "No Name" when teacher name is null',
        (tester) async {
      const noName = <String, dynamic>{'name': null, 'homeroom_class': null};
      await tester.pumpWidget(_buildCard(teacher: noName));
      expect(find.text('No Name'), findsOneWidget);
    });

    testWidgets('handles homeroom_class as a non-empty List', (tester) async {
      const listShape = <String, dynamic>{
        'name': 'Bob Lee',
        'homeroom_class': [
          {'name': 'Class 8B'},
        ],
      };
      await tester.pumpWidget(_buildCard(teacher: listShape));
      expect(find.text('Class 8B'), findsOneWidget);
      expect(find.text('Wali Kelas'), findsOneWidget);
    });
  });
}
