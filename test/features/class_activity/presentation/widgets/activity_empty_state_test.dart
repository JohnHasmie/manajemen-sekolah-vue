// Tests for ActivityEmptyState — centred placeholder shown when the list is
// empty.
// Purely presentational: one required [message] param, no providers.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_empty_state.dart';

void main() {
  Widget buildSubject(String message) {
    return MaterialApp(
      home: Scaffold(body: ActivityEmptyState(message: message)),
    );
  }

  group('ActivityEmptyState', () {
    testWidgets('displays the provided message', (tester) async {
      await tester.pumpWidget(buildSubject('No activities found'));

      expect(find.text('No activities found'), findsOneWidget);
    });

    testWidgets('renders the event_note icon', (tester) async {
      await tester.pumpWidget(buildSubject('Empty'));

      expect(find.byIcon(Icons.event_note_outlined), findsOneWidget);
    });

    testWidgets('widget is centred (Center ancestor present)', (tester) async {
      await tester.pumpWidget(buildSubject('Nothing here'));

      expect(find.byType(Center), findsWidgets);
    });

    testWidgets('renders with a long message without overflow error', (
      tester,
    ) async {
      final longMsg = 'A' * 200;
      await tester.pumpWidget(buildSubject(longMsg));

      // Should pump without throwing an exception.
      expect(find.byType(ActivityEmptyState), findsOneWidget);
    });

    testWidgets('renders with an empty string message', (tester) async {
      await tester.pumpWidget(buildSubject(''));

      expect(find.byType(ActivityEmptyState), findsOneWidget);
    });
  });
}
