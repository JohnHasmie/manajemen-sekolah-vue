// Shared KPI strip card used across parent screens.
//
// A white card with N equal-width columns separated by thin dividers.
// Each column shows a value + label + optional accent badge.
//
// Usage (like Vue props):
// ```dart
// BrandKpiStrip(
//   columns: [
//     BrandKpiColumn(label: 'Penilaian', value: '14', sub: '10 sudah · 4 menunggu'),
//     BrandKpiColumn(label: 'Rata-rata', value: '88,2', badge: 'Sangat Baik', badgeColor: Colors.green),
//     BrandKpiColumn(label: 'Rentang', value: '76 — 96'),
//   ],
// )
// ```
//
// Place as the first child of the body ListView. When the parent
// screen sets `BrandPageHeader(kpiOverlayHeight: BrandKpiStrip.defaultOverlap)`,
// the gradient extends behind this card, creating the overlap effect.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A single column in the KPI strip.
class BrandKpiColumn {
  /// Small label above the value (e.g. "Rata-rata").
  final String label;

  /// Large prominent value (e.g. "88,2", "Rp 1,8jt").
  final String value;

  /// Optional color for the value text. Defaults to slate-900.
  final Color? valueColor;

  /// Optional sub-text below the value (e.g. "10 sudah · 4 menunggu").
  final String? sub;

  /// Optional badge text below the value (e.g. "Sangat Baik").
  final String? badge;

  /// Badge background color. Only used when [badge] is set.
  final Color? badgeColor;

  /// Badge text color. Defaults to a darker shade of [badgeColor].
  final Color? badgeTextColor;

  const BrandKpiColumn({
    required this.label,
    required this.value,
    this.valueColor,
    this.sub,
    this.badge,
    this.badgeColor,
    this.badgeTextColor,
  });
}

/// Shared KPI strip card — white card with equal-width columns.
///
/// Set `BrandPageHeader(kpiOverlayHeight: BrandKpiStrip.defaultOverlap)`
/// on the header, then place this as the first child of the body
/// `ListView` to get the overlap effect.
class BrandKpiStrip extends StatelessWidget {
  /// The columns to display.
  final List<BrandKpiColumn> columns;

  /// Horizontal padding around the card. Default: 16.
  final double horizontalPadding;

  /// Default overlap height — pass this to
  /// `BrandPageHeader.kpiOverlayHeight` to get the standard overlap.
  static const double defaultOverlap = 40;

  const BrandKpiStrip({
    super.key,
    required this.columns,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 0.75,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              for (int i = 0; i < columns.length; i++) ...[
                Expanded(child: _buildColumn(columns[i])),
                if (i < columns.length - 1)
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: const Color(0xFFF1F5F9),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColumn(BrandKpiColumn col) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          col.label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          col.value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: col.valueColor ?? ColorUtils.slate900,
            height: 1.0,
            letterSpacing: -0.3,
          ),
        ),
        if (col.badge != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (col.badgeColor ?? Colors.green).withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(9)),
            ),
            child: Text(
              col.badge!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: col.badgeTextColor ??
                    col.badgeColor ??
                    const Color(0xFF15803D),
              ),
            ),
          ),
        ],
        if (col.sub != null) ...[
          const SizedBox(height: 4),
          Text(
            col.sub!,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ],
    );
  }
}
