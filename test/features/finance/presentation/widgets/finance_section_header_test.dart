// Tests for FinanceSectionHeader — section header with left-border accent.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_section_header.dart';

Widget _build({
  String title = 'Tagihan',
  IconData icon = Icons.receipt_long,
  Color color = Colors.blue,
}) =>
    MaterialApp(
      home: Scaffold(
        body: FinanceSectionHeader(title: title, icon: icon, color: color),
      ),
    );

void main() {
  group('FinanceSectionHeader', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.byType(FinanceSectionHeader), findsOneWidget);
    });

    testWidgets('displays the title', (tester) async {
      await tester.pumpWidget(_build(title: 'Pembayaran Tertunda'));
      expect(find.text('Pembayaran Tertunda'), findsOneWidget);
    });

    testWidgets('displays the icon', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.payment));
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.payment),
        findsOneWidget,
      );
    });

    testWidgets('icon has size 16', (tester) async {
      await tester.pumpWidget(_build(icon: Icons.receipt_long));
      final icon = tester.widget<Icon>(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.receipt_long),
      );
      expect(icon.size, 16);
    });

    testWidgets('handles empty title without crashing', (tester) async {
      await tester.pumpWidget(_build(title: ''));
      expect(find.byType(FinanceSectionHeader), findsOneWidget);
    });

    testWidgets('title font size is 13', (tester) async {
      await tester.pumpWidget(_build(title: 'Summary'));
      final text = tester.widget<Text>(find.text('Summary'));
      expect(text.style?.fontSize, 13);
    });

    testWidgets('renders with different color values', (tester) async {
      for (final c in [Colors.red, Colors.green, Colors.purple, Colors.teal]) {
        await tester.pumpWidget(_build(color: c));
        expect(find.byType(FinanceSectionHeader), findsOneWidget);
      }
    });

    testWidgets('can stack multiple headers without crashing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FinanceSectionHeader(
                  title: 'Tagihan',
                  icon: Icons.receipt_long,
                  color: Colors.blue,
                ),
                FinanceSectionHeader(
                  title: 'Pembayaran',
                  icon: Icons.payment,
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(FinanceSectionHeader), findsNWidgets(2));
      expect(find.text('Tagihan'), findsOneWidget);
      expect(find.text('Pembayaran'), findsOneWidget);
    });
  });
}
