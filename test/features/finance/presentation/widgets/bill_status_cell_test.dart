// Widget tests for BillStatusCell.
// Pure StatelessWidget — no providers needed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/bill_status_cell.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('BillStatusCell', () {
    testWidgets('renders empty SizedBox when bill is null', (tester) async {
      await tester.pumpWidget(_wrap(const BillStatusCell(bill: null)));
      // No status text should be visible.
      expect(find.text('Lunas'), findsNothing);
      expect(find.text('Menunggu'), findsNothing);
      expect(find.text('Belum'), findsNothing);
      expect(find.byType(SizedBox), findsAtLeast(1));
    });

    testWidgets('shows "Lunas" for verified status', (tester) async {
      final bill = {'status': 'verified', 'payments': []};
      await tester.pumpWidget(_wrap(BillStatusCell(bill: bill)));
      expect(find.text('Lunas'), findsOneWidget);
    });

    testWidgets('shows "Menunggu" when a payment has pending status', (
      tester,
    ) async {
      final bill = {
        'status': 'unpaid',
        'payments': [
          {'status': 'pending'},
        ],
      };
      await tester.pumpWidget(_wrap(BillStatusCell(bill: bill)));
      expect(find.text('Menunggu'), findsOneWidget);
    });

    testWidgets(
      'shows "Belum" when status is not verified and no pending payments',
      (tester) async {
        final bill = {
          'status': 'unpaid',
          'payments': [
            {'status': 'rejected'},
          ],
        };
        await tester.pumpWidget(_wrap(BillStatusCell(bill: bill)));
        expect(find.text('Belum'), findsOneWidget);
      },
    );

    testWidgets('shows "Belum" when payments list is empty', (tester) async {
      final bill = {'status': 'unpaid', 'payments': []};
      await tester.pumpWidget(_wrap(BillStatusCell(bill: bill)));
      expect(find.text('Belum'), findsOneWidget);
    });

    testWidgets('fires onTap callback when tapped', (tester) async {
      bool tapped = false;
      final bill = {'status': 'verified', 'payments': []};
      await tester.pumpWidget(
        _wrap(BillStatusCell(bill: bill, onTap: () => tapped = true)),
      );
      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });
  });
}
