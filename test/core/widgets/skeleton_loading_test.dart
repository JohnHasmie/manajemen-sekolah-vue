// Tests for the SkeletonListCard and SkeletonListLoading widgets.
//
// Both widgets use the `shimmer` package (Shimmer.fromColors) which is a
// pure Flutter widget — no Riverpod or platform channel dependencies.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:shimmer/shimmer.dart';

void main() {
  // ---------------------------------------------------------------------------
  // SkeletonListCard
  // ---------------------------------------------------------------------------
  group('SkeletonListCard', () {
    Widget buildCard({
      int infoTagCount = 1,
      bool showActions = true,
      Color? baseColor,
      Color? highlightColor,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SkeletonListCard(
            infoTagCount: infoTagCount,
            showActions: showActions,
            baseColor: baseColor,
            highlightColor: highlightColor,
          ),
        ),
      );
    }

    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.byType(SkeletonListCard), findsOneWidget);
    });

    testWidgets('contains a Shimmer widget', (WidgetTester tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.byType(Shimmer), findsOneWidget);
    });

    testWidgets('contains a CircleAvatar as avatar placeholder', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildCard());
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('renders with showActions = false without crashing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildCard(showActions: false));
      expect(find.byType(SkeletonListCard), findsOneWidget);
    });

    testWidgets('accepts custom colors without crashing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildCard(baseColor: Colors.grey[300], highlightColor: Colors.white),
      );
      expect(find.byType(Shimmer), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // SkeletonListLoading
  // ---------------------------------------------------------------------------
  group('SkeletonListLoading', () {
    Widget buildList({int itemCount = 3, bool showActions = true}) {
      return MaterialApp(
        home: Scaffold(
          body: SkeletonListLoading(
            itemCount: itemCount,
            showActions: showActions,
          ),
        ),
      );
    }

    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildList());
      expect(find.byType(SkeletonListLoading), findsOneWidget);
    });

    testWidgets('renders the expected number of SkeletonListCard items', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildList(itemCount: 3));
      expect(find.byType(SkeletonListCard), findsNWidgets(3));
    });

    testWidgets('renders a ListView', (WidgetTester tester) async {
      await tester.pumpWidget(buildList());
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('renders correct count when itemCount = 1', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildList(itemCount: 1));
      expect(find.byType(SkeletonListCard), findsOneWidget);
    });

    testWidgets('passes showActions to child cards', (
      WidgetTester tester,
    ) async {
      // Just verify it renders without throwing when showActions=false.
      await tester.pumpWidget(buildList(showActions: false));
      expect(find.byType(SkeletonListCard), findsNWidgets(3));
    });
  });
}
