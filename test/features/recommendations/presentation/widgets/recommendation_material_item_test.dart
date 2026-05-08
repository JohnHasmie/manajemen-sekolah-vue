// Tests for RecommendationMaterialItem — single material row inside
// RecommendationCard.
//
// Key scenarios:
// - type='video': shows play_circle_filled_rounded icon
// - type='exercise': shows task_alt_rounded icon
// - type='reading': shows auto_stories_rounded icon
// - type='other' / unknown: shows extension_rounded icon
// - Falls back to 'Materi' when title absent
// - Renders with matItem that is not a Map → SizedBox.shrink
// - Shows title text
//
// Pure display widget — no providers, no callbacks.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/recommendation_material_item.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _build(dynamic matItem) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: RecommendationMaterialItem(matItem: matItem),
    ),
  ),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RecommendationMaterialItem — type icon mapping', () {
    testWidgets('type=video shows play icon', (tester) async {
      await tester.pumpWidget(
        _build({'type': 'video', 'title': 'Video 1', 'content': ''}),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.play_circle_filled_rounded), findsOneWidget);
    });

    testWidgets('type=exercise shows task_alt icon', (tester) async {
      await tester.pumpWidget(
        _build({'type': 'exercise', 'title': 'Latihan', 'content': ''}),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
    });

    testWidgets('type=reading shows auto_stories icon', (tester) async {
      await tester.pumpWidget(
        _build({'type': 'reading', 'title': 'Bacaan', 'content': ''}),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
    });

    testWidgets('type=other shows extension icon', (tester) async {
      await tester.pumpWidget(
        _build({'type': 'other', 'title': 'Misc', 'content': ''}),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.extension_rounded), findsOneWidget);
    });

    testWidgets('unknown type falls back to extension icon', (tester) async {
      await tester.pumpWidget(
        _build({'type': 'quiz', 'title': 'Kuis', 'content': ''}),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.extension_rounded), findsOneWidget);
    });
  });

  group('RecommendationMaterialItem — title', () {
    testWidgets('shows title from mat map', (tester) async {
      await tester.pumpWidget(
        _build({'type': 'video', 'title': 'Intro Aljabar', 'content': ''}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Intro Aljabar'), findsOneWidget);
    });

    testWidgets('falls back to "Materi" when title absent', (tester) async {
      await tester.pumpWidget(_build({'type': 'video', 'content': ''}));
      await tester.pumpAndSettle();
      expect(find.text('Materi'), findsOneWidget);
    });
  });

  group('RecommendationMaterialItem — non-map guard', () {
    testWidgets('renders empty SizedBox for non-map input (string)', (
      tester,
    ) async {
      await tester.pumpWidget(_build('invalid'));
      await tester.pumpAndSettle();
      // No icon rendered — guard returned SizedBox.shrink
      expect(find.byIcon(Icons.play_circle_filled_rounded), findsNothing);
      expect(find.byIcon(Icons.extension_rounded), findsNothing);
    });

    testWidgets('renders empty SizedBox for null input', (tester) async {
      await tester.pumpWidget(_build(null));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.extension_rounded), findsNothing);
    });
  });
}
