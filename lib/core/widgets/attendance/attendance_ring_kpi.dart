// Donut + legend KPI card used inside the parent Kehadiran main view.
//
// Why this exists
// ---------------
// The Kehadiran main screen mockup shows an attendance percentage as a
// donut ring on the left, with a 4-row legend on the right (Hadir /
// Izin / Sakit / Alpha) and an optional `vs bulan lalu` delta chip at
// the bottom. Three other surfaces will reuse this card later:
//
//   • Admin dashboard "Kehadiran hari ini" tile (smaller variant)
//   • Wali kelas roll-call summary
//   • Print rapor cover page
//
// Pulling it out as a shared widget means the donut math, the
// status-color mapping (`AttendanceStatusPalette`), and the trend chip
// all live in one place.
//
// Visual contract (mockup `Parent_Phase3_Kehadiran_Mockup.svg`)
// ------------------------------------------------------------
//   • White card, 0.75 px slate-200 border, 16 px corner.
//   • Donut: 104 px outer (stroke 10), brand-colored arc, slate-200
//     track.
//   • Legend: 4 rows, each with status dot + label + count-of-days.
//   • Footer: optional "vs bulan lalu" + green/red trend chip.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/attendance/attendance_status.dart';

/// Donut + legend KPI card for monthly attendance.
class AttendanceRingKpi extends StatelessWidget {
  /// Attendance percentage 0..100. Drives both the displayed number
  /// and the donut arc fill.
  final double rate;

  /// Counts of the four primary statuses for the period.
  final int presentDays;
  final int excusedDays;
  final int sickDays;
  final int alphaDays;

  /// Total school days the rate is computed against. Shown in the
  /// "Bulan ini · N hari sekolah" subtitle.
  final int schoolDays;

  /// Optional period label rendered above the legend (e.g.
  /// `'Bulan ini'`). Pass null to hide.
  final String? periodLabel;

  /// Optional delta vs the previous period. Positive ➜ green up chip,
  /// negative ➜ red down chip, null hides the footer trend.
  final double? deltaPct;

  /// Brand color for the donut arc. Defaults to the parent brand
  /// azure; pass `ColorUtils.brandDarkBlue` for admin.
  final Color brandColor;

  const AttendanceRingKpi({
    super.key,
    required this.rate,
    required this.presentDays,
    required this.excusedDays,
    required this.sickDays,
    required this.alphaDays,
    required this.schoolDays,
    this.periodLabel = 'Bulan ini',
    this.deltaPct,
    this.brandColor = const Color(0xFF1A8FBE),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 116,
                height: 116,
                child: _DonutRing(
                  rate: rate,
                  brandColor: brandColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (periodLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '$periodLabel · $schoolDays hari sekolah',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    _LegendRow(
                      status: AttendanceStatus.present,
                      count: presentDays,
                    ),
                    const SizedBox(height: 10),
                    _LegendRow(
                      status: AttendanceStatus.excused,
                      count: excusedDays,
                    ),
                    const SizedBox(height: 10),
                    _LegendRow(
                      status: AttendanceStatus.sick,
                      count: sickDays,
                    ),
                    const SizedBox(height: 10),
                    _LegendRow(
                      status: AttendanceStatus.alpha,
                      count: alphaDays,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (deltaPct != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'vs bulan lalu',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const Spacer(),
                _TrendChip(deltaPct: deltaPct!),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DonutRing extends StatelessWidget {
  final double rate;
  final Color brandColor;

  const _DonutRing({required this.rate, required this.brandColor});

  @override
  Widget build(BuildContext context) {
    final clamped = rate.clamp(0.0, 100.0);
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: CustomPaint(
            painter: _DonutPainter(
              progress: clamped / 100,
              brandColor: brandColor,
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatPercent(clamped),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                height: 1.0,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kehadiran',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatPercent(double v) {
    // 90.34 → "90,3%" (one decimal, comma separator like Indonesian)
    final rounded = (v * 10).round() / 10;
    final intPart = rounded.truncate();
    final fracPart = ((rounded - intPart) * 10).round().abs();
    if (fracPart == 0) return '$intPart%';
    return '$intPart,$fracPart%';
  }
}

class _DonutPainter extends CustomPainter {
  final double progress; // 0..1
  final Color brandColor;

  _DonutPainter({required this.progress, required this.brandColor});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFE2E8F0);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = brandColor;
    canvas.drawCircle(center, radius, track);
    final rect = Rect.fromCircle(center: center, radius: radius);
    // Sweep starts at 12 o'clock (-90°) and goes clockwise.
    canvas.drawArc(
      rect,
      -1.5708, // -90 degrees in radians
      6.2832 * progress.clamp(0.0, 1.0), // 2π × progress
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress || old.brandColor != brandColor;
}

class _LegendRow extends StatelessWidget {
  final AttendanceStatus status;
  final int count;

  const _LegendRow({required this.status, required this.count});

  @override
  Widget build(BuildContext context) {
    final palette = statusPalette(status);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: palette.dot,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          palette.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const Spacer(),
        Text(
          '$count hari',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _TrendChip extends StatelessWidget {
  final double deltaPct;

  const _TrendChip({required this.deltaPct});

  @override
  Widget build(BuildContext context) {
    final isUp = deltaPct >= 0;
    final bg = isUp ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final fg = isUp ? ColorUtils.success600 : ColorUtils.error600;
    final label = '${isUp ? '+' : ''}${deltaPct.toStringAsFixed(1)}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            size: 12,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
