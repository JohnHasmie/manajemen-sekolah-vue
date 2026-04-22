// Labeled form field components with consistent styling.
//
// Replaces repeated Column(children: [Text(label), SizedBox, TextField/Dropdown])
// patterns across 8+ form dialogs and sheets.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A labeled form field wrapper with title, optional required marker,
/// and child input widget.
///
/// Example:
/// ```dart
/// FormFieldSection(
///   label: 'Teacher Name',
///   isRequired: true,
///   child: TextField(controller: _nameController),
/// )
/// ```
class FormFieldSection extends StatelessWidget {
  /// The field label displayed above the input.
  final String label;

  /// Whether to show a red asterisk (*) after the label.
  final bool isRequired;

  /// The input widget (TextField, Dropdown, DatePicker, etc.).
  final Widget child;

  /// Optional helper text displayed below the input.
  final String? helperText;

  /// Optional error text displayed below the input in red.
  final String? errorText;

  /// Padding below the section for spacing between fields.
  final EdgeInsets padding;

  const FormFieldSection({
    super.key,
    required this.label,
    required this.child,
    this.isRequired = false,
    this.helperText,
    this.errorText,
    this.padding = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              if (isRequired)
                const Text(
                  ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Input
          child,

          // Helper text
          if (helperText != null) ...[
            const SizedBox(height: 4),
            Text(
              helperText!,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],

          // Error text
          if (errorText != null) ...[
            const SizedBox(height: 4),
            Text(
              errorText!,
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

/// A pre-built dropdown form field with consistent styling.
///
/// Example:
/// ```dart
/// FormDropdownField<String>(
///   label: 'Class',
///   isRequired: true,
///   value: _selectedClassId,
///   items: classes.map((c) => DropdownMenuItem(
///     value: c['id'],
///     child: Text(c['name']),
///   )).toList(),
///   onChanged: (v) => setState(() => _selectedClassId = v),
///   hintText: 'Select class...',
/// )
/// ```
class FormDropdownField<T> extends StatelessWidget {
  /// The field label.
  final String label;

  /// Whether the field is required.
  final bool isRequired;

  /// Current selected value.
  final T? value;

  /// Dropdown menu items.
  final List<DropdownMenuItem<T>> items;

  /// Called when the selection changes.
  final ValueChanged<T?> onChanged;

  /// Placeholder text when no value is selected.
  final String? hintText;

  /// Optional helper text.
  final String? helperText;

  /// Optional error text.
  final String? errorText;

  /// Whether the dropdown is enabled. Default: true.
  final bool enabled;

  /// Whether the dropdown is currently loading data. Default: false.
  final bool isLoading;

  const FormDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isRequired = false,
    this.hintText,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return FormFieldSection(
      label: label,
      isRequired: isRequired,
      helperText: helperText,
      errorText: errorText,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
          color: enabled ? Colors.white : Colors.grey.shade50,
        ),
        child: isLoading
            ? Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.grey.shade400,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              )
            : DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: value,
                  items: items,
                  onChanged: enabled ? onChanged : null,
                  isExpanded: true,
                  hint: hintText != null
                      ? Text(
                          hintText!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
                        )
                      : null,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade900),
                  borderRadius: BorderRadius.circular(10),
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
      ),
    );
  }
}

/// A pre-built text form field with consistent styling.
///
/// Example:
/// ```dart
/// FormTextField(
///   label: 'Description',
///   controller: _descController,
///   hintText: 'Enter description...',
///   maxLines: 3,
/// )
/// ```
class FormTextField extends StatelessWidget {
  /// The field label.
  final String label;

  /// Whether the field is required.
  final bool isRequired;

  /// Text editing controller.
  final TextEditingController controller;

  /// Placeholder text.
  final String? hintText;

  /// Maximum number of lines. Default: 1.
  final int? maxLines;

  /// Keyboard type. Default: text.
  final TextInputType? keyboardType;

  /// Validation function.
  final String? Function(String?)? validator;

  /// Optional helper text.
  final String? helperText;

  /// Optional error text.
  final String? errorText;

  /// Whether the field is enabled. Default: true.
  final bool enabled;

  /// Optional prefix icon.
  final IconData? prefixIcon;

  /// Optional suffix widget.
  final Widget? suffix;

  /// Called when the value changes.
  final ValueChanged<String>? onChanged;

  const FormTextField({
    super.key,
    required this.label,
    required this.controller,
    this.isRequired = false,
    this.hintText,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.prefixIcon,
    this.suffix,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FormFieldSection(
      label: label,
      isRequired: isRequired,
      helperText: helperText,
      errorText: errorText,
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        enabled: enabled,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade900),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 20, color: Colors.grey.shade500)
              : null,
          suffixIcon: suffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: Theme.of(context).primaryColor,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          filled: !enabled,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }
}
