// Tests for LessonPlanInfoTag — small colored pill for lesson plan metadata.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_info_tag.dart';

Widget _build({
  required IconData icon,
  required String label,
  Color? tagColor,
}) => MaterialApp(
  home: Scaffold(
    body: LessonPlanInfoTag(icon: icon, label: label, tagColor: tagColor),
  ),
);

void main() {
  group('LessonPlanInfoTag', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.class_, label: 'VII-A'));
      expect(find.byType(LessonPlanInfoTag), findsOneWidget);
    });

    testWidgets('displays the label text', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.class_, label: 'VIII-B'));
      expect(find.text('VIII-B'), findsOneWidget);
    });

    testWidgets('displays the icon', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.class_, label: 'class'));
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.class_),
        findsOneWidget,
      );
    });

    testWidgets('renders without tagColor (defaults to slate500)', (
      tester,
    ) async {
      await tester.pumpWidget(_build(icon: Icons.class_, label: 'VII-A'));
      expect(find.byType(LessonPlanInfoTag), findsOneWidget);
    });

    testWidgets('renders with custom tagColor', (tester) async {
      await tester.pumpWidget(
        _build(icon: Icons.class_, label: 'VII-A', tagColor: Colors.blue),
      );
      expect(find.byType(LessonPlanInfoTag), findsOneWidget);
    });

    testWidgets('icon has size 10', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.class_, label: 'VII-A'));
      final icon = tester.widget<Icon>(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.class_),
      );
      expect(icon.size, 10);
    });

    testWidgets('text has size 10', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.class_, label: 'VII-A'));
      final text = tester.widget<Text>(find.text('VII-A'));
      expect(text.style?.fontSize, 10);
    });

    testWidgets('handles empty label without crashing', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.class_, label: ''));
      expect(find.byType(LessonPlanInfoTag), findsOneWidget);
    });

    testWidgets('Text widget declares maxLines=1 and ellipsis overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(
          icon: Icons.class_,
          label: 'Very long class name VII-A Bilingual',
        ),
      );
      final text = tester.widget<Text>(
        find.text('Very long class name VII-A Bilingual'),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });
}
