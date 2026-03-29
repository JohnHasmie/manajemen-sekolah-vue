// Extracted from parent_attendance_screen.dart (_buildInfoTag).
// Like a Vue `<InfoTag>` component -- a small pill/badge showing an icon
// and text label used in attendance item rows (date, lesson hour, status).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A compact icon+label badge used inside attendance list items.
///
/// Parameters (like Vue props):
/// - [icon]     -- the leading icon
/// - [text]     -- the label string
/// - [tagColor] -- optional accent color; defaults to [ColorUtils.slate600]
class ParentAttendanceInfoTag extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? tagColor;

  const ParentAttendanceInfoTag({
    super.key,
    required this.icon,
    required this.text,
    this.tagColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color c = tagColor ?? ColorUtils.slate600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tagColor != null
            ? tagColor!.withValues(alpha: 0.08)
            : ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: tagColor != null
              ? tagColor!.withValues(alpha: 0.3)
              : ColorUtils.slate200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: c),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: c,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
