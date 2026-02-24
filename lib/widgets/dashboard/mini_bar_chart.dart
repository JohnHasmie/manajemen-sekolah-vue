import 'dart:math' as math;

import 'package:flutter/material.dart';

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
