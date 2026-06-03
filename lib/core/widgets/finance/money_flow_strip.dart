// MoneyFlowStrip — 3 horizontal tiles inside the navy hero:
//   Masuk (incoming) · Terutang (outstanding) · Jatuh Tempo (overdue,
//   red-tinted overlay).
//
// Tiles are intentionally narrow so the existing finance hub still
// fits the rest of its chrome (back button, title, tabs) without
// scrolling. Consumes only existing tokens.

import 'package:flutter/material.dart';

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
