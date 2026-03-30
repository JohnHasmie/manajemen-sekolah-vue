// Tests for GradeRecapInfoTag — a stateless icon+text pill badge.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_info_tag.dart';

Widget _build(IconData icon, String text) => MaterialApp(
      home: Scaffold(body: GradeRecapInfoTag(icon: icon, text: text)),
    );

void main() {
  group('GradeRecapInfoTag', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_build(Icons.layers_outlined, 'VII'));
      expect(find.byType(GradeRecapInfoTag), findsOneWidget);
    });

    testWidgets('displays the text label', (tester) async {
      await tester.pumpWidget(_build(Icons.person_outline, 'Budi Santoso'));
      expect(find.text('Budi Santoso'), findsOneWidget);
    });

    testWidgets('displays the icon', (tester) async {
      await tester.pumpWidget(_build(Icons.layers_outlined, 'Level'));
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.layers_outlined),
        findsOneWidget,
      );
    });

    testWidgets('shows empty string text without crashing', (tester) async {
      await tester.pumpWidget(_build(Icons.star, ''));
      expect(find.byType(GradeRecapInfoTag), findsOneWidget);
    });

    testWidgets('Text widget declares maxLines=1 and ellipsis overflow',
        (tester) async {
      await tester.pumpWidget(
        _build(Icons.person_outline, 'A very long teacher name that should be truncated'),
      );
      final text = tester.widget<Text>(find.byType(Text).last);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('accepts special characters in text', (tester) async {
      await tester.pumpWidget(_build(Icons.school, 'VII-A & B'));
      expect(find.text('VII-A & B'), findsOneWidget);
    });

    testWidgets('accepts numeric text', (tester) async {
      await tester.pumpWidget(_build(Icons.grade, '95.5'));
      expect(find.text('95.5'), findsOneWidget);
    });

    testWidgets('icon has size 11', (tester) async {
      await tester.pumpWidget(_build(Icons.layers_outlined, 'VII'));
      final icon = tester.widget<Icon>(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.layers_outlined),
      );
      expect(icon.size, 11);
    });

    testWidgets('can render multiple tags side by side', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: [
                GradeRecapInfoTag(icon: Icons.layers_outlined, text: 'VII'),
                GradeRecapInfoTag(icon: Icons.person_outline, text: 'Budi'),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(GradeRecapInfoTag), findsNWidgets(2));
      expect(find.text('VII'), findsOneWidget);
      expect(find.text('Budi'), findsOneWidget);
    });
  });
}
