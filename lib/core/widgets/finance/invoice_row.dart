// InvoiceRow — Mockup #13.
//
// Single invoice row used inside the Tagihan tab list.

import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Display payload for [InvoiceRow]. The screen does the formatting
/// (rupiah, dates) so this widget stays a pure renderer.
class InvoiceRowData {
  final String id;
  final String title; // "SPP November · 8B"
  final String studentName; // "Rania Putri"
  final String invoiceNumber; // "#INV-2025-1142"
  final String amountLabel; // "Rp 1.250.000"
  final InvoiceRowStatus status;
  final int? overdueDays; // shown as "Lewat N hari" when status == overdue
  final int reminderCount; // 0 = no pill, ≥1 = "Reminder ke-N" pill
  final String? paidAtLabel; // "Lunas · 5 Nov"
  final String? paidMethodLabel; // "Transfer BCA · 14:32"

  const InvoiceRowData({
    required this.id,
    required this.title,
    required this.studentName,
    required this.invoiceNumber,
    required this.amountLabel,
    required this.status,
    this.overdueDays,
    this.reminderCount = 0,
    this.paidAtLabel,
    this.paidMethodLabel,
  });
}

enum InvoiceRowStatus { paid, unpaid, overdue }

extension InvoiceRowStatusEdge on InvoiceRowStatus {
  Color get edgeColor {
    switch (this) {
      case InvoiceRowStatus.paid:
        return const Color(0xFF10B981);
      case InvoiceRowStatus.unpaid:
        return const Color(0xFFFCD34D);
      case InvoiceRowStatus.overdue:
        return const Color(0xFFDC2626);
    }
  }

  Color get amountColor {
    switch (this) {
      case InvoiceRowStatus.paid:
      case InvoiceRowStatus.unpaid:
        return const Color(0xFF0F172A);
      case InvoiceRowStatus.overdue:
        return const Color(0xFFDC2626);
    }
  }
}

/// Single invoice row used inside the Tagihan tab list.
///
/// Layout (mockup #13):
///   ┌────────────────────────────────────────────────┐
///   │██ SPP November · 8B                 [Tagih ↗]  │
///   │   Rania Putri · #INV-2025-1142                 │
///   │   Rp 1.250.000   ⚠ Lewat 14 hari               │
///   │   [Reminder ke-3]                              │
///   └────────────────────────────────────────────────┘
///
/// 4-px left edge in status color, optional "Reminder ke-N" pill, and
/// a right-side primary "Tagih" button shown only when [onTagihTap]
/// is non-null and the bill isn't paid.
class InvoiceRow extends StatelessWidget {
  final InvoiceRowData data;
  final VoidCallback? onTap;
  final VoidCallback? onTagihTap;

  const InvoiceRow({
    super.key,
    required this.data,
    this.onTap,
    this.onTagihTap,
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    final isOverdue = data.status == InvoiceRowStatus.overdue;
    final isPaid = data.status == InvoiceRowStatus.paid;
    final showTagih = onTagihTap != null && !isPaid;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOverdue ? const Color(0xFFFEE2E2) : ColorUtils.slate200,
            width: isOverdue ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 4-px status edge
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: data.status.edgeColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              data.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showTagih) ...[
                            const SizedBox(width: 8),
                            _InvoiceTagihButton(navy: navy, onTap: onTagihTap!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        // Drop the trailing " · <id>" when invoiceNumber is
                        // empty so grouped bill rows (which only carry a
                        // count/summary in studentName) don't render a
                        // dangling separator. The Tagihan tab also relies on
                        // this to suppress the raw UUID fallback admins
                        // didn't want to see.
                        data.invoiceNumber.isEmpty
                            ? data.studentName
                            : '${data.studentName} · ${data.invoiceNumber}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: ColorUtils.slate500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            data.amountLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: data.status.amountColor,
                            ),
                          ),
                          if (isOverdue && data.overdueDays != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '⚠ Lewat ${data.overdueDays} hari',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                          if (isPaid && data.paidAtLabel != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                data.paidAtLabel!,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF166534),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (data.reminderCount > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Reminder ke-${data.reminderCount}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                        ),
                      ],
                      if (isPaid && data.paidMethodLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          data.paidMethodLabel!,
                          style: TextStyle(
                            fontSize: 10,
                            color: ColorUtils.slate400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceTagihButton extends StatelessWidget {
  final Color navy;
  final VoidCallback onTap;
  const _InvoiceTagihButton({required this.navy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Tagih',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
