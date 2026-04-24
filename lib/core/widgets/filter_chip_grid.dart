// A Wrap of selectable FilterChips for single or multi-select options.
//
// Used inside FilterBottomSheet for each filter category (days, classes,
// semesters, statuses, etc.). Replaces 15+ identical FilterChip Wrap
// patterns across filter sheet files.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Data model for a single selectable filter option.
class FilterOption<T> {
  /// The underlying value used for identification and callbacks.
  final T value;

  /// Display text shown on the chip.
  final String label;

  /// Optional badge count shown after the label.
  final int? count;

  /// Optional leading icon.
  final IconData? icon;

  const FilterOption({
    required this.value,
    required this.label,
    this.count,
    this.icon,
  });
}

/// A wrapped grid of selectable filter chips.
///
/// Supports both single-select and multi-select modes.
/// Includes an optional section title above the chips.
///
/// Example (single select):
/// ```dart
/// FilterChipGrid<String>(
///   title: 'Semester',
///   options: [
///     FilterOption(value: '1', label: 'Semester 1'),
///     FilterOption(value: '2', label: 'Semester 2'),
///   ],
///   selectedValue: _selectedSemester,
///   onSelected: (value) => setState(() => _selectedSemester = value),
///   selectedColor: primaryColor,
/// )
/// ```
///
/// Example (multi select):
/// ```dart
/// FilterChipGrid<String>(
///   title: 'Days',
///   options: dayOptions,
///   selectedValues: _selectedDays,
///   onMultiSelected: (values) => setState(() => _selectedDays = values),
///   multiSelect: true,
///   selectedColor: primaryColor,
/// )
/// ```
class FilterChipGrid<T> extends StatelessWidget {
  /// Optional section title above the chips.
  final String? title;

  /// Available options to display as chips.
  final List<FilterOption<T>> options;

  /// Currently selected value (single-select mode).
  final T? selectedValue;

  /// Currently selected values (multi-select mode).
  final Set<T>? selectedValues;

  /// Called when a chip is selected/deselected in single-select mode.
  final ValueChanged<T?>? onSelected;

  /// Called with the updated set when chips change in multi-select mode.
  final ValueChanged<Set<T>>? onMultiSelected;

  /// Accent color for selected chips.
  final Color? selectedColor;

  /// Whether multiple chips can be selected. Default: false.
  final bool multiSelect;

  /// Spacing between chips.
  final double spacing;

  /// Run spacing between chip rows.
  final double runSpacing;

  const FilterChipGrid({
    super.key,
    this.title,
    required this.options,
    this.selectedValue,
    this.selectedValues,
    this.onSelected,
    this.onMultiSelected,
    this.selectedColor,
    this.multiSelect = false,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  bool _isSelected(T value) {
    if (multiSelect) {
      return selectedValues?.contains(value) ?? false;
    }
    return selectedValue == value;
  }

  void _handleTap(T value) {
    if (multiSelect) {
      final current = Set<T>.from(selectedValues ?? <T>{});
      if (current.contains(value)) {
        current.remove(value);
      } else {
        current.add(value);
      }
      onMultiSelected?.call(current);
    } else {
      // Toggle: tap again to deselect
      if (selectedValue == value) {
        onSelected?.call(null);
      } else {
        onSelected?.call(value);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate900,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: options.map((option) {
            final selected = _isSelected(option.value);

            return GestureDetector(
              onTap: () => _handleTap(option.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.1)
                      : ColorUtils.slate50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? color : ColorUtils.slate200,
                    width: selected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (option.icon != null) ...[
                      Icon(
                        option.icon,
                        size: 14,
                        color: selected ? color : ColorUtils.slate500,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected ? color : ColorUtils.slate600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (option.count != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${option.count})',
                        style: TextStyle(
                          fontSize: 11,
                          color: selected
                              ? color.withValues(alpha: 0.7)
                              : ColorUtils.slate400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
