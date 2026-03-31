// A small badge/chip showing a single piece of schedule metadata.
// Extracted from TeachingScheduleScreen._buildScheduleInfoTag().
//
// Like a Vue `<ScheduleInfoTag icon="..." label="..." color="..." />` component.
// Purely presentational -- no state, no side effects.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A compact icon+label badge used inside schedule cards to show metadata
/// such as time range, class name, session number, or semester.
///
/// Analogous to a Bootstrap badge `<span class="badge">` — purely visual.
class ScheduleInfoTag extends StatelessWidget {
  const ScheduleInfoTag({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  /// The leading icon, e.g. [Icons.access_time_rounded].
  final IconData icon;

  /// The text label shown beside the icon.
  final String label;

  /// Accent color used for icon, text, border and background tint.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
