// Reusable styled text field used inside finance dialogs (e.g. manual payment form).
// Like a Vue component `<FinanceDialogTextField />` that wraps a TextField with
// consistent border, background, and prefix icon styling for finance-related dialogs.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A styled [TextField] wrapper for use inside finance dialogs.
///
/// Renders a rounded, slate-tinted text field with a leading icon — like a
/// reusable `<input-field>` Vue component scoped to finance dialogs.
///
/// [primaryColor] replaces the parent's `_getPrimaryColor()` call.
/// [onTap] makes the field read-only and opens a custom picker (e.g. date picker).
class FinanceDialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final TextInputType keyboardType;
  final VoidCallback? onTap;
  final Color primaryColor;

  const FinanceDialogTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.primaryColor,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.onTap,
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
        keyboardType: keyboardType,
        onTap: onTap,
        readOnly: onTap != null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: primaryColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}
