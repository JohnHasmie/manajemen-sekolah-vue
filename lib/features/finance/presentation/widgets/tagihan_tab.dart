// Tagihan tab body — Mockup #13 (Phase Final), filter-consolidated
// revision.
//
// Earlier the tab body owned its own filter chrome (sub-filter strip
// for status + a "Filter jenis & bulan" toolbar). All three of those
// filters now live in the page header as `BrandFilterChip`s, so the
// body shrinks to just bill rows + the pinned `ClassReportDrillCard`.
//
// The tab is still parameterised by the active filter values so its
// `_applyFilter` can produce the right list — the screen still owns
// the state, this widget only renders.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_finance_components.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';

class TagihanTab extends StatelessWidget {
  /// Raw bill records from the API. Each record is a `Map<String, dynamic>`
  /// with the standard finance shape (id, status, amount, due_date,
  /// student.name, payment_type.name, ...).
  final List<dynamic> billList;

  /// Active status filter key — one of `'all'`, `'unpaid'`, `'overdue'`.
  /// Driven from the header's "Status" chip.
  final String activeFilterKey;

  /// Tap handler for the right-aligned "Tagih" button on each
  /// [InvoiceRow]. Carries the raw bill map so the caller can fan out
  /// to its existing reminder / verification flow.
  final void Function(Map<String, dynamic> bill)? onTagih;

  /// Tap handler for a row body — typically opens a detail sheet.
  final void Function(Map<String, dynamic> bill)? onTap;

  /// Tap handler for the navy-tinted [ClassReportDrillCard] pinned at
  /// the bottom of the list.
  final VoidCallback onClassReportTap;

  /// Pull-to-refresh callback.
  final Future<void> Function() onRefresh;

  /// Set of payment-type IDs to include. Empty = all jenis.
  /// Driven from the header's "Jenis" chip.
  final Set<String> selectedJenisIds;

  /// `YYYY-MM` to include, or `null` for all months.
  /// Driven from the header's "Bulan" chip.
  final String? selectedMonth;

  const TagihanTab({
    super.key,
    required this.billList,
    required this.activeFilterKey,
    required this.onClassReportTap,
    required this.onRefresh,
    required this.selectedJenisIds,
    required this.selectedMonth,
    this.onTagih,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilter(billList);

    // Body is now filter-chrome free — status / jenis / bulan all live
    // in the page header. The body is just the bill rows + the drill
    // card pinned at the bottom.
    final emptyOffset = filtered.isEmpty ? 1 : 0;
    final itemCount = filtered.length + emptyOffset + 1;

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      role: 'admin',
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Empty state slot (shown only when filtered list is empty)
          if (filtered.isEmpty && index == 0) {
            return _EmptyTagihan(activeKey: activeFilterKey);
          }

          // Bill rows
          final rowIndex = index - emptyOffset;
          if (rowIndex >= 0 && rowIndex < filtered.length) {
            final bill = filtered[rowIndex] as Map<String, dynamic>;
            return InvoiceRow(
              data: _mapBillToRow(bill),
              onTap: onTap == null ? null : () => onTap!(bill),
              onTagihTap: onTagih == null ? null : () => onTagih!(bill),
            );
          }

          // Drill card pinned at bottom
          return ClassReportDrillCard(onTap: onClassReportTap);
        },
      ),
    );
  }

  // ── Filtering + mapping ────────────────────────────────────────────

  List<dynamic> _applyFilter(List<dynamic> bills) {
    final now = DateTime.now();
    return bills.where((raw) {
      final b = Map<String, dynamic>.from(raw as Map);
      final status = (b['status'] ?? '').toString().toLowerCase();
      final isUnpaid = status == 'pending' || status == 'unpaid';

      // 1. Status sub-filter (Semua / Belum bayar / Jatuh tempo).
      bool matchesStatus;
      switch (activeFilterKey) {
        case 'unpaid':
          matchesStatus = isUnpaid;
          break;
        case 'overdue':
          if (!isUnpaid) {
            matchesStatus = false;
          } else {
            final due = _parseDate(
              b['due_date'] ?? b['jatuh_tempo'] ?? b['tanggal_jatuh_tempo'],
            );
            matchesStatus = due != null && due.isBefore(now);
          }
          break;
        default:
          matchesStatus = true;
      }
      if (!matchesStatus) return false;

      // 2. Jenis pembayaran (multi-select). Empty set = no filter.
      if (selectedJenisIds.isNotEmpty) {
        final id =
            (b['payment_type_id'] ??
                    b['paymentTypeId'] ??
                    (b['payment_type'] is Map
                        ? b['payment_type']['id']
                        : null) ??
                    (b['paymentType'] is Map ? b['paymentType']['id'] : null))
                ?.toString();
        if (id == null || !selectedJenisIds.contains(id)) return false;
      }

      // 3. Bulan jatuh tempo. `null` = no filter.
      if (selectedMonth != null) {
        final due = _parseDate(
          b['due_date'] ?? b['jatuh_tempo'] ?? b['tanggal_jatuh_tempo'],
        );
        if (due == null) return false;
        final mm = due.month.toString().padLeft(2, '0');
        final key = '${due.year}-$mm';
        if (key != selectedMonth) return false;
      }

      return true;
    }).toList();
  }

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
    final classesList = studentMap?['classes'] is List
        ? (studentMap!['classes'] as List)
        : const [];
    String? classLabel;
    if (classesList.isNotEmpty && classesList.first is Map) {
      classLabel = (classesList.first['name'] ?? classesList.first['nama'])
          ?.toString();
    }
    final studentName =
        (studentMap?['name'] ??
                bill['student_name'] ??
                bill['nama_siswa'] ??
                'Siswa')
            .toString();

    // Laravel relation method `paymentType()` serialises to
    // `paymentType` (camelCase) by default but some endpoints flatten
    // or rename the field — fall through every shape we've seen.
    final typeName =
        (bill['name'] ??
                bill['title'] ??
                (bill['payment_type'] is Map
                    ? bill['payment_type']['name']
                    : null) ??
                (bill['paymentType'] is Map
                    ? bill['paymentType']['name']
                    : null) ??
                bill['jenis_pembayaran_nama'] ??
                'Tagihan')
            .toString();
    final title = classLabel == null || classLabel.isEmpty
        ? typeName
        : '$typeName · $classLabel';

    final invoiceNumber =
        (bill['invoice_number'] ??
                bill['nomor_invoice'] ??
                (bill['id'] != null ? '#${bill['id']}' : ''))
            .toString();

    return InvoiceRowData(
      id: (bill['id'] ?? '').toString(),
      title: title,
      studentName: studentName,
      invoiceNumber: invoiceNumber,
      amountLabel: _formatRupiah(bill['amount']),
      status: rowStatus,
      overdueDays: overdueDays,
      reminderCount: (bill['reminder_count'] as num?)?.toInt() ?? 0,
      paidAtLabel: isPaid
          ? _formatLunasLabel(
              bill['paid_at'] ?? bill['payment_date'] ?? bill['updated_at'],
            )
          : null,
      paidMethodLabel: isPaid
          ? (bill['payment_method'] ?? bill['metode_pembayaran'])?.toString()
          : null,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────

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

  String? _formatLunasLabel(dynamic raw) {
    final d = _parseDate(raw);
    if (d == null) return null;
    return 'Lunas · ${d.day} ${_months[d.month]}';
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final str = raw.toString();
    return DateTime.tryParse(str);
  }
}

class _EmptyTagihan extends StatelessWidget {
  final String activeKey;
  const _EmptyTagihan({required this.activeKey});

  @override
  Widget build(BuildContext context) {
    final copy = switch (activeKey) {
      'overdue' => 'Tidak ada tagihan yang jatuh tempo. Semua aman.',
      'unpaid' => 'Tidak ada tagihan yang belum dibayar untuk periode ini.',
      _ => 'Belum ada tagihan terdata pada periode ini.',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ColorUtils.slate200),
        ),
        child: Row(
          children: [
            Icon(
              activeKey == 'overdue'
                  ? Icons.check_circle_rounded
                  : Icons.inbox_outlined,
              color: activeKey == 'overdue'
                  ? const Color(0xFF10B981)
                  : ColorUtils.slate400,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                copy,
                style: TextStyle(
                  fontSize: 12.5,
                  color: ColorUtils.slate500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
