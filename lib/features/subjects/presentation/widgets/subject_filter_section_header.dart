// Section header used inside the subject filter bottom sheet.
// Shows a small icon + bold label that groups filter options visually.
// Extracted from admin_subject_management_screen.dart to slim down the screen.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A small heading row that labels a group of filter options in the subject
/// filter sheet.
///
/// Like a Vue `<FilterSectionHeader>` component — purely presentational.
/// Receives a [title] string and an [icon] and renders them together with
/// consistent spacing and typography.
class SubjectFilterSectionHeader extends StatelessWidget {
  /// The label text for this filter group (e.g. "Status", "Grade Level").
  final String title;

  /// The leading icon that represents the filter group.
  final IconData icon;

  const SubjectFilterSectionHeader({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ColorUtils.slate600),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate800,
            ),
          ),
        ],
      ),
    );
  }
}
