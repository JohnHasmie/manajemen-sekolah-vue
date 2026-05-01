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

          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.28),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    Text(
                      yearLabel.isEmpty ? '—' : yearLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (semesterLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${semesterLabel!} ▾',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 2),
                      Text(
                        '▾',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.72),
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


