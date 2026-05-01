// Compact tahun-ajaran chip rendered next to the school pill in the
// dashboard hero. Tap → opens [AcademicYearPickerSheet] so the user
// can switch the active academic year. Active year flows through
// `academicYearRiverpod` and re-keys the rest of the dashboard via
// `dashboardProvider.notifier.reloadForYearChange()`.
//
// Visual matches Phase-4 mockup #4:
//
//   ┌────────────────────────┐
//   │ 📅 TAHUN AJARAN        │
//   │    2025/2026           │
//   │    Sem. Ganjil ▾       │
//   └────────────────────────┘
//
// Lives over the brand-azure gradient hero so all surface colours are
// translucent-white, matching the school pill it sits next to.

import 'package:flutter/material.dart';

/// Compact tahun-ajaran chip for the dashboard hero. Pass the
/// currently-active year + semester labels and an [onTap] that
/// opens [AcademicYearPickerSheet].
class AcademicYearChip extends StatelessWidget {
  /// Year string from the backend (e.g. `'2025/2026'`). Empty string
  /// shows an em-dash so the chip never renders broken.
  final String yearLabel;

  /// Optional semester sub-label (e.g. `'Sem. Ganjil'`). Pass null to
  /// omit; the chip then renders shorter.
  final String? semesterLabel;

  /// Tap handler — usually `() => showAcademicYearPickerSheet(context)`.
  final VoidCallback? onTap;

  /// Width override for the chip; default 110 fits the hero next to a
  /// shrunk school pill on narrow viewports without wrapping.
  final double width;

  const AcademicYearChip({
    super.key,
    required this.yearLabel,
    this.semesterLabel,
    this.onTap,
    this.width = 110,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: Container(
          width: width,
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.28),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mini calendar icon
              SizedBox(
                width: 22,
                height: 22,
                child: CustomPaint(painter: _CalendarIconPainter()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TAHUN AJARAN',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      yearLabel.isEmpty ? '—' : yearLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (semesterLabel != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        '${semesterLabel!} ▾',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 1),
                      Text(
                        '▾',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom mini-calendar icon — drawn rather than using
/// `Icons.calendar_today` so the stroke matches the hero typography.
class _CalendarIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fill = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 4, size.width, size.height - 4),
        const Radius.circular(3),
      ),
      paint,
    );
    // Hangers (top)
    canvas.drawRect(Rect.fromLTWH(4, 0, 2, 5), fill);
    canvas.drawRect(Rect.fromLTWH(size.width - 6, 0, 2, 5), fill);
    // Header line
    canvas.drawLine(
      Offset(0, 9),
      Offset(size.width, 9),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
