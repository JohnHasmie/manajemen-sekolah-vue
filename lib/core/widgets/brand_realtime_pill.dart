// Realtime indicator pill rendered inside a brand gradient header.
//
// Why this exists
// ---------------
// The admin / teacher / parent dashboard bodies each had a private
// `_RealtimePill` + `_PulsingDot` pair — three copies of the same
// 60-line widget. As the parent deep-tab screens start adopting the
// same indicator (Kehadiran, Pengumuman, Aktivitas all poll), the
// duplication compounds. This file is the canonical implementation.
//
// Visual contract
// ---------------
//   • Pulsing 8 px green dot (`#4ADE80`) when fresh, static grey when
//     the last poll failed.
//   • 11 pt 72%-white label "Terhubung realtime · HH:MM" or
//     "Terakhir diperbarui N menit lalu".
//   • No pill background — sits inline inside the gradient hero,
//     between the title row and the school pill / child selector.
import 'package:flutter/material.dart';

/// Inline realtime indicator pill for use inside a brand gradient
/// header.
///
/// Pure presentational — the parent owns the polling state and passes
/// [isFresh] + [lastSync] in. When [isFresh] is true the dot pulses
/// green and the copy reads `Terhubung realtime · HH:MM`. When false
/// the dot turns grey/static and the copy reads
/// `Terakhir diperbarui N menit lalu`, with the special
/// `Mencoba menyambungkan ulang…` for the first failed minute.
class BrandRealtimePill extends StatelessWidget {
  /// True while we are connected and the last poll succeeded.
  final bool isFresh;

  /// Timestamp of the most recent successful poll. Drives both the
  /// `HH:MM` display when fresh and the `N menit lalu` count when stale.
  final DateTime lastSync;

  const BrandRealtimePill({
    super.key,
    required this.isFresh,
    required this.lastSync,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isFresh ? const Color(0xFF4ADE80) : Colors.grey.shade400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PulsingDot(color: dotColor, animate: isFresh),
        const SizedBox(width: 8),
        Text(
          _buildLabel(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.72),
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  String _buildLabel() {
    if (isFresh) {
      final hh = lastSync.hour.toString().padLeft(2, '0');
      final mm = lastSync.minute.toString().padLeft(2, '0');
      return 'Terhubung realtime · $hh:$mm';
    }
    final mins = DateTime.now().difference(lastSync).inMinutes;
    if (mins <= 0) return 'Mencoba menyambungkan ulang…';
    return 'Terakhir diperbarui $mins menit lalu';
  }
}

/// A subtly pulsing 8 px dot. Skips the animation when [animate] is
/// false (used to mark the indicator as stale).
class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool animate;

  const _PulsingDot({required this.color, required this.animate});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final alpha = widget.animate ? (0.55 + 0.45 * _controller.value) : 1.0;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: alpha),
            shape: BoxShape.circle,
            boxShadow: widget.animate
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
