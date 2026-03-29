// AdminActivityDetailItem — a single labelled row used inside the admin
// activity detail dialog (icon + label + value, like a form field in read mode).
//
// Extracted from `AdminClassActivityScreenState._buildDetailItem`.
// Think of this like a Vue `<DetailItem :icon :label :value />` — a small,
// purely presentational component with no state.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// One labelled detail row inside the admin activity detail dialog.
///
/// Constructor params (Vue-style props):
/// - [icon]         — leading icon placed in a tinted square badge
/// - [label]        — small caption above the value (e.g. "Hari", "Tanggal")
/// - [value]        — the actual data string displayed below the label
/// - [primaryColor] — colour used for the icon badge background and icon tint
class AdminActivityDetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  /// Theme colour passed in from the parent so this widget is fully stateless.
  /// In the admin screen this is always [ColorUtils.getRoleColor('admin')].
  final Color primaryColor;

  const AdminActivityDetailItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tinted icon badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: primaryColor),
          ),
          SizedBox(width: AppSpacing.md),
          // Label + value stacked vertically
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
                    color: ColorUtils.slate800,
                    fontWeight: FontWeight.w600,
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
