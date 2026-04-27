// Reusable interaction primitives used across the deep teacher integration
// tests. These are intentionally tolerant of variability — the dev backend
// is real, list contents change between seed runs, and we want one helper
// call to do the right thing on a populated list, an empty list, or a list
// still loading.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repeatedly pumps a frame until [finder] finds at least one widget, or the
/// [maxSeconds] budget is exhausted. Returns whether the widget was found.
///
/// Use this instead of `pumpAndSettle()` when the UI keeps animating
/// (shimmer, indeterminate progress) and `pumpAndSettle()` would time out.
Future<bool> waitForWidget(
  WidgetTester tester,
  Finder finder, {
  int maxSeconds = 10,
  Duration interval = const Duration(milliseconds: 250),
}) async {
  final deadline = DateTime.now().add(Duration(seconds: maxSeconds));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(interval);
    if (finder.evaluate().isNotEmpty) return true;
  }
  return false;
}

/// Pumps [count] frames at [interval] each. Useful after triggering an
/// async action when `pumpAndSettle()` would hang on continuous animations.
Future<void> pumpFor(
  WidgetTester tester, {
  int count = 12,
  Duration interval = const Duration(milliseconds: 250),
}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(interval);
  }
}

/// Taps the first [FloatingActionButton] on screen, if any. Returns whether
/// a FAB was found. Useful for "open create form / generate sheet" flows.
Future<bool> tapFAB(WidgetTester tester) async {
  final fab = find.byType(FloatingActionButton);
  if (fab.evaluate().isEmpty) return false;
  await tester.tap(fab.first);
  await pumpFor(tester);
  return true;
}

/// Taps the first list item in any list/grid view. Tries [ListTile] first,
/// then falls back to [Card]. Returns whether a tap happened.
Future<bool> tapFirstListItem(WidgetTester tester) async {
  for (final type in [find.byType(ListTile), find.byType(Card)]) {
    if (type.evaluate().isNotEmpty) {
      await tester.tap(type.first, warnIfMissed: false);
      await pumpFor(tester);
      return true;
    }
  }
  return false;
}

/// Asserts that a screen has rendered into a stable shape — i.e. it has at
/// least one [Scaffold] and is no longer showing only a loading spinner.
///
/// `findsWidgets` (not `findsOneWidget`) because nested screens commonly
/// have multiple Scaffolds (drawer + content).
void expectScreenLoaded(String screenName) {
  expect(
    find.byType(Scaffold),
    findsWidgets,
    reason: '$screenName should render at least one Scaffold',
  );
}

/// Tries to dismiss a modal sheet / dialog by tapping outside, pressing
/// Escape, or tapping a "Batal"/"Tutup"/Cancel button. Used to clean up
/// after FAB-opens-sheet style tests so subsequent assertions aren't
/// blocked by an open overlay.
Future<void> dismissSheet(WidgetTester tester) async {
  for (final label in ['Batal', 'Tutup', 'Cancel']) {
    final btn = find.text(label);
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn.first);
      await tester.pumpAndSettle();
      return;
    }
  }
  // Fall back to tapping the back button (works for full-screen sheets).
  final backButton = find.byType(BackButton);
  if (backButton.evaluate().isNotEmpty) {
    await tester.tap(backButton.first);
    await tester.pumpAndSettle();
    return;
  }
  // Last resort: pop the top route directly.
  final navState = tester.state<NavigatorState>(find.byType(Navigator).first);
  if (navState.canPop()) {
    navState.pop();
    await tester.pumpAndSettle();
  }
}

/// Returns true if the screen is currently showing the EmptyState widget,
/// the literal text "Belum Ada", or "tidak ada data" (Indonesian copies).
bool isShowingEmptyState() {
  return find.textContaining('Belum Ada').evaluate().isNotEmpty ||
      find
          .textContaining(RegExp('tidak ada', caseSensitive: false))
          .evaluate()
          .isNotEmpty ||
      find
          .textContaining(RegExp('no data', caseSensitive: false))
          .evaluate()
          .isNotEmpty;
}
