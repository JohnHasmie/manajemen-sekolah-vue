// Extracted from parent_attendance_screen.dart (_buildStatItem).
// Like a Vue `<StatItem>` component -- a small circle-count + label used
// in the monthly summary row (hadir, terlambat, izin, sakit, alpha).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A single attendance-stat column: a colored circle showing [count] and
/// a small [label] below it.
///
/// Parameters (like Vue props):
/// - [label] -- translated status label (e.g. "Hadir", "Present")
/// - [count] -- numeric count for the period
/// - [color] -- status accent color passed from parent
class ParentAttendanceStatItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const ParentAttendanceStatItem({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: ColorUtils.slate500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
