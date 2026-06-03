// Creative in-flight banner shown while a drag-and-drop reschedule
// PATCH is racing the network.
//
// Built for TR.E — without this the source block disappears the
// moment the admin drops it and reappears at the new slot ~600ms
// later (server round-trip + list refresh). That dead window leaves
// the admin staring at a stale grid without any feedback, easy to
// mistake for a no-op.
//
// The banner sits in a floating pill near the top of the body and
// goes through three visual phases:
//
//   1. loading  → cobalt pill with the schedule's subject on the
//                 left, the target slot on the right, and three
//                 shimmer-dots traveling along an arrow between
//                 them. Each cycle is ~900ms so even slow networks
//                 see a few passes before the response lands.
//   2. success  → pill flips green, a checkmark scales in from the
//                 right end of the arrow, message reads
//                 "Berhasil dipindah". Auto-dismisses after ~700ms.
//   3. error    → pill flips red, an X scales in, message reads the
//                 server's reason. Dismissed when the consumer
//                 clears its state field after the snackbar fires.
//
// The widget is "dumb" — it doesn't know about the API, it just
// renders the supplied [phase] + meta. The screen sets phase before
// awaiting the PATCH, then transitions to success/error after the
// future resolves.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// The three visual states the banner can be in.
enum ScheduleReschedulePhase { loading, success, error }

/// Snapshot of the move-in-progress info to render.
///
/// Held as a record on the screen — passing the whole bag keeps the
/// banner free of business logic and gives the screen one place to
/// flip phase + dispose the overlay.
class ScheduleRescheduleSnapshot {
  final String subjectName;
  final String? fromSlotLabel; // e.g. "Senin · 07:00"
  final String toSlotLabel; // e.g. "Selasa · 09:30"
  final ScheduleReschedulePhase phase;
  final String? errorMessage; // surfaced on phase == error

  const ScheduleRescheduleSnapshot({
    required this.subjectName,
    required this.toSlotLabel,
    required this.phase,
    this.fromSlotLabel,
    this.errorMessage,
  });

  ScheduleRescheduleSnapshot copyWith({
    ScheduleReschedulePhase? phase,
    String? errorMessage,
  }) {
    return ScheduleRescheduleSnapshot(
      subjectName: subjectName,
      fromSlotLabel: fromSlotLabel,
      toSlotLabel: toSlotLabel,
      phase: phase ?? this.phase,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Floating reschedule progress banner.
///
/// Self-contained: handles its own slide-down + slide-up animation
/// when [snapshot] flips between null and non-null. The shimmer-dot
/// animation while in [ScheduleReschedulePhase.loading] is driven by
/// a private repeating [AnimationController].
class ScheduleRescheduleBanner extends StatefulWidget {
  const ScheduleRescheduleBanner({super.key, required this.snapshot});

  /// Pass `null` to hide the banner. When the value transitions from
  /// non-null to null the widget runs a slide-up dismiss before
  /// disappearing.
  final ScheduleRescheduleSnapshot? snapshot;

  @override
  State<ScheduleRescheduleBanner> createState() =>
      _ScheduleRescheduleBannerState();
}

class _ScheduleRescheduleBannerState extends State<ScheduleRescheduleBanner>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _shimmer;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  ScheduleRescheduleSnapshot? _lastSnapshot; // for hide-out transition

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _slide = CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic);
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _lastSnapshot = widget.snapshot;
    if (widget.snapshot != null) {
      _entry.value = 1;
      if (widget.snapshot!.phase == ScheduleReschedulePhase.loading) {
        _shimmer.repeat();
      }
    }
  }

  @override
  void didUpdateWidget(covariant ScheduleRescheduleBanner old) {
    super.didUpdateWidget(old);
    final next = widget.snapshot;
    final prev = old.snapshot;

    // Capture the latest non-null snapshot so the slide-up exit
    // animation has something to render while the controller
    // unwinds.
    if (next != null) _lastSnapshot = next;

    if (prev == null && next != null) {
      _entry.forward(from: 0);
      if (next.phase == ScheduleReschedulePhase.loading) {
        _shimmer.repeat();
      }
    } else if (prev != null && next == null) {
      _entry.reverse();
      _shimmer.stop();
    } else if (prev?.phase != next?.phase) {
      // Phase flipped — stop the shimmer once we leave loading so
      // the success/error icon doesn't keep painting behind the
      // travel dots.
      if (next?.phase == ScheduleReschedulePhase.loading) {
        _shimmer.repeat();
      } else {
        _shimmer.stop();
      }
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.snapshot ?? _lastSnapshot;
    if (snap == null) return const SizedBox.shrink();

    final (bg, fg, border) = _palette(snap.phase);

    return AnimatedBuilder(
      animation: _entry,
      builder: (context, _) {
        final dy = (1 - _slide.value) * -24;
        return Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: border.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                  child: Row(
                    children: [
                      _PhaseIcon(phase: snap.phase, color: fg),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _BannerBody(
                          snapshot: snap,
                          shimmer: _shimmer,
                          accent: fg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Returns (background, foreground/accent, border) for each phase.
  ///
  /// Only `success600` / `error600` exist in [ColorUtils] today —
  /// the lighter shades are derived by alpha-compositing against
  /// white, which avoids adding new tokens just for this widget.
  (Color, Color, Color) _palette(ScheduleReschedulePhase phase) {
    return switch (phase) {
      ScheduleReschedulePhase.loading => (
        Colors.white,
        ColorUtils.brandCobalt,
        ColorUtils.brandCobalt.withValues(alpha: 0.35),
      ),
      ScheduleReschedulePhase.success => (
        Color.alphaBlend(
          ColorUtils.success600.withValues(alpha: 0.10),
          Colors.white,
        ),
        ColorUtils.success600,
        ColorUtils.success600.withValues(alpha: 0.45),
      ),
      ScheduleReschedulePhase.error => (
        Color.alphaBlend(
          ColorUtils.error600.withValues(alpha: 0.10),
          Colors.white,
        ),
        ColorUtils.error600,
        ColorUtils.error600.withValues(alpha: 0.45),
      ),
    };
  }
}

class _PhaseIcon extends StatelessWidget {
  const _PhaseIcon({required this.phase, required this.color});

  final ScheduleReschedulePhase phase;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (phase) {
      ScheduleReschedulePhase.loading => Icons.swap_horiz_rounded,
      ScheduleReschedulePhase.success => Icons.check_circle_rounded,
      ScheduleReschedulePhase.error => Icons.error_outline_rounded,
    };
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: anim,
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Icon(icon, key: ValueKey(icon), size: 20, color: color),
      ),
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody({
    required this.snapshot,
    required this.shimmer,
    required this.accent,
  });

  final ScheduleRescheduleSnapshot snapshot;
  final Animation<double> shimmer;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _headline(snapshot),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate900,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                snapshot.fromSlotLabel ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: ColorUtils.slate600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 60,
              height: 14,
              child: snapshot.phase == ScheduleReschedulePhase.loading
                  ? _ShimmerArrow(progress: shimmer, accent: accent)
                  : _StaticArrow(accent: accent),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                snapshot.toSlotLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
        if (snapshot.phase == ScheduleReschedulePhase.error &&
            (snapshot.errorMessage?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 4),
          Text(
            snapshot.errorMessage!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: ColorUtils.error600,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }

  String _headline(ScheduleRescheduleSnapshot s) {
    return switch (s.phase) {
      ScheduleReschedulePhase.loading => 'Memindahkan ${s.subjectName}…',
      ScheduleReschedulePhase.success => 'Berhasil dipindah · ${s.subjectName}',
      ScheduleReschedulePhase.error => 'Gagal dipindah · ${s.subjectName}',
    };
  }
}

/// Three dots traveling along a dashed arrow.
///
/// Each dot follows the same Tween but offset by 1/3 of a cycle, so
/// the impression is a continuous shimmer left → right that mirrors
/// the schedule actually moving between slots. The dot's opacity
/// fades in/out at the edges so it doesn't pop off the line.
class _ShimmerArrow extends StatelessWidget {
  const _ShimmerArrow({required this.progress, required this.accent});

  final Animation<double> progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        return CustomPaint(
          painter: _ShimmerArrowPainter(
            progress: progress.value,
            accent: accent,
          ),
        );
      },
    );
  }
}

class _StaticArrow extends StatelessWidget {
  const _StaticArrow({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StaticArrowPainter(accent: accent));
  }
}

class _ShimmerArrowPainter extends CustomPainter {
  _ShimmerArrowPainter({required this.progress, required this.accent});

  final double progress; // 0 → 1, loops
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;

    // Backing dashed line.
    final linePaint = Paint()
      ..color = accent.withValues(alpha: 0.25)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const dashWidth = 3.0;
    const gapWidth = 3.0;
    double x = 0;
    while (x < size.width - 10) {
      canvas.drawLine(Offset(x, midY), Offset(x + dashWidth, midY), linePaint);
      x += dashWidth + gapWidth;
    }

    // Arrow head.
    final headPath = Path()
      ..moveTo(size.width - 8, midY - 4)
      ..lineTo(size.width, midY)
      ..lineTo(size.width - 8, midY + 4);
    canvas.drawPath(
      headPath,
      Paint()
        ..color = accent.withValues(alpha: 0.55)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Three shimmer dots, evenly phased.
    const dotCount = 3;
    final trackWidth = size.width - 6;
    for (var i = 0; i < dotCount; i++) {
      final offset = (progress + i / dotCount) % 1.0;
      final cx = offset * trackWidth;
      // Fade in/out near the edges so the dot doesn't pop.
      double opacity;
      if (offset < 0.12) {
        opacity = offset / 0.12;
      } else if (offset > 0.88) {
        opacity = (1 - offset) / 0.12;
      } else {
        opacity = 1.0;
      }
      final dotPaint = Paint()
        ..color = accent.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, midY), 2.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ShimmerArrowPainter old) =>
      old.progress != progress || old.accent != accent;
}

class _StaticArrowPainter extends CustomPainter {
  _StaticArrowPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final paint = Paint()
      ..color = accent
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(Offset(0, midY), Offset(size.width - 4, midY), paint);
    final headPath = Path()
      ..moveTo(size.width - 8, midY - 4)
      ..lineTo(size.width, midY)
      ..lineTo(size.width - 8, midY + 4);
    canvas.drawPath(headPath, paint);
  }

  @override
  bool shouldRepaint(covariant _StaticArrowPainter old) => old.accent != accent;
}
