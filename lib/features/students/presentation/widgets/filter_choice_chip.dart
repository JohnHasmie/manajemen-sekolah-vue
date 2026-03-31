// FilterChoiceChip widget — a styled ChoiceChip for filter option rows.
//
// Like a Vue `<FilterChip>` component. Extracted from the identical
// _buildStatusChip and _buildGenderChip helpers in AdminStudentManagementScreen
// so both filter sections (status and gender) share one widget.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A single selectable chip used inside filter option rows (status, gender, etc.).
///
/// Pass [primaryColor] from the screen so this stays role-agnostic.
/// The [onSelected] callback fires when the chip is tapped — no setState here;
/// the caller is responsible for updating state (same as a Vue event emit).
class FilterChoiceChip extends StatelessWidget {
  /// Display text inside the chip.
  final String label;

  /// The value this chip represents (e.g. 'active', 'M', or null for "All").
  final String? value;

  /// The currently selected value from the parent — used to compute [isSelected].
  final String? selectedValue;

  /// Called when the chip is tapped; parent should update [selectedValue].
  final VoidCallback onSelected;

  /// Accent color — typically [ColorUtils.getRoleColor('admin')].
  final Color primaryColor;

  const FilterChoiceChip({
    super.key,
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onSelected,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedValue == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: primaryColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? primaryColor : ColorUtils.slate700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? primaryColor : ColorUtils.slate300,
      ),
    );
  }
}
