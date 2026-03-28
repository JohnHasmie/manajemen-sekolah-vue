// Mini bar chart widget using Flutter's CustomPaint (Canvas API).
//
// Like a lightweight Chart.js bar chart in a Vue component, but rendered
// directly on the Flutter canvas instead of using a charting library.
// In Laravel/Vue you would use `<canvas>` with Chart.js; here we use
// Flutter's `CustomPainter` which is the equivalent of the Canvas API.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A mini bar chart rendered via CustomPaint for dashboard stat cards.
///
/// Like a minimal Chart.js bar chart. Uses Flutter's `CustomPainter`
/// (equivalent to HTML Canvas 2D API / Chart.js) to draw bars.
///
/// Props:
/// - [data] - list of numeric values for each bar
/// - [color] - bar fill color
/// - [height] / [width] - chart dimensions
/// - [barWidth] / [barSpacing] - bar geometry
/// - [cornerRadius] - rounded corners on bars
/// - [showLabels] - whether to draw value labels above bars
///
/// Used inside [AttendanceBarChartCard] and [FinanceBarChartCard].
class MiniBarChart extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;
  final double? width;
  final double barWidth;
  final double barSpacing;
  final double cornerRadius;
  final bool showLabels;
  final TextStyle? labelStyle;

  const MiniBarChart({
    super.key,
    required this.data,
    required this.color,
    this.height = 40.0,
    this.width,
    this.barWidth = 8.0,
    this.barSpacing = 4.0,
    this.cornerRadius = 2.0,
    this.showLabels = false,
    this.labelStyle,
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
        painter: _BarChartPainter(
          data: data,
          color: color,
          barWidth: barWidth,
          barSpacing: barSpacing,
          cornerRadius: cornerRadius,
          showLabels: showLabels,
          labelStyle: labelStyle,
        ),
      ),
    );
  }
}

/// Custom painter that draws the actual bar chart on the canvas.
/// Like the Chart.js rendering engine -- receives data and paints bars.
class _BarChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double barWidth;
  final double barSpacing;
  final double cornerRadius;
  final bool showLabels;
  final TextStyle? labelStyle;

  _BarChartPainter({
    required this.data,
    required this.color,
    required this.barWidth,
    required this.barSpacing,
    required this.cornerRadius,
    required this.showLabels,
    this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final maxValue = data.reduce(math.max);
    final effectiveMax = maxValue == 0 ? 1.0 : maxValue;

    // Calculate total required width to center or spread bars
    final totalBarsWidth =
        (data.length * barWidth) + ((data.length - 1) * barSpacing);
    final startX = (size.width - totalBarsWidth) / 2;

    for (int i = 0; i < data.length; i++) {
      final value = data[i];
      // Ensure a minimum height of 2.0 so that 0-value bars are slightly visible
      final barHeight = math.max((value / effectiveMax) * size.height, 2.0);

      final x = startX + (i * (barWidth + barSpacing));
      final y = size.height - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(cornerRadius),
      );

      canvas.drawRRect(rect, paint);

      if (showLabels) {
        final textSpan = TextSpan(
          text: value.toInt().toString(),
          style: labelStyle ?? TextStyle(fontSize: 10, color: color),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        final textX = x + (barWidth - textPainter.width) / 2;
        final textY = y - textPainter.height - 4; // 4px padding above bar
        textPainter.paint(canvas, Offset(textX, textY));
      }
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.color != color ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.barSpacing != barSpacing ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}
