// Section header widget for the class promotion wizard.
// Renders a pill-shaped header with a left accent border, icon, and title text.
// Used at the top of each wizard step's content card.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A left-bordered section header with [icon] and [title].
///
/// Like a `<section-header>` Vue component — purely display, no state.
/// [primaryColor] controls the left border and icon tint.
class PromotionSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color primaryColor;

  const PromotionSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border(left: BorderSide(color: primaryColor, width: 3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: primaryColor),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
