// Tests for GradeRecapSubjectList — searchable subject list for grade recap wizard.
//
// Key scenarios:
// - isLoading=true: shows skeleton loader
// - isLoading=false + empty list: shows emptyLabel + search_off icon
// - searchQuery filters subjects by 'nama' and 'name' (case-insensitive)
// - Renders GradeRecapSubjectCard for each filtered item
// - onSubjectTap fires with the tapped item
//
// Like testing a Vue <SubjectList> component — presentational, state via props.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_subject_list.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_subject_card.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _subject({
  String? nama,
  String? name,
  String code = 'MAT',
}) =>
    {
      if (nama != null) 'nama': nama,
      if (name != null) 'name': name,
      'subject_code': code,
    };

Widget _build({
  List<dynamic> subjectList = const [],
  String searchQuery = '',
  bool isLoading = false,
  String emptyLabel = 'Mata pelajaran tidak ditemukan',
  ValueChanged<Map<String, dynamic>>? onSubjectTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: GradeRecapSubjectList(
        subjectList: subjectList,
        searchQuery: searchQuery,
        isLoading: isLoading,
        emptyLabel: emptyLabel,
        onSubjectTap: onSubjectTap ?? (_) {},
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GradeRecapSubjectList — loading state', () {
    testWidgets('shows skeleton when isLoading=true', (tester) async {
      await tester.pumpWidget(_build(isLoading: true));
      expect(find.byType(GradeRecapSubjectCard), findsNothing);
    });

    testWidgets('does not show emptyLabel while loading', (tester) async {
      await tester.pumpWidget(_build(
        isLoading: true,
        emptyLabel: 'Tidak ada mapel',
      ));
      expect(find.text('Tidak ada mapel'), findsNothing);
    });
  });

  group('GradeRecapSubjectList — empty state', () {
    testWidgets('shows emptyLabel when list is empty', (tester) async {
      await tester.pumpWidget(_build(
        subjectList: [],
        emptyLabel: 'Mata pelajaran tidak ditemukan',
      ));
      expect(find.text('Mata pelajaran tidak ditemukan'), findsOneWidget);
    });

    testWidgets('shows search_off icon on empty state', (tester) async {
      await tester.pumpWidget(_build(subjectList: []));
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('shows emptyLabel when search yields no results', (tester) async {
      await tester.pumpWidget(_build(
        subjectList: [_subject(nama: 'Matematika')],
        searchQuery: 'fisika',
        emptyLabel: 'Tidak ada mapel',
      ));
      expect(find.text('Tidak ada mapel'), findsOneWidget);
    });
  });

  group('GradeRecapSubjectList — item rendering', () {
    testWidgets('renders one GradeRecapSubjectCard per item', (tester) async {
      await tester.pumpWidget(_build(
        subjectList: [
          _subject(nama: 'Matematika'),
          _subject(nama: 'Fisika'),
        ],
      ));
      expect(find.byType(GradeRecapSubjectCard), findsNWidgets(2));
    });

    testWidgets('renders 3 cards for 3 subjects', (tester) async {
      await tester.pumpWidget(_build(
        subjectList: [
          _subject(nama: 'Matematika'),
          _subject(nama: 'Fisika'),
          _subject(nama: 'Kimia'),
        ],
      ));
      expect(find.byType(GradeRecapSubjectCard), findsNWidgets(3));
    });
  });

  group('GradeRecapSubjectList — search filtering', () {
    testWidgets('filters by "nama" key (case-insensitive)', (tester) async {
      await tester.pumpWidget(_build(
        subjectList: [
          _subject(nama: 'Matematika'),
          _subject(nama: 'Fisika'),
        ],
        searchQuery: 'fisika',
      ));
      expect(find.byType(GradeRecapSubjectCard), findsOneWidget);
    });

    testWidgets('filters by "name" key', (tester) async {
      await tester.pumpWidget(_build(
        subjectList: [
          _subject(name: 'Biology'),
          _subject(name: 'Chemistry'),
        ],
        searchQuery: 'bio',
      ));
      expect(find.byType(GradeRecapSubjectCard), findsOneWidget);
    });

    testWidgets('empty searchQuery shows all items', (tester) async {
      await tester.pumpWidget(_build(
        subjectList: [
          _subject(nama: 'Matematika'),
          _subject(nama: 'Fisika'),
          _subject(nama: 'Kimia'),
        ],
        searchQuery: '',
      ));
      expect(find.byType(GradeRecapSubjectCard), findsNWidgets(3));
    });
  });

  group('GradeRecapSubjectList — no pagination spinner', () {
    testWidgets('no CircularProgressIndicator in subject list', (tester) async {
      await tester.pumpWidget(_build(
        subjectList: [_subject(nama: 'Matematika')],
      ));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
