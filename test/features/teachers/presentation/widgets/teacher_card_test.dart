// ignore_for_file: lines_longer_than_80_chars
// teacher_card_test.dart — widget tests for TeacherCard.
//
// TeacherCard is a ConsumerWidget (reads languageRiverpod +
// academicYearRiverpod),
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
      //
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
  'homeroom_class': {
    'id': '7a',
    'name': 'Class 7A',
  }, // Map shape (with id) → shows Wali homeroom chip
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

    testWidgets('renders avatar initials from teacher name', (tester) async {
      await tester.pumpWidget(_buildCard(teacher: _teacher));
      // InitialsAvatar shows two-letter initials of "John Doe" → 'JD'.
      expect(find.text('JD'), findsAtLeastNWidgets(1));
    });

    // ── Status badge — conditional on homeroom_class ─────────────────────────

    testWidgets('shows Active badge when teacher has no homeroom class', (
      tester,
    ) async {
      await tester.pumpWidget(_buildCard(teacher: _teacher));
      // Default language is 'id', so the Indonesian label is rendered.
      expect(find.text('Aktif'), findsOneWidget);
    });

    testWidgets('shows Wali homeroom chip when teacher has a homeroom class', (
      tester,
    ) async {
      await tester.pumpWidget(_buildCard(teacher: _homeroomTeacher));
      // SS2 redesign: the homeroom secondary chip combines the "Wali"
      // role label (id) with the class name into a single chip.
      expect(find.text('Wali Class 7A'), findsOneWidget);
    });

    testWidgets(
      'does NOT render homeroom chip for a non-homeroom teacher',
      (tester) async {
        await tester.pumpWidget(_buildCard(teacher: _teacher));
        expect(find.text('Wali Class 7A'), findsNothing);
        expect(find.textContaining('Wali'), findsNothing);
      },
    );

    // ── Trailing CTA ──────────────────────────────────────────────────────────
    //
    // The SS2 redesign replaced the inline edit/delete icon buttons with a
    // "Detail →" trailing CTA. Editing is now triggered via long-press
    // (wired to onEdit when not read-only).

    testWidgets('shows Detail CTA in the trailing slot', (tester) async {
      await tester.pumpWidget(_buildCard(teacher: _teacher, readOnly: false));
      expect(find.text('Detail →'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    // ── Callbacks ─────────────────────────────────────────────────────────────
    //

    testWidgets('calls onTap when card is tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _buildCard(teacher: _teacher, onTap: () => tapped = true),
      );
      await tester.tap(find.text('John Doe'));
      expect(tapped, isTrue);
    });

    testWidgets('calls onEdit on long-press when NOT read-only', (
      tester,
    ) async {
      bool edited = false;
      await tester.pumpWidget(
        _buildCard(
          teacher: _teacher,
          readOnly: false,
          onEdit: () => edited = true,
        ),
      );
      await tester.longPress(find.text('John Doe'));
      expect(edited, isTrue);
    });

    testWidgets('does not call onEdit on long-press when read-only', (
      tester,
    ) async {
      bool edited = false;
      await tester.pumpWidget(
        _buildCard(
          teacher: _teacher,
          readOnly: true,
          onEdit: () => edited = true,
        ),
      );
      await tester.longPress(find.text('John Doe'));
      expect(edited, isFalse);
    });

    // ── Edge cases ────────────────────────────────────────────────────────────
    //

    testWidgets('falls back to localised "No Name" when teacher name is null', (
      tester,
    ) async {
      // The name-missing fallback used to be the hardcoded literal "No
      // Name"; the i18n sweep wrapped it in `kTeaNoName.tr` which now
      // resolves via the global `languageProvider`. The provider defaults
      // to Indonesian in production AND in tests, so the rendered string
      // is the Indonesian value from the dictionary.
      const noName = <String, dynamic>{'name': null, 'homeroom_class': null};
      await tester.pumpWidget(_buildCard(teacher: noName));
      expect(find.text('Tanpa Nama'), findsOneWidget);
    });

    testWidgets('handles homeroom_class as a non-empty List', (tester) async {
      const listShape = <String, dynamic>{
        'name': 'Bob Lee',
        'homeroom_class': [
          {'id': '8b', 'name': 'Class 8B'},
        ],
      };
      await tester.pumpWidget(_buildCard(teacher: listShape));
      expect(find.text('Wali Class 8B'), findsOneWidget);
    });
  });
}
