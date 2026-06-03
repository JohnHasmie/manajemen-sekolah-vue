// Tests for ActivityTypeOptionTile — a tappable card for selecting an type.
// activity
// Purely presentational, no providers.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_type_option_tile.dart';

void main() {
  Widget buildSubject({
    IconData icon = Icons.assignment_outlined,
    String title = 'Tugas',
    String description = 'Buat tugas baru',
    Color color = Colors.blue,
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ActivityTypeOptionTile(
          icon: icon,
          title: title,
          description: description,
          color: color,
          onTap: onTap ?? () {},
        ),
      ),
    );
  }

  group('ActivityTypeOptionTile', () {
    testWidgets('shows title and description', (tester) async {
      await tester.pumpWidget(
        buildSubject(title: 'Materi', description: 'Tambah materi pelajaran'),
      );

      expect(find.text('Materi'), findsOneWidget);
      expect(find.text('Tambah materi pelajaran'), findsOneWidget);
    });

    testWidgets('renders the provided icon', (tester) async {
      await tester.pumpWidget(buildSubject(icon: Icons.menu_book_outlined));

      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    });

    testWidgets('has no trailing arrow icon (redesigned tile)', (tester) async {
      // The redesigned tile uses a left accent line + leading icon circle
      // and dropped the trailing chevron. Only the provided leading icon
      // is rendered.
      await tester.pumpWidget(buildSubject(icon: Icons.assignment_outlined));

      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsNothing);
      expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);
    });

    testWidgets('fires onTap callback when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildSubject(onTap: () => tapped = true));

      await tester.tap(find.byType(ActivityTypeOptionTile));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('renders without errors for different accent colours', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(color: Colors.orange));

      expect(find.byType(ActivityTypeOptionTile), findsOneWidget);
    });
  });
}
