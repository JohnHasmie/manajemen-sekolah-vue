// Horizontal scrollable row of active filter chips with remove buttons.
//
// Replaces 8+ identical `_buildFilterChips()` / `_buildFilterTag()` methods
// across teacher and admin screens.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Data model for a single active filter chip.
class ActiveFilter {
  /// Display text (e.g., "Semester: 1", "Monday", "Class 10A").
  final String label;

  /// Called when the user taps the remove (×) button on this chip.
  final VoidCallback onRemove;

  /// Optional chip accent color. Defaults to primaryColor.
  final Color? color;

  /// Optional leading icon.
  final IconData? icon;

  const ActiveFilter({
    required this.label,
    required this.onRemove,
    this.color,
    this.icon,
  });
}

/// A horizontal scrollable row of dismissible filter chips.
///
/// Shows active filters as small colored chips with a close button.
/// Optionally includes a "Clear all" action at the end.
///
/// Example:
/// ```dart
/// ActiveFilterChips(
///   filters: [
///     ActiveFilter(label: 'Monday', onRemove: () => _removeDay('monday')),
///     ActiveFilter(label: 'Class 10A', onRemove: () => _removeClass()),
///   ],
///   primaryColor: primaryColor,
///   onClearAll: _clearAllFilters,
/// )
/// ```
class ActiveFilterChips extends StatelessWidget {
  /// The list of currently active filters to display.
  final List<ActiveFilter> filters;

  /// The accent color for chip backgrounds and text.
  final Color? primaryColor;

  /// Called when the user taps "Clear all".
  final VoidCallback? onClearAll;

  /// Label for the clear-all button.
  final String clearAllLabel;

  /// Optional leading icon before the filter chips.
  final IconData? leadingIcon;

  /// Padding around the entire row.
  final EdgeInsets padding;

  /// Use white-on-transparent style for rendering
  /// inside gradient headers. Default: false.
  final bool transparentStyle;

  const ActiveFilterChips({
    super.key,
    required this.filters,
    this.primaryColor,
    this.onClearAll,
    this.clearAllLabel = 'Hapus',
    this.leadingIcon = Icons.filter_alt_outlined,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.transparentStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filters.isEmpty) return const SizedBox.shrink();

    final color = primaryColor ?? ColorUtils.getRoleColor('guru');

    return Container(
      padding: padding,
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            Icon(
              leadingIcon,
              size: 14,
              color: transparentStyle
                  ? Colors.white.withValues(alpha: 0.9)
                  : color,
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters.map((filter) {
                  return _FilterChip(
                    label: filter.label,
                    onRemove: filter.onRemove,
                    color: filter.color ?? color,
                    icon: filter.icon,
                    transparentStyle: transparentStyle,
                  );
                }).toList(),
              ),
            ),
          ),
          if (onClearAll != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClearAll,
              child: Text(
                clearAllLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: transparentStyle ? Colors.white : ColorUtils.error600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A single dismissible filter chip with label and
/// close button.
class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  final Color color;
  final IconData? icon;
  final bool transparentStyle;

  const _FilterChip({
    required this.label,
    required this.onRemove,
    required this.color,
    this.icon,
    this.transparentStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = transparentStyle ? Colors.white : color;
    final bgColor = transparentStyle
        ? Colors.white.withValues(alpha: 0.2)
        : color.withValues(alpha: 0.08);

    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: transparentStyle
            ? Border.all(color: Colors.white.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 12, color: textColor),
          ),
        ],
      ),
    );
  }
}
