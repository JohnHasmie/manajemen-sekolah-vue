import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Mixin providing action buttons for verification dialog.
mixin VerificationDialogActionsMixin {
  /// Abstract: State and status access.
  BuildContext get context;
  String get status;
  Future<void> Function() get handleConfirmFn;

  /// Builds the action buttons row (cancel and confirm).
  Widget buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          _buildCancelButton(),
          const SizedBox(width: AppSpacing.md),
          _buildConfirmButton(),
        ],
      ),
    );
  }

  /// Builds the cancel button.
  Widget _buildCancelButton() {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: ColorUtils.slate300),
        ),
        child: Text(
          AppLocalizations.cancel.tr,
          style: TextStyle(color: ColorUtils.slate700),
        ),
      ),
    );
  }

  /// Builds the confirm button with dynamic colors based on status.
  Widget _buildConfirmButton() {
    final isVerified = status == 'verified';

    return Expanded(
      child: ElevatedButton(
        onPressed: handleConfirmFn,
        style: ElevatedButton.styleFrom(
          backgroundColor: isVerified
              ? ColorUtils.success600
              : ColorUtils.error600,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          isVerified ? 'Terima' : 'Tolak',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
