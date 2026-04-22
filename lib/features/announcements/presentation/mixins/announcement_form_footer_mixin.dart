import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_form_sheet.dart';

/// Mixin for announcement form footer with cancel/save buttons.
mixin AnnouncementFormFooterMixin on State<AnnouncementFormSheet> {
  bool get _isSaving;
  bool get _isEdit;

  Future<void> handleSave(LanguageProvider lang);

  /// Builds cancel button.
  Widget _buildCancelButton(LanguageProvider lang) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () => AppNavigator.pop(context),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: ColorUtils.slate300),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        child: Text(
          lang.getTranslatedText({'en': 'Cancel', 'id': 'Batal'}),
          style: TextStyle(
            color: ColorUtils.slate700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Builds save/update button content (loader or text).
  Widget _buildSaveButtonChild(LanguageProvider lang) {
    return _isSaving
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(
            _isEdit
                ? lang.getTranslatedText({'en': 'Update', 'id': 'Perbarui'})
                : lang.getTranslatedText({'en': 'Save', 'id': 'Simpan'}),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          );
  }

  /// Builds save/update button.
  Widget _buildSaveButton(LanguageProvider lang, Color primaryColor) {
    return Expanded(
      child: ElevatedButton(
        onPressed: _isSaving ? null : () => handleSave(lang),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          disabledBackgroundColor: primaryColor.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 2,
          shadowColor: primaryColor.withValues(alpha: 0.4),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        child: _buildSaveButtonChild(lang),
      ),
    );
  }

  /// Builds footer with Cancel and Save/Update buttons.
  Widget buildFooter(LanguageProvider lang, Color primaryColor) {
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
          _buildCancelButton(lang),
          const SizedBox(width: AppSpacing.md),
          _buildSaveButton(lang, primaryColor),
        ],
      ),
    );
  }
}
