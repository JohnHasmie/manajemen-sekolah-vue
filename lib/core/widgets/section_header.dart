// A section title row with optional trailing action button/link.
//
// Replaces repeated Row(children: [Text(title), Spacer(), TextButton(...)])
// patterns found across almost every screen.
import 'package:flutter/material.dart';

/// A section title with an optional trailing action.
///
/// Example:
/// ```dart
/// SectionHeader(
///   title: 'Recent Activity',
///   actionText: 'View All',
///   onActionTap: () => _navigateToAll(),
/// )
/// ```
class SectionHeader extends StatelessWidget {
  /// The section title text.
  final String title;

  /// Optional action text displayed as a tappable link on the right.
  final String? actionText;

  /// Called when the action text is tapped.
  final VoidCallback? onActionTap;

  /// Optional action icon shown before the action text.
  final IconData? actionIcon;

  /// Style override for the title text.
  final TextStyle? titleStyle;

  /// Color of the action text and icon.
  final Color? actionColor;

  /// Padding around the header row.
  final EdgeInsets padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onActionTap,
    this.actionIcon,
    this.titleStyle,
    this.actionColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style:
                  titleStyle ??
                  TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
            ),
          ),
          if (actionText != null || actionIcon != null)
            GestureDetector(
              onTap: onActionTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (actionIcon != null) ...[
                    Icon(
                      actionIcon,
                      size: 14,
                      color: actionColor ?? Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (actionText != null)
                    Text(
                      actionText!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: actionColor ?? Theme.of(context).primaryColor,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
