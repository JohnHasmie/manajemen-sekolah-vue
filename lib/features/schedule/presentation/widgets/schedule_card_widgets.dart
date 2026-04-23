// Small reusable widgets extracted from AdminScheduleManagementScreen.
//
// Think of these like Blade components in Laravel - tiny, self-contained pieces
// that take only plain data props and produce UI. No state, no providers.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Section header used inside filter bottom sheets.
///
/// Renders a row with a leading [icon] and a bold [title] text, with top/bottom
/// padding so filter sections feel visually grouped.
class ScheduleFilterSectionHeader extends StatelessWidget {
  const ScheduleFilterSectionHeader({
    super.key,
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ColorUtils.slate700),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact pill-shaped tag used inside schedule cards to display metadata
/// (class name, day, time, etc.).
///
/// Pass an [icon] and a short [text] label. The widget clips long text to one
/// line with an ellipsis so card rows stay tidy.
class ScheduleInfoTag extends StatelessWidget {
  const ScheduleInfoTag({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ColorUtils.slate600),
          const SizedBox(width: AppSpacing.xs),
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

/// Small circular icon button used for edit / delete actions on schedule cards.
///
/// Like a Laravel named route button - the caller supplies the [icon], accent
/// [color], and [onPressed] callback; the button handles all the styling itself.
class ScheduleCircleActionButton extends StatelessWidget {
  const ScheduleCircleActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
