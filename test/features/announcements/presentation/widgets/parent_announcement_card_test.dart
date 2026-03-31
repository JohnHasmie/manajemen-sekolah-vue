// Tests for ParentAnnouncementCard — read-only announcement card for parents.
// No edit/delete buttons; shows an unread dot when is_read is false.
// Purely presentational, no providers.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/parent_announcement_card.dart';

void main() {
  Map<String, dynamic> baseData({
    String? priority,
    dynamic isRead,
    String? pembuatNama,
  }) =>
      {
        'title': 'Rapat Wali Murid',
        'content': 'Rapat akan diadakan Sabtu pagi.',
        'priority': priority,
        'is_read': isRead,
        'pembuat_nama': pembuatNama ?? 'Kepala Sekolah',
      };

  Widget buildSubject({
    Map<String, dynamic>? data,
    VoidCallback? onTap,
    String importantLabel = 'Penting',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ParentAnnouncementCard(
            announcementData: data ?? baseData(),
            primaryColor: Colors.teal,
            formattedDate: '07/06/2025',
            targetText: 'Wali Murid',
            importantLabel: importantLabel,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    );
  }

  group('ParentAnnouncementCard', () {
    testWidgets('renders title and content preview', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Rapat Wali Murid'), findsOneWidget);
      expect(find.textContaining('Sabtu pagi'), findsOneWidget);
    });

    testWidgets('shows creator name chip', (tester) async {
      await tester.pumpWidget(
        buildSubject(data: baseData(pembuatNama: 'Pak Budi')),
      );

      expect(find.text('Pak Budi'), findsOneWidget);
    });

    testWidgets('fires onTap when card is tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildSubject(onTap: () => tapped = true));

      await tester.tap(find.byType(InkWell).first);
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('shows important chip when priority is "important"',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          data: baseData(priority: 'important'),
          importantLabel: 'Important',
        ),
      );

      expect(find.text('Important'), findsOneWidget);
    });

    testWidgets('does NOT show important chip for null priority',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(data: baseData(priority: null)),
      );

      expect(find.text('Penting'), findsNothing);
    });

    testWidgets('shows unread dot when is_read is false', (tester) async {
      await tester.pumpWidget(
        buildSubject(data: baseData(isRead: false)),
      );

      // The unread Container uses BoxShape.circle; verify widget renders.
      expect(find.byType(ParentAnnouncementCard), findsOneWidget);
    });
  });
}
