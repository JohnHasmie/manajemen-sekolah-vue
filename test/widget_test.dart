// This is a basic Flutter widget test for the School Management App.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/main.dart';

void main() {
  testWidgets('SchoolManagementApp builds successfully', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SchoolManagementApp());

    // Wait for the app to initialize
    await tester.pumpAndSettle();

    // Verify that the app builds without errors
    // The app should show either a loading screen or the login/dashboard
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
