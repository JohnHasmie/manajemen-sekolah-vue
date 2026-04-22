// Tests for BillingCard — a tappable billing record card with status badge.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/billing_card.dart';

Map<String, dynamic> _makeBilling({
  String? name,
  String? description,
  String status = 'unpaid',
  dynamic amount,
  dynamic isRead,
}) => {
  'name': name ?? 'SPP Bulan Maret',
  'description': description ?? 'Pembayaran bulan Maret 2025',
  'status': status,
  'amount': amount ?? 500000,
  'is_read': isRead ?? false,
};

Widget _build({
  Map<String, dynamic>? billing,
  VoidCallback? onTap,
  LanguageProvider? lp,
}) {
  final provider = lp ?? LanguageProvider();
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: BillingCard(
          billing: billing ?? _makeBilling(),
          onTap: onTap ?? () {},
          languageProvider: provider,
        ),
      ),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().init();
  });

  group('BillingCard', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.byType(BillingCard), findsOneWidget);
    });

    testWidgets('displays billing name', (tester) async {
      await tester.pumpWidget(_build(billing: _makeBilling(name: 'SPP April')));
      expect(find.text('SPP April'), findsOneWidget);
    });

    testWidgets('displays billing description', (tester) async {
      await tester.pumpWidget(
        _build(billing: _makeBilling(description: 'Tagihan bulan April')),
      );
      expect(find.text('Tagihan bulan April'), findsOneWidget);
    });

    testWidgets('shows "Belum Bayar" status badge for unpaid (Indonesian)', (
      tester,
    ) async {
      await tester.pumpWidget(_build(billing: _makeBilling(status: 'unpaid')));
      expect(find.text('Belum Bayar'), findsOneWidget);
    });

    testWidgets(
      'shows "Terverifikasi" status badge for verified (Indonesian)',
      (tester) async {
        await tester.pumpWidget(
          _build(billing: _makeBilling(status: 'verified')),
        );
        expect(find.text('Terverifikasi'), findsOneWidget);
      },
    );

    testWidgets('shows "Tertunda" status badge for pending (Indonesian)', (
      tester,
    ) async {
      await tester.pumpWidget(_build(billing: _makeBilling(status: 'pending')));
      expect(find.text('Tertunda'), findsOneWidget);
    });

    testWidgets('shows "Unpaid" status badge for unpaid (English)', (
      tester,
    ) async {
      final lp = LanguageProvider()..setLanguage(LanguageProvider.english);
      await tester.pumpWidget(
        _build(
          billing: _makeBilling(status: 'unpaid'),
          lp: lp,
        ),
      );
      expect(find.text('Unpaid'), findsOneWidget);
    });

    testWidgets('shows "Verified" status badge for verified (English)', (
      tester,
    ) async {
      final lp = LanguageProvider()..setLanguage(LanguageProvider.english);
      await tester.pumpWidget(
        _build(
          billing: _makeBilling(status: 'verified'),
          lp: lp,
        ),
      );
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('shows "Pending" status badge for pending (English)', (
      tester,
    ) async {
      final lp = LanguageProvider()..setLanguage(LanguageProvider.english);
      await tester.pumpWidget(
        _build(
          billing: _makeBilling(status: 'pending'),
          lp: lp,
        ),
      );
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('onTap fires when card is tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_build(onTap: () => tapped = true));
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('shows "-" for name when all name keys are null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(
          billing: {'status': 'unpaid', 'amount': 100000, 'is_read': false},
        ),
      );
      expect(find.text('-'), findsWidgets);
    });

    testWidgets('is_read as int 1 renders without crashing', (tester) async {
      await tester.pumpWidget(_build(billing: _makeBilling(isRead: 1)));
      expect(find.byType(BillingCard), findsOneWidget);
    });

    testWidgets('is_read as string "1" renders without crashing', (
      tester,
    ) async {
      await tester.pumpWidget(_build(billing: _makeBilling(isRead: '1')));
      expect(find.byType(BillingCard), findsOneWidget);
    });

    testWidgets('unknown status defaults to unpaid badge', (tester) async {
      await tester.pumpWidget(_build(billing: _makeBilling(status: 'unknown')));
      // Default case is unpaid
      expect(find.text('Belum Bayar'), findsOneWidget);
    });

    testWidgets('renders long billing name with overflow handling', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(
          billing: _makeBilling(
            name:
                'Pembayaran SPP dan Dana Kegiatan Siswa Semester Genap Tahun Ajaran 2024/2025',
          ),
        ),
      );
      expect(find.byType(BillingCard), findsOneWidget);
    });
  });
}
