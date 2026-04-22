// Small info badge with an icon + label.
// Like a Vue `<InfoTag icon="..." text="..." />` presentational component.
//
// Extracted from `_buildInfoTag` in `teacher_grade_recap_screen.dart`.
// Stateless and dependency-free — accepts only primitive props.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A compact pill-shaped tag that shows an [icon] and a [text] label.
///
/// Used in class and subject cards to display metadata (e.g. grade level,
/// homeroom teacher, subject code).  Equivalent to a badge/chip in HTML.
class GradeRecapInfoTag extends StatelessWidget {
  /// The icon displayed on the left side of the tag.
  final IconData icon;

  /// The text label displayed next to the icon.
  final String text;

  const GradeRecapInfoTag({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: ColorUtils.slate600),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: ColorUtils.slate700,
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
