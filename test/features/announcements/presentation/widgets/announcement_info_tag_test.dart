// Tests for AnnouncementInfoTag — compact icon+text badge for announcement cards.
//
// Key scenarios:
// - Renders icon and text
// - tagColor=null: uses default slate color styling
// - tagColor provided: uses that color for icon, text, border, background
// - text has maxLines=1 and ellipsis overflow
//
// Purely presentational — no providers.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_info_tag.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _build({
  IconData icon = Icons.access_time_outlined,
  required String text,
  Color? tagColor,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: AnnouncementInfoTag(icon: icon, text: text, tagColor: tagColor),
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AnnouncementInfoTag — rendering', () {
    testWidgets('renders icon', (tester) async {
      await tester.pumpWidget(_build(
        icon: Icons.access_time_outlined,
        text: '1 Jan 2025',
      ));
      expect(find.byIcon(Icons.access_time_outlined), findsOneWidget);
    });

    testWidgets('renders text', (tester) async {
      await tester.pumpWidget(_build(text: '1 Jan 2025'));
      expect(find.text('1 Jan 2025'), findsOneWidget);
    });

    testWidgets('renders people icon', (tester) async {
      await tester.pumpWidget(_build(
        icon: Icons.people_outline,
        text: 'Semua',
      ));
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
    });

    testWidgets('text has maxLines=1 and ellipsis overflow', (tester) async {
      await tester.pumpWidget(_build(
        text: 'Teks yang sangat panjang dan perlu dipotong',
      ));
      final textWidget = tester.widget<Text>(
        find.text('Teks yang sangat panjang dan perlu dipotong'),
      );
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });
  });

  group('AnnouncementInfoTag — tagColor', () {
    testWidgets('renders without crash when tagColor is null', (tester) async {
      await tester.pumpWidget(_build(text: 'Default', tagColor: null));
      expect(find.byType(AnnouncementInfoTag), findsOneWidget);
    });

    testWidgets('renders without crash when tagColor=orange', (tester) async {
      await tester.pumpWidget(_build(
        text: 'Penting',
        tagColor: Colors.orange,
        icon: Icons.warning_amber_rounded,
      ));
      expect(find.text('Penting'), findsOneWidget);
    });
  });
}
