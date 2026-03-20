// Custom circular/semi-circular progress ring widget for dashboard stats.
//
// Like a Vue `<CircularProgress>` component (e.g., from Vuetify's
// `<v-progress-circular>`) used in dashboard stat cards. Drawn with
// Flutter's CustomPainter (Canvas API) and supports animated transitions.
// Similar to a CSS circular progress bar with SVG stroke-dashoffset animation.
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// An animated circular or semi-circular progress ring indicator.
///
/// Like Vuetify's `<v-progress-circular>` or a CSS radial progress bar.
///
/// Props:
/// - [value] - progress from 0.0 to 1.0 (like `:value="0.75"`)
/// - [color] - arc color
/// - [strokeWidth] - ring thickness
/// - [size] - overall widget dimension
/// - [animate] - whether to animate from 0 to value on mount
/// - [isSemiCircle] - render as 180-degree arc instead of full 360-degree
/// - [backgroundColor] - track color behind the progress arc
///
/// Uses `AnimationController` for smooth value transitions (like Vue `<transition>`).
class ProgressRing extends StatefulWidget {
  /// Progress value from 0.0 to 1.0
  final double value;

  /// Color of the progress arc
  final Color color;

  /// Stroke width of the ring
  final double strokeWidth;

  /// Size of the widget
  final double size;

  /// Whether to animate the progress
  final bool animate;

  /// Whether to show semi-circle (180°) or full circle (360°)
  final bool isSemiCircle;

  /// Background color of the track
  final Color? backgroundColor;

  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.strokeWidth = 8.0,
    this.size = 80.0,
    this.animate = true,
    this.isSemiCircle = false,
    this.backgroundColor,
  });

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.animate ? 1200 : 0),
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: widget.value.clamp(0.0, 1.0),
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.value.clamp(0.0, 1.0),
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        ),
      );
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.isSemiCircle ? widget.size / 2 + widget.strokeWidth : widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _ProgressRingPainter(
              progress: _animation.value,
              color: widget.color,
              strokeWidth: widget.strokeWidth,
              isSemiCircle: widget.isSemiCircle,
              backgroundColor:
                  widget.backgroundColor ?? widget.color.withValues(alpha: 0.1),
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter that draws the background track and progress arc.
/// Like SVG circle stroke rendering with `stroke-dashoffset` for progress.
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final bool isSemiCircle;
  final Color backgroundColor;

  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.isSemiCircle,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Start angle and sweep angle
    final startAngle = isSemiCircle ? math.pi : -math.pi / 2;
    final sweepAngle = isSemiCircle ? math.pi : 2 * math.pi;

    // Draw background track
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    // Draw progress arc
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
