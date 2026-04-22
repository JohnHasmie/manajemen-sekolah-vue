import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_form_dialog.dart';

/// Handles UI building and styling for teacher form
mixin TeacherFormUiMixin on ConsumerState<TeacherFormDialog> {
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [getPrimaryColor(), getPrimaryColor().withValues(alpha: 0.7)],
    );
  }

  Widget buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextField(
        controller: controller,
        decoration: _buildTextFieldDecoration(label, icon),
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        keyboardType: keyboardType,
      ),
    );
  }

  InputDecoration _buildTextFieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
      prefixIcon: Icon(icon, color: ColorUtils.corporateBlue600, size: 18),
      border: InputBorder.none,
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: ColorUtils.corporateBlue600, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget buildDialogDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: _buildDropdownDecoration(label, icon),
        items: items,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        dropdownColor: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: ColorUtils.slate500,
        ),
      ),
    );
  }

  InputDecoration _buildDropdownDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
      prefixIcon: Icon(icon, color: ColorUtils.corporateBlue600, size: 18),
      border: InputBorder.none,
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: ColorUtils.corporateBlue600, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}
