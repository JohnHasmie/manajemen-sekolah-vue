import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_add_edit_sheet.dart';

mixin SubjectAddEditSheetButtonsMixin on ConsumerState<SubjectAddEditSheet> {
  // Abstract accessors for state fields.
  bool get isSaving;
  Future<void> save(BuildContext context);

  /// Build footer with action buttons
  Widget buildFooterButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _buildCancelButton(context)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _buildSaveButton(context)),
        ],
      ),
    );
  }

  /// Cancel button
  Widget _buildCancelButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () => AppNavigator.pop(context),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: ColorUtils.slate300),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      child: Text(
        AppLocalizations.cancel.tr,
        style: TextStyle(
          color: ColorUtils.slate700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Save button with loading indicator
  Widget _buildSaveButton(BuildContext context) {
    return ElevatedButton(
      onPressed: isSaving ? null : () => save(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: ColorUtils.corporateBlue600,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        elevation: 2,
      ),
      child: isSaving
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
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
    );
  }
}
