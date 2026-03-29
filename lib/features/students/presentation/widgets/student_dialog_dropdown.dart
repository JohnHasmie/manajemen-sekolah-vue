// StudentDialogDropdown widget — a styled dropdown for student create/edit dialogs.
//
// Like a Vue `<FormSelect>` component. Extracted from _buildDialogDropdown
// in AdminStudentManagementScreen so the dialog form dropdowns (class, gender)
// can be reused and tested without the full screen.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A rounded, icon-prefixed dropdown form field used in the student create/edit dialog.
///
/// The [onChanged] callback is called when the user picks a new item,
/// keeping this widget purely presentational — the caller owns state.
class StudentDialogDropdown extends StatelessWidget {
  /// Currently selected value (may be null if nothing is selected yet).
  final String? value;

  /// Label text shown as the floating hint.
  final String label;

  /// Leading icon.
  final IconData icon;

  /// Dropdown options.
  final List<DropdownMenuItem<String>> items;

  /// Called when the user selects a new item; pass null to clear the selection.
  final void Function(String?) onChanged;

  /// Accent color for the focused border and prefix icon.
  final Color primaryColor;

  const StudentDialogDropdown({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.items,
    required this.onChanged,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(icon, color: primaryColor, size: 18),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: items,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: ColorUtils.slate500,
        ),
      ),
    );
  }
}
