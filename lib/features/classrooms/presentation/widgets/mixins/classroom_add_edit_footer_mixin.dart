import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Mixin for building the footer action buttons section of
/// [ClassroomAddEditSheet].
///
/// Provides [buildFooterSection] to render Cancel and
/// Save/Update buttons with loading state.
mixin ClassroomAddEditFooterMixin {
  /// Provides access to BuildContext for navigation.
  BuildContext get context;

  /// Provides access to class data (null = add mode).
  Map<String, dynamic>? get classData;

  /// Provides access to isSaving flag.
  bool get isSaving;

  /// Provides access to language provider for translations.
  dynamic get languageProvider;

  /// Callback for submit button press.
  Future<void> submit();

  /// Builds the footer section with Cancel and Save buttons.
  ///
  /// Returns a Container with action buttons (Cancel on left,
  /// Save/Update on right) with loading state on submit button.
  Widget buildFooterSection() {
    final isEdit = classData != null;
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
          Expanded(child: _buildCancelButton()),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _buildSubmitButton(isEdit)),
        ],
      ),
    );
  }

  /// Builds the cancel button.
  Widget _buildCancelButton() {
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

  /// Builds the submit button with loading state.
  Widget _buildSubmitButton(bool isEdit) {
    return ElevatedButton(
      onPressed: isSaving ? null : submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: ColorUtils.corporateBlue600,
        disabledBackgroundColor: ColorUtils.corporateBlue600.withValues(
          alpha: 0.6,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        elevation: 2,
        shadowColor: ColorUtils.corporateBlue600.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
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
              isEdit
                  ? languageProvider.getTranslatedText({
                      'en': 'Update',
                      'id': 'Perbarui',
                    })
                  : AppLocalizations.save.tr,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
    );
  }
}
