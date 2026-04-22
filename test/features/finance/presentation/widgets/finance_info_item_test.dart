// Widget tests for FinanceInfoItem.
// Pure StatelessWidget — no providers needed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_info_item.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('FinanceInfoItem', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        _wrap(const FinanceInfoItem(label: 'Tagihan', value: 'Rp 500.000')),
      );
      expect(find.text('Tagihan'), findsOneWidget);
    });

    testWidgets('renders value text', (tester) async {
      await tester.pumpWidget(
        _wrap(const FinanceInfoItem(label: 'Tagihan', value: 'Rp 500.000')),
      );
      expect(find.text('Rp 500.000'), findsOneWidget);
    });

    testWidgets('label column is constrained to 100px wide via SizedBox', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const FinanceInfoItem(label: 'Status', value: 'Lunas')),
      );
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, 100);
    });

    testWidgets('value text is inside an Expanded widget', (tester) async {
      await tester.pumpWidget(
        _wrap(const FinanceInfoItem(label: 'Tanggal', value: '2025-01-01')),
      );
      // Expanded wraps the value Text — confirm the Expanded exists in the tree.
      expect(find.byType(Expanded), findsOneWidget);
    });

    testWidgets('renders correctly with empty value string', (tester) async {
      await tester.pumpWidget(
        _wrap(const FinanceInfoItem(label: 'Catatan', value: '')),
      );
      expect(find.text('Catatan'), findsOneWidget);
      // Empty string still renders a Text widget (just blank).
      expect(find.text(''), findsOneWidget);
    });

    testWidgets('wraps both texts in a Row layout', (tester) async {
      await tester.pumpWidget(
        _wrap(const FinanceInfoItem(label: 'Label', value: 'Value')),
      );
      expect(find.byType(Row), findsAtLeast(1));
    });
  });
}
