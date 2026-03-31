// Reusable inline tag chip for announcement cards.
// Displays a small icon + text badge — like Vue's <InfoChip> component.
// Used in AnnouncementCard to show date, target audience, and priority hints.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A compact icon+text label used inside announcement list cards.
///
/// In Laravel/Blade terms, think of this as a partial view
/// (`@include('partials.info-tag', ['icon' => ..., 'text' => ...])`)
/// that renders a coloured badge with an icon and short text.
class AnnouncementInfoTag extends StatelessWidget {
  final IconData icon;
  final String text;

  /// Optional accent colour — defaults to [ColorUtils.slate600] when null.
  final Color? tagColor;

  const AnnouncementInfoTag({
    super.key,
    required this.icon,
    required this.text,
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
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                color: c,
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
