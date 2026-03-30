// Widget tests for ReportCardStatusBadge.
// Pure StatelessWidget — no providers needed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/report_card_status_badge.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ReportCardStatusBadge', () {
    testWidgets('shows "Belum Isi" when hasReportCard is false', (tester) async {
      await tester.pumpWidget(
        _wrap(const ReportCardStatusBadge(
          hasReportCard: false,
          status: '',
        )),
      );
      expect(find.text('Belum Isi'), findsOneWidget);
    });

    testWidgets('shows "Draft" when hasReportCard is true and status is "draft"', (tester) async {
      await tester.pumpWidget(
        _wrap(const ReportCardStatusBadge(
          hasReportCard: true,
          status: 'draft',
        )),
      );
      expect(find.text('Draft'), findsOneWidget);
    });

    testWidgets('status comparison is case-insensitive (DRAFT → Draft label)', (tester) async {
      await tester.pumpWidget(
        _wrap(const ReportCardStatusBadge(
          hasReportCard: true,
          status: 'DRAFT',
        )),
      );
      expect(find.text('Draft'), findsOneWidget);
    });

    testWidgets('shows "Selesai" when hasReportCard is true and status is "final"', (tester) async {
      await tester.pumpWidget(
        _wrap(const ReportCardStatusBadge(
          hasReportCard: true,
          status: 'final',
        )),
      );
      expect(find.text('Selesai'), findsOneWidget);
    });

    testWidgets('shows "Selesai" when hasReportCard is true and status is "published"', (tester) async {
      await tester.pumpWidget(
        _wrap(const ReportCardStatusBadge(
          hasReportCard: true,
          status: 'published',
        )),
      );
      expect(find.text('Selesai'), findsOneWidget);
    });

    testWidgets('widget renders inside a Container with a rounded border radius', (tester) async {
      await tester.pumpWidget(
        _wrap(const ReportCardStatusBadge(
          hasReportCard: false,
          status: '',
        )),
      );
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(12));
    });
  });
}
