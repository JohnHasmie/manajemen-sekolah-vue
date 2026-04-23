// StudentDialogTextField widget — a styled text field for student create/edit dialogs.
//
// Like a Vue `<FormInput>` component. Extracted from _buildDialogTextField
// in AdminStudentManagementScreen so the dialog form fields can be reused
// independently and tested without the full screen.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A rounded, icon-prefixed text field used inside the student create/edit dialog.
///
/// All mutable state (the [TextEditingController]) is passed in from the caller,
/// keeping this widget purely presentational — like a Vue "dumb component".
class StudentDialogTextField extends StatelessWidget {
  /// Controls the text being edited.
  final TextEditingController controller;

  /// Label text shown as the floating hint.
  final String label;

  /// Leading icon.
  final IconData icon;

  /// Keyboard type for the field (e.g. [TextInputType.number]).
  final TextInputType? keyboardType;

  /// Number of lines (1 = single-line, >1 = multiline e.g. address).
  final int maxLines;

  /// Optional placeholder text shown when the field is empty.
  final String? hintText;

  /// Optional tap callback — used for date-picker fields (readOnly + onTap).
  final VoidCallback? onTap;

  /// When true the keyboard is suppressed and [onTap] handles input.
  final bool readOnly;

  /// Accent color for the focused border and prefix icon.
  final Color primaryColor;

  const StudentDialogTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.primaryColor,
    this.keyboardType,
    this.maxLines = 1,
    this.hintText,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          hintText: hintText,
          hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
          prefixIcon: Icon(icon, color: primaryColor, size: 18),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        keyboardType: keyboardType,
        maxLines: maxLines,
        onTap: onTap,
        readOnly: readOnly,
      ),
    );
  }
}
