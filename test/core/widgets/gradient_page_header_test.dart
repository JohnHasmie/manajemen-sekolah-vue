// Tests for the GradientPageHeader widget.
//
// The header uses AppNavigator.canPop (which calls context.canPop from
// go_router). To avoid setting up a full go_router stack we wrap the widget
// inside a Navigator with at least one route so canPop returns false and
// no back button is rendered unless we supply onBackPressed explicitly.
// No Riverpod dependencies.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:manajemensekolah/core/widgets/gradient_page_header.dart';

// GradientPageHeader calls AppNavigator.canPop → context.canPop (go_router),
// so tests must be wrapped in a GoRouter context.
Widget buildWidget({
  String title = 'Page Title',
  String subtitle = 'Subtitle here',
  Color primaryColor = Colors.blue,
  VoidCallback? onBackPressed,
  Widget? actionMenu,
  Widget? searchBar,
  Widget? filterChips,
}) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => Scaffold(
        body: GradientPageHeader(
          title: title,
          subtitle: subtitle,
          primaryColor: primaryColor,
          onBackPressed: onBackPressed,
          actionMenu: actionMenu,
          searchBar: searchBar,
          filterChips: filterChips,
        ),
      ),
    ),
  ]);
  return MaterialApp.router(routerConfig: router);
}

void main() {
  group('GradientPageHeader', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(GradientPageHeader), findsOneWidget);
    });

    testWidgets('displays the title text', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(title: 'Manajemen Siswa'));
      expect(find.text('Manajemen Siswa'), findsOneWidget);
    });

    testWidgets('displays the subtitle text', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(subtitle: 'Kelola data siswa'));
      expect(find.text('Kelola data siswa'), findsOneWidget);
    });

    testWidgets('shows back button when onBackPressed is provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget(onBackPressed: () {}));
      // GestureDetector wrapping the back arrow container should be present.
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.arrow_back,
        ),
        findsOneWidget,
      );
    });

    testWidgets('onBackPressed callback fires when back button is tapped', (
      WidgetTester tester,
    ) async {
      int callCount = 0;
      await tester.pumpWidget(buildWidget(onBackPressed: () => callCount++));
      await tester.tap(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.arrow_back),
      );
      await tester.pump();
      expect(callCount, 1);
    });

    testWidgets('renders optional actionMenu widget', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(actionMenu: const Icon(Icons.more_vert, key: Key('menu'))),
      );
      expect(find.byKey(const Key('menu')), findsOneWidget);
    });

    testWidgets('renders optional searchBar widget', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          searchBar: const Text('search bar slot', key: Key('search')),
        ),
      );
      expect(find.byKey(const Key('search')), findsOneWidget);
    });

    testWidgets('renders optional filterChips widget', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          filterChips: const Text('filter chips slot', key: Key('chips')),
        ),
      );
      expect(find.byKey(const Key('chips')), findsOneWidget);
    });
  });
}
