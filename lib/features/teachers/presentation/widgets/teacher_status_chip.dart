// TeacherStatusChip — reusable ChoiceChip used in the teacher filter bottom sheet.
// Displays a selectable chip with corporate-blue highlight when selected.
// Extracted from TeacherAdminScreen._buildStatusChip (admin_teacher_management_screen.dart).

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A single selectable chip for filter options (gender, employment status, etc.).
///
/// In Laravel/Vue terms, this is like a small v-chip component that knows
/// whether it is "active" and styles itself accordingly.
class TeacherStatusChip extends StatelessWidget {
  /// The text displayed on the chip.
  final String label;

  /// The value this chip represents (null means "All / no filter").
  final String? value;

  /// The currently selected value in the parent filter group.
  final String? selectedValue;

  /// Called when the user taps this chip.
  final VoidCallback onSelected;

  const TeacherStatusChip({
    super.key,
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedValue == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: Colors.white,
      selectedColor: ColorUtils.corporateBlue600.withValues(alpha: 0.15),
      checkmarkColor: ColorUtils.corporateBlue600,
      labelStyle: TextStyle(
        color: isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate300,
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
