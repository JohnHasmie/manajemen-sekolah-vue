// Widget tests for FinanceStatCard.
// Pure StatelessWidget — no providers needed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_stat_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('FinanceStatCard', () {
    const testCard = FinanceStatCard(
      icon: Icons.attach_money,
      value: '150',
      label: 'Tagihan',
      color: Colors.blue,
    );

    testWidgets('renders value text', (tester) async {
      await tester.pumpWidget(_wrap(testCard));
      expect(find.text('150'), findsOneWidget);
    });

    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(_wrap(testCard));
      expect(find.text('Tagihan'), findsOneWidget);
    });

    testWidgets('renders the supplied icon', (tester) async {
      await tester.pumpWidget(_wrap(testCard));
      expect(find.byIcon(Icons.attach_money), findsOneWidget);
    });

    testWidgets('value text uses the supplied color', (tester) async {
      await tester.pumpWidget(_wrap(testCard));
      final valueText = tester.widget<Text>(find.text('150'));
      expect(valueText.style?.color, Colors.blue);
    });

    testWidgets('label text is clamped to a single line via maxLines:1', (tester) async {
      await tester.pumpWidget(_wrap(testCard));
      final labelText = tester.widget<Text>(find.text('Tagihan'));
      expect(labelText.maxLines, 1);
    });

    testWidgets('widget tree contains a Column (icon on top, value, label beneath)', (tester) async {
      await tester.pumpWidget(_wrap(testCard));
      expect(find.byType(Column), findsAtLeast(1));
    });
  });
}
