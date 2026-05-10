// Compact tri-state action chip used in the schedule-card footer
// (Frame A · v2 redesign).
//
// Three visual states:
//
//   • outline   — slate-50 background, slate-200 border, slate-600 text.
//                 Default state when there's no data and the lesson
//                 isn't current.
//   • filled    — green-tinted (success) chip indicating the action
//                 has data attached. Used for "X/Y Hadir", "N Kegiatan",
//                 etc.
//   • cobalt    — cobalt-tinted CTA on the live row (the lesson
//                 happening right now). Pulls the teacher's eye to
//                 the next obvious action ("Ambil Presensi").
//
// All three states share the same 7×6 padding + 10dp radius so the
// row stays optically aligned even when only one chip is in the
// cobalt state.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

enum ScheduleActionState { outline, filled, cobalt }

class ScheduleCardActionButton extends StatelessWidget {
  final IconData icon;
  final String label;

  /// Resolved tri-state. Hosts call [resolveState] with their
  /// `isFilled` + `isCurrent` flags.
  final ScheduleActionState state;

  final VoidCallback onPressed;

  const ScheduleCardActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.state,
    required this.onPressed,
  });

  /// Convenience for callers that only know `isFilled` + `isCurrent`.
  /// `isCobaltCta` overrides everything; otherwise `filled` wins over
  /// `outline`.
  static ScheduleActionState resolveState({
    required bool isFilled,
    bool isCobaltCta = false,
  }) {
    if (isCobaltCta) return ScheduleActionState.cobalt;
    if (isFilled) return ScheduleActionState.filled;
    return ScheduleActionState.outline;
  }

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (state) {
      ScheduleActionState.outline => (
        ColorUtils.slate50,
        ColorUtils.slate200,
        ColorUtils.slate600,
      ),
      ScheduleActionState.filled => (
        ColorUtils.success600.withValues(alpha: 0.08),
        ColorUtils.success600.withValues(alpha: 0.30),
        ColorUtils.success600,
      ),
      ScheduleActionState.cobalt => (
        ColorUtils.brandCobalt.withValues(alpha: 0.08),
        ColorUtils.brandCobalt.withValues(alpha: 0.30),
        ColorUtils.brandCobalt,
      ),
    };

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: fg),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    letterSpacing: 0.1,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
