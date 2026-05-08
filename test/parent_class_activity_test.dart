import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart';

void main() {
  testWidgets('Renders ParentClassActivityScreen without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ParentClassActivityScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ParentClassActivityScreen), findsOneWidget);
  });
}
