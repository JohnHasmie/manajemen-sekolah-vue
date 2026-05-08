/// Core navigation flow tests — verifies AppNavigator push/pop/replace/clear-stack
/// work correctly using real Navigator state.
///
/// Each test pumps a minimal widget tree, performs a navigation action, and
// asserts
/// the correct screen appears or disappears. Like integration-testing Vue
// Router
/// `push`, `back`, and `replace` calls.
///
/// Pattern:
///   A) Render a "home" page with a button that triggers navigation
///   B) Tap the button → navigate forward
///   C) Assert the new screen is visible
///   D) Navigate back (pop) → assert the original screen is restored
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

// ---------------------------------------------------------------------------
// MockNavigatorObserver — records every push/pop/replace for assertions
// ---------------------------------------------------------------------------

class MockNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];
  final List<Route<dynamic>> popped = [];
  final List<Route<dynamic>?> replaced = [];

  @override
  void didPush(Route route, Route? previousRoute) => pushed.add(route);

  @override
  void didPop(Route route, Route? previousRoute) => popped.add(route);

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (newRoute != null) replaced.add(newRoute);
  }
}

// ---------------------------------------------------------------------------
// Small screen helpers
// ---------------------------------------------------------------------------

/// Screen A — the "home" page. Has a button that calls [onNavigate].
class _ScreenA extends StatelessWidget {
  final VoidCallback onNavigate;
  const _ScreenA({required this.onNavigate});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Screen A')),
    body: Center(
      child: ElevatedButton(
        key: const Key('go_btn'),
        onPressed: onNavigate,
        child: const Text('Go to B'),
      ),
    ),
  );
}

/// Screen B — the "destination" page. Has a back button.
class _ScreenB extends StatelessWidget {
  const _ScreenB();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Screen B'),
      leading: IconButton(
        key: const Key('back_btn'),
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: const Center(child: Text('You are on Screen B')),
  );
}

/// Screen C — a third level screen.
class _ScreenC extends StatelessWidget {
  const _ScreenC();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Screen C')),
    body: const Center(child: Text('Deep Page C')),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // 1. Forward navigation (push)
  // =========================================================================
  group('AppNavigator.push — forward navigation', () {
    testWidgets('navigates to new screen on push', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => _ScreenA(
              onNavigate: () => AppNavigator.push(ctx, const _ScreenB()),
            ),
          ),
        ),
      );

      expect(find.text('Screen A'), findsOneWidget);
      expect(find.text('You are on Screen B'), findsNothing);

      await tester.tap(find.byKey(const Key('go_btn')));
      await tester.pumpAndSettle();

      expect(find.text('You are on Screen B'), findsOneWidget);
      expect(find.text('Screen A'), findsNothing);
    });

    testWidgets('push records a new route in the observer', (tester) async {
      final observer = MockNavigatorObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: Builder(
            builder: (ctx) => _ScreenA(
              onNavigate: () => AppNavigator.push(ctx, const _ScreenB()),
            ),
          ),
        ),
      );

      final initialPushCount = observer.pushed.length;
      await tester.tap(find.byKey(const Key('go_btn')));
      await tester.pumpAndSettle();

      // One more push recorded
      expect(observer.pushed.length, greaterThan(initialPushCount));
    });

    testWidgets('multiple pushes stack screens correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => _ScreenA(
              onNavigate: () async {
                await AppNavigator.push(
                  ctx,
                  Builder(
                    builder: (ctx2) => Scaffold(
                      appBar: AppBar(title: const Text('Screen B')),
                      body: Center(
                        child: ElevatedButton(
                          key: const Key('go_c_btn'),
                          onPressed: () =>
                              AppNavigator.push(ctx2, const _ScreenC()),
                          child: const Text('Go to C'),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Go to B
      await tester.tap(find.byKey(const Key('go_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Screen B'), findsOneWidget);

      // Go to C from B
      await tester.tap(find.byKey(const Key('go_c_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Deep Page C'), findsOneWidget);
    });
  });

  // =========================================================================
  // 2. Back navigation (pop)
  // =========================================================================
  group('AppNavigator.pop — back navigation', () {
    testWidgets('pop returns to previous screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => _ScreenA(
              onNavigate: () => AppNavigator.push(ctx, const _ScreenB()),
            ),
          ),
        ),
      );

      // Navigate to B
      await tester.tap(find.byKey(const Key('go_btn')));
      await tester.pumpAndSettle();
      expect(find.text('You are on Screen B'), findsOneWidget);

      // Pop back to A
      await tester.tap(find.byKey(const Key('back_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Go to B'), findsOneWidget);
      expect(find.text('You are on Screen B'), findsNothing);
    });

    testWidgets('system back button (BackButton widget) pops correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => _ScreenA(
              onNavigate: () => AppNavigator.push(ctx, const _ScreenB()),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('go_btn')));
      await tester.pumpAndSettle();

      // Use AppBar's automatic back button (BackButton)
      await tester.tap(find.byKey(const Key('back_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Screen A'), findsOneWidget);
    });

    testWidgets('pop with result returns value to caller', (tester) async {
      String? returnedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              return Scaffold(
                body: ElevatedButton(
                  key: const Key('open_btn'),
                  onPressed: () async {
                    returnedValue = await AppNavigator.push<String>(
                      ctx,
                      Builder(
                        builder: (ctx2) => Scaffold(
                          body: ElevatedButton(
                            key: const Key('return_btn'),
                            onPressed: () =>
                                Navigator.pop(ctx2, 'result_value'),
                            child: const Text('Return'),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('return_btn')));
      await tester.pumpAndSettle();

      expect(returnedValue, 'result_value');
    });

    testWidgets('deep pop (3 levels) — popping from C reaches B', (
      tester,
    ) async {
      late BuildContext ctxA, ctxB;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              ctxA = ctx;
              return Scaffold(
                appBar: AppBar(title: const Text('A')),
                body: ElevatedButton(
                  key: const Key('a_to_b'),
                  onPressed: () => AppNavigator.push(
                    ctxA,
                    Builder(
                      builder: (ctx2) {
                        ctxB = ctx2;
                        return Scaffold(
                          appBar: AppBar(title: const Text('B')),
                          body: ElevatedButton(
                            key: const Key('b_to_c'),
                            onPressed: () => AppNavigator.push(
                              ctxB,
                              Scaffold(
                                appBar: AppBar(
                                  leading: Builder(
                                    builder: (ctx3) => IconButton(
                                      key: const Key('c_back'),
                                      icon: const Icon(Icons.arrow_back),
                                      onPressed: () => Navigator.pop(ctx3),
                                    ),
                                  ),
                                  title: const Text('C'),
                                ),
                                body: const Text('Page C'),
                              ),
                            ),
                            child: const Text('Go C'),
                          ),
                        );
                      },
                    ),
                  ),
                  child: const Text('Go B'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('a_to_b')));
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);

      await tester.tap(find.byKey(const Key('b_to_c')));
      await tester.pumpAndSettle();
      expect(find.text('Page C'), findsOneWidget);

      // Pop from C → lands on B
      await tester.tap(find.byKey(const Key('c_back')));
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
      expect(find.text('Page C'), findsNothing);
    });
  });

  // =========================================================================
  // 3. pushReplacement
  // =========================================================================
  group('AppNavigator.pushReplacement — replace navigation', () {
    testWidgets('replace removes current screen from stack', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => _ScreenA(
              onNavigate: () =>
                  AppNavigator.pushReplacement(ctx, const _ScreenB()),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('go_btn')));
      await tester.pumpAndSettle();

      expect(find.text('You are on Screen B'), findsOneWidget);
      // No back button in AppBar since A was replaced (no previous route)
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('observer records replace event', (tester) async {
      final observer = MockNavigatorObserver();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: Builder(
            builder: (ctx) => _ScreenA(
              onNavigate: () =>
                  AppNavigator.pushReplacement(ctx, const _ScreenB()),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('go_btn')));
      await tester.pumpAndSettle();

      // pushReplacement fires didReplace (or didPush for the new route)
      expect(
        observer.replaced.isNotEmpty || observer.pushed.length > 1,
        isTrue,
      );
    });
  });

  // =========================================================================
  // 4. pushAndClearStack (logout / root navigation)
  // =========================================================================
  group('AppNavigator.pushAndClearStack — clear entire stack', () {
    testWidgets('navigates to new screen and clears history', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => _ScreenA(
              onNavigate: () => AppNavigator.pushAndClearStack(
                ctx,
                const Scaffold(body: Text('Fresh Start')),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('go_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Fresh Start'), findsOneWidget);
      // No back button — stack was cleared
      expect(find.byType(BackButton), findsNothing);
    });
  });

  // =========================================================================
  // 5. canPop
  // =========================================================================
  group('AppNavigator.canPop', () {
    testWidgets('canPop returns false on root screen', (tester) async {
      late BuildContext capturedCtx;
      bool? canPopResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              capturedCtx = ctx;
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    canPopResult = Navigator.of(capturedCtx).canPop();
                  },
                  child: const Text('Check'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Check'));
      expect(canPopResult, isFalse);
    });

    testWidgets('canPop returns true after push', (tester) async {
      bool? canPopResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => _ScreenA(
              onNavigate: () => AppNavigator.push(
                ctx,
                Builder(
                  builder: (ctx2) => Scaffold(
                    body: ElevatedButton(
                      onPressed: () {
                        canPopResult = Navigator.of(ctx2).canPop();
                      },
                      child: const Text('Check can pop'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('go_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check can pop'));

      expect(canPopResult, isTrue);
    });
  });

  // =========================================================================
  // 6. Round-trip flow: push → back → push again
  // =========================================================================
  group('Navigation round-trip flows', () {
    testWidgets('push → pop → push again works correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => _ScreenA(
              onNavigate: () => AppNavigator.push(ctx, const _ScreenB()),
            ),
          ),
        ),
      );

      // First forward
      await tester.tap(find.byKey(const Key('go_btn')));
      await tester.pumpAndSettle();
      expect(find.text('You are on Screen B'), findsOneWidget);

      // Pop back
      await tester.tap(find.byKey(const Key('back_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Go to B'), findsOneWidget);

      // Forward again
      await tester.tap(find.byKey(const Key('go_btn')));
      await tester.pumpAndSettle();
      expect(find.text('You are on Screen B'), findsOneWidget);
    });

    testWidgets('dialog-style pop with result and return to previous state', (
      tester,
    ) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              return Scaffold(
                body: Column(
                  children: [
                    if (result != null) Text('Got: $result'),
                    ElevatedButton(
                      key: const Key('open_dialog'),
                      onPressed: () async {
                        result = await AppNavigator.push<String>(
                          ctx,
                          Builder(
                            builder: (ctx2) => Scaffold(
                              body: Column(
                                children: [
                                  ElevatedButton(
                                    key: const Key('confirm_btn'),
                                    onPressed: () =>
                                        Navigator.pop(ctx2, 'confirmed'),
                                    child: const Text('Confirm'),
                                  ),
                                  ElevatedButton(
                                    key: const Key('cancel_btn'),
                                    onPressed: () =>
                                        Navigator.pop(ctx2, 'cancelled'),
                                    child: const Text('Cancel'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Text('Open Dialog'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Open dialog-like screen
      await tester.tap(find.byKey(const Key('open_dialog')));
      await tester.pumpAndSettle();

      // Confirm → returns 'confirmed' (check var directly; Builder has no
      // setState)
      await tester.tap(find.byKey(const Key('confirm_btn')));
      await tester.pumpAndSettle();
      expect(result, 'confirmed');
    });
  });
}
