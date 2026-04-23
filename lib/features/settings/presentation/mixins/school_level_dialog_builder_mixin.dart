import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Mixin for building dialog UI widgets.
mixin SchoolLevelDialogBuilderMixin {
  BuildContext get context;

  /// Builds the gradient header section of the dialog.
  Widget buildDialogHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorUtils.corporateBlue600,
            ColorUtils.corporateBlue600.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Informasi Sekolah',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Perbarui data informasi sekolah',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the form fields section of the dialog.
  Widget buildDialogFormFields({
    required TextEditingController nameController,
    required TextEditingController addressController,
    required String tempJenjang,
    required List<String> jenjangOptions,
    required Function(String) onJenjangChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          buildNameField(nameController),
          const SizedBox(height: AppSpacing.md),
          buildAddressField(addressController),
          const SizedBox(height: AppSpacing.md),
          buildJenjangDropdown(tempJenjang, jenjangOptions, onJenjangChanged),
        ],
      ),
    );
  }

  /// Builds the name text field.
  Widget buildNameField(TextEditingController controller) {
    return TextField(
      controller: controller,
      maxLines: 1,
      decoration: buildFieldDecoration('Nama Sekolah', Icons.school_outlined),
    );
  }

  /// Builds the address text field.
  Widget buildAddressField(TextEditingController controller) {
    return TextField(
      controller: controller,
      maxLines: 2,
      decoration: buildFieldDecoration(
        'Alamat Sekolah',
        Icons.location_on_outlined,
      ),
    );
  }

  /// Builds common field decoration.
  InputDecoration buildFieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: ColorUtils.corporateBlue600, size: 20),
      border: buildOutlineBorder(),
      enabledBorder: buildOutlineBorder(),
      focusedBorder: buildOutlineBorder(focused: true),
      filled: true,
      fillColor: ColorUtils.slate50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  /// Builds outline border for fields.
  OutlineInputBorder buildOutlineBorder({bool focused = false}) {
    return OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(
        color: focused ? ColorUtils.corporateBlue600 : ColorUtils.slate200,
        width: focused ? 1.5 : 1.0,
      ),
    );
  }

  /// Builds the jenjang dropdown field.
  Widget buildJenjangDropdown(
    String tempJenjang,
    List<String> jenjangOptions,
    Function(String) onJenjangChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: tempJenjang,
      decoration: buildDropdownDecoration(),
      items: jenjangOptions
          .map((j) => DropdownMenuItem(value: j, child: Text(j)))
          .toList(),
      onChanged: (value) {
        if (value != null) {
          onJenjangChanged(value);
        }
      },
    );
  }

  /// Builds dropdown decoration.
  InputDecoration buildDropdownDecoration() {
    return InputDecoration(
      labelText: 'Jenjang Sekolah',
      prefixIcon: Icon(
        Icons.stairs_rounded,
        color: ColorUtils.corporateBlue600,
        size: 20,
      ),
      border: buildOutlineBorder(),
      enabledBorder: buildOutlineBorder(),
      focusedBorder: buildOutlineBorder(focused: true),
      filled: true,
      fillColor: ColorUtils.slate50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  /// Builds the footer with action buttons.
  Widget buildDialogFooter({
    required bool isSaving,
    required BuildContext context,
    required TextEditingController nameController,
    required TextEditingController addressController,
    required String tempJenjang,
    required Function(bool) onSaving,
    required Function(String, String, String) onSaveSettings,
    required Function() onLoadSettings,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate100)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          children: [
            Expanded(child: buildCancelButton(context)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: buildSaveButton(
                isSaving: isSaving,
                context: context,
                nameController: nameController,
                addressController: addressController,
                tempJenjang: tempJenjang,
                onSaving: onSaving,
                onSaveSettings: onSaveSettings,
                onLoadSettings: onLoadSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the cancel button.
  Widget buildCancelButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () => AppNavigator.pop(context),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 13),
        side: BorderSide(color: ColorUtils.slate300),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      child: Text(
        AppLocalizations.cancel.tr,
        style: TextStyle(color: ColorUtils.slate600),
      ),
    );
  }

  /// Builds the save button.
  Widget buildSaveButton({
    required bool isSaving,
    required BuildContext context,
    required TextEditingController nameController,
    required TextEditingController addressController,
    required String tempJenjang,
    required Function(bool) onSaving,
    required Function(String, String, String) onSaveSettings,
    required Function() onLoadSettings,
  }) {
    return ElevatedButton(
      onPressed: isSaving
          ? null
          : () => handleSaveAction(
              context: context,
              nameController: nameController,
              addressController: addressController,
              tempJenjang: tempJenjang,
              onSaving: onSaving,
              onSaveSettings: onSaveSettings,
              onLoadSettings: onLoadSettings,
            ),
      style: ElevatedButton.styleFrom(
        backgroundColor: ColorUtils.corporateBlue600,
        disabledBackgroundColor: ColorUtils.corporateBlue600.withValues(
          alpha: 0.6,
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        elevation: 0,
      ),
      child: buildSaveButtonChild(isSaving),
    );
  }

  /// Builds the save button child widget.
  Widget buildSaveButtonChild(bool isSaving) {
    return isSaving
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(
            AppLocalizations.save.tr,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          );
  }

  /// Abstract method to handle save action - implemented in
  /// SchoolLevelDialogMixin.
  Future<void> handleSaveAction({
    required BuildContext context,
    required TextEditingController nameController,
    required TextEditingController addressController,
    required String tempJenjang,
    required Function(bool) onSaving,
    required Function(String, String, String) onSaveSettings,
    required Function() onLoadSettings,
  });
}
