// ActivityInfoTag — a small coloured badge showing an icon + label.
//
// Extracted from `ClassActivityScreenState._buildActivityInfoTag`.
// Think of this like a Vue `<InfoTag :icon="..." :label="..." :color="..." />`
// component — a pure presentational widget with no state of its own.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A compact tag used inside activity cards to surface key metadata
/// (date, type, target audience, deadline) with an icon and a text label.
///
/// Parameters (Vue-style props):
/// - [icon]     — leading icon
/// - [label]    — text shown next to the icon
/// - [tagColor] — when provided the tag uses a tinted background/border;
///                when null the neutral slate palette is used
class ActivityInfoTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? tagColor;

  const ActivityInfoTag({
    super.key,
    required this.icon,
    required this.label,
    this.tagColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = tagColor ?? ColorUtils.slate600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tagColor != null
            ? tagColor!.withValues(alpha: 0.08)
            : ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: Border.all(
          color: tagColor != null
              ? tagColor!.withValues(alpha: 0.3)
              : ColorUtils.slate200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: c),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: c,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
