// Tests for AnnouncementCard — admin list-card with edit/delete actions.
// Purely presentational (no providers), all data driven via constructor params.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_card.dart';

void main() {
  Map<String, dynamic> baseData({String? priority, dynamic isRead}) => {
    'title': 'Libur Nasional',
    'content': 'Sekolah libur tanggal 17 Agustus.',
    'priority': priority,
    'is_read': isRead,
  };

  Widget buildSubject({
    Map<String, dynamic>? data,
    VoidCallback? onTap,
    String importantLabel = 'Penting',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AnnouncementCard(
            announcementData: data ?? baseData(),
            primaryColor: Colors.blue,
            formattedDate: '09/06/2025',
            targetText: 'Semua',
            onTap: onTap ?? () {},
            importantLabel: importantLabel,
          ),
        ),
      ),
    );
  }

  group('AnnouncementCard', () {
    testWidgets('renders title and content preview', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Libur Nasional'), findsOneWidget);
      expect(find.textContaining('17 Agustus'), findsOneWidget);
    });

    testWidgets('shows important label chip when priority is "penting"', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          data: baseData(priority: 'penting'),
          importantLabel: 'Penting',
        ),
      );

      expect(find.text('Penting'), findsOneWidget);
    });

    testWidgets('does NOT show important chip for normal priority', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(data: baseData(priority: 'normal')));

      // "Penting" text must not appear.
      expect(find.text('Penting'), findsNothing);
    });
  });
}
