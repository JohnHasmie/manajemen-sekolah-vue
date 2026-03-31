// Mini sparkline chart widget using Flutter's CustomPaint (Canvas API).
//
// Like a Vue sparkline component (e.g., `vue-sparklines` or a tiny Chart.js
// line chart) used in dashboard stat cards. Draws a smooth bezier curve
// with optional area fill. In Laravel/Vue you might use `<sparkline>`
// from a charting library; here we use Flutter's `CustomPainter`.
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A mini sparkline chart for dashboard statistics.
///
/// Like a Vue sparkline component displaying a simple line chart.
/// Uses quadratic bezier curves for smooth lines.
///
/// Props:
/// - [data] - list of numeric data points (ideally 5-7)
/// - [color] - line and fill color
/// - [height] / [width] - chart dimensions
/// - [strokeWidth] - line thickness
/// - [fillArea] - whether to fill the area under the line with translucent color
///
/// Used inside [EnhancedStatCard] for trend visualization.
class MiniSparkline extends StatelessWidget {
  /// Data points to display (ideally 5-7 points)
  final List<double> data;

  /// Color of the line
  final Color color;

  /// Height of the chart
  final double height;

  /// Width of the chart
  final double? width;

  /// Stroke width of the line
  final double strokeWidth;

  /// Whether to fill the area under the line
  final bool fillArea;

  const MiniSparkline({
    super.key,
    required this.data,
    required this.color,
    this.height = 40.0,
    this.width,
    this.strokeWidth = 2.0,
    this.fillArea = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(height: height, width: width);
    }

    return SizedBox(
      height: height,
      width: width,
      child: CustomPaint(
        painter: _SparklinePainter(
          data: data,
          color: color,
          strokeWidth: strokeWidth,
          fillArea: fillArea,
        ),
      ),
    );
  }
}

/// Custom painter that draws the sparkline curve and optional fill area.
/// Uses quadratic bezier curves for smooth interpolation between data points.
class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double strokeWidth;
  final bool fillArea;

  _SparklinePainter({
    required this.data,
    required this.color,
    required this.strokeWidth,
    required this.fillArea,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || data.length < 2) return;

    // Find min and max values for scaling
    final minValue = data.reduce(math.min);
    final maxValue = data.reduce(math.max);
    final valueRange = maxValue - minValue;

    // Handle case where all values are the same
    final effectiveRange = valueRange == 0 ? 1.0 : valueRange;

    // Calculate spacing between points
    final spacing = size.width / (data.length - 1);

    // Create path for the line
    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = i * spacing;
      // Normalize and invert y (canvas y increases downward)
      final normalizedValue = (data[i] - minValue) / effectiveRange;
      final y = size.height - (normalizedValue * size.height);

      final point = Offset(x, y);
      points.add(point);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Use quadratic bezier for smooth curves
        final previousPoint = points[i - 1];
        final controlPointX =
            previousPoint.dx + (point.dx - previousPoint.dx) / 2;

        path.quadraticBezierTo(
          controlPointX,
          previousPoint.dy,
          point.dx,
          point.dy,
        );
      }
    }

    // Fill area under the line if enabled
    if (fillArea) {
      final fillPath = Path.from(path);
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();

      final fillPaint = Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw the line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Draw points at each data point
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, strokeWidth * 1.2, pointPaint);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.fillArea != fillArea;
  }
}
