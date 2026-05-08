// ignore_for_file: lines_longer_than_80_chars
/// Tests for AppNavigator — widget tests verifying push, pop, canPop,
/// pushReplacement, and pushAndClearStack work correctly.
///
/// The `pop` and `canPop` methods use go_router's context extensions,
/// so those tests wrap the widget tree in a GoRouter. The `push`-family
/// methods use plain Navigator, so MaterialApp is sufficient.
///
/// Like testing Vue Router's `this.$router.push()` and `this.$router.back()`
/// to ensure navigation moves between screens as expected.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

void main() {
  group('AppNavigator', () {
    testWidgets('push navigates to a new screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppNavigator.push(
                      context,
                      const Scaffold(body: Text('Second Screen')),
                    );
                  },
                  child: const Text('Go'),
                );
              },
            ),
          ),
        ),
      );

      // Verify we start on the first screen
      expect(find.text('Go'), findsOneWidget);
      expect(find.text('Second Screen'), findsNothing);

      // Push to second screen
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      // Verify we're on the second screen
      expect(find.text('Second Screen'), findsOneWidget);
    });

    testWidgets('push returns result when popped with value', (tester) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await AppNavigator.push<String>(
                      context,
                      Scaffold(
                        body: Builder(
                          builder: (innerContext) {
                            return ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(innerContext, 'done'),
                              child: const Text('Pop with result'),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('Go'),
                );
              },
            ),
          ),
        ),
      );

      // Push to second screen
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      // Pop with result
      await tester.tap(find.text('Pop with result'));
      await tester.pumpAndSettle();

      expect(result, 'done');
    });

    testWidgets('pop goes back to previous screen (via GoRouter)', (
      tester,
    ) async {
      // AppNavigator.pop uses context.canPop()/context.pop() from go_router,
      // so we must provide a GoRouter in the widget tree.
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (ctx) {
                  return ElevatedButton(
                    onPressed: () {
                      // Use Navigator.push (like AppNavigator.push does) to add a route
                      //
                      Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            body: Builder(
                              builder: (innerContext) {
                                return ElevatedButton(
                                  onPressed: () =>
                                      AppNavigator.pop(innerContext),
                                  child: const Text('Go Back'),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Go Forward'),
                  );
                },
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Navigate forward
      await tester.tap(find.text('Go Forward'));
      await tester.pumpAndSettle();
      expect(find.text('Go Back'), findsOneWidget);

      // Pop back
      await tester.tap(find.text('Go Back'));
      await tester.pumpAndSettle();
      expect(find.text('Go Forward'), findsOneWidget);
    });

    testWidgets('canPop returns true when there is a route to pop', (
      tester,
    ) async {
      bool? canPopResult;

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (ctx) {
                  return ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            body: Builder(
                              builder: (innerContext) {
                                return ElevatedButton(
                                  onPressed: () {
                                    canPopResult = AppNavigator.canPop(
                                      innerContext,
                                    );
                                  },
                                  child: const Text('Check canPop'),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Go Forward'),
                  );
                },
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Navigate to second screen to create a stack
      await tester.tap(find.text('Go Forward'));
      await tester.pumpAndSettle();

      // Check canPop on the second screen (should be true)
      await tester.tap(find.text('Check canPop'));
      await tester.pump();

      expect(canPopResult, isTrue);
    });

    testWidgets('canPop returns false on the root route', (tester) async {
      bool? canPopResult;

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (ctx) {
                  return ElevatedButton(
                    onPressed: () {
                      canPopResult = AppNavigator.canPop(ctx);
                    },
                    child: const Text('Check canPop'),
                  );
                },
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check canPop'));
      await tester.pump();

      expect(canPopResult, isFalse);
    });

    testWidgets('pushReplacement replaces current route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppNavigator.pushReplacement(
                      context,
                      const Scaffold(body: Text('Replacement Screen')),
                    );
                  },
                  child: const Text('Replace'),
                );
              },
            ),
          ),
        ),
      );

      // Push replacement
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();

      // Verify we're on the replacement screen
      expect(find.text('Replacement Screen'), findsOneWidget);
      expect(find.text('Replace'), findsNothing);
    });

    testWidgets('pushAndClearStack clears all routes and shows new screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    // First push a route so we have a stack
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          body: Builder(
                            builder: (innerContext) {
                              return ElevatedButton(
                                onPressed: () {
                                  AppNavigator.pushAndClearStack(
                                    innerContext,
                                    const Scaffold(body: Text('Fresh Start')),
                                  );
                                },
                                child: const Text('Clear Stack'),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Go'),
                );
              },
            ),
          ),
        ),
      );

      // Navigate forward
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      // Clear stack and navigate to fresh screen
      await tester.tap(find.text('Clear Stack'));
      await tester.pumpAndSettle();

      expect(find.text('Fresh Start'), findsOneWidget);
    });
  });
}
