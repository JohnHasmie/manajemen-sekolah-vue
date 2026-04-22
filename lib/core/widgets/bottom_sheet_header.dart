// Gradient header bar for modal bottom sheets.
//
// Replaces 20+ identical gradient-header patterns that include:
//   icon-in-rounded-box + title + subtitle + close button
// across feature-specific bottom sheets.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/drag_handle.dart';

/// A gradient header for modal bottom sheets with an icon, title,
/// optional subtitle, and a close button.
///
/// Includes a [DragHandle.onGradient] at the top by default.
///
/// Example:
/// ```dart
/// BottomSheetHeader(
///   title: 'Filter Attendance',
///   subtitle: 'Narrow down your results',
///   icon: Icons.filter_list,
///   primaryColor: Colors.blue,
/// )
/// ```
class BottomSheetHeader extends StatelessWidget {
  /// Title displayed in the header.
  final String title;

  /// Optional subtitle displayed below the title.
  final String? subtitle;

  /// Leading icon.
  final IconData icon;

  /// Gradient base color.
  final Color primaryColor;

  /// Border radius for the top corners. Defaults to 24.
  final double borderRadius;

  /// Whether to show the drag handle above the header.
  final bool showDragHandle;

  /// Optional trailing widget instead of the default close button.
  /// Useful for adding a "Reset" text button, for example.
  final Widget? trailing;

  /// Called when the close button is tapped.
  /// Defaults to `Navigator.pop(context)` if not provided.
  final VoidCallback? onClose;

  const BottomSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.primaryColor,
    this.borderRadius = 24,
    this.showDragHandle = true,
    this.trailing,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
      decoration: _headerDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle) const DragHandle.onGradient(),
          _contentRow(context),
        ],
      ),
    );
  }

  BoxDecoration _headerDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
      ),
      borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
      boxShadow: [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _contentRow(BuildContext context) {
    return Row(
      children: [
        _IconBox(icon: icon),
        const SizedBox(width: 14),
        Expanded(
          child: _TitleColumn(title: title, subtitle: subtitle),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ] else
          _CloseButton(onClose: onClose ?? () => Navigator.pop(context)),
      ],
    );
  }
}

/// Icon inside a semi-transparent rounded box.
class _IconBox extends StatelessWidget {
  final IconData icon;

  const _IconBox({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

/// Title + optional subtitle column.
class _TitleColumn extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _TitleColumn({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }
}

/// Close button with semi-transparent circle background.
class _CloseButton extends StatelessWidget {
  final VoidCallback onClose;

  const _CloseButton({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onClose,
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 18),
      ),
    );
  }
}
