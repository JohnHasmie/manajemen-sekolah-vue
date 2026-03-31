// Reusable section header widget for the teacher detail screen.
// Like a Vue component `<SectionHeader>` with a left-border accent and an icon.
// Extracted from TeacherDetailScreen to keep the screen lean and focused.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A section title bar with a blue left border and an icon.
///
/// Used to separate named sections (e.g. "Informasi Pribadi") inside teacher
/// detail cards. Uses the app-wide [ColorUtils.corporateBlue600] constant —
/// no state needed, making this a plain [StatelessWidget].
class TeacherSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const TeacherSectionHeader({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border(
          left: BorderSide(color: ColorUtils.corporateBlue600, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ColorUtils.corporateBlue600),
          SizedBox(width: AppSpacing.sm),
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
