// Small icon button for toggling between view modes.
//
// Replaces duplicated GestureDetector + Icon patterns for card/table/
// timeline/list/grid view toggles across 6+ screens.
import 'package:flutter/material.dart';

/// Available view modes with associated icons and labels.
enum ViewMode {
  card(icon: Icons.view_agenda_outlined, label: 'Card'),
  table(icon: Icons.table_chart_outlined, label: 'Table'),
  timeline(icon: Icons.view_list_rounded, label: 'Timeline'),
  list(icon: Icons.list_outlined, label: 'List'),
  grid(icon: Icons.grid_view_rounded, label: 'Grid');

  final IconData icon;
  final String label;
  const ViewMode({required this.icon, required this.label});
}

/// A compact icon button that cycles through view modes on tap.
///
/// Designed for use inside gradient headers (shows the icon for the
/// *next* mode so users know what they'll switch to).
///
/// Example:
/// ```dart
/// ViewToggleButton(
///   currentMode: _isTableView ? ViewMode.table : ViewMode.card,
///   onChanged: (mode) =>
///       setState(() => _isTableView = mode == ViewMode.table),
///   availableModes: [ViewMode.card, ViewMode.table],
/// )
/// ```
class ViewToggleButton extends StatelessWidget {
  /// The currently active view mode.
  final ViewMode currentMode;

  /// Called with the new mode when the button is tapped.
  final ValueChanged<ViewMode> onChanged;

  /// Which modes to cycle through. Must have at least 2 entries.
  final List<ViewMode> availableModes;

  /// Icon color. Default: white (for use in gradient headers).
  final Color? iconColor;

  /// Background color. Default: semi-transparent white.
  final Color? backgroundColor;

  /// Icon size. Default: 18.
  final double iconSize;

  /// Button size. Default: 36×36.
  final double buttonSize;

  const ViewToggleButton({
    super.key,
    required this.currentMode,
    required this.onChanged,
    required this.availableModes,
    this.iconColor,
    this.backgroundColor,
    this.iconSize = 18,
    this.buttonSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    // Find the next mode in the cycle
    final currentIndex = availableModes.indexOf(currentMode);
    final nextIndex = (currentIndex + 1) % availableModes.length;
    final nextMode = availableModes[nextIndex];

    return GestureDetector(
      onTap: () => onChanged(nextMode),
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          // Match BrandHeaderIconButton's 18 % white tint so all
          // header action icons render at the same visual weight.
          color: backgroundColor ?? Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          nextMode.icon,
          color: iconColor ?? Colors.white,
          size: iconSize,
        ),
      ),
    );
  }
}
