// Tests for PaymentTypeCard — admin finance payment type entry card.
//
// Key scenarios:
// - Renders payment name, formatted amount, status chip (Aktif / Non-Aktif)
// - Shows description when present, hides when absent
// - Shows goal tag when item['goal'] is not null
// - Fires onGenerateBills, onEdit, onDelete callbacks independently
// - Falls back to 'No Name' when name is missing
// - Index-based color renders without crashing
//
// Like testing a Vue card component: all data and callbacks are props.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/payment_type_card.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _item({
  String name = 'SPP Bulanan',
  dynamic amount = 150000,
  String status = 'aktif',
  String? description,
  dynamic goal,
  String? periode = 'bulanan',
}) =>
    {
      'name': name,
      'amount': amount,
      'status': status,
      if (description != null) 'description': description,
      if (goal != null) 'goal': goal,
      'periode': periode,
    };

Widget _build({
  Map<String, dynamic>? item,
  int index = 0,
  VoidCallback? onGenerateBills,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: PaymentTypeCard(
          item: item ?? _item(),
          index: index,
          formatCurrency: (v) => 'Rp ${v ?? 0}',
          primaryColor: Colors.blue,
          getGoalDescription: (v) => 'Goal: $v',
          getTranslatedPeriod: (v) => v ?? '-',
          onGenerateBills: onGenerateBills ?? () {},
          onEdit: onEdit ?? () {},
          onDelete: onDelete ?? () {},
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PaymentTypeCard — content rendering', () {
    testWidgets('renders payment name', (tester) async {
      await tester.pumpWidget(_build(item: _item(name: 'SPP Bulanan')));
      expect(find.text('SPP Bulanan'), findsOneWidget);
    });

    testWidgets('renders formatted amount via formatCurrency', (tester) async {
      await tester.pumpWidget(_build(item: _item(amount: 200000)));
      expect(find.text('Rp 200000'), findsOneWidget);
    });

    testWidgets('shows "Aktif" chip when status=aktif', (tester) async {
      await tester.pumpWidget(_build(item: _item(status: 'aktif')));
      expect(find.text('Aktif'), findsOneWidget);
    });

    testWidgets('shows "Non-Aktif" chip when status is not aktif', (tester) async {
      await tester.pumpWidget(_build(item: _item(status: 'nonaktif')));
      expect(find.text('Non-Aktif'), findsOneWidget);
    });

    testWidgets('falls back to "No Name" when name is absent', (tester) async {
      await tester.pumpWidget(_build(item: {'status': 'aktif', 'amount': 0}));
      expect(find.text('No Name'), findsOneWidget);
    });

    testWidgets('shows description when present', (tester) async {
      await tester.pumpWidget(
        _build(item: _item(description: 'Pembayaran rutin')),
      );
      expect(find.text('Pembayaran rutin'), findsOneWidget);
    });

    testWidgets('hides description when absent', (tester) async {
      await tester.pumpWidget(_build(item: _item(description: null)));
      expect(find.text('Pembayaran rutin'), findsNothing);
    });

    testWidgets('shows goal tag when goal is present', (tester) async {
      await tester.pumpWidget(_build(item: _item(goal: 'semua_siswa')));
      expect(find.textContaining('Goal:'), findsOneWidget);
    });

    testWidgets('hides goal tag when goal is null', (tester) async {
      await tester.pumpWidget(_build(item: _item(goal: null)));
      expect(find.byIcon(Icons.groups_rounded), findsNothing);
    });

    testWidgets('shows period tag via getTranslatedPeriod', (tester) async {
      await tester.pumpWidget(_build(item: _item(periode: 'bulanan')));
      expect(find.text('bulanan'), findsOneWidget);
    });

    testWidgets('shows payment icon', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.byIcon(Icons.payment_rounded), findsOneWidget);
    });
  });

  group('PaymentTypeCard — action callbacks', () {
    testWidgets('fires onGenerateBills on autorenew button tap', (tester) async {
      bool called = false;
      await tester.pumpWidget(_build(onGenerateBills: () => called = true));
      await tester.tap(find.byIcon(Icons.autorenew_rounded));
      expect(called, isTrue);
    });

    testWidgets('fires onEdit on edit button tap', (tester) async {
      bool called = false;
      await tester.pumpWidget(_build(onEdit: () => called = true));
      await tester.tap(find.byIcon(Icons.edit_rounded));
      expect(called, isTrue);
    });

    testWidgets('fires onDelete on delete button tap', (tester) async {
      bool called = false;
      await tester.pumpWidget(_build(onDelete: () => called = true));
      await tester.tap(find.byIcon(Icons.delete_rounded));
      expect(called, isTrue);
    });

    testWidgets('all three callbacks fire independently', (tester) async {
      int genCount = 0;
      int editCount = 0;
      int delCount = 0;
      await tester.pumpWidget(_build(
        onGenerateBills: () => genCount++,
        onEdit: () => editCount++,
        onDelete: () => delCount++,
      ));

      await tester.tap(find.byIcon(Icons.autorenew_rounded));
      await tester.tap(find.byIcon(Icons.edit_rounded));
      await tester.tap(find.byIcon(Icons.delete_rounded));

      expect(genCount, 1);
      expect(editCount, 1);
      expect(delCount, 1);
    });
  });

  group('PaymentTypeCard — index-based colors', () {
    testWidgets('renders with index 0 without crashing', (tester) async {
      await tester.pumpWidget(_build(index: 0));
      expect(find.byType(PaymentTypeCard), findsOneWidget);
    });

    testWidgets('renders with index 3 without crashing', (tester) async {
      await tester.pumpWidget(_build(index: 3));
      expect(find.byType(PaymentTypeCard), findsOneWidget);
    });
  });
}
