// ActivityTypeOptionTile — a single tappable option card shown in the
// "Select Activity Type" bottom sheet (Tugas / Materi).
//
// Extracted from `ClassActivityScreenState._buildActivityTypeOption`.
// Think of this like a Vue `<ActivityTypeOption :icon :title :description :color @tap />`.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A tappable card that represents one activity type (e.g. "Tugas" or "Materi").
///
/// Constructor params replace every state reference from the original
/// `_buildActivityTypeOption` method — like Vue props:
/// - [icon]        — leading icon for the tile
/// - [title]       — bold heading text
/// - [description] — secondary subtitle text
/// - [color]       — accent colour (border, background tint, arrow)
/// - [onTap]       — callback fired when the tile is tapped
class ActivityTypeOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const ActivityTypeOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Leading icon container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: AppSpacing.lg),
            // Title + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.slate900,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
                  ),
                ],
              ),
            ),
            // Trailing arrow
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
