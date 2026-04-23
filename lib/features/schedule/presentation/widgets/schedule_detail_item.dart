// Detail row widget extracted from AdminScheduleManagementScreen._buildDetailItem.
//
// Like a single <tr> in a Laravel Blade detail table - an icon badge on the left,
// then a stacked label + value on the right, with an optional bottom border
// (omitted on the last row via [isLast]).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A labeled icon-row used inside the schedule detail dialog.
///
/// [primaryColor] is the role-specific accent color (e.g. admin blue). Pass
/// `isLast: true` on the final row so the bottom divider is omitted.
class ScheduleDetailItem extends StatelessWidget {
  const ScheduleDetailItem({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.primaryColor,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color primaryColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: ColorUtils.slate100, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, size: 18, color: primaryColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
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
                    color: ColorUtils.slate900,
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
