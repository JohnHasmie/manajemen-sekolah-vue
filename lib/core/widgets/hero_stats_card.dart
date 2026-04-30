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

/// Progress descriptor for the optional Stories-style segmented strip
/// drawn at the top edge of a [HeroStatsCard].
///
/// Used by `BrandKpiCarousel` so each card in the strip can render the
/// same multi-segment "which slice is active" indicator (e.g., one
/// segment per anak for a parent dashboard, one per kelas for a guru
/// dashboard). When `total` is 1 the strip is omitted entirely — a
/// single-slice card looks like a plain stats card.
@immutable
class KpiProgress {
  /// Total number of slices in the cycle (e.g., 3 children).
  final int total;

  /// 0-based index of the currently-active slice.
  final int activeIndex;

  /// 0..1 fill of the active segment (0 = just started, 1 = about to
  /// advance). Sibling cards in the same strip share this value so the
  /// animation is visually one continuous bar.
  final double fillFraction;

  const KpiProgress({
    required this.total,
    required this.activeIndex,
    required this.fillFraction,
  });
}

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

  /// Optional secondary line under [label] showing which slice the card
  /// currently represents (e.g., "Salman · 30 hari", "Kelas 5A · MTK").
  /// Lives between the label and the value so the user always knows
  /// whose number they're reading. Pass null when no slice context
  /// applies (single-anak parent, admin school view, etc.).
  final String? sliceLabel;

  /// When true the [sliceLabel] is rendered in muted slate instead of
  /// the card's [accentColor]. Used for placeholder / empty states
  /// ("Belum ada data") so they don't read as alerts.
  final bool sliceLabelMuted;

  /// Optional Stories-style segmented progress at the top edge.
  /// Driven by `BrandKpiCarousel`'s `activeSliceProvider` so all cards
  /// in the strip animate in sync. Null hides the strip entirely.
  final KpiProgress? progress;

  /// Short tap handler — in carousel context this pauses/plays.
  final VoidCallback? onTap;

  /// Long press handler — navigates to the detail screen.
  final VoidCallback? onLongPress;

  /// Padding inside the card. Default: 12 px all around (compact so three
  /// tiles fit a 360 px viewport with the value+label inline format).
  final EdgeInsets padding;

  const HeroStatsCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.caption,
    this.trend,
    this.sliceLabel,
    this.sliceLabelMuted = false,
    this.progress,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
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
        children: [
          // Optional Stories-style progress strip at the top edge.
          if (progress != null && progress!.total > 1) ...[
            _SliceProgressStrip(progress: progress!, accentColor: accentColor),
            const SizedBox(height: 10),
          ],
          // Icon badge + label on same row (v3 mockup)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.all(Radius.circular(11)),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (sliceLabel != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        sliceLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: sliceLabelMuted
                              ? const Color(0xFF94A3B8)
                              : accentColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          // Big value + trend badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (trend != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _TrendChip(trend: trend!),
                ),
              ],
            ],
          ),
          // Caption below value (separate line)
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null && onLongPress == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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

/// Stories-style segmented progress bar drawn flush to the top edge
/// of a [HeroStatsCard]. Each segment represents one slice in the
/// cycle (e.g., one anak / one kelas). The active segment fills from
/// 0..1 according to [KpiProgress.fillFraction] driven by
/// `BrandKpiCarousel`'s active-slice notifier; segments before the
/// active index are fully filled, segments after are empty.
class _SliceProgressStrip extends StatelessWidget {
  final KpiProgress progress;
  final Color accentColor;

  const _SliceProgressStrip({required this.progress, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 4.0;
          final totalGaps = (progress.total - 1) * gap;
          final segWidth =
              (constraints.maxWidth - totalGaps) / progress.total;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (int i = 0; i < progress.total; i++) ...[
                _Segment(
                  width: segWidth,
                  // Segments before active are full, the active one
                  // animates 0..1, segments after are empty.
                  fill: i < progress.activeIndex
                      ? 1.0
                      : (i == progress.activeIndex
                            ? progress.fillFraction.clamp(0.0, 1.0)
                            : 0.0),
                  color: accentColor,
                ),
                if (i < progress.total - 1) const SizedBox(width: gap),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final double width;
  final double fill;
  final Color color;

  const _Segment({
    required this.width,
    required this.fill,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Track
        Container(
          width: width,
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        // Fill
        Container(
          width: width * fill,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ],
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
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1) SizedBox(width: spacing),
            ],
          ],
        ),
      ),
    );
  }
}
