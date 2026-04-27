import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Compact circular progress ring used across the Rekap Nilai overview.
///
/// Renders a track circle + a stroked arc showing [value] in [0, 1], with
/// an optional centered [label] (usually a percentage). Sizes scale down to
/// as small as 28px for in-row indicators or up to ~72px for the stats hero.
class GradeRecapProgressRing extends StatelessWidget {
  /// Completion in the range `[0, 1]`. Values outside the range are clamped.
  final double value;

  /// Overall widget size (it always renders as a square).
  final double size;

  /// Arc thickness.
  final double strokeWidth;

  /// Colour for the completed portion of the arc.
  final Color activeColor;

  /// Colour for the remaining (background) portion.
  final Color trackColor;

  /// Optional text inside the ring — typically `'72%'`.
  final String? label;

  /// Style for [label]. A sensible default is applied when null.
  final TextStyle? labelStyle;

  const GradeRecapProgressRing({
    super.key,
    required this.value,
    this.size = 36,
    this.strokeWidth = 3,
    required this.activeColor,
    required this.trackColor,
    this.label,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0, 1).toDouble(),
          strokeWidth: strokeWidth,
          activeColor: activeColor,
          trackColor: trackColor,
        ),
        child: label == null
            ? null
            : Center(
                child: Text(
                  label!,
                  style:
                      labelStyle ??
                      TextStyle(
                        fontSize: size * 0.28,
                        fontWeight: FontWeight.w700,
                        color: activeColor,
                      ),
                ),
              ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double strokeWidth;
  final Color activeColor;
  final Color trackColor;

  _RingPainter({
    required this.value,
    required this.strokeWidth,
    required this.activeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, trackPaint);

    if (value <= 0) return;

    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start at 12 o'clock
      2 * math.pi * value,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.strokeWidth != strokeWidth ||
      old.activeColor != activeColor ||
      old.trackColor != trackColor;
}
