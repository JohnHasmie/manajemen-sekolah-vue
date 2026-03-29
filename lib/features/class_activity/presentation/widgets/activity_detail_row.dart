// ActivityDetailRow — a single labelled row inside the activity detail dialog.
//
// Extracted from `ParentClassActivityScreenState._buildDetailRow`.
// Like a Vue `<DetailRow :icon="..." :label="..." :value="..." />` component.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// One metadata row inside [ActivityDetailDialog] (or any detail sheet).
///
/// Renders a coloured icon box on the left and a label+value column on the right.
/// Mirrors the `<DetailRow>` pattern common in Laravel Blade detail cards.
///
/// Props (constructor params — like Vue props):
/// - [icon]         — leading [IconData]
/// - [label]        — small caption above the value (e.g. "Teacher", "Date")
/// - [value]        — main value text
/// - [iconColor]    — overrides the default [primaryColor] for the icon box;
///                    useful for danger/warning rows such as a deadline
/// - [primaryColor] — base theme colour used when [iconColor] is null
class ActivityDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final Color primaryColor;

  const ActivityDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.primaryColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = iconColor ?? primaryColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: c),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
