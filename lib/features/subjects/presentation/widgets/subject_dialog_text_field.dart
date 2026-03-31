// Styled text field used inside the Add / Edit subject bottom sheet.
// Wraps a plain TextField in a rounded container that matches the app design.
// Extracted from admin_subject_management_screen.dart for reuse in dialogs.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A consistently-styled text input for the subject form dialog.
///
/// Like a Vue `<FormTextField>` — pure props in, no state emitted back.
/// Supports multi-line mode, optional [focusNode], and an optional
/// trailing [suffixIcon] (used for the autocomplete clear button).
class SubjectDialogTextField extends StatelessWidget {
  /// Controls the text being edited.
  final TextEditingController controller;

  /// Label shown inside the field (floats up when focused).
  final String label;

  /// Icon displayed as a leading prefix inside the field.
  final IconData icon;

  /// Number of lines allowed (1 = single-line, 3+ = multi-line).
  final int maxLines;

  /// Optional focus node for programmatic focus control.
  final FocusNode? focusNode;

  /// Optional widget appended to the right side of the field.
  final Widget? suffixIcon;

  const SubjectDialogTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.focusNode,
    this.suffixIcon,
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
        focusNode: focusNode,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 14),
          prefixIcon: Icon(
            icon,
            color: ColorUtils.corporateBlue600,
            size: 20,
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(
              color: ColorUtils.corporateBlue600,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}
