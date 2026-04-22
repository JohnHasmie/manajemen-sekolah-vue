// Tests for GradeRecapClassCard — class selection card for the grade wizard.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_class_card.dart';

Map<String, dynamic> _makeItem({
  String? nama,
  String? gradeLevel,
  dynamic homeroomTeacher,
}) => {
  'id': '1',
  'nama': nama ?? 'VII-A',
  'grade_level': gradeLevel ?? 'VII',
  if (homeroomTeacher != null) 'homeroom_teacher': homeroomTeacher,
};

Widget _build({
  Map<String, dynamic>? item,
  Color primaryColor = Colors.blue,
  bool isToday = false,
  String todayLabel = 'TODAY',
  VoidCallback? onTap,
}) => MaterialApp(
  home: Scaffold(
    body: GradeRecapClassCard(
      item: item ?? _makeItem(),
      primaryColor: primaryColor,
      isToday: isToday,
      todayLabel: todayLabel,
      onTap: onTap ?? () {},
    ),
  ),
);

void main() {
  group('GradeRecapClassCard', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.byType(GradeRecapClassCard), findsOneWidget);
    });

    testWidgets('displays class name from "nama" key', (tester) async {
      await tester.pumpWidget(_build(item: _makeItem(nama: 'VIII-B')));
      expect(find.text('VIII-B'), findsOneWidget);
    });

    testWidgets('displays class name from "name" key as fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(item: {'id': '1', 'name': 'IX-C', 'grade_level': 'IX'}),
      );
      expect(find.text('IX-C'), findsOneWidget);
    });

    testWidgets('shows "-" when both nama and name are missing', (
      tester,
    ) async {
      await tester.pumpWidget(_build(item: {'id': '1', 'grade_level': 'VII'}));
      expect(find.text('-'), findsWidgets);
    });

    testWidgets('displays grade level in info tag', (tester) async {
      await tester.pumpWidget(_build(item: _makeItem(gradeLevel: 'VIII')));
      expect(find.text('VIII'), findsOneWidget);
    });

    testWidgets('displays homeroom teacher when Map with name key', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(item: _makeItem(homeroomTeacher: {'name': 'Pak Ahmad'})),
      );
      expect(find.text('Pak Ahmad'), findsOneWidget);
    });

    testWidgets('displays homeroom teacher when List of Maps', (tester) async {
      await tester.pumpWidget(
        _build(
          item: _makeItem(
            homeroomTeacher: [
              {'name': 'Bu Sari'},
            ],
          ),
        ),
      );
      expect(find.text('Bu Sari'), findsOneWidget);
    });

    testWidgets('shows "-" when homeroom_teacher is null', (tester) async {
      await tester.pumpWidget(_build(item: _makeItem()));
      // One dash for homeroom teacher tag
      expect(find.text('-'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows class icon', (tester) async {
      await tester.pumpWidget(_build());
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.class_outlined,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows chevron_right icon', (tester) async {
      await tester.pumpWidget(_build());
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.chevron_right,
        ),
        findsOneWidget,
      );
    });

    testWidgets('does NOT show TODAY badge when isToday is false', (
      tester,
    ) async {
      await tester.pumpWidget(_build(isToday: false, todayLabel: 'TODAY'));
      expect(find.text('TODAY'), findsNothing);
    });

    testWidgets('shows TODAY badge when isToday is true', (tester) async {
      await tester.pumpWidget(_build(isToday: true, todayLabel: 'TODAY'));
      expect(find.text('TODAY'), findsOneWidget);
    });

    testWidgets('shows translated today label', (tester) async {
      await tester.pumpWidget(_build(isToday: true, todayLabel: 'HARI INI'));
      expect(find.text('HARI INI'), findsOneWidget);
    });

    testWidgets('onTap fires when card is tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_build(onTap: () => tapped = true));
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('handles wali_kelas as a Map with "nama" key', (tester) async {
      await tester.pumpWidget(
        _build(
          item: {
            'id': '1',
            'nama': 'VII-A',
            'grade_level': 'VII',
            'wali_kelas': {'nama': 'Pak Rudi'},
          },
        ),
      );
      expect(find.text('Pak Rudi'), findsOneWidget);
    });
  });
}
