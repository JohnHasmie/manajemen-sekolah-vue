import 'dart:io';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Mixin providing payment dialog footer and actions.
mixin PaymentDialogFooterMixin {
  /// Abstract: BuildContext for navigation.
  BuildContext get context;

  /// Abstract: Primary color for styling.
  Color get primaryColor;

  /// Abstract: Payment method controller.
  TextEditingController get paymentMethodController;

  /// Abstract: Amount controller.
  TextEditingController get amountController;

  /// Abstract: Payment date controller.
  TextEditingController get paymentDateController;

  /// Abstract: Selected file.
  File? get selectedFile;

  /// Abstract: Callback on save.
  void Function({
    required String paymentMethod,
    required double amount,
    required String date,
    File? file,
  })
  get onSave;

  /// Builds the dialog footer with action buttons.
  Widget buildFooter() => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    decoration: _buildFooterDecoration(),
    child: Row(
      children: [
        Expanded(child: _buildCancelButton()),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildSaveButton()),
      ],
    ),
  );

  /// Builds decoration for footer.
  BoxDecoration _buildFooterDecoration() {
    return BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: ColorUtils.slate100)),
      boxShadow: [
        BoxShadow(
          color: ColorUtils.slate900.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, -2),
        ),
      ],
    );
  }

  /// Builds cancel button.
  Widget _buildCancelButton() => OutlinedButton(
    onPressed: () => AppNavigator.pop(context),
    style: OutlinedButton.styleFrom(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 13),
      side: BorderSide(color: ColorUtils.slate300),
    ),
    child: Text(
      AppLocalizations.cancel.tr,
      style: TextStyle(color: ColorUtils.slate600),
    ),
  );

  /// Builds save button.
  Widget _buildSaveButton() => ElevatedButton(
    onPressed: _handleSave,
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
    ),
    child: Text(
      AppLocalizations.save.tr,
      style: const TextStyle(color: Colors.white),
    ),
  );

  /// Handles save button press with validation.
  void _handleSave() {
    if (paymentMethodController.text.isEmpty || amountController.text.isEmpty) {
      return;
    }

    AppNavigator.pop(context);
    onSave(
      paymentMethod: paymentMethodController.text,
      amount: double.parse(amountController.text),
      date: paymentDateController.text,
      file: selectedFile,
    );
  }
}
