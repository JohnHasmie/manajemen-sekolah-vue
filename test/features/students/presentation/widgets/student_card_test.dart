// ignore_for_file: lines_longer_than_80_chars
// student_card_test.dart — widget tests for StudentCard.
//
// StudentCard is a plain StatelessWidget (no Riverpod). It receives isReadOnly
// as a constructor parameter, so tests just flip that flag directly —
// no ProviderScope override needed, but we still wrap in MaterialApp for
// proper widget context (like mounting a Vue component with a real DOM).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manajemensekolah/features/students/presentation/widgets/student_card.dart';

// ---------------------------------------------------------------------------
// Helper — builds StudentCard inside MaterialApp > Scaffold.
// primaryColor is required by the widget; we use a stable test colour.
// ---------------------------------------------------------------------------
Widget _buildCard({
  required Map<String, dynamic> student,
  int index = 0,
  bool isReadOnly = false,
  Color primaryColor = Colors.blue,
  String genderText = 'Male',
  VoidCallback? onTap,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) {
  return MaterialApp(
    home: Scaffold(
      body: StudentCard(
        student: student,
        index: index,
        isReadOnly: isReadOnly,
        primaryColor: primaryColor,
        genderText: genderText,
        onTap: onTap ?? () {},
        onEdit: onEdit ?? () {},
        onDelete: onDelete ?? () {},
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Sample student data — mirrors the Laravel StudentResource API response.
// ---------------------------------------------------------------------------
const _student = <String, dynamic>{
  'name': 'Alice Tan',
  'class': {'name': 'Class 7A'},
};

void main() {
  group('StudentCard', () {
    // ── Basic rendering ──────────────────────────────────────────────────────

    testWidgets('renders student name', (tester) async {
      await tester.pumpWidget(_buildCard(student: _student));
      expect(find.text('Alice Tan'), findsOneWidget);
    });

    testWidgets('renders NIS meta line when student_number present', (
      tester,
    ) async {
      // The SS2 redesign dropped the standalone gender tag. The top meta
      // line now carries "className · NIS <number>" instead.
      const withNis = <String, dynamic>{
        'name': 'Alice Tan',
        'class': {'name': 'Class 7A'},
        'student_number': '1234567',
      };
      await tester.pumpWidget(_buildCard(student: withNis));
      expect(find.text('Class 7A · NIS 1234567'), findsOneWidget);
    });

    testWidgets('renders class name in top meta', (tester) async {
      // With no NIS the top meta line is just the class name.
      await tester.pumpWidget(_buildCard(student: _student));
      expect(find.text('Class 7A'), findsOneWidget);
    });

    testWidgets('renders avatar initials from student name', (tester) async {
      await tester.pumpWidget(_buildCard(student: _student));
      // InitialsAvatar shows two-letter initials of "Alice Tan" → 'AT'.
      expect(find.text('AT'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders Aktif status badge', (tester) async {
      await tester.pumpWidget(_buildCard(student: _student));
      // BrandListRow renders a hardcoded "Aktif" inline status label.
      expect(find.text('Aktif'), findsOneWidget);
    });

    // ── Trailing CTA ──────────────────────────────────────────────────────────
    //
    // The SS2 redesign replaced the inline edit/delete icon buttons with a
    // "Detail →" trailing CTA. Editing is now triggered via long-press
    // (wired to onEdit when not read-only); deletion happens from the detail
    // sheet / bulk-select mode, not from a per-row icon.

    testWidgets('shows Detail CTA in the trailing slot', (tester) async {
      await tester.pumpWidget(_buildCard(student: _student, isReadOnly: false));
      expect(find.text('Detail →'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    // ── Callbacks ─────────────────────────────────────────────────────────────
    //

    testWidgets('calls onTap when card is tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _buildCard(student: _student, onTap: () => tapped = true),
      );
      await tester.tap(find.text('Alice Tan'));
      expect(tapped, isTrue);
    });

    testWidgets('calls onEdit on long-press when NOT read-only', (
      tester,
    ) async {
      bool edited = false;
      await tester.pumpWidget(
        _buildCard(
          student: _student,
          isReadOnly: false,
          onEdit: () => edited = true,
        ),
      );
      await tester.longPress(find.text('Alice Tan'));
      expect(edited, isTrue);
    });

    testWidgets('does not call onEdit on long-press when read-only', (
      tester,
    ) async {
      bool edited = false;
      await tester.pumpWidget(
        _buildCard(
          student: _student,
          isReadOnly: true,
          onEdit: () => edited = true,
        ),
      );
      await tester.longPress(find.text('Alice Tan'));
      expect(edited, isFalse);
    });

    // ── Conditional rendering — class name ───────────────────────────────────

    testWidgets('shows "-" when student has no class assigned', (tester) async {
      const noClass = <String, dynamic>{'name': 'Bob Kim', 'class': null};
      await tester.pumpWidget(_buildCard(student: noClass));
      expect(find.text('-'), findsOneWidget);
    });

    // ── Edge cases ────────────────────────────────────────────────────────────
    //

    testWidgets('falls back to "No Name" when student name is null', (
      tester,
    ) async {
      const noName = <String, dynamic>{'name': null};
      await tester.pumpWidget(_buildCard(student: noName));
      expect(find.text('No Name'), findsOneWidget);
    });

    testWidgets('renders correctly with a custom primaryColor', (tester) async {
      await tester.pumpWidget(
        _buildCard(student: _student, primaryColor: Colors.purple),
      );
      // Spot-check: the card still renders the student name regardless of color.
      //
      expect(find.text('Alice Tan'), findsOneWidget);
    });
  });
}
