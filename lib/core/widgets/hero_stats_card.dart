// A large, dashboard-hero stat card.
//
// Why this exists
// ---------------
// Admin/teacher/orangtua dashboards all have a top-of-screen "hero" row that
// highlights the three most-watched KPIs (e.g., for admin: active students,
// teachers, outstanding tuition). Today these are hand-painted per role with
// duplicated padding, shadow, and icon-sizing code — and they drift. One
// role has a white card, another has a tinted card, a third has a gradient.
//
// This widget ships the single canonical look:
//   • rounded 16 px corner
//   • alpha-0.12 icon disc (matches StatSummaryCard idiom but larger)
//   • bold w800 value at 24 pt
//   • 11 pt label + optional trend chip (▲ 12% vs. last week)
//
// It is deliberately bigger than [StatSummaryCard] because hero tiles get
// one row on the dashboard while the stat row gets three cards per row.
// When you only need a chip-sized number use StatSummaryCard instead.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Direction of a stat's trend indicator.
enum StatTrendDirection { up, down, flat }

/// A single-line, optional trend indicator rendered in the top-right of the
/// card (e.g., "▲ 12% vs minggu lalu").
class StatTrend {
  /// Direction arrow shown next to [label].
  final StatTrendDirection direction;

  /// Short copy such as "12% vs minggu lalu".
  final String label;

  /// When true, "up" is treated as the undesirable direction (e.g., tagihan
  /// telat). This swaps the red/green mapping so the semantics read right.
  final bool inverse;

  const StatTrend({
    required this.direction,
    required this.label,
    this.inverse = false,
  });
}

/// A dashboard-hero stat card with icon, value, label, and optional trend.
///
/// Example:
/// ```dart
/// HeroStatsCard(
///   label: 'Siswa Aktif',
///   value: '1.248',
///   icon: Icons.school_outlined,
///   accentColor: Colors.indigo,
///   trend: StatTrend(
///     direction: StatTrendDirection.up,
///     label: '+24 minggu ini',
///   ),
///   onTap: () => navigateToStudentList(),
/// )
/// ```
class HeroStatsCard extends StatelessWidget {
  /// Descriptive label (e.g., "Siswa Aktif").
  final String label;

  /// Prominently displayed value.
  final String value;

  /// Icon shown in a tinted circular container.
  final IconData icon;

  /// Accent color for the icon, value, and optional trend.
  final Color accentColor;

  /// Optional trailing caption under the value (e.g., "total terdaftar").
  final String? caption;

  /// Optional trend chip in the top-right of the card.
  final StatTrend? trend;

  /// Tap handler — typically navigates to a detail view.
  final VoidCallback? onTap;

  /// Padding inside the card. Default: 14 px all around (a touch tighter
  /// than [AppSpacing.lg] so three tiles still fit a 360 px viewport).
  final EdgeInsets padding;

  const HeroStatsCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.caption,
    this.trend,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: accentColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon + optional trend chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const Spacer(),
              if (trend != null) _TrendChip(trend: trend!),
            ],
          ),
          AppSpacing.v12,
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: accentColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: card,
      ),
    );
  }
}

/// Trend chip in the top-right of a [HeroStatsCard].
class _TrendChip extends StatelessWidget {
  final StatTrend trend;

  const _TrendChip({required this.trend});

  @override
  Widget build(BuildContext context) {
    // Semantic color: up-is-good (default) vs inverse (down-is-good).
    final isPositive = trend.inverse
        ? trend.direction == StatTrendDirection.down
        : trend.direction == StatTrendDirection.up;
    final color = trend.direction == StatTrendDirection.flat
        ? Colors.grey.shade500
        : (isPositive ? Colors.green.shade600 : Colors.red.shade500);

    final arrow = switch (trend.direction) {
      StatTrendDirection.up => Icons.arrow_upward_rounded,
      StatTrendDirection.down => Icons.arrow_downward_rounded,
      StatTrendDirection.flat => Icons.remove_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(arrow, size: 10, color: color),
          const SizedBox(width: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 72),
            child: Text(
              trend.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A horizontal row of [HeroStatsCard]s with equal spacing.
///
/// Typical use: three hero cards across the dashboard top, each
/// `Expanded`-wrapped inside the row.
class HeroStatsRow extends StatelessWidget {
  /// The cards to display.
  final List<HeroStatsCard> cards;

  /// Padding around the row. Default: `16 px` horizontal.
  final EdgeInsets padding;

  /// Gap between cards.
  final double spacing;

  const HeroStatsRow({
    super.key,
    required this.cards,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.spacing = AppSpacing.sm,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            Expanded(child: cards[i]),
            if (i < cards.length - 1) SizedBox(width: spacing),
          ],
        ],
      ),
    );
  }
}
