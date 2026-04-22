// Circular icon button used for edit / delete actions on subject cards.
// Self-contained — receives icon, color, and onPressed callback from parent.
// Extracted from admin_subject_management_screen.dart to keep cards readable.
import 'package:flutter/material.dart';

/// A small circular button with a subtle border and shadow.
///
/// Like a Vue `<CircleActionButton>` component — purely presentational.
/// The [color] controls both the border tint and the icon color.
class SubjectCircleActionButton extends StatelessWidget {
  /// Icon to render inside the circle.
  final IconData icon;

  /// Accent color for the icon, border, and shadow.
  final Color color;

  /// Called when the user taps the button.
  final VoidCallback onPressed;

  const SubjectCircleActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
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
