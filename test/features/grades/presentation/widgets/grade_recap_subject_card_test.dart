// Tests for GradeRecapSubjectCard — subject selection card for grade recap wizard.
//
// Key scenarios:
// - Shows subject name from 'nama' key
// - Falls back to 'name' key when 'nama' is absent
// - Shows '-' when both 'nama' and 'name' absent
// - Shows subject_code via GradeRecapInfoTag (or 'Mata Pelajaran' default)
// - Shows book icon
// - Shows chevron right arrow
// - Fires onTap when card is tapped
//
// Purely presentational — no providers.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_subject_card.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _item({String? nama, String? name, String? subjectCode}) =>
    {
      if (nama != null) 'nama': nama,
      if (name != null) 'name': name,
      if (subjectCode != null) 'subject_code': subjectCode,
    };

Widget _build({Map<String, dynamic>? item, VoidCallback? onTap}) => MaterialApp(
  home: Scaffold(
    body: GradeRecapSubjectCard(
      item: item ?? _item(nama: 'Matematika'),
      onTap: onTap ?? () {},
    ),
  ),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GradeRecapSubjectCard — subject name', () {
    testWidgets('shows subject name from "nama" key', (tester) async {
      await tester.pumpWidget(_build(item: _item(nama: 'Fisika')));
      expect(find.text('Fisika'), findsOneWidget);
    });

    testWidgets('falls back to "name" key when "nama" absent', (tester) async {
      await tester.pumpWidget(_build(item: _item(name: 'Chemistry')));
      expect(find.text('Chemistry'), findsOneWidget);
    });

    testWidgets('shows "-" when both "nama" and "name" absent', (tester) async {
      await tester.pumpWidget(_build(item: {}));
      expect(find.text('-'), findsOneWidget);
    });
  });

  group('GradeRecapSubjectCard — subject code tag', () {
    testWidgets('shows subject_code in info tag', (tester) async {
      await tester.pumpWidget(
        _build(
          item: _item(nama: 'Biologi', subjectCode: 'BIO-101'),
        ),
      );
      expect(find.text('BIO-101'), findsOneWidget);
    });

    testWidgets('shows "Mata Pelajaran" fallback when subject_code absent', (
      tester,
    ) async {
      await tester.pumpWidget(_build(item: _item(nama: 'Kimia')));
      expect(find.text('Mata Pelajaran'), findsOneWidget);
    });
  });

  group('GradeRecapSubjectCard — visual elements', () {
    testWidgets('shows book icon', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.byIcon(Icons.book_outlined), findsOneWidget);
    });

    testWidgets('shows chevron right icon', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });

  group('GradeRecapSubjectCard — onTap', () {
    testWidgets('fires onTap when card is tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_build(onTap: () => tapped = true));
      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isTrue);
    });

    testWidgets('fires onTap multiple times on repeated taps', (tester) async {
      int count = 0;
      await tester.pumpWidget(_build(onTap: () => count++));
      await tester.tap(find.byType(GestureDetector));
      await tester.tap(find.byType(GestureDetector));
      expect(count, 2);
    });
  });
}
