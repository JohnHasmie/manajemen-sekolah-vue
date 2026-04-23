// TeacherInfoTag — small icon+text label used inside teacher list cards.
// Shows a single piece of metadata (e.g. email, homeroom class) with a slate border.
// Extracted from TeacherAdminScreen._buildInfoTag (admin_teacher_management_screen.dart).

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A compact pill-shaped tag that pairs an [icon] with a [text] value.
///
/// Think of it like a small Badge component in Vue — read-only display only.
/// Used in [TeacherCard] to show email, class name, etc.
class TeacherInfoTag extends StatelessWidget {
  /// The icon shown on the left of the tag.
  final IconData icon;

  /// The label text shown next to the icon.
  final String text;

  const TeacherInfoTag({super.key, required this.icon, required this.text});

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
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: ColorUtils.slate700,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
