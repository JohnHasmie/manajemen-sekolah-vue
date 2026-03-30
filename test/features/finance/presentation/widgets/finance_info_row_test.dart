// Tests for FinanceInfoRow — a label-value row used in payment dialogs.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_info_row.dart';

Widget _build(String label, String value) => MaterialApp(
      home: Scaffold(body: FinanceInfoRow(label: label, value: value)),
    );

void main() {
  group('FinanceInfoRow', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_build('Nama', 'Ahmad Fauzi'));
      expect(find.byType(FinanceInfoRow), findsOneWidget);
    });

    testWidgets('displays the label', (tester) async {
      await tester.pumpWidget(_build('Jumlah', 'Rp 150.000'));
      expect(find.text('Jumlah'), findsOneWidget);
    });

    testWidgets('displays the value', (tester) async {
      await tester.pumpWidget(_build('Jumlah', 'Rp 150.000'));
      expect(find.text('Rp 150.000'), findsOneWidget);
    });

    testWidgets('shows the colon separator', (tester) async {
      await tester.pumpWidget(_build('Status', 'Lunas'));
      expect(find.text(': '), findsOneWidget);
    });

    testWidgets('handles empty label and value without crashing', (tester) async {
      await tester.pumpWidget(_build('', ''));
      expect(find.byType(FinanceInfoRow), findsOneWidget);
    });

    testWidgets('displays long value text without overflow crash', (tester) async {
      await tester.pumpWidget(_build(
        'Keterangan',
        'Pembayaran SPP bulan Maret 2025 untuk kelas VII-A sudah diterima',
      ));
      expect(find.byType(FinanceInfoRow), findsOneWidget);
    });

    testWidgets('label column has fixed 80px width', (tester) async {
      await tester.pumpWidget(_build('Siswa', 'Budi'));
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, 80);
    });

    testWidgets('value expands to fill remaining width', (tester) async {
      await tester.pumpWidget(_build('Kelas', 'VII-A'));
      expect(find.byType(Expanded), findsOneWidget);
    });

    testWidgets('can stack multiple rows without crashing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FinanceInfoRow(label: 'Nama', value: 'Budi'),
                FinanceInfoRow(label: 'Kelas', value: 'VII-A'),
                FinanceInfoRow(label: 'Total', value: 'Rp 500.000'),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(FinanceInfoRow), findsNWidgets(3));
      expect(find.text('Nama'), findsOneWidget);
      expect(find.text('Kelas'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
    });

    testWidgets('renders currency value correctly', (tester) async {
      await tester.pumpWidget(_build('Tagihan', 'Rp 1.500.000'));
      expect(find.text('Rp 1.500.000'), findsOneWidget);
    });

    testWidgets('label font size is 12', (tester) async {
      await tester.pumpWidget(_build('Label', 'Value'));
      final labelText = tester.widget<Text>(find.text('Label'));
      expect(labelText.style?.fontSize, 12);
    });

    testWidgets('value font size is 12', (tester) async {
      await tester.pumpWidget(_build('Label', 'Value'));
      final valueText = tester.widget<Text>(find.text('Value'));
      expect(valueText.style?.fontSize, 12);
    });
  });
}
