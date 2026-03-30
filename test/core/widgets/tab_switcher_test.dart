// Tests for the TabSwitcher widget.
//
// TabSwitcher requires a TabController which in turn requires a
// TickerProvider. We use SingleTickerProviderStateMixin via a simple
// StatefulWidget harness. No Riverpod dependencies.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/widgets/tab_switcher.dart';

// ---------------------------------------------------------------------------
// Test harness that owns a TabController and exposes it for assertions.
// ---------------------------------------------------------------------------
class _TabSwitcherHarness extends StatefulWidget {
  final List<TabItem> tabs;
  final Color? primaryColor;
  final void Function(TabController)? onControllerReady;

  const _TabSwitcherHarness({
    required this.tabs,
    this.primaryColor,
    this.onControllerReady,
  });

  @override
  State<_TabSwitcherHarness> createState() => _TabSwitcherHarnessState();
}

class _TabSwitcherHarnessState extends State<_TabSwitcherHarness>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: widget.tabs.length, vsync: this);
    widget.onControllerReady?.call(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: TabSwitcher(
          tabController: _controller,
          tabs: widget.tabs,
          primaryColor: widget.primaryColor,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Convenience factory for the two-tab case used by most tests.
// ---------------------------------------------------------------------------
List<TabItem> _twoTabs() => [
  TabItem(label: 'Students', icon: Icons.people),
  TabItem(label: 'Teachers', icon: Icons.school),
];

void main() {
  group('TabSwitcher', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(_TabSwitcherHarness(tabs: _twoTabs()));
      expect(find.byType(TabSwitcher), findsOneWidget);
    });

    testWidgets('renders all tab labels', (WidgetTester tester) async {
      await tester.pumpWidget(_TabSwitcherHarness(tabs: _twoTabs()));
      expect(find.text('Students'), findsOneWidget);
      expect(find.text('Teachers'), findsOneWidget);
    });

    testWidgets('renders icons for each tab', (WidgetTester tester) async {
      await tester.pumpWidget(_TabSwitcherHarness(tabs: _twoTabs()));
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.people),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.school),
        findsOneWidget,
      );
    });

    testWidgets('tapping a tab calls animateTo on the controller', (
      WidgetTester tester,
    ) async {
      TabController? ctrl;
      await tester.pumpWidget(
        _TabSwitcherHarness(
          tabs: _twoTabs(),
          onControllerReady: (c) => ctrl = c,
        ),
      );
      // Tap the second tab ("Teachers").
      await tester.tap(find.text('Teachers'));
      await tester.pumpAndSettle();
      expect(ctrl!.index, 1);
    });

    testWidgets('first tab is selected by default', (
      WidgetTester tester,
    ) async {
      TabController? ctrl;
      await tester.pumpWidget(
        _TabSwitcherHarness(
          tabs: _twoTabs(),
          onControllerReady: (c) => ctrl = c,
        ),
      );
      expect(ctrl!.index, 0);
    });

    testWidgets('accepts a custom primaryColor without crashing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _TabSwitcherHarness(tabs: _twoTabs(), primaryColor: Colors.green),
      );
      expect(find.byType(TabSwitcher), findsOneWidget);
    });
  });
}
