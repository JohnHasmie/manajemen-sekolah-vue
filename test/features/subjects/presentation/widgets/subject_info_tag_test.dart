// Tests for SubjectInfoTag — a compact icon+text pill badge for subject cards.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_info_tag.dart';

Widget _build(IconData icon, String text) => MaterialApp(
      home: Scaffold(body: SubjectInfoTag(icon: icon, text: text)),
    );

void main() {
  group('SubjectInfoTag', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_build(Icons.class_outlined, '3 Kelas'));
      expect(find.byType(SubjectInfoTag), findsOneWidget);
    });

    testWidgets('displays the text', (tester) async {
      await tester.pumpWidget(_build(Icons.class_outlined, 'VII-A, VII-B'));
      expect(find.text('VII-A, VII-B'), findsOneWidget);
    });

    testWidgets('displays the icon', (tester) async {
      await tester.pumpWidget(_build(Icons.people_outline, 'text'));
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.people_outline),
        findsOneWidget,
      );
    });

    testWidgets('icon has size 11', (tester) async {
      await tester.pumpWidget(_build(Icons.class_outlined, 'text'));
      final icon = tester.widget<Icon>(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.class_outlined),
      );
      expect(icon.size, 11);
    });

    testWidgets('text has size 11', (tester) async {
      await tester.pumpWidget(_build(Icons.class_outlined, 'label'));
      final text = tester.widget<Text>(find.text('label'));
      expect(text.style?.fontSize, 11);
    });

    testWidgets('Text widget declares maxLines=1 and ellipsis overflow',
        (tester) async {
      await tester.pumpWidget(
        _build(Icons.class_outlined, 'VII-A, VII-B, VIII-A, VIII-B, IX-A, IX-B'),
      );
      final text = tester.widget<Text>(
        find.text('VII-A, VII-B, VIII-A, VIII-B, IX-A, IX-B'),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('handles empty text without crashing', (tester) async {
      await tester.pumpWidget(_build(Icons.class_outlined, ''));
      expect(find.byType(SubjectInfoTag), findsOneWidget);
    });

    testWidgets('handles numeric text', (tester) async {
      await tester.pumpWidget(_build(Icons.class_outlined, '5 Kelas'));
      expect(find.text('5 Kelas'), findsOneWidget);
    });

    testWidgets('can render multiple tags in a Wrap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: [
                SubjectInfoTag(icon: Icons.class_outlined, text: '3 Kelas'),
                SubjectInfoTag(icon: Icons.people_outline, text: 'VII-A, VII-B'),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(SubjectInfoTag), findsNWidgets(2));
      expect(find.text('3 Kelas'), findsOneWidget);
      expect(find.text('VII-A, VII-B'), findsOneWidget);
    });
  });
}
