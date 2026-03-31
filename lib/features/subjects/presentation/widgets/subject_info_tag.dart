// Small pill-shaped info tag used inside subject cards.
// Displays an icon + text label (e.g. "3 Classes", "7A, 7B").
// Extracted from admin_subject_management_screen.dart to keep it reusable.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A compact badge that pairs an [icon] with a [text] string.
///
/// Like a Vue `<InfoTag>` component — takes pure props, emits nothing.
/// Used in subject cards to display class count and class name lists.
class SubjectInfoTag extends StatelessWidget {
  /// The leading icon shown before [text].
  final IconData icon;

  /// The label text displayed next to the icon.
  final String text;

  const SubjectInfoTag({
    super.key,
    required this.icon,
    required this.text,
  });

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
