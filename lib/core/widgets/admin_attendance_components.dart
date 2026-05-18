// Admin Kehadiran report shared components — Mockup #11.
//
// Three new widgets:
//   • AttendanceRingHero — centered SVG ring with H/I/S/A legend
//                          flanking it, lives inside the navy hero.
//   • TrendSparkRow      — per-tingkat row: label · % · 7-day
//                          sparkline · delta. Color-coded by current
//                          attendance rate.
//   • DateRangeChipBar   — Hari ini / Minggu ini / Bulan ini / Custom.
//                          Lives inside the hero, above the ring.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';

// =====================================================================
// Status palette (shared across both Mockup #11 and #12)
// =====================================================================

class AttendancePalette {
  static const Color present = Color(0xFF10B981);
  static const Color excused = Color(0xFFF59E0B);
  static const Color sick = Color(0xFF3B82F6);
  static const Color alpha = Color(0xFFDC2626);
  static const Color holiday = Color(0xFFE2E8F0);
}

// =====================================================================
// AttendanceRingHero
// =====================================================================

/// Aggregated attendance breakdown for a single day / period. The
/// ring renders [presentPct] as the filled arc; the four counts
/// drive the legend.
class AttendanceBreakdown {
  final int present;
  final int excused;
  final int sick;
  final int alpha;
  final double presentPct; // 0..100

  const AttendanceBreakdown({
    required this.present,
    required this.excused,
    required this.sick,
    required this.alpha,
    required this.presentPct,
  });

  int get total => present + excused + sick + alpha;
}

class AttendanceRingHero extends StatelessWidget {
  final AttendanceBreakdown breakdown;
  final String? subtitle;
  final EdgeInsetsGeometry padding;

  const AttendanceRingHero({
    super.key,
    required this.breakdown,
    this.subtitle = 'Hadir hari ini',
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _LegendColumn(
            entries: [
              _LegendEntry(
                label: 'Hadir',
                value: breakdown.present.toString(),
                color: AttendancePalette.present,
              ),
              _LegendEntry(
                label: 'Izin',
                value: breakdown.excused.toString(),
                color: AttendancePalette.excused,
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 152,
                height: 152,
                child: CustomPaint(
                  painter: _RingPainter(percent: breakdown.presentPct),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${breakdown.presentPct.round()}%',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle ?? 'Hadir',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _LegendColumn(
            crossAxisAlignment: CrossAxisAlignment.end,
            entries: [
              _LegendEntry(
                label: 'Sakit',
                value: breakdown.sick.toString(),
                color: AttendancePalette.sick,
              ),
              _LegendEntry(
                label: 'Alpa',
                value: breakdown.alpha.toString(),
                color: AttendancePalette.alpha,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendEntry {
  final String label;
  final String value;
  final Color color;
  const _LegendEntry({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _LegendColumn extends StatelessWidget {
  final List<_LegendEntry> entries;
  final CrossAxisAlignment crossAxisAlignment;
  const _LegendColumn({
    required this.entries,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            _LegendCell(entry: entries[i], align: crossAxisAlignment),
            if (i < entries.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _LegendCell extends StatelessWidget {
  final _LegendEntry entry;
  final CrossAxisAlignment align;
  const _LegendCell({required this.entry, required this.align});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: entry.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              entry.label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          entry.value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  const _RingPainter({required this.percent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 7;
    const stroke = 14.0;

    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final pct = (percent.clamp(0, 100)) / 100;
    if (pct <= 0) return;
    final fill = Paint()
      ..color = AttendancePalette.present
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    const start = -math.pi / 2;
    final sweep = pct * math.pi * 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.percent != percent;
}

// =====================================================================
// TrendSparkRow
// =====================================================================

class TrendSparkRow extends StatelessWidget {
  final String label;
  final double currentPct;
  final List<double> sparkPoints; // 7 values, 0..100
  final double deltaPct;
  final String? alertCopy;
  final VoidCallback? onTap;

  const TrendSparkRow({
    super.key,
    required this.label,
    required this.currentPct,
    required this.sparkPoints,
    required this.deltaPct,
    this.alertCopy,
    this.onTap,
  });

  Color get _accent {
    if (currentPct >= 90) return AttendancePalette.present;
    if (currentPct >= 80) return AttendancePalette.excused;
    return AttendancePalette.alpha;
  }

  bool get _alert => currentPct < 80 || alertCopy != null;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                      ),
                    ),
                  ),
                  Text(
                    '${currentPct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    height: 18,
                    child: CustomPaint(
                      painter: _SparkPainter(
                        points: sparkPoints,
                        color: _accent,
                        strokeWidth: _alert ? 2.5 : 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 36,
                    child: Text(
                      _formatDelta(deltaPct),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _alert
                            ? AttendancePalette.alpha
                            : ColorUtils.slate500,
                      ),
                    ),
                  ),
                ],
              ),
              if (alertCopy != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⚠ $alertCopy',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDelta(double v) {
    final sign = v >= 0 ? '↑' : '↓';
    return '$sign${v.abs().toStringAsFixed(1)}';
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> points;
  final Color color;
  final double strokeWidth;

  const _SparkPainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Normalize against fixed [80..100] band so that all rows share
    // the same visual baseline (a 5% drop reads bigger than a 5%
    // drop on a 92% row).
    const minPct = 70.0;
    const maxPct = 100.0;
    const span = maxPct - minPct;

    final dx = points.length > 1 ? size.width / (points.length - 1) : 0;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final v = points[i].clamp(minPct, maxPct);
      final yFrac = 1 - ((v - minPct) / span);
      final x = i * dx;
      final y = yFrac * size.height;
      if (i == 0) {
        path.moveTo(x.toDouble(), y);
      } else {
        path.lineTo(x.toDouble(), y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.points != points || old.color != color;
}

// =====================================================================
// CalendarHeatmap (Mockup #12)
// =====================================================================

enum CellState { present, excused, sick, alpha, holiday, none }

extension CellStateColor on CellState {
  Color get color {
    switch (this) {
      case CellState.present:
        return AttendancePalette.present;
      case CellState.excused:
        return AttendancePalette.excused;
      case CellState.sick:
        return AttendancePalette.sick;
      case CellState.alpha:
        return AttendancePalette.alpha;
      case CellState.holiday:
        return AttendancePalette.holiday;
      case CellState.none:
        return const Color(0xFFF1F5F9);
    }
  }

  String get labelId {
    switch (this) {
      case CellState.present:
        return 'Hadir';
      case CellState.excused:
        return 'Izin';
      case CellState.sick:
        return 'Sakit';
      case CellState.alpha:
        return 'Alpa';
      case CellState.holiday:
        return 'Libur';
      case CellState.none:
        return 'Belum dicatat';
    }
  }
}

/// Per-student row of N cells (default 30). Cell width auto-fits the
/// row so 30 cells fit in a phone-width card. Selected cell gets a
/// 2px navy border. Tapping a cell calls [onCellTap] with the index
/// — caller is responsible for opening the [CellDetailSheet] /
/// inline expansion.
class CalendarHeatmap extends StatelessWidget {
  final List<CellState> cells;
  final int? selectedIndex;
  final ValueChanged<int>? onCellTap;
  final double height;
  final double gap;

  const CalendarHeatmap({
    super.key,
    required this.cells,
    this.selectedIndex,
    this.onCellTap,
    this.height = 20,
    this.gap = 2,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (cells.isEmpty) return SizedBox(height: height);
        final n = cells.length;
        final totalGaps = gap * (n - 1);
        final cellWidth = ((constraints.maxWidth - totalGaps) / n).clamp(
          4.0,
          double.infinity,
        );

        return SizedBox(
          height: height,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              for (var i = 0; i < n; i++) ...[
                _Cell(
                  state: cells[i],
                  width: cellWidth,
                  height: height,
                  selected: selectedIndex == i,
                  onTap: onCellTap == null ? null : () => onCellTap!(i),
                ),
                if (i < n - 1) SizedBox(width: gap),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  final CellState state;
  final double width;
  final double height;
  final bool selected;
  final VoidCallback? onTap;

  const _Cell({
    required this.state,
    required this.width,
    required this.height,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: state.color,
          borderRadius: BorderRadius.circular(2),
          border: selected ? Border.all(color: navy, width: 2) : null,
        ),
      ),
    );
  }
}

// =====================================================================
// StudentRowHeader
// =====================================================================

/// Avatar + name + class + monthly % header row that sits above each
/// CalendarHeatmap. Card border turns red when [alert] is true (the
/// caller computes alpa-streak detection).
class StudentRowHeader extends StatelessWidget {
  final String avatarInitials;
  final Color avatarColor;
  final String name;
  final String classRoll;
  final double monthlyPct;
  final int presentDays;
  final int totalDays;
  final bool alert;
  final String? alertCopy;

  const StudentRowHeader({
    super.key,
    required this.avatarInitials,
    required this.avatarColor,
    required this.name,
    required this.classRoll,
    required this.monthlyPct,
    required this.presentDays,
    required this.totalDays,
    this.alert = false,
    this.alertCopy,
  });

  Color get _pctColor {
    if (monthlyPct >= 90) return AttendancePalette.present;
    if (monthlyPct >= 80) return AttendancePalette.excused;
    return AttendancePalette.alpha;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: avatarColor, shape: BoxShape.circle),
          child: Text(
            avatarInitials,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                alert && alertCopy != null ? '⚠ $alertCopy' : classRoll,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: alert ? FontWeight.w700 : FontWeight.w500,
                  color: alert ? AttendancePalette.alpha : ColorUtils.slate500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${monthlyPct.round()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _pctColor,
              ),
            ),
            Text(
              '$presentDays/$totalDays',
              style: TextStyle(fontSize: 10, color: ColorUtils.slate500),
            ),
          ],
        ),
      ],
    );
  }
}

// =====================================================================
// DateRangeChipBar
// =====================================================================

enum AttendanceRange { today, thisWeek, thisMonth, custom }

class DateRangeChipBar extends StatelessWidget {
  final AttendanceRange active;
  final ValueChanged<AttendanceRange> onSelect;
  final VoidCallback? onCustomTap;
  final EdgeInsetsGeometry padding;

  const DateRangeChipBar({
    super.key,
    required this.active,
    required this.onSelect,
    this.onCustomTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final entries = <(_ChipDef, AttendanceRange)>[
      (const _ChipDef('Hari ini'), AttendanceRange.today),
      (const _ChipDef('Minggu ini'), AttendanceRange.thisWeek),
      (const _ChipDef('Bulan ini'), AttendanceRange.thisMonth),
      (const _ChipDef('Custom', dashed: true), AttendanceRange.custom),
    ];

    return Padding(
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            // Each chip flexes to share the available width — matches
            // the parent role's `BrandFilterChipStrip` and prevents the
            // 4-chip row ("Hari ini / Minggu ini / Bulan ini / Custom")
            // from overflowing on a 380dp screen.
            Expanded(
              child: _RangeChip(
                def: entries[i].$1,
                active: entries[i].$2 == active,
                onTap: () {
                  final r = entries[i].$2;
                  if (r == AttendanceRange.custom && onCustomTap != null) {
                    onCustomTap!();
                  } else {
                    onSelect(r);
                  }
                },
              ),
            ),
            if (i < entries.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _ChipDef {
  final String label;
  final bool dashed;
  const _ChipDef(this.label, {this.dashed = false});
}

class _RangeChip extends StatelessWidget {
  final _ChipDef def;
  final bool active;
  final VoidCallback onTap;
  const _RangeChip({
    required this.def,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    final bg = active ? Colors.white : Colors.white.withValues(alpha: 0.18);
    final fg = active ? navy : Colors.white;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: !active && def.dashed
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1,
                  )
                : null,
          ),
          child: Text(
            def.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
