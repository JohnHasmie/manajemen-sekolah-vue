// Small info tag widget for RPP (lesson plan) cards.
// Like a reusable Vue component `<InfoTag :icon="..." :label="..." />`.
// Displays an icon + text label with a colored pill background.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A small colored pill that shows an icon and a label.
///
/// Used inside [LessonPlanCard] to display metadata like class name.
/// Like a `<v-chip>` in Vue Material or a `<Badge>` in Bootstrap.
class LessonPlanInfoTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? tagColor;

  const LessonPlanInfoTag({
    super.key,
    required this.icon,
    required this.label,
    this.tagColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = tagColor ?? ColorUtils.slate500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
