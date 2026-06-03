// Detail screen for a single Tagihan group (one payment type × one
// class × one academic year). Opened when the admin taps a grouped
// row in the Tagihan tab — drills into the per-student bills inside
// the bucket so the admin can see who's paid, who's overdue, and
// trigger reminders per row instead of in bulk.
//
// Data flow: the hub no longer carries every individual bill in
// memory (it only fetches aggregated /finance/bill-groups). This
// screen fetches its own per-student bill list on init by calling
// /bills with payment_type_id + class_id + academic_year_id
// filters. Pull-to-refresh re-runs the same fetch.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_finance_components.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/brand_kpi_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/features/finance/data/finance_service.dart';

class AdminBillGroupDetailScreen extends StatefulWidget {
  /// Combined `<jenis> · <kelas> (<tahun>)` label — same string the
  /// Tagihan tab shows on the grouped row, kept in sync so the user
  /// lands on a header that matches the card they tapped.
  final String title;

  /// Bucket key fields — used to scope the /bills fetch this screen
  /// runs on init. All three together uniquely identify the bucket.
  final String paymentTypeId;
  final String classId;
  final String? academicYearId;

  /// Optional callbacks forwarded to each per-bill row. `onTagih`
  /// fires the reminder flow for a single bill (same handler the hub
  /// uses); `onTapBill` opens a bill-level detail elsewhere if the
  /// caller wants one.
  final void Function(Map<String, dynamic> bill)? onTagih;
  final void Function(Map<String, dynamic> bill)? onTapBill;

  const AdminBillGroupDetailScreen({
    super.key,
    required this.title,
    required this.paymentTypeId,
    required this.classId,
    this.academicYearId,
    this.onTagih,
    this.onTapBill,
  });

  /// Convenience push so call sites don't have to wire the route
  /// themselves.
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String paymentTypeId,
    required String classId,
    String? academicYearId,
    void Function(Map<String, dynamic> bill)? onTagih,
    void Function(Map<String, dynamic> bill)? onTapBill,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AdminBillGroupDetailScreen(
          title: title,
          paymentTypeId: paymentTypeId,
          classId: classId,
          academicYearId: academicYearId,
          onTagih: onTagih,
          onTapBill: onTapBill,
        ),
      ),
    );
  }

  @override
  State<AdminBillGroupDetailScreen> createState() =>
      _AdminBillGroupDetailScreenState();
}

class _AdminBillGroupDetailScreenState
    extends State<AdminBillGroupDetailScreen> {
  /// Per-student bills inside the bucket. Empty during the initial
  /// load and after a failure.
  List<Map<String, dynamic>> _bills = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Pull every bill in the bucket — typical school has at most
      // a few dozen students per (jenis × kelas), so a single page
      // of 200 is more than enough. paginate=false would be cleaner
      // but the existing endpoint always paginates.
      final response = await FinanceService.getBillsPaginated(
        paymentTypeId: widget.paymentTypeId,
        classId: widget.classId,
        academicYearId: widget.academicYearId,
        limit: 200,
      );
      final raw = response['data'];
      final list = raw is List ? raw : const [];
      if (!mounted) return;
      setState(() {
        _bills = list.whereType<Map>().map(Map<String, dynamic>.from).toList();
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('bill_group_detail', e);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorUtils.getFriendlyMessage(e);
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadBills();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _GroupStats.from(_bills);
    final adminColor = ColorUtils.getRoleColor('admin');

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: BrandPageLayout(
        role: 'admin',
        onRefresh: _onRefresh,
        header: BrandPageHeader(
          role: 'admin',
          subtitle: 'DETAIL TAGIHAN',
          title: widget.title,
          isRealtimeFresh: !_isLoading && _errorMessage == null,
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
              valueColor: stats.unpaidCount > 0 ? ColorUtils.warning600 : null,
              sub: _formatRupiahShort(stats.unpaidAmount),
            ),
            BrandKpiColumn(
              label: 'Jatuh tempo',
              value: '${stats.overdueCount}',
              valueColor: stats.overdueCount > 0 ? ColorUtils.error600 : null,
              sub: _formatRupiahShort(stats.overdueAmount),
            ),
          ],
        ),
        bodyChildren: [_buildBody(adminColor, stats)],
      ),
    );
  }

  Widget _buildBody(Color adminColor, _GroupStats stats) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return _ErrorState(message: _errorMessage!, onRetry: _loadBills);
    }
    return AppRefreshIndicator(
      onRefresh: _onRefresh,
      role: 'admin',
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, AppSpacing.xl),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: 1 + _bills.length,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Summary card sits above the per-student list so the
            // total + average read like a "ringkasan tagihan" header.
            return _SummaryCard(stats: stats, adminColor: adminColor);
          }
          final bill = _bills[index - 1];
          return InvoiceRow(
            data: _mapBillToRow(bill),
            onTap: widget.onTapBill == null
                ? null
                : () => widget.onTapBill!(bill),
            onTagihTap: widget.onTagih == null
                ? null
                : () => widget.onTagih!(bill),
          );
        },
      ),
    );
  }

  // ── Mapping ────────────────────────────────────────────────────

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
        final due = dueRaw == null
            ? null
            : DateTime.tryParse(dueRaw.toString());
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
    final paidShort = _AdminBillGroupDetailScreenState._formatRupiahShort(
      stats.paidAmount,
    );
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
              value: _AdminBillGroupDetailScreenState._formatRupiahShort(
                stats.totalAmount,
              ),
              accent: adminColor,
              isBold: true,
            ),
            const SizedBox(height: 8),
            _row(
              label: 'Sudah dibayar',
              value: '$paidShort · $pctPaid%',
              accent: const Color(0xFF10B981),
            ),
            const SizedBox(height: 8),
            _row(
              label: 'Rata-rata / siswa',
              value: _AdminBillGroupDetailScreenState._formatRupiahShort(avg),
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

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 36, color: ColorUtils.slate400),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: ColorUtils.slate600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}
