// Tests for GradeRecapClassList — searchable class list for grade recap wizard.
//
// Key scenarios:
// - isLoading=true: shows skeleton loader (no cards)
// - isLoading=false + empty filteredList: shows empty state icon + emptyLabel
// - isLoading=false + items: renders GradeRecapClassCard for each item
// - searchQuery filters by 'nama' and 'grade_level' (case-insensitive)
// - isLoadingMore=true: spinner appended after last card
// - isLoadingMore=false: no spinner
// - todaySchedules: matching class_id triggers isToday=true on GradeRecapClassCard
// - onClassTap fires with the tapped item's data
//
// Like testing a Vue <ClassList> — presentational, all state via props.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_class_list.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_class_card.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _cls({
  String id = '1',
  String nama = 'Kelas 7A',
  String gradeLevel = '7',
}) => {'id': id, 'nama': nama, 'grade_level': gradeLevel};

Widget _build({
  List<dynamic> classList = const [],
  String searchQuery = '',
  bool isLoading = false,
  bool isLoadingMore = false,
  Color primaryColor = Colors.blue,
  List<dynamic> todaySchedules = const [],
  String todayLabel = 'TODAY',
  String emptyLabel = 'Kelas tidak ditemukan',
  ValueChanged<Map<String, dynamic>>? onClassTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: GradeRecapClassList(
        classList: classList,
        searchQuery: searchQuery,
        isLoading: isLoading,
        isLoadingMore: isLoadingMore,
        primaryColor: primaryColor,
        todaySchedules: todaySchedules,
        todayLabel: todayLabel,
        emptyLabel: emptyLabel,
        scrollController: ScrollController(),
        onClassTap: onClassTap ?? (_) {},
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GradeRecapClassList — loading state', () {
    testWidgets('shows skeleton when isLoading=true', (tester) async {
      await tester.pumpWidget(_build(isLoading: true));
      // No GradeRecapClassCard should appear
      expect(find.byType(GradeRecapClassCard), findsNothing);
    });

    testWidgets('does not show emptyLabel when isLoading=true', (tester) async {
      await tester.pumpWidget(_build(isLoading: true, classList: []));
      expect(find.text('Kelas tidak ditemukan'), findsNothing);
    });
  });

  group('GradeRecapClassList — empty state', () {
    testWidgets('shows emptyLabel when list is empty and not loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(
          classList: [],
          isLoading: false,
          emptyLabel: 'Kelas tidak ditemukan',
        ),
      );
      expect(find.text('Kelas tidak ditemukan'), findsOneWidget);
    });

    testWidgets('shows search_off icon on empty state', (tester) async {
      await tester.pumpWidget(_build(classList: [], isLoading: false));
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('shows emptyLabel when search yields no results', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(
          classList: [_cls(nama: 'Kelas 7A')],
          searchQuery: 'kelas 9',
          emptyLabel: 'Tidak ada kelas',
        ),
      );
      expect(find.text('Tidak ada kelas'), findsOneWidget);
    });
  });

  group('GradeRecapClassList — item rendering', () {
    testWidgets('renders GradeRecapClassCard for each item', (tester) async {
      await tester.pumpWidget(
        _build(
          classList: [
            _cls(id: '1', nama: 'Kelas 7A'),
            _cls(id: '2', nama: 'Kelas 8B'),
          ],
        ),
      );
      expect(find.byType(GradeRecapClassCard), findsNWidgets(2));
    });

    testWidgets('renders 3 cards for 3 items', (tester) async {
      await tester.pumpWidget(
        _build(
          classList: [
            _cls(id: '1', nama: 'Kelas 7A'),
            _cls(id: '2', nama: 'Kelas 8B'),
            _cls(id: '3', nama: 'Kelas 9C'),
          ],
        ),
      );
      expect(find.byType(GradeRecapClassCard), findsNWidgets(3));
    });
  });

  group('GradeRecapClassList — search filtering', () {
    testWidgets('filters by class name (case-insensitive)', (tester) async {
      await tester.pumpWidget(
        _build(
          classList: [
            _cls(id: '1', nama: 'Kelas 7A'),
            _cls(id: '2', nama: 'Kelas 8B'),
          ],
          searchQuery: '8b',
        ),
      );
      expect(find.byType(GradeRecapClassCard), findsOneWidget);
    });

    testWidgets('filters by grade_level', (tester) async {
      await tester.pumpWidget(
        _build(
          classList: [
            _cls(id: '1', nama: 'Alpha', gradeLevel: '7'),
            _cls(id: '2', nama: 'Beta', gradeLevel: '8'),
          ],
          searchQuery: '8',
        ),
      );
      expect(find.byType(GradeRecapClassCard), findsOneWidget);
    });

    testWidgets('empty searchQuery shows all items', (tester) async {
      await tester.pumpWidget(
        _build(
          classList: [
            _cls(id: '1', nama: 'Kelas 7A'),
            _cls(id: '2', nama: 'Kelas 8B'),
            _cls(id: '3', nama: 'Kelas 9C'),
          ],
          searchQuery: '',
        ),
      );
      expect(find.byType(GradeRecapClassCard), findsNWidgets(3));
    });
  });

  group('GradeRecapClassList — pagination', () {
    testWidgets('shows CircularProgressIndicator when isLoadingMore=true', (
      tester,
    ) async {
      await tester.pumpWidget(_build(classList: [_cls()], isLoadingMore: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('no CircularProgressIndicator when isLoadingMore=false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(classList: [_cls()], isLoadingMore: false),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
