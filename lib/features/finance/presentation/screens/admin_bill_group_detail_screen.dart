// Detail screen for a single Tagihan group (one payment type × one
// class). Opened when the admin taps a grouped row in the Tagihan tab
// of the Operasional Keuangan hub — drills into per-student bills so
// the admin can see who's paid, who's overdue, and trigger reminders
// per row instead of in bulk.
//
// All data flows IN via constructor params; the screen owns no remote
// fetch logic of its own. The parent admin_finance_screen already
// loads the full bill list once and filters down to this group's
// subset before pushing this route, which keeps the detail view in
// sync with whatever the hub is currently showing (status / bulan /
// jenis filters from the page header all narrow the upstream list
// before the group is even formed).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_finance_components.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/brand_kpi_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';

class AdminBillGroupDetailScreen extends StatelessWidget {
  /// Combined `<jenis> · <kelas>` label — same string the Tagihan tab
  /// shows on the grouped row, kept in sync so the user lands on a
  /// header that matches the card they tapped.
  final String title;

  /// The bills that make up this group. All share the same
  /// (payment_type_id, class_id) — see TagihanTab._groupBills for the
  /// keying rule.
  final List<Map<String, dynamic>> bills;

  /// Optional callbacks forwarded to each [InvoiceRow]. `onTagih`
  /// fires the reminder flow for a single bill (same handler the
  /// hub uses); `onTapBill` opens a bill-level detail elsewhere if
  /// the caller wants one. Both are nullable so the screen still
  /// renders read-only views.
  final void Function(Map<String, dynamic> bill)? onTagih;
  final void Function(Map<String, dynamic> bill)? onTapBill;

  /// Pull-to-refresh — re-runs the parent's bill fetch. Reuses the
  /// hub's existing refresh callback so the data the group filters
  /// from stays in sync.
  final Future<void> Function() onRefresh;

  const AdminBillGroupDetailScreen({
    super.key,
    required this.title,
    required this.bills,
    required this.onRefresh,
    this.onTagih,
    this.onTapBill,
  });

  /// Convenience push so call sites don't have to wire the route
  /// themselves. Mirrors the pattern used by other admin detail
  /// sheets/screens in this app (`*.show(context: ..., ...)` static
  /// helpers).
  static Future<void> show({
    required BuildContext context,
    required String title,
    required List<Map<String, dynamic>> bills,
    required Future<void> Function() onRefresh,
    void Function(Map<String, dynamic> bill)? onTagih,
    void Function(Map<String, dynamic> bill)? onTapBill,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AdminBillGroupDetailScreen(
          title: title,
          bills: bills,
          onRefresh: onRefresh,
          onTagih: onTagih,
          onTapBill: onTapBill,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _GroupStats.from(bills);
    final adminColor = ColorUtils.getRoleColor('admin');

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: BrandPageLayout(
        role: 'admin',
        onRefresh: onRefresh,
        header: BrandPageHeader(
          role: 'admin',
          subtitle: 'DETAIL TAGIHAN',
          title: title,
          isRealtimeFresh: true,
          kpiOverlayHeight: BrandKpiStrip.defaultOverlap,
        ),
        kpiCard: BrandKpiStrip(
          columns: [
            BrandKpiColumn(
              label: 'Siswa',
              value: '${stats.totalCount}',
              sub: stats.paidCount > 0 ? '${stats.paidCount} lunas' : null,
            ),
            BrandKpiColumn(
              label: 'Belum bayar',
              value: '${stats.unpaidCount}',
              valueColor: stats.unpaidCount > 0
                  ? ColorUtils.warning600
                  : null,
              sub: _formatRupiahShort(stats.unpaidAmount),
            ),
            BrandKpiColumn(
              label: 'Jatuh tempo',
              value: '${stats.overdueCount}',
              valueColor: stats.overdueCount > 0
                  ? ColorUtils.error600
                  : null,
              sub: _formatRupiahShort(stats.overdueAmount),
            ),
          ],
        ),
        bodyChildren: [_buildBody(adminColor, stats)],
      ),
    );
  }

  Widget _buildBody(Color adminColor, _GroupStats stats) {
    return AppRefreshIndicator(
      onRefresh: onRefresh,
      role: 'admin',
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          0,
          AppSpacing.md,
          0,
          AppSpacing.xl,
        ),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: 1 + bills.length,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Summary card sits above the per-student list so the
            // total + average read like a "ringkasan tagihan" header.
            return _SummaryCard(stats: stats, adminColor: adminColor);
          }
          final bill = bills[index - 1];
          return InvoiceRow(
            data: _mapBillToRow(bill),
            onTap: onTapBill == null ? null : () => onTapBill!(bill),
            onTagihTap: onTagih == null ? null : () => onTagih!(bill),
          );
        },
      ),
    );
  }

  // ── Mapping (mirrors TagihanTab's per-bill mapping, minus the
  //    UUID fallback admins didn't want to see) ────────────────────

  InvoiceRowData _mapBillToRow(Map<String, dynamic> bill) {
    final status = (bill['status'] ?? '').toString().toLowerCase();
    final isPaid = status == 'paid' || status == 'verified';

    final due = _parseDate(
      bill['due_date'] ?? bill['jatuh_tempo'] ?? bill['tanggal_jatuh_tempo'],
    );
    final now = DateTime.now();
    final overdueDays = (!isPaid && due != null && due.isBefore(now))
        ? now.difference(due).inDays
        : null;

    final InvoiceRowStatus rowStatus;
    if (isPaid) {
      rowStatus = InvoiceRowStatus.paid;
    } else if (overdueDays != null && overdueDays > 0) {
      rowStatus = InvoiceRowStatus.overdue;
    } else {
      rowStatus = InvoiceRowStatus.unpaid;
    }

    final studentMap = bill['student'] is Map
        ? Map<String, dynamic>.from(bill['student'] as Map)
        : null;
    final studentName =
        (studentMap?['name'] ??
                bill['student_name'] ??
                bill['nama_siswa'] ??
                'Siswa')
            .toString();

    // Per-student row is already inside a (jenis × kelas) detail —
    // collapsing the title to just the student name reads cleaner
    // than repeating the jenis · kelas pair the page header already
    // shows. Subtitle is reserved for the due-date hint.
    final dueLabel = due == null ? '' : 'Jatuh tempo ${_formatDate(due)}';

    return InvoiceRowData(
      id: (bill['id'] ?? '').toString(),
      title: studentName,
      studentName: dueLabel,
      invoiceNumber: '',
      amountLabel: _formatRupiah(bill['amount']),
      status: rowStatus,
      overdueDays: overdueDays,
      reminderCount: (bill['reminder_count'] as num?)?.toInt() ?? 0,
      paidAtLabel: null,
      paidMethodLabel: null,
    );
  }

  // ── Formatters ─────────────────────────────────────────────────

  static final NumberFormat _idr = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String _formatRupiah(dynamic raw) {
    if (raw == null) return 'Rp 0';
    final n = double.tryParse(raw.toString());
    if (n == null) return 'Rp 0';
    return _idr.format(n);
  }

  /// Shorten to "Rp 10jt" / "Rp 1,5jt" for the KPI sub-line so it
  /// fits the narrow column width.
  static String _formatRupiahShort(double raw) {
    if (raw <= 0) return '—';
    if (raw >= 1000000000) {
      return 'Rp ${(raw / 1000000000).toStringAsFixed(1)}M';
    }
    if (raw >= 1000000) {
      return 'Rp ${(raw / 1000000).toStringAsFixed(0)}jt';
    }
    if (raw >= 1000) {
      return 'Rp ${(raw / 1000).toStringAsFixed(0)}rb';
    }
    return 'Rp ${raw.toStringAsFixed(0)}';
  }

  static const _months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  String _formatDate(DateTime d) => '${d.day} ${_months[d.month]} ${d.year}';

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }
}

/// Aggregate stats for the group — derived once at build time and
/// shared between the KPI strip + the summary card so the numbers
/// can't drift between them.
class _GroupStats {
  final int totalCount;
  final int paidCount;
  final int unpaidCount;
  final int overdueCount;
  final double totalAmount;
  final double paidAmount;
  final double unpaidAmount;
  final double overdueAmount;

  const _GroupStats({
    required this.totalCount,
    required this.paidCount,
    required this.unpaidCount,
    required this.overdueCount,
    required this.totalAmount,
    required this.paidAmount,
    required this.unpaidAmount,
    required this.overdueAmount,
  });

  factory _GroupStats.from(List<Map<String, dynamic>> bills) {
    int paid = 0;
    int unpaid = 0;
    int overdue = 0;
    double totalAmt = 0;
    double paidAmt = 0;
    double unpaidAmt = 0;
    double overdueAmt = 0;
    final now = DateTime.now();
    for (final b in bills) {
      final amt = double.tryParse((b['amount'] ?? 0).toString()) ?? 0;
      totalAmt += amt;
      final s = (b['status'] ?? '').toString().toLowerCase();
      final isPaid = s == 'paid' || s == 'verified';
      final isUnpaid = s == 'pending' || s == 'unpaid';
      if (isPaid) {
        paid++;
        paidAmt += amt;
      } else if (isUnpaid) {
        final dueRaw =
            b['due_date'] ?? b['jatuh_tempo'] ?? b['tanggal_jatuh_tempo'];
        final due = dueRaw == null ? null : DateTime.tryParse(dueRaw.toString());
        if (due != null && due.isBefore(now)) {
          overdue++;
          overdueAmt += amt;
        } else {
          unpaid++;
          unpaidAmt += amt;
        }
      }
    }
    return _GroupStats(
      totalCount: bills.length,
      paidCount: paid,
      unpaidCount: unpaid,
      overdueCount: overdue,
      totalAmount: totalAmt,
      paidAmount: paidAmt,
      unpaidAmount: unpaidAmt,
      overdueAmount: overdueAmt,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final _GroupStats stats;
  final Color adminColor;

  const _SummaryCard({required this.stats, required this.adminColor});

  @override
  Widget build(BuildContext context) {
    final pctPaid = stats.totalAmount > 0
        ? (stats.paidAmount / stats.totalAmount * 100).round()
        : 0;
    final avg = stats.totalCount > 0
        ? stats.totalAmount / stats.totalCount
        : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        4,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ColorUtils.slate200),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RINGKASAN',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: ColorUtils.slate500,
              ),
            ),
            const SizedBox(height: 10),
            _row(
              label: 'Total tagihan',
              value: AdminBillGroupDetailScreen._formatRupiahShort(
                stats.totalAmount,
              ),
              accent: adminColor,
              isBold: true,
            ),
            const SizedBox(height: 8),
            _row(
              label: 'Sudah dibayar',
              value:
                  '${AdminBillGroupDetailScreen._formatRupiahShort(stats.paidAmount)} · $pctPaid%',
              accent: const Color(0xFF10B981),
            ),
            const SizedBox(height: 8),
            _row(
              label: 'Rata-rata / siswa',
              value: AdminBillGroupDetailScreen._formatRupiahShort(avg),
              accent: ColorUtils.slate700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row({
    required String label,
    required String value,
    required Color accent,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: ColorUtils.slate600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: accent,
          ),
        ),
      ],
    );
  }
}