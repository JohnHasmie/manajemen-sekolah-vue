/// Tests for SnackBarUtils — widget tests verifying each snackbar variant
/// displays correctly with the expected message and background color.
///
/// Like testing Laravel's `session()->flash()` to ensure the right
/// flash type (success/error/warning/info) is shown with correct styling.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

void main() {
  /// Helper: taps button, pumps, and returns the SnackBar widget.
  Future<SnackBar> tapAndGetSnackBar(WidgetTester tester) async {
    await tester.tap(find.text('tap'));
    await tester.pump(); // start the snackbar animation
    return tester.widget<SnackBar>(find.byType(SnackBar));
  }

  group('SnackBarUtils', () {
    testWidgets('showSuccess shows snackbar with message', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () =>
                  SnackBarUtils.showSuccess(context, 'Operation successful'),
              child: const Text('tap'),
            );
          }),
        ),
      ));

      await tester.tap(find.text('tap'));
      await tester.pump();

      expect(find.text('Operation successful'), findsOneWidget);
    });

    testWidgets('showSuccess uses green background', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => SnackBarUtils.showSuccess(context, 'OK'),
              child: const Text('tap'),
            );
          }),
        ),
      ));

      final snackBar = await tapAndGetSnackBar(tester);
      expect(snackBar.backgroundColor, Colors.green);
    });

    testWidgets('showError shows snackbar with message', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () =>
                  SnackBarUtils.showError(context, 'Something went wrong'),
              child: const Text('tap'),
            );
          }),
        ),
      ));

      await tester.tap(find.text('tap'));
      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('showError uses red background', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => SnackBarUtils.showError(context, 'Error'),
              child: const Text('tap'),
            );
          }),
        ),
      ));

      final snackBar = await tapAndGetSnackBar(tester);
      expect(snackBar.backgroundColor, Colors.red);
    });

    testWidgets('showWarning shows snackbar with message', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () =>
                  SnackBarUtils.showWarning(context, 'Be careful'),
              child: const Text('tap'),
            );
          }),
        ),
      ));

      await tester.tap(find.text('tap'));
      await tester.pump();

      expect(find.text('Be careful'), findsOneWidget);
    });

    testWidgets('showWarning uses orange background', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => SnackBarUtils.showWarning(context, 'Warning'),
              child: const Text('tap'),
            );
          }),
        ),
      ));

      final snackBar = await tapAndGetSnackBar(tester);
      expect(snackBar.backgroundColor, Colors.orange);
    });

    testWidgets('showInfo shows snackbar with message', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => SnackBarUtils.showInfo(context, 'FYI'),
              child: const Text('tap'),
            );
          }),
        ),
      ));

      await tester.tap(find.text('tap'));
      await tester.pump();

      expect(find.text('FYI'), findsOneWidget);
    });

    testWidgets('showInfo uses blue background', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => SnackBarUtils.showInfo(context, 'Info'),
              child: const Text('tap'),
            );
          }),
        ),
      ));

      final snackBar = await tapAndGetSnackBar(tester);
      expect(snackBar.backgroundColor, Colors.blue);
    });

    testWidgets('showErrorFromException extracts Exception message',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => SnackBarUtils.showErrorFromException(
                context,
                Exception('Network timeout'),
              ),
              child: const Text('tap'),
            );
          }),
        ),
      ));

      await tester.tap(find.text('tap'));
      await tester.pump();

      // The method strips "Exception: " prefix
      expect(find.text('Network timeout'), findsOneWidget);
    });

    testWidgets('showErrorFromException handles non-Exception error',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => SnackBarUtils.showErrorFromException(
                context,
                'Plain string error',
              ),
              child: const Text('tap'),
            );
          }),
        ),
      ));

      await tester.tap(find.text('tap'));
      await tester.pump();

      expect(find.text('Plain string error'), findsOneWidget);
    });

    testWidgets('showErrorFromException uses red background', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => SnackBarUtils.showErrorFromException(
                context,
                Exception('Boom'),
              ),
              child: const Text('tap'),
            );
          }),
        ),
      ));

      final snackBar = await tapAndGetSnackBar(tester);
      expect(snackBar.backgroundColor, Colors.red);
    });

    testWidgets('snackbar uses floating behavior', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => SnackBarUtils.showSuccess(context, 'Float'),
              child: const Text('tap'),
            );
          }),
        ),
      ));

      final snackBar = await tapAndGetSnackBar(tester);
      expect(snackBar.behavior, SnackBarBehavior.floating);
    });
  });
}
