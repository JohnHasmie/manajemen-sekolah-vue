// Reusable section-header row with a coloured left-border accent.
//
// Extracted from `_buildSectionHeader` in admin_finance_screen.dart.
// Like a Vue `<SectionHeader>` component used above every list section.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A styled section header with a leading icon and a left-border accent.
///
/// Used above each logical section inside the finance dashboard tab.
/// Equivalent to `_buildSectionHeader(title, icon, color?)` in the parent screen.
class FinanceSectionHeader extends StatelessWidget {
  /// Title text shown to the right of the icon.
  final String title;

  /// Leading icon displayed in [color].
  final IconData icon;

  /// Accent colour (left border + icon tint). Falls back to the caller's
  /// primary colour when omitted.
  final Color color;

  const FinanceSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.sm),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
