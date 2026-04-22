// Tests for LessonPlanCard — an RPP entry card with view/edit/delete actions.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_card.dart';

Map<String, dynamic> _makePlan({
  String? judul,
  String? mataPelajaranNama,
  String? kelasNama,
}) => {
  'id': 'lp-1',
  'judul': judul ?? 'Pecahan Biasa',
  'mata_pelajaran_nama': mataPelajaranNama ?? 'Matematika',
  'kelas_nama': kelasNama ?? 'VII-A',
};

Widget _build({
  Map<String, dynamic>? lessonPlan,
  Color accentColor = Colors.blue,
  Color statusColor = Colors.orange,
  String statusLabel = 'Draft',
  Color primaryColor = Colors.blue,
  VoidCallback? onView,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: LessonPlanCard(
        lessonPlan: lessonPlan ?? _makePlan(),
        accentColor: accentColor,
        statusColor: statusColor,
        statusLabel: statusLabel,
        primaryColor: primaryColor,
        onView: onView ?? () {},
        onEdit: onEdit ?? () {},
        onDelete: onDelete ?? () {},
      ),
    ),
  ),
);

void main() {
  group('LessonPlanCard', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.byType(LessonPlanCard), findsOneWidget);
    });

    testWidgets('displays title from "judul" key', (tester) async {
      await tester.pumpWidget(_build(lessonPlan: _makePlan(judul: 'Segitiga')));
      expect(find.text('Segitiga'), findsOneWidget);
    });

    testWidgets('shows "No Title" when judul is null', (tester) async {
      await tester.pumpWidget(
        _build(
          lessonPlan: {'mata_pelajaran_nama': 'Math', 'kelas_nama': 'VII'},
        ),
      );
      expect(find.text('No Title'), findsOneWidget);
    });

    testWidgets('displays subject name', (tester) async {
      await tester.pumpWidget(
        _build(lessonPlan: _makePlan(mataPelajaranNama: 'Fisika')),
      );
      expect(find.text('Fisika'), findsOneWidget);
    });

    testWidgets('shows "No Subject" when mata_pelajaran_nama is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(lessonPlan: {'judul': 'Title', 'kelas_nama': 'VII'}),
      );
      expect(find.text('No Subject'), findsOneWidget);
    });

    testWidgets('displays class name in info tag', (tester) async {
      await tester.pumpWidget(
        _build(lessonPlan: _makePlan(kelasNama: 'VIII-B')),
      );
      expect(find.text('VIII-B'), findsOneWidget);
    });

    testWidgets('shows "No Class" when kelas_nama is null', (tester) async {
      await tester.pumpWidget(
        _build(lessonPlan: {'judul': 'Title', 'mata_pelajaran_nama': 'Math'}),
      );
      expect(find.text('No Class'), findsOneWidget);
    });

    testWidgets('displays the status label badge', (tester) async {
      await tester.pumpWidget(_build(statusLabel: 'Approved'));
      expect(find.text('Approved'), findsOneWidget);
    });

    testWidgets('shows description icon', (tester) async {
      await tester.pumpWidget(_build());
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.description_rounded,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows view button (visibility icon)', (tester) async {
      await tester.pumpWidget(_build());
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.visibility_outlined,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows edit button (edit icon)', (tester) async {
      await tester.pumpWidget(_build());
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.edit_outlined,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows delete button (delete icon)', (tester) async {
      await tester.pumpWidget(_build());
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.delete_outlined,
        ),
        findsOneWidget,
      );
    });

    testWidgets('onView fires when view button is tapped', (tester) async {
      var viewed = false;
      await tester.pumpWidget(_build(onView: () => viewed = true));
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.visibility_outlined,
        ),
      );
      await tester.pump();
      expect(viewed, isTrue);
    });

    testWidgets('onEdit fires when edit button is tapped', (tester) async {
      var edited = false;
      await tester.pumpWidget(_build(onEdit: () => edited = true));
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.edit_outlined,
        ),
      );
      await tester.pump();
      expect(edited, isTrue);
    });

    testWidgets('onDelete fires when delete button is tapped', (tester) async {
      var deleted = false;
      await tester.pumpWidget(_build(onDelete: () => deleted = true));
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.delete_outlined,
        ),
      );
      await tester.pump();
      expect(deleted, isTrue);
    });

    testWidgets('onView fires when InkWell card area is tapped', (
      tester,
    ) async {
      var viewed = false;
      await tester.pumpWidget(_build(onView: () => viewed = true));
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      expect(viewed, isTrue);
    });

    testWidgets('long title is truncated to 2 lines', (tester) async {
      await tester.pumpWidget(
        _build(
          lessonPlan: _makePlan(
            judul:
                'Materi Matematika Bab 3: Bilangan Pecahan Biasa dan Campuran untuk Kelas VII',
          ),
        ),
      );
      final titleText = tester.widget<Text>(
        find.text(
          'Materi Matematika Bab 3: Bilangan Pecahan Biasa dan Campuran untuk Kelas VII',
        ),
      );
      expect(titleText.maxLines, 2);
    });
  });
}
