import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Validation mixin for student form data.
///
/// Provides methods to validate form inputs and display error messages.
mixin StudentFormValidationMixin {
  late final TextEditingController nameController;
  late final TextEditingController nisController;
  late final TextEditingController addressController;
  late final TextEditingController birthDateController;
  late final TextEditingController parentNameController;
  late final TextEditingController phoneController;
  late final TextEditingController emailParentController;

  String? selectedClassId;
  String? selectedGender;

  /// Translation helper — must be implemented by consuming class.
  String t(Map<String, String> translations);

  /// Access to BuildContext — must be implemented by consuming class.
  BuildContext get buildContext;

  /// Validate form and show error if invalid.
  ///
  /// Returns true if all required fields are valid, false otherwise.
  bool validateAndShowError() {
    final name = nameController.text.trim();
    final nis = nisController.text.trim();
    final address = addressController.text.trim();
    final birthDate = birthDateController.text.trim();
    final nameParent = parentNameController.text.trim();
    final noPhone = phoneController.text.trim();
    final emailParent = emailParentController.text.trim();

    if (name.isEmpty ||
        nis.isEmpty ||
        selectedClassId == null ||
        address.isEmpty ||
        birthDate.isEmpty ||
        selectedGender == null ||
        nameParent.isEmpty ||
        noPhone.isEmpty) {
      ScaffoldMessenger.of(buildContext).showSnackBar(
        SnackBar(
          content: Text(
            t({
              'en': 'All fields must be filled',
              'id': 'Semua field harus diisi',
            }),
          ),
          backgroundColor: ColorUtils.warning600,
        ),
      );
      return false;
    }

    if (emailParent.isNotEmpty &&
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailParent)) {
      ScaffoldMessenger.of(buildContext).showSnackBar(
        SnackBar(
          content: Text(
            t({'en': 'Invalid email format', 'id': 'Format email tidak valid'}),
          ),
          backgroundColor: ColorUtils.warning600,
        ),
      );
      return false;
    }

    return true;
  }
}
