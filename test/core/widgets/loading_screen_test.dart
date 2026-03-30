// Tests for the LoadingScreen widget.
//
// Verifies default and custom message display, and spinner presence.
// No Riverpod dependencies.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/widgets/loading_screen.dart';

void main() {
  group('LoadingScreen', () {
    Widget buildWidget({String? message}) {
      return MaterialApp(
        home: message != null
            ? LoadingScreen(message: message)
            : const LoadingScreen(),
      );
    }

    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(LoadingScreen), findsOneWidget);
    });

    testWidgets('shows default message "Memuat data..." when none provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('Memuat data...'), findsOneWidget);
    });

    testWidgets('shows custom message when provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget(message: 'Loading students...'));
      expect(find.text('Loading students...'), findsOneWidget);
    });

    testWidgets('contains a CircularProgressIndicator', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('default message is not shown when custom message is given', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget(message: 'Please wait...'));
      expect(find.text('Memuat data...'), findsNothing);
      expect(find.text('Please wait...'), findsOneWidget);
    });
  });
}
