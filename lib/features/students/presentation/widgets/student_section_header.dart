// Reusable section header widget for the student detail screen.
// Like a Vue component `<SectionHeader>` with a left-border accent and an icon.
// Extracted from StudentDetailScreen to keep the screen lean and focused.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A section title bar with a coloured left border and an icon.
///
/// Used to separate named sections (e.g. "Personal Information") inside
/// student detail cards. Receives [primaryColor] as a prop so it stays
/// stateless — same pattern as a Vue functional component with `:color` prop.
class StudentSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color primaryColor;

  const StudentSectionHeader({
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
