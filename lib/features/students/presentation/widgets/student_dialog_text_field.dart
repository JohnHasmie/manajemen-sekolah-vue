// StudentDialogTextField widget — a styled text field for student create/edit dialogs.
//
// Like a Vue `<FormInput>` component. Extracted from _buildDialogTextField
// in AdminStudentManagementScreen so the dialog form fields can be reused
// independently and tested without the full screen.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A rounded, icon-prefixed text field used inside the student create/edit dialog.
///
/// All mutable state (the [TextEditingController]) is passed in from the
/// caller,
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

  /// Optional inline error text rendered beneath the field (and a
  /// red border + red prefix-icon variant while present). Pass null
  /// when there's no error.
  final String? errorText;

  /// Called whenever the text changes — used by the parent form to
  /// clear a stale [errorText] as soon as the user edits the value.
  final ValueChanged<String>? onChanged;

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
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    final accent = hasError ? ColorUtils.error600 : primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(
              color: hasError ? ColorUtils.error600 : ColorUtils.slate200,
              width: hasError ? 1.2 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
              hintText: hintText,
              hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
              prefixIcon: Icon(icon, color: accent, size: 18),
              border: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: accent, width: 1.5),
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
            onChanged: onChanged,
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(
              errorText!,
              style: TextStyle(
                fontSize: 11.5,
                color: ColorUtils.error600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
