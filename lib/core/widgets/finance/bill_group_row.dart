// BillGroupRow — aggregated card for the Tagihan list.
//
// Each instance represents one (payment_type × class) bucket — derived
// client-side in TagihanTab._groupBills.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Display model for the grouped Tagihan card. Each instance
/// represents one (payment_type × class) bucket — derived client-side
/// in TagihanTab._groupBills. The widget renders a richer card than
/// InvoiceRow: title + count summary, a progress strip showing
/// (paid + on-time) vs (overdue), and a per-bucket total.
class BillGroupRowData {
  /// Top line — e.g. "Uang Pangkal · 7A (2024)".
  final String title;

  /// Total students in the group.
  final int totalCount;

  /// Already paid (status: paid / verified).
  final int paidCount;

  /// Unpaid but not yet past due.
  final int unpaidCount;

  /// Unpaid AND past due date.
  final int overdueCount;

  /// Group total amount across every bill in the bucket.
  final double totalAmount;

  /// Already-collected portion of [totalAmount].
  final double paidAmount;

  const BillGroupRowData({
    required this.title,
    required this.totalCount,
    required this.paidCount,
    required this.unpaidCount,
    required this.overdueCount,
    required this.totalAmount,
    required this.paidAmount,
  });
}

class BillGroupRow extends StatelessWidget {
  final BillGroupRowData data;
  final VoidCallback? onTap;

  const BillGroupRow({super.key, required this.data, this.onTap});

  static final NumberFormat _idr = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String _shortRp(double v) {
    if (v <= 0) return 'Rp 0';
    if (v >= 1000000000) return 'Rp ${(v / 1000000000).toStringAsFixed(1)}M';
    if (v >= 1000000) return 'Rp ${(v / 1000000).toStringAsFixed(0)}jt';
    if (v >= 1000) return 'Rp ${(v / 1000).toStringAsFixed(0)}rb';
    return _idr.format(v);
  }

  @override
  Widget build(BuildContext context) {
    // Side accent color hints at the worst status in the bucket:
    //   overdue → red, unpaid → amber, all-paid → green.
    final Color accent;
    if (data.overdueCount > 0) {
      accent = ColorUtils.error600;
    } else if (data.unpaidCount > 0) {
      accent = ColorUtils.warning600;
    } else {
      accent = const Color(0xFF10B981); // emerald 500 — success
    }

    final pctPaid = data.totalAmount > 0
        ? (data.paidAmount / data.totalAmount).clamp(0.0, 1.0)
        : 0.0;
    final pctOverdue = data.totalAmount > 0
        ? (data.overdueCount / data.totalCount.clamp(1, 1 << 30)).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    // Subtitle — count breakdown ordered worst-first so the most
    // actionable number reads first.
    final parts = <String>['${data.totalCount} siswa'];
    if (data.overdueCount > 0) parts.add('${data.overdueCount} jatuh tempo');
    if (data.unpaidCount > 0) parts.add('${data.unpaidCount} belum bayar');
    if (data.paidCount > 0 && data.overdueCount == 0 && data.unpaidCount == 0) {
      parts.add('semua lunas');
    } else if (data.paidCount > 0) {
      parts.add('${data.paidCount} lunas');
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent rail (matches the existing InvoiceRow
                // visual language — colored strip on the leading edge
                // indicating row status).
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row + chevron + amount on the right.
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: ColorUtils.slate400,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          parts.join(' · '),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: ColorUtils.slate500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        // Stacked progress strip: paid (green) on the
                        // left, overdue (red) on the right, rest is
                        // unpaid (slate-100 track). Reads as a
                        // dashboard at a glance.
                        _ProgressStrip(
                          pctPaid: pctPaid,
                          pctOverdue: pctOverdue,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              _shortRp(data.totalAmount),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'total',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: ColorUtils.slate500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            if (data.paidAmount > 0)
                              Text(
                                '${_shortRp(data.paidAmount)} lunas',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
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

class _ProgressStrip extends StatelessWidget {
  final double pctPaid;
  final double pctOverdue;

  const _ProgressStrip({required this.pctPaid, required this.pctOverdue});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            if (pctPaid > 0)
              Expanded(
                flex: (pctPaid * 1000).round(),
                child: Container(color: const Color(0xFF10B981)),
              ),
            // Middle "on-time-unpaid" fills the gap between paid and
            // overdue with a neutral slate so the proportions line
            // up — amber would over-emphasize unpaid bills that
            // haven't hit their due date yet.
            if (1.0 - pctPaid - pctOverdue > 0)
              Expanded(
                flex: ((1.0 - pctPaid - pctOverdue) * 1000).round(),
                child: Container(color: ColorUtils.slate200),
              ),
            if (pctOverdue > 0)
              Expanded(
                flex: (pctOverdue * 1000).round(),
                child: Container(color: ColorUtils.error600),
              ),
          ],
        ),
      ),
    );
  }
}
