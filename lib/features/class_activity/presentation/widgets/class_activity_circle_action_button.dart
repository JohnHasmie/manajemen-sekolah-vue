// ClassActivityCircleActionButton — a small circular icon button for
// edit / delete actions inside activity cards.
//
// Extracted from `ClassActivityScreenState._buildCircleActionButton`.
// Like a Vue `<CircleButton :icon="..." :color="..." @click="..." />` —
// pure UI, no state.

import 'package:flutter/material.dart';

/// A 36×36 rounded icon button with a tinted background, used for
/// edit and delete actions on activity card rows.
///
/// Parameters:
/// - [icon]      — the icon to display
/// - [color]     — accent colour for background tint and icon
/// - [onPressed] — callback fired when the button is tapped
/// - [tooltip]   — optional accessibility / hover tooltip
class ClassActivityCircleActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String? tooltip;

  const ClassActivityCircleActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
