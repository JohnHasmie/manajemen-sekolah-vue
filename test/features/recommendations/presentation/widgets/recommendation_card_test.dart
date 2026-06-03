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
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
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
    // Redesign: the priority pill now reads the uppercased Indonesian
    // label ("PRIORITAS TINGGI/SEDANG/RENDAH") rather than HIGH/MEDIUM/LOW.
    testWidgets('shows "PRIORITAS TINGGI" badge for priority=high', (
      tester,
    ) async {
      await tester.pumpWidget(_build(rec: _rec(priority: 'high')));
      await tester.pumpAndSettle();
      expect(find.text('PRIORITAS TINGGI'), findsOneWidget);
    });

    testWidgets('shows "PRIORITAS SEDANG" badge for priority=medium', (
      tester,
    ) async {
      await tester.pumpWidget(_build(rec: _rec(priority: 'medium')));
      await tester.pumpAndSettle();
      expect(find.text('PRIORITAS SEDANG'), findsOneWidget);
    });

    testWidgets('shows "PRIORITAS RENDAH" badge for priority=low', (
      tester,
    ) async {
      await tester.pumpWidget(_build(rec: _rec(priority: 'low')));
      await tester.pumpAndSettle();
      expect(find.text('PRIORITAS RENDAH'), findsOneWidget);
    });

    testWidgets('fallback priority is "PRIORITAS RENDAH" when absent', (
      tester,
    ) async {
      await tester.pumpWidget(_build(rec: {'type': 'video', 'title': 'Test'}));
      await tester.pumpAndSettle();
      expect(find.text('PRIORITAS RENDAH'), findsOneWidget);
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
    testWidgets('renders description via HtmlWidget, no REKOMENDASI label', (
      tester,
    ) async {
      // Redesign: the description renders straight through an HtmlWidget
      // (rich text, not a plain Text), so the old "REKOMENDASI:" section
      // header was removed.
      await tester.pumpWidget(
        _build(rec: _rec(description: 'Kerjakan soal aljabar berikut.')),
      );
      await tester.pumpAndSettle();
      expect(find.text('REKOMENDASI:'), findsNothing);
      final html = tester.widget<HtmlWidget>(find.byType(HtmlWidget));
      expect(html.html, 'Kerjakan soal aljabar berikut.');
    });

    testWidgets('shows "ALASAN AI" reasoning label', (tester) async {
      // Redesign: the reasoning block header is now "ALASAN AI".
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.text('ALASAN AI'), findsOneWidget);
    });

    testWidgets('shows ai_reasoning text', (tester) async {
      await tester.pumpWidget(
        _build(rec: _rec(aiReasoning: 'Siswa lemah di aljabar.')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Siswa lemah di aljabar.'), findsOneWidget);
    });

    testWidgets('shows auto_awesome icon in reasoning section', (tester) async {
      // Redesign: the reasoning icon is now Icons.auto_awesome_rounded.
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });
  });

  group('RecommendationCard — materials section', () {
    // Redesign: the materials header is now "Materi & Aktivitas" (title
    // case, no trailing colon).
    testWidgets('hides materials section when materials=null', (tester) async {
      await tester.pumpWidget(_build(rec: _rec(materials: null)));
      await tester.pumpAndSettle();
      expect(find.text('Materi & Aktivitas'), findsNothing);
    });

    testWidgets('hides materials section when materials is empty list', (
      tester,
    ) async {
      await tester.pumpWidget(_build(rec: _rec(materials: [])));
      await tester.pumpAndSettle();
      expect(find.text('Materi & Aktivitas'), findsNothing);
    });

    testWidgets('shows "Materi & Aktivitas" when materials has items', (
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
      expect(find.text('Materi & Aktivitas'), findsOneWidget);
    });
  });

  group('RecommendationCard — misc', () {
    testWidgets('shows the BELUM DIKIRIM share pill by default', (
      tester,
    ) async {
      // Redesign: there is no more_horiz icon. An un-shared rec shows the
      // "BELUM DIKIRIM" share-state pill in the pill row.
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.more_horiz), findsNothing);
      expect(find.text('BELUM DIKIRIM'), findsOneWidget);
    });

    testWidgets('renders without crashing with empty rec map', (tester) async {
      await tester.pumpWidget(_build(rec: {}));
      await tester.pumpAndSettle();
      expect(find.byType(RecommendationCard), findsOneWidget);
    });
  });
}
