// Tests for RecommendationCard — AI learning recommendation display card.
//
// Key scenarios:
// - priority badge: HIGH (red), MEDIUM (orange), LOW / other (blue) — uppercased
// - type badge: uppercased from type field
// - Falls back to 'Rekomendasi' for missing title
// - Shows 'REKOMENDASI:' section header
// - Shows 'BERDASARKAN ANALISIS AI:' reasoning section with ai_reasoning text
// - Shows 'MATERI & AKTIVITAS:' section when materials present
// - Hides materials section when materials is null or empty
// - Default fallback values when map is mostly empty
//
// Like testing a Vue <RecommendationCard> — purely presentational.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/recommendation_card.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _rec({
  String priority = 'high',
  String type = 'exercise',
  String title = 'Latihan Soal Aljabar',
  String description = 'Kerjakan soal aljabar berikut.',
  String aiReasoning = 'Siswa lemah di aljabar.',
  List<dynamic>? materials,
}) => {
  'priority': priority,
  'type': type,
  'title': title,
  'description': description,
  'ai_reasoning': aiReasoning,
  if (materials != null) 'materials': materials,
};

Widget _build({Map<String, dynamic>? rec, Key? listKey}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: RecommendationCard(rec: rec ?? _rec(), listKey: listKey),
    ),
  ),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RecommendationCard — priority badge', () {
    testWidgets('shows "HIGH" badge for priority=high', (tester) async {
      await tester.pumpWidget(_build(rec: _rec(priority: 'high')));
      await tester.pumpAndSettle();
      expect(find.text('HIGH'), findsOneWidget);
    });

    testWidgets('shows "MEDIUM" badge for priority=medium', (tester) async {
      await tester.pumpWidget(_build(rec: _rec(priority: 'medium')));
      await tester.pumpAndSettle();
      expect(find.text('MEDIUM'), findsOneWidget);
    });

    testWidgets('shows "LOW" badge for priority=low', (tester) async {
      await tester.pumpWidget(_build(rec: _rec(priority: 'low')));
      await tester.pumpAndSettle();
      expect(find.text('LOW'), findsOneWidget);
    });

    testWidgets('fallback priority is "LOW" when priority absent', (
      tester,
    ) async {
      await tester.pumpWidget(_build(rec: {'type': 'video', 'title': 'Test'}));
      await tester.pumpAndSettle();
      expect(find.text('LOW'), findsOneWidget);
    });
  });

  group('RecommendationCard — type badge', () {
    testWidgets('shows "EXERCISE" badge for type=exercise', (tester) async {
      await tester.pumpWidget(_build(rec: _rec(type: 'exercise')));
      await tester.pumpAndSettle();
      expect(find.text('EXERCISE'), findsOneWidget);
    });

    testWidgets('shows "VIDEO" badge for type=video', (tester) async {
      await tester.pumpWidget(_build(rec: _rec(type: 'video')));
      await tester.pumpAndSettle();
      expect(find.text('VIDEO'), findsOneWidget);
    });

    testWidgets('shows "OTHER" badge when type absent', (tester) async {
      await tester.pumpWidget(_build(rec: {'priority': 'low', 'title': 'T'}));
      await tester.pumpAndSettle();
      expect(find.text('OTHER'), findsOneWidget);
    });
  });

  group('RecommendationCard — title', () {
    testWidgets('renders title from rec map', (tester) async {
      await tester.pumpWidget(_build(rec: _rec(title: 'Latihan Soal Aljabar')));
      await tester.pumpAndSettle();
      expect(find.text('Latihan Soal Aljabar'), findsOneWidget);
    });

    testWidgets('falls back to "Rekomendasi" when title absent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(rec: {'priority': 'low', 'type': 'video'}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rekomendasi'), findsOneWidget);
    });
  });

  group('RecommendationCard — sections', () {
    testWidgets('shows "REKOMENDASI:" section label', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.text('REKOMENDASI:'), findsOneWidget);
    });

    testWidgets('shows "BERDASARKAN ANALISIS AI:" reasoning label', (
      tester,
    ) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.text('BERDASARKAN ANALISIS AI:'), findsOneWidget);
    });

    testWidgets('shows ai_reasoning text', (tester) async {
      await tester.pumpWidget(
        _build(rec: _rec(aiReasoning: 'Siswa lemah di aljabar.')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Siswa lemah di aljabar.'), findsOneWidget);
    });

    testWidgets('shows insights icon in reasoning section', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.insights_rounded), findsOneWidget);
    });
  });

  group('RecommendationCard — materials section', () {
    testWidgets('hides materials section when materials=null', (tester) async {
      await tester.pumpWidget(_build(rec: _rec(materials: null)));
      await tester.pumpAndSettle();
      expect(find.text('MATERI & AKTIVITAS:'), findsNothing);
    });

    testWidgets('hides materials section when materials is empty list', (
      tester,
    ) async {
      await tester.pumpWidget(_build(rec: _rec(materials: [])));
      await tester.pumpAndSettle();
      expect(find.text('MATERI & AKTIVITAS:'), findsNothing);
    });

    testWidgets('shows "MATERI & AKTIVITAS:" when materials has items', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(
          rec: _rec(
            materials: [
              {'title': 'Soal Latihan 1', 'type': 'exercise'},
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('MATERI & AKTIVITAS:'), findsOneWidget);
    });
  });

  group('RecommendationCard — misc', () {
    testWidgets('shows more_horiz icon', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('renders without crashing with empty rec map', (tester) async {
      await tester.pumpWidget(_build(rec: {}));
      await tester.pumpAndSettle();
      expect(find.byType(RecommendationCard), findsOneWidget);
    });
  });
}
