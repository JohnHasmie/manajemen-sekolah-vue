// Flutter wrapper around the Mockup #13 money-flow endpoint.
// Returns typed [MoneyFlowSummary] consumed by the admin Keuangan
// hub hero (MoneyFlowStrip + FlowBar).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/widgets/admin_finance_components.dart';

class MoneyFlowSummary {
  final MoneyFlowFigures figures;
  final double paidPct;
  final double outstandingPct;
  final double overduePct;
  final String periodLabel;

  const MoneyFlowSummary({
    required this.figures,
    required this.paidPct,
    required this.outstandingPct,
    required this.overduePct,
    required this.periodLabel,
  });

  bool get hasOverdue => figures.overdueCount > 0;
}

class MoneyFlowService {
  final ApiService _api;
  MoneyFlowService(this._api);

  /// GET /api/finance/money-flow
  Future<MoneyFlowSummary> fetch({String? academicYearId}) async {
    final qs = academicYearId == null
        ? ''
        : '?academic_year_id=$academicYearId';
    final raw = await _api.get('/finance/money-flow$qs');
    final data = (raw is Map && raw['data'] is Map)
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : <String, dynamic>{};

    final income = Map<String, dynamic>.from(
      (data['income'] as Map?) ?? const {},
    );
    final outstanding = Map<String, dynamic>.from(
      (data['outstanding'] as Map?) ?? const {},
    );
    final overdue = Map<String, dynamic>.from(
      (data['overdue'] as Map?) ?? const {},
    );
    final flowBar = Map<String, dynamic>.from(
      (data['flow_bar'] as Map?) ?? const {},
    );
    final period = Map<String, dynamic>.from(
      (data['period'] as Map?) ?? const {},
    );

    final delta = income['delta_pct_vs_last_month'];
    final deltaLabel = delta is num
        ? (delta >= 0
              ? '↑ ${delta.toStringAsFixed(0)}% vs bulan lalu'
              : '↓ ${(-delta).toStringAsFixed(0)}% vs bulan lalu')
        : null;

    return MoneyFlowSummary(
      figures: MoneyFlowFigures(
        incomingAmount: formatRupiahCompact(income['amount']),
        incomingDelta: deltaLabel,
        incomingCount: (income['transaction_count'] as num?)?.toInt() ?? 0,
        outstandingAmount: formatRupiahCompact(outstanding['amount']),
        outstandingCount: (outstanding['count'] as num?)?.toInt() ?? 0,
        overdueAmount: formatRupiahCompact(overdue['amount']),
        overdueCount:
            (overdue['guardians_count'] as num?)?.toInt() ??
            (overdue['count'] as num?)?.toInt() ??
            0,
      ),
      paidPct: (flowBar['paid_pct'] as num?)?.toDouble() ?? 0,
      outstandingPct: (flowBar['outstanding_pct'] as num?)?.toDouble() ?? 0,
      overduePct: (flowBar['overdue_pct'] as num?)?.toDouble() ?? 0,
      periodLabel: (period['month'] ?? '').toString(),
    );
  }
}

// =====================================================================
// Riverpod
// =====================================================================

final moneyFlowServiceProvider = Provider<MoneyFlowService>((ref) {
  return MoneyFlowService(ApiService());
});

/// Family provider keyed by academicYearId. The screen reads
/// `ref.watch(moneyFlowProvider(currentAyId))` so switching the
/// active academic year refreshes the strip without invalidation.
///
/// Note: `.autoDispose` was removed (and a 15s soft timeout added)
/// because the previous variant suffered the same dispose-and-refetch
/// race that broke the Raport hub. Each rebuild of `_MoneyFlowSection`
/// briefly dropped the only listener, autoDispose disposed the
/// provider mid-flight and cancelled the Dio request, and the next
/// `ref.watch` kicked off a fresh GET. After several cycles the strip
/// stayed in `loading` state forever (the user reported it as "no KPI
/// cards rendered" because the skeleton blends into the navy hero).
///
/// The timeout converts a backend hang into a visible
/// `_MoneyFlowError` retry tile rather than an indefinite skeleton.
final moneyFlowProvider = FutureProvider.family<MoneyFlowSummary, String?>((
  ref,
  academicYearId,
) async {
  return ref
      .read(moneyFlowServiceProvider)
      .fetch(academicYearId: academicYearId)
      .timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
          'Server keuangan tidak merespon dalam 15 detik. '
          'Cek koneksi backend lalu tap "Coba lagi".',
        ),
      );
});
