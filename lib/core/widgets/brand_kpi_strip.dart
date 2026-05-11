// Shared KPI strip card used across all role screens.
//
// A white card with N equal-width columns separated by thin dividers.
// Each column shows a value + label + optional accent badge + sub-text.
//
// Usage:
// ```dart
// BrandKpiStrip(
//   columns: [
//     BrandKpiColumn(label: 'Penilaian', value: '14',
//         sub: '10 sudah · 4 menunggu'),
//     BrandKpiColumn(label: 'Rata-rata', value: '88,2',
//         badge: 'Sangat Baik', badgeColor: Colors.green),
//     BrandKpiColumn(label: 'Rentang', value: '76 — 96'),
//   ],
// )
// ```
//
// Place as `kpiCard` of BrandPageLayout. The header's
// `kpiOverlayHeight: BrandKpiStrip.defaultOverlap` extends the
// gradient so the card visually overlaps the hero bottom edge.
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

  /// Optional sub-text below the value.
  final String? sub;

  /// Optional badge text below the value (e.g. "Sangat Baik").
  final String? badge;

  /// Badge background color. Only used when [badge] is set.
  final Color? badgeColor;

  /// Badge text color. Defaults to [badgeColor].
  final Color? badgeTextColor;

  /// Optional icon inside the badge pill.
  final IconData? badgeIcon;

  /// Per-column tap handler.
  final VoidCallback? onTap;

  const BrandKpiColumn({
    required this.label,
    required this.value,
    this.valueColor,
    this.sub,
    this.badge,
    this.badgeColor,
    this.badgeTextColor,
    this.badgeIcon,
    this.onTap,
  });
}

/// Shared KPI strip card — white card with equal-width columns.
///
/// Set `BrandPageHeader(kpiOverlayHeight: BrandKpiStrip.defaultOverlap)`
/// on the header, then pass this as `kpiCard` to `BrandPageLayout`
/// to get the standard overlap effect.
class BrandKpiStrip extends StatelessWidget {
  final List<BrandKpiColumn> columns;
  final double horizontalPadding;

  /// Default overlap — pass to `BrandPageHeader.kpiOverlayHeight`
  /// and `BrandPageLayout.overlapHeight`.
  static const double defaultOverlap = 45;

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
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
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
    final content = Column(
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
          _BadgePill(
            text: col.badge!,
            color: col.badgeColor,
            textColor: col.badgeTextColor,
            icon: col.badgeIcon,
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

    if (col.onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: col.onTap,
        child: content,
      );
    }
    return content;
  }
}

class _BadgePill extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? textColor;
  final IconData? icon;

  const _BadgePill({required this.text, this.color, this.textColor, this.icon});

  @override
  Widget build(BuildContext context) {
    final bg = (color ?? Colors.green).withValues(alpha: 0.12);
    final fg = textColor ?? color ?? const Color(0xFF15803D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
