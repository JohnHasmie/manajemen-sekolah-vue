// Tests for RecommendationClassCard — expandable class card with history.
//
// Key scenarios:
// - Shows className in header
// - isLoading=true: shows 'Memuat...' subtitle
// - totalRec > 0 (from summary.by_status): shows count and history.length
// - totalRec = 0 + !isLoading: shows 'Belum ada rekomendasi'
// - isExpanded=false: no expanded content (Divider, history, generate button)
// - isExpanded=true + isLoadingHistory=true: shows spinner
// - isExpanded=true + history=[]: shows 'Belum ada riwayat rekomendasi'
// - isExpanded=true + schedulesLoaded=true + !isGenerating: shows generate button
// - isExpanded=true + isGenerating=true: shows 'Memproses...' on button
// - onToggleExpand fires when header is tapped
// - onGenerate fires when generate button pressed (not generating)
//
// Like testing a Vue accordion component — all state via props.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/recommendation_class_card.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _build({
  String className = 'Kelas 7A',
  String classId = 'cls-1',
  Map<String, dynamic>? summary,
  Color primaryColor = Colors.blue,
  bool isLoading = false,
  bool isGenerating = false,
  bool schedulesLoaded = false,
  List<Map<String, dynamic>> history = const [],
  bool isLoadingHistory = false,
  bool isExpanded = false,
  VoidCallback? onToggleExpand,
  VoidCallback? onGenerate,
  void Function(Map<String, dynamic>)? onHistoryItemTap,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: RecommendationClassCard(
              className: className,
              classId: classId,
              classData: {'id': classId, 'name': className},
              summary: summary,
              primaryColor: primaryColor,
              isLoading: isLoading,
              isGenerating: isGenerating,
              schedulesLoaded: schedulesLoaded,
              history: history,
              isLoadingHistory: isLoadingHistory,
              isExpanded: isExpanded,
              onToggleExpand: onToggleExpand ?? () {},
              onGenerate: onGenerate ?? () {},
              onHistoryItemTap: onHistoryItemTap ?? (_) {},
            ),
          ),
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RecommendationClassCard — header content', () {
    testWidgets('shows className', (tester) async {
      await tester.pumpWidget(_build(className: 'Kelas 8B'));
      expect(find.text('Kelas 8B'), findsOneWidget);
    });

    testWidgets('shows class icon', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.byIcon(Icons.class_outlined), findsOneWidget);
    });

    testWidgets('shows chevron arrow icon', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });
  });

  group('RecommendationClassCard — subtitle states', () {
    testWidgets('shows "Memuat..." when isLoading=true', (tester) async {
      await tester.pumpWidget(_build(isLoading: true));
      expect(find.text('Memuat...'), findsOneWidget);
    });

    testWidgets('shows "Belum ada rekomendasi" when totalRec=0 and !isLoading',
        (tester) async {
      await tester.pumpWidget(_build(isLoading: false, summary: null));
      expect(find.text('Belum ada rekomendasi'), findsOneWidget);
    });

    testWidgets('shows count text when totalRec > 0', (tester) async {
      await tester.pumpWidget(_build(
        summary: {
          'by_status': {'pending': 3, 'completed': 2}
        },
        history: [
          {'date': '2025-03-01', 'count': 5, 'trigger_source': 'on_demand'},
        ],
      ));
      // totalRec = 3+2 = 5, history.length = 1
      expect(find.textContaining('5 rekomendasi'), findsOneWidget);
      expect(find.textContaining('1 sesi'), findsOneWidget);
    });
  });

  group('RecommendationClassCard — collapsed (isExpanded=false)', () {
    testWidgets('no Divider when collapsed', (tester) async {
      await tester.pumpWidget(_build(isExpanded: false));
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('no generate button when collapsed', (tester) async {
      await tester.pumpWidget(
          _build(isExpanded: false, schedulesLoaded: true));
      expect(find.text('Generate Rekomendasi AI'), findsNothing);
    });
  });

  group('RecommendationClassCard — expanded (isExpanded=true)', () {
    testWidgets('shows Divider when expanded', (tester) async {
      await tester.pumpWidget(_build(isExpanded: true));
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('shows "Belum ada riwayat rekomendasi" when history empty',
        (tester) async {
      await tester.pumpWidget(_build(
        isExpanded: true,
        history: [],
        isLoadingHistory: false,
      ));
      expect(find.text('Belum ada riwayat rekomendasi'), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator when isLoadingHistory=true',
        (tester) async {
      await tester.pumpWidget(_build(
        isExpanded: true,
        isLoadingHistory: true,
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('no history empty label when isLoadingHistory=true',
        (tester) async {
      await tester.pumpWidget(_build(
        isExpanded: true,
        isLoadingHistory: true,
      ));
      expect(find.text('Belum ada riwayat rekomendasi'), findsNothing);
    });
  });

  group('RecommendationClassCard — generate button', () {
    testWidgets('shows generate button when expanded + schedulesLoaded',
        (tester) async {
      await tester.pumpWidget(_build(
        isExpanded: true,
        schedulesLoaded: true,
        isGenerating: false,
      ));
      expect(find.text('Generate Rekomendasi AI'), findsOneWidget);
    });

    testWidgets('no generate button when schedulesLoaded=false', (tester) async {
      await tester.pumpWidget(_build(
        isExpanded: true,
        schedulesLoaded: false,
      ));
      expect(find.text('Generate Rekomendasi AI'), findsNothing);
    });

    testWidgets('shows "Memproses..." when isGenerating=true', (tester) async {
      await tester.pumpWidget(_build(
        isExpanded: true,
        schedulesLoaded: true,
        isGenerating: true,
      ));
      expect(find.text('Memproses...'), findsOneWidget);
      expect(find.text('Generate Rekomendasi AI'), findsNothing);
    });

    testWidgets('fires onGenerate when button tapped (not generating)',
        (tester) async {
      bool called = false;
      await tester.pumpWidget(_build(
        isExpanded: true,
        schedulesLoaded: true,
        isGenerating: false,
        onGenerate: () => called = true,
      ));
      await tester.tap(find.text('Generate Rekomendasi AI'));
      expect(called, isTrue);
    });
  });

  group('RecommendationClassCard — callbacks', () {
    testWidgets('fires onToggleExpand when header tapped', (tester) async {
      bool toggled = false;
      await tester.pumpWidget(
        _build(onToggleExpand: () => toggled = true),
      );
      await tester.tap(find.byType(InkWell).first);
      expect(toggled, isTrue);
    });
  });
}
