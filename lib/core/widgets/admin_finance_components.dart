// Admin Keuangan hub shared components — Mockup #13.
//
// Two new widgets:
//   • MoneyFlowStrip — 3 horizontal tiles inside the navy hero:
//                      Masuk (incoming) · Terutang (outstanding) ·
//                      Jatuh Tempo (overdue, red-tinted overlay).
//   • FlowBar        — single-row stacked horizontal bar visualising
//                      paid / outstanding / overdue percentages.
//
// Tiles are intentionally narrow so the existing finance hub still
// fits the rest of its chrome (back button, title, tabs) without
// scrolling. Both consume only existing tokens.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';

// =====================================================================
// MoneyFlowStrip
// =====================================================================

/// Display payload for [MoneyFlowStrip]. The screen is responsible for
/// formatting raw rupiah values into compact labels (e.g. "Rp 184jt")
/// before passing them in — this widget just renders.
class MoneyFlowFigures {
  final String incomingAmount;
  final String? incomingDelta;
  final int incomingCount;

  final String outstandingAmount;
  final int outstandingCount;

  final String overdueAmount;
  final int overdueCount;

  const MoneyFlowFigures({
    required this.incomingAmount,
    this.incomingDelta,
    required this.incomingCount,
    required this.outstandingAmount,
    required this.outstandingCount,
    required this.overdueAmount,
    required this.overdueCount,
  });
}

class MoneyFlowStrip extends StatelessWidget {
  final MoneyFlowFigures figures;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onOverdueTap;

  const MoneyFlowStrip({
    super.key,
    required this.figures,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.onOverdueTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _FlowTile(
                kicker: 'MASUK',
                amount: figures.incomingAmount,
                delta: figures.incomingDelta,
                deltaColor: const Color(0xFF86EFAC),
                meta: '${figures.incomingCount} transaksi',
                tone: _FlowTone.translucent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FlowTile(
                kicker: 'TERUTANG',
                amount: figures.outstandingAmount,
                delta: '⏰ jatuh tempo',
                deltaColor: const Color(0xFFFCD34D),
                meta: '${figures.outstandingCount} tagihan',
                tone: _FlowTone.translucent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onOverdueTap,
                child: _FlowTile(
                  kicker: 'JATUH TEMPO',
                  amount: figures.overdueAmount,
                  delta: figures.overdueCount > 0
                      ? '⚠ ${figures.overdueCount} wali murid'
                      : null,
                  deltaColor: Colors.white,
                  meta: figures.overdueCount > 0
                      ? 'tindakan diperlukan'
                      : 'tidak ada',
                  tone: figures.overdueCount > 0
                      ? _FlowTone.danger
                      : _FlowTone.translucent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _FlowTone { translucent, danger }

class _FlowTile extends StatelessWidget {
  final String kicker;
  final String amount;
  final String? delta;
  final Color deltaColor;
  final String? meta;
  final _FlowTone tone;

  const _FlowTile({
    required this.kicker,
    required this.amount,
    this.delta,
    required this.deltaColor,
    this.meta,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final bg = switch (tone) {
      _FlowTone.translucent => Colors.white.withValues(alpha: 0.18),
      _FlowTone.danger => const Color(0xFFDC2626).withValues(alpha: 0.32),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            kicker,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.75),
              letterSpacing: 0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (delta != null) ...[
            const SizedBox(height: 6),
            Text(
              delta!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: deltaColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (meta != null) ...[
            const SizedBox(height: 3),
            Text(
              meta!,
              style: TextStyle(
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// =====================================================================
// FlowBar
// =====================================================================

enum FlowSegment { paid, outstanding, overdue }

/// Single-row stacked horizontal bar visualising payment-pipeline
/// distribution: green (paid) · amber (outstanding) · red (overdue).
/// Lives directly below the [MoneyFlowStrip] inside the hero.
class FlowBar extends StatelessWidget {
  final double paidPct;
  final double outstandingPct;
  final double overduePct;
  final ValueChanged<FlowSegment>? onSegmentTap;
  final EdgeInsetsGeometry padding;

  const FlowBar({
    super.key,
    required this.paidPct,
    required this.outstandingPct,
    required this.overduePct,
    this.onSegmentTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  /// Total of all percentages — defends against rounding error.
  double get _total {
    final t = paidPct + outstandingPct + overduePct;
    return t <= 0 ? 1.0 : t;
  }

  @override
  Widget build(BuildContext context) {
    final paidFrac = paidPct / _total;
    final outFrac = outstandingPct / _total;
    final ovrFrac = overduePct / _total;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ALIRAN ↓',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  if (paidFrac > 0)
                    Expanded(
                      flex: (paidFrac * 1000).round(),
                      child: _Segment(
                        color: const Color(0xFF10B981),
                        label: '${paidPct.round()}% terbayar',
                        textColor: Colors.white,
                        onTap: onSegmentTap == null
                            ? null
                            : () => onSegmentTap!(FlowSegment.paid),
                      ),
                    ),
                  if (outFrac > 0)
                    Expanded(
                      flex: (outFrac * 1000).round(),
                      child: _Segment(
                        color: const Color(0xFFFCD34D),
                        label: '${outstandingPct.round()}%',
                        textColor: const Color(0xFF92400E),
                        onTap: onSegmentTap == null
                            ? null
                            : () => onSegmentTap!(FlowSegment.outstanding),
                      ),
                    ),
                  if (ovrFrac > 0)
                    Expanded(
                      flex: (ovrFrac * 1000).round(),
                      child: _Segment(
                        color: const Color(0xFFDC2626),
                        label: '${overduePct.round()}%',
                        textColor: Colors.white,
                        onTap: onSegmentTap == null
                            ? null
                            : () => onSegmentTap!(FlowSegment.overdue),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final Color color;
  final String label;
  final Color textColor;
  final VoidCallback? onTap;

  const _Segment({
    required this.color,
    required this.label,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// MoneyFlowSkeleton
// =====================================================================

/// Skeleton placeholder for [MoneyFlowStrip] while the dashboard
/// summary is loading. Reuses the slate100 shimmer tone but stays
/// inside the navy hero so the layout doesn't jump on resolve.
class MoneyFlowSkeleton extends StatelessWidget {
  const MoneyFlowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(
          3,
          (i) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Container(
                height: 92,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 60,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Compact rupiah formatter — exported so screens can use it.
// =====================================================================

/// Returns a compact "Rp 184jt" / "Rp 1,2M" / "Rp 28rb" label.
/// Returns "Rp 0" for null / non-positive inputs.
String formatRupiahCompact(num? value) {
  final v = (value ?? 0).toDouble();
  if (v <= 0) return 'Rp 0';
  final abs = v.abs();
  String body;
  if (abs >= 1e9) {
    body = '${(abs / 1e9).toStringAsFixed(abs >= 10e9 ? 0 : 1)}M';
  } else if (abs >= 1e6) {
    body = '${(abs / 1e6).toStringAsFixed(abs >= 10e6 ? 0 : 1)}jt';
  } else if (abs >= 1e3) {
    body = '${(abs / 1e3).toStringAsFixed(abs >= 10e3 ? 0 : 1)}rb';
  } else {
    body = abs.toStringAsFixed(0);
  }
  // Trim trailing ".0" for cleaner display ("184jt" not "184.0jt").
  body = body.replaceAll(RegExp(r'\.0(?=[a-zA-Z])'), '');
  return 'Rp $body';
}

// Re-export ColorUtils admin gradient as a convenience so screens
// that import this file don't also need to import color_utils.
LinearGradient adminFinanceGradient() => ColorUtils.brandGradient('admin');

// =====================================================================
// FinanceSubFilterStrip — Mockup #13
// =====================================================================

/// Sub-filter chip for the Tagihan tab. A pill that flips between an
/// outlined neutral state, an active navy state, and an overdue
/// red-tinted variant when [tone] == [SubFilterTone.danger].
enum SubFilterTone { neutral, danger }

class SubFilterChipData {
  final String key;
  final String label;
  final int? badge;
  final SubFilterTone tone;
  const SubFilterChipData({
    required this.key,
    required this.label,
    this.badge,
    this.tone = SubFilterTone.neutral,
  });
}

/// Horizontal scrollable strip of [SubFilterChipData] pills. Lives
/// directly under the FinanceTabBar on the Tagihan tab. Tapping a chip
/// re-scopes the bill list. Mockup #13 spec: `Semua` / `Belum bayar` /
/// `Jatuh tempo · 32` (last one tinted red when overdue ≥ 1).
class FinanceSubFilterStrip extends StatelessWidget {
  final List<SubFilterChipData> chips;
  final String activeKey;
  final ValueChanged<String> onSelect;
  final EdgeInsetsGeometry padding;

  const FinanceSubFilterStrip({
    super.key,
    required this.chips,
    required this.activeKey,
    required this.onSelect,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              _SubFilterChip(
                data: chips[i],
                active: chips[i].key == activeKey,
                onTap: () => onSelect(chips[i].key),
              ),
              if (i < chips.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubFilterChip extends StatelessWidget {
  final SubFilterChipData data;
  final bool active;
  final VoidCallback onTap;

  const _SubFilterChip({
    required this.data,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    final isDanger = data.tone == SubFilterTone.danger;

    final Color bg;
    final Color fg;
    final Color border;
    if (active) {
      bg = isDanger ? const Color(0xFFFEF2F2) : navy;
      fg = isDanger ? const Color(0xFF991B1B) : Colors.white;
      border = isDanger ? const Color(0xFFFCA5A5) : navy;
    } else if (isDanger) {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFF991B1B);
      border = const Color(0xFFFCA5A5);
    } else {
      bg = Colors.white;
      fg = const Color(0xFF334155);
      border = const Color(0xFFCBD5E1);
    }

    final label = data.badge != null && data.badge! > 0
        ? '${data.label} · ${data.badge}'
        : data.label;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active || isDanger ? FontWeight.w800 : FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// InvoiceRow — Mockup #13
// =====================================================================

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

// =====================================================================
// ClassReportDrillCard — Mockup #13
// =====================================================================

/// Soft navy-tinted card pinned at the bottom of the Tagihan list. Tap
/// drills into the per-kelas finance report.
class ClassReportDrillCard extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final String subtitle;

  const ClassReportDrillCard({
    super.key,
    required this.onTap,
    this.title = 'Laporan per kelas',
    this.subtitle = 'Drill ke ClassFinanceReport untuk breakdown lengkap',
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: navy, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: navy.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: navy, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// BillGroupRow — aggregated card for the Tagihan list
// ─────────────────────────────────────────────────────────────────────

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
        ? (data.overdueCount / data.totalCount.clamp(1, 1 << 30))
              .clamp(0.0, 1.0)
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
