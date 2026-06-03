// FlowBar — single-row stacked horizontal bar visualising payment-
// pipeline distribution: green (paid) · amber (outstanding) · red
// (overdue). Lives directly below the MoneyFlowStrip inside the hero.

import 'package:flutter/material.dart';

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
