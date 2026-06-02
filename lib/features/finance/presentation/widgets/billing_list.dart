// Parent billing list — Phase 3 body per
// `Parent_Phase3_Tagihan_Mockup.svg`.
//
// Layout (top to bottom):
//   • 'PERLU PERHATIAN' alert card surfacing overdue bills.
//   • Monthly section headers ('OKTOBER 2025') with each month's
//     bills underneath as `_BillingRow`s.
//
// The KPI strip card (Total bulan ini · Sudah lunas · Belum lunas)
// is no longer rendered inline here — it lives at the screen level
// inside a Stack overlay so its top edge tucks into the gradient
// header (matches the admin Dashboard's hero+KPI pattern). Use the
// public `BillingKpiOverlay` widget below to render the strip in
// the screen's hero Stack.
//
// Implemented as a single Column rendered inside the parent screen's
// outer `ListView`, so scroll/refresh stay at the screen level.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_empty_state.dart';
import 'package:manajemensekolah/core/widgets/brand_kpi_strip.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/finance/presentation/controllers/parent_finance_controller.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/parent_bill_checkout_screen.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/parent_payment_success_screen.dart';

/// Floating KPI strip rendered inside the parent billing screen's
/// hero `Stack` overlay. Watches the same `parentFinanceProvider` as
/// [BillingList] and computes the same aggregate (Total bulan ini /
/// Sudah lunas / Belum lunas) so the numbers stay in sync.
///
/// Returns a 16dp horizontally-padded card. The screen is responsible
/// for the Stack + Positioned wiring.
class BillingKpiOverlay extends ConsumerWidget {
  final LanguageProvider languageProvider;

  const BillingKpiOverlay({super.key, required this.languageProvider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financeState = ref.watch(parentFinanceProvider);
    final items = financeState.maybeWhen(
      data: (state) => state.billingItems,
      orElse: () => const <dynamic>[],
    );
    final stats = _aggregateBilling(items);
    final lp = languageProvider;

    return BrandKpiStrip(
      columns: [
        BrandKpiColumn(
          label: lp.getTranslatedText({
            'en': 'This month',
            'id': 'Total bulan ini',
          }),
          value: _formatRupiahShort(stats.totalThisMonth),
          sub:
              '${stats.countThisMonth} '
              '${lp.getTranslatedText({'en': 'bills', 'id': 'tagihan'})}',
        ),
        BrandKpiColumn(
          label: lp.getTranslatedText({'en': 'Paid', 'id': 'Sudah lunas'}),
          value: _formatRupiahShort(stats.paid),
          badge: stats.paidCount > 0
              ? '${stats.paidCount} ${lp.getTranslatedText({'en': 'bills', 'id': 'tagihan'})}'
              : null,
          badgeColor: const Color(0xFF15803D),
          badgeIcon: Icons.check_rounded,
        ),
        BrandKpiColumn(
          label: lp.getTranslatedText({'en': 'Unpaid', 'id': 'Belum lunas'}),
          value: _formatRupiahShort(stats.unpaid),
          valueColor: stats.unpaid > 0 ? const Color(0xFFDC2626) : null,
          badge: stats.overdueCount > 0
              ? '${stats.overdueCount} ${lp.getTranslatedText({'en': 'late', 'id': 'telat'})}'
              : null,
          badgeColor: const Color(0xFFDC2626),
          badgeIcon: Icons.priority_high_rounded,
        ),
      ],
    );
  }
}

class BillingList extends ConsumerWidget {
  final LanguageProvider languageProvider;

  const BillingList({super.key, required this.languageProvider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financeState = ref.watch(parentFinanceProvider);

    return financeState.when(
      data: (state) {
        if (state.isLoading && state.billingItems.isEmpty) {
          return const SkeletonListLoading(
            padding: EdgeInsets.only(top: 8, bottom: 80),
            shrinkWrap: true,
          );
        }

        if (state.billingItems.isEmpty) {
          return BrandEmptyState(
            icon: Icons.receipt_long_outlined,
            tone: BrandEmptyStateTone.info,
            kicker: languageProvider.getTranslatedText({
              'en': 'No bills',
              'id': 'Belum ada tagihan',
            }),
            title: languageProvider.getTranslatedText({
              'en': 'No billing yet',
              'id': 'Belum ada tagihan',
            }),
            message: languageProvider.getTranslatedText({
              'en':
                  'Bills issued by the school will appear here. '
                  'Check back later or pull to refresh.',
              'id':
                  'Tagihan yang diterbitkan sekolah akan muncul di sini. '
                  'Periksa kembali nanti atau tarik untuk segarkan.',
            }),
            secondaryAction: BrandEmptyStateAction(
              label: languageProvider.getTranslatedText({
                'en': 'Refresh',
                'id': 'Muat ulang',
              }),
              icon: Icons.refresh_rounded,
              onTap: () =>
                  ref.read(parentFinanceProvider.notifier).forceRefresh(),
            ),
          );
        }

        return _BillingBody(
          items: state.billingItems,
          lang: languageProvider,
          onMarkVisible: (id, isRead) => ref
              .read(parentFinanceProvider.notifier)
              .markItemVisible(id, isRead),
        );
      },
      loading: () => const SkeletonListLoading(
        padding: EdgeInsets.only(top: 8, bottom: 80),
        shrinkWrap: true,
      ),
      error: (error, _) =>
          Center(child: Text('${AppLocalizations.error.tr}: $error')),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — splits items into overdue / by-month, then renders each section.
// ---------------------------------------------------------------------------

class _BillingBody extends StatelessWidget {
  final List<dynamic> items;
  final LanguageProvider lang;
  final void Function(String id, bool isRead) onMarkVisible;

  const _BillingBody({
    required this.items,
    required this.lang,
    required this.onMarkVisible,
  });

  /// Bucket every item:
  ///   - pending: status == 'pending' — parent has uploaded payment
  ///     proof, waiting for admin verification. These leave the
  ///     "Perlu perhatian" pool because the parent has nothing left
  ///     to act on; they get their own "Menunggu verifikasi" section
  ///     so the parent has visible confirmation that the upload
  ///     landed (the original UX gap that prompted this change).
  ///   - overdue: status == 'unpaid' AND due_date < today
  ///   - byMonth: keyed by 'YYYY-MM' of due_date (or created_at fallback)
  ({
    List<Map<String, dynamic>> pending,
    List<Map<String, dynamic>> overdue,
    Map<String, List<Map<String, dynamic>>> byMonth,
    List<String> monthsOrdered,
  })
  _bucketize() {
    final pending = <Map<String, dynamic>>[];
    final overdue = <Map<String, dynamic>>[];
    final byMonth = <String, List<Map<String, dynamic>>>{};
    final monthsOrdered = <String>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final raw in items) {
      final m = Map<String, dynamic>.from(raw as Map);
      final due = _parseDate(
        m['due_date'] ?? m['jatuh_tempo'] ?? m['created_at'],
      );
      final status = (m['status'] ?? '').toString().toLowerCase();

      // Pending bills go to their own bucket regardless of due date.
      // The parent's bukti is in the admin queue — surfacing it as
      // overdue/Telat would mis-signal that another action is needed.
      if (status == 'pending') {
        pending.add(m);
        continue;
      }

      final isUnpaid =
          status == 'unpaid' || status == 'belum_lunas' || status == '';
      if (due != null && isUnpaid && due.isBefore(today)) {
        overdue.add(m);
        continue;
      }
      final key = due == null
          ? 'unknown'
          : '${due.year}-${due.month.toString().padLeft(2, '0')}';
      if (!byMonth.containsKey(key)) {
        byMonth[key] = [];
        monthsOrdered.add(key);
      }
      byMonth[key]!.add(m);
    }
    // Newest month first.
    monthsOrdered.sort((a, b) => b.compareTo(a));
    return (
      pending: pending,
      overdue: overdue,
      byMonth: byMonth,
      monthsOrdered: monthsOrdered,
    );
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty || s == 'null') return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  String _formatRupiah(double v) => _formatRupiahShort(v);

  String _monthLabel(String yyyymm) {
    if (yyyymm == 'unknown') {
      return lang.getTranslatedText({'en': 'OTHER', 'id': 'LAINNYA'});
    }
    final parts = yyyymm.split('-');
    if (parts.length != 2) return yyyymm.toUpperCase();
    final year = int.tryParse(parts[0]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 0;
    const months = [
      '',
      'JANUARI',
      'FEBRUARI',
      'MARET',
      'APRIL',
      'MEI',
      'JUNI',
      'JULI',
      'AGUSTUS',
      'SEPTEMBER',
      'OKTOBER',
      'NOVEMBER',
      'DESEMBER',
    ];
    if (month < 1 || month > 12) return yyyymm.toUpperCase();
    return '${months[month]} $year';
  }

  @override
  Widget build(BuildContext context) {
    final buckets = _bucketize();

    // Mark every visible bill as read on first build — preserves the
    // legacy auto-mark behaviour without a per-item ScrollAware widget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final raw in items) {
        final m = Map<String, dynamic>.from(raw as Map);
        final isRead =
            m['is_read'] == true || m['is_read'] == 1 || m['is_read'] == '1';
        if (!isRead) {
          onMarkVisible(m['id'].toString(), isRead);
        }
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // KPI strip moved out — `BillingKpiOverlay` is now rendered at
        // the screen level inside the hero Stack so its top edge can
        // tuck into the gradient (overlap effect).

        // Menunggu verifikasi — bills where the parent has already
        // uploaded payment proof. Surfaces at the top so the parent
        // sees confirmation of their action.
        if (buckets.pending.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionHeader(
            label: lang.getTranslatedText({
              'en': 'AWAITING VERIFICATION',
              'id': 'MENUNGGU VERIFIKASI',
            }),
            tone: _SectionHeaderTone.warning,
          ),
          for (final m in buckets.pending)
            _BillingRow(
              data: m,
              lang: lang,
              isOverdue: false,
              formatRupiah: _formatRupiah,
            ),
        ],

        // Perlu perhatian (overdue) section
        if (buckets.overdue.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionHeader(
            label: lang.getTranslatedText({
              'en': 'NEEDS ATTENTION',
              'id': 'PERLU PERHATIAN',
            }),
          ),
          for (final m in buckets.overdue)
            _BillingRow(
              data: m,
              lang: lang,
              isOverdue: true,
              formatRupiah: _formatRupiah,
            ),
        ],

        // Monthly groups
        for (final monthKey in buckets.monthsOrdered) ...[
          const SizedBox(height: 20),
          _SectionHeader(label: _monthLabel(monthKey)),
          for (final m in buckets.byMonth[monthKey]!)
            _BillingRow(
              data: m,
              lang: lang,
              isOverdue: false,
              formatRupiah: _formatRupiah,
            ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Top-level helpers — shared between the inline body and the public
// `BillingKpiOverlay` widget so the KPI numbers stay derived from the
// same source data.
// ---------------------------------------------------------------------------

double _toBillingDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
}

/// Parse a date OR datetime string into [DateTime]. Tolerant of the
/// mixed shapes Laravel sends (Y-m-d for due_date, ISO-8601 for
/// timestamps). Returns null on anything unparseable.
DateTime? _parseDateTime(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  if (s.isEmpty || s == 'null') return null;
  try {
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}

/// Turn a "YYYY-MM" month tag (the format Bill.month uses) into a
/// human label like "Mei 2026". Leaves unrecognized shapes alone so
/// the caller can fall through to the raw value.
String _humanMonth(String yyyymm) {
  final parts = yyyymm.split('-');
  if (parts.length != 2) return yyyymm;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) {
    return yyyymm;
  }
  const months = [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  return '${months[month]} $year';
}

DateTime? _parseBillingDate(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  if (s.isEmpty || s == 'null') return null;
  try {
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}

String _formatRupiahShort(double v) {
  if (v >= 1000000) {
    final m = v / 1000000;
    return 'Rp ${m % 1 == 0 ? m.toStringAsFixed(0) : m.toStringAsFixed(1).replaceAll('.', ',')}jt';
  }
  if (v >= 1000) {
    final k = v / 1000;
    return 'Rp ${k.toStringAsFixed(0)}rb';
  }
  return 'Rp ${v.toStringAsFixed(0)}';
}

({
  double totalThisMonth,
  int countThisMonth,
  double paid,
  int paidCount,
  double unpaid,
  int overdueCount,
})
_aggregateBilling(List<dynamic> items) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var totalThisMonth = 0.0;
  var countThisMonth = 0;
  var paid = 0.0;
  var paidCount = 0;
  var unpaid = 0.0;
  var overdueCount = 0;
  for (final raw in items) {
    final m = Map<String, dynamic>.from(raw as Map);
    final amount = _toBillingDouble(m['amount'] ?? m['nominal'] ?? 0);
    final status = (m['status'] ?? '').toString().toLowerCase();
    final due = _parseBillingDate(
      m['due_date'] ?? m['jatuh_tempo'] ?? m['created_at'],
    );
    final isPaid =
        status == 'verified' || status == 'lunas' || status == 'paid';
    final isUnpaid =
        status == 'unpaid' ||
        status == 'belum_lunas' ||
        status == '' ||
        status == 'pending';

    if (due != null && due.year == now.year && due.month == now.month) {
      totalThisMonth += amount;
      countThisMonth += 1;
    }
    if (isPaid) {
      paid += amount;
      paidCount += 1;
    } else {
      unpaid += amount;
    }
    if (due != null && isUnpaid && due.isBefore(today)) {
      overdueCount += 1;
    }
  }
  return (
    totalThisMonth: totalThisMonth,
    countThisMonth: countThisMonth,
    paid: paid,
    paidCount: paidCount,
    unpaid: unpaid,
    overdueCount: overdueCount,
  );
}

// ---------------------------------------------------------------------------
// Section header — uppercased slate caption above each group.
// ---------------------------------------------------------------------------

/// Visual tone for [_SectionHeader]. `normal` keeps the slate caption;
/// `warning` paints the label in amber so the "Menunggu verifikasi"
/// group reads as informational (not urgent) and distinct from
/// "Perlu perhatian" red.
enum _SectionHeaderTone { normal, warning }

class _SectionHeader extends StatelessWidget {
  final String label;
  final _SectionHeaderTone tone;

  const _SectionHeader({
    required this.label,
    this.tone = _SectionHeaderTone.normal,
  });

  @override
  Widget build(BuildContext context) {
    final color = tone == _SectionHeaderTone.warning
        ? const Color(0xFFB45309) // amber-700
        : ColorUtils.slate600;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Billing row — status icon left, title + amount + status pill on right.
// Overdue rows get the red border + red exclamation badge.
// ---------------------------------------------------------------------------

class _BillingRow extends ConsumerWidget {
  final Map<String, dynamic> data;
  final LanguageProvider lang;
  final bool isOverdue;
  final String Function(double) formatRupiah;

  const _BillingRow({
    required this.data,
    required this.lang,
    required this.isOverdue,
    required this.formatRupiah,
  });

  /// Tap handler for the row — Phase-5C wiring.
  /// Unpaid bills launch the full-screen Bayar checkout. Paid /
  /// verified bills open the success screen as a receipt-only view.
  /// Pending (manual transfer awaiting verification) opens success
  /// in `isManualPending` mode so the parent sees the timeline.
  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final status = (data['status'] ?? '').toString().toLowerCase();
    final isPaid =
        status == 'verified' || status == 'lunas' || status == 'paid';
    final isPending = status == 'pending';

    if (isPaid || isPending) {
      // Receipt / pending review — go straight to success screen
      // through AppNavigator so app-level routing observers fire.
      // For paid bills the screen renders a printable kuitansi card;
      // pull every available field from the bill payload so the
      // receipt has school + class + period + verifikasi info filled
      // in. Missing fields gracefully degrade to "—" in the UI.
      final latestPayment = data['latest_payment_relation'] is Map
          ? Map<String, dynamic>.from(data['latest_payment_relation'] as Map)
          : <String, dynamic>{};
      final paymentType = data['payment_type'] is Map
          ? Map<String, dynamic>.from(data['payment_type'] as Map)
          : <String, dynamic>{};
      final billName =
          (paymentType['name'] ??
                  data['name'] ??
                  data['title'] ??
                  data['type'] ??
                  'Tagihan')
              .toString();
      final method =
          (latestPayment['payment_method'] ??
                  data['payment_method'] ??
                  data['method'] ??
                  '-')
              .toString();
      final classes = data['student']?['classes'];
      final className = classes is List && classes.isNotEmpty
          ? (classes.first is Map ? classes.first['name']?.toString() : null)
          : null;
      final periodStr = data['month']?.toString();
      final paidAt = _parseDateTime(
        latestPayment['payment_date'] ?? latestPayment['created_at'],
      );
      final verifiedAt = _parseDateTime(latestPayment['verified_at']);
      final verifierName = latestPayment['verifier'] is Map
          ? latestPayment['verifier']['name']?.toString()
          : null;

      await AppNavigator.push<void>(
        context,
        ParentPaymentSuccessScreen(
          billName: billName,
          studentName:
              (data['student_name'] ?? data['student']?['name'] ?? 'Anak')
                  .toString(),
          methodLabel: method,
          amount: double.tryParse((data['amount'] ?? '0').toString()) ?? 0,
          adminFee: double.tryParse((data['admin_fee'] ?? '0').toString()) ?? 0,
          isManualPending: isPending,
          paymentProofUrl: data['payment_proof_url']?.toString(),
          paymentId: latestPayment['id']?.toString(),
          schoolName:
              (data['school']?['name'] ?? data['school']?['school_name'])
                  ?.toString(),
          className: className,
          period: periodStr != null ? _humanMonth(periodStr) : null,
          paidAt: paidAt,
          verifiedAt: verifiedAt,
          verifierName: verifierName,
          billId: data['id']?.toString(),
        ),
      );
      return;
    }

    // Unpaid → open the brand checkout. When it returns true the
    // gateway has confirmed payment, so refresh the bill list to
    // pick up the new status / amount paid.
    final refreshed = await openParentBillCheckout(context, bill: data);
    if (refreshed == true) {
      // ignore: unused_result — fire-and-forget refresh.
      ref.read(parentFinanceProvider.notifier).refreshBilling();
    }
  }

  ({Color bg, Color fg, IconData icon, String label}) _appearance() {
    final status = (data['status'] ?? '').toString().toLowerCase();

    // Pending takes precedence over isOverdue — parent has uploaded
    // bukti, so we never paint the red "Telat" treatment on top.
    if (status == 'pending') {
      return (
        bg: const Color(0xFFFEF3C7),
        fg: const Color(0xFFB45309),
        icon: Icons.hourglass_top_rounded,
        label: lang.getTranslatedText({
          'en': 'Awaiting verification',
          'id': 'Menunggu verifikasi',
        }),
      );
    }
    if (isOverdue) {
      return (
        bg: const Color(0xFFFEE2E2),
        fg: const Color(0xFFDC2626),
        icon: Icons.priority_high_rounded,
        label: lang.getTranslatedText({'en': 'Late', 'id': 'Telat'}),
      );
    }
    switch (status) {
      case 'verified':
      case 'lunas':
      case 'paid':
        return (
          bg: const Color(0xFFDCFCE7),
          fg: const Color(0xFF15803D),
          icon: Icons.check_rounded,
          label: lang.getTranslatedText({'en': 'Paid', 'id': 'Lunas'}),
        );
      default:
        return (
          bg: const Color(0xFFFEF3C7),
          fg: const Color(0xFFB45309),
          icon: Icons.account_balance_wallet_outlined,
          label: lang.getTranslatedText({'en': 'Unpaid', 'id': 'Belum lunas'}),
        );
    }
  }

  String _formatDateShort(dynamic v) {
    if (v == null) return '';
    final s = v.toString();
    if (s.isEmpty || s == 'null') return '';
    try {
      final dt = DateTime.parse(s);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return s;
    }
  }

  String? _overdueDays(dynamic dueRaw) {
    if (!isOverdue) return null;
    final due = DateTime.tryParse(dueRaw?.toString() ?? '');
    if (due == null) return null;
    final today = DateTime.now();
    final days = today.difference(due).inDays;
    return lang.getTranslatedText({
      'en': 'Late $days days',
      'id': 'Telat $days hari',
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = _appearance();
    final title =
        (data['name'] ?? data['title'] ?? data['jenis_pembayaran_nama'] ?? '-')
            .toString();
    final amount =
        double.tryParse(
          (data['amount'] ?? data['nominal'] ?? '0').toString(),
        ) ??
        0;
    final due = data['due_date'] ?? data['jatuh_tempo'];
    final dueLabel = _formatDateShort(due);
    final overdueLabel = _overdueDays(due);
    final status = (data['status'] ?? '').toString().toLowerCase();
    final isPaid =
        status == 'verified' || status == 'lunas' || status == 'paid';
    final isPending = status == 'pending';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          onTap: () => _onTap(context, ref),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isOverdue
                    ? const Color(0xFFFCA5A5)
                    : ColorUtils.slate200,
                width: isOverdue ? 1.2 : 0.75,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: a.bg,
                    borderRadius: const BorderRadius.all(Radius.circular(11)),
                  ),
                  child: Icon(a.icon, size: 20, color: a.fg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: ColorUtils.slate600,
                              ),
                            ),
                          ),
                          if (overdueLabel != null)
                            Text(
                              overdueLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            )
                          else if (dueLabel.isNotEmpty)
                            Text(
                              '${lang.getTranslatedText({'en': 'Due', 'id': 'Jatuh tempo'})} $dueLabel',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: ColorUtils.slate500,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatRupiah(amount),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isPaid
                              ? ColorUtils.slate600
                              : ColorUtils.slate900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: a.bg,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(11),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: a.fg,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  a.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: a.fg,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (isPending)
                            Text(
                              '${lang.getTranslatedText({'en': 'View proof', 'id': 'Lihat bukti'})} →',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309),
                              ),
                            )
                          else if (!isPaid)
                            Text(
                              '${lang.getTranslatedText({'en': 'Pay', 'id': 'Bayar'})} →',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: ColorUtils.brandAzureDeep,
                              ),
                            )
                          else
                            Text(
                              '${lang.getTranslatedText({'en': 'View receipt', 'id': 'Lihat bukti'})} →',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: ColorUtils.slate500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
