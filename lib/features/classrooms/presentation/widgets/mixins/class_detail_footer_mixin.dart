import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Mixin for building the footer section of
/// ClassDetailDialog.
///
/// Provides [buildFooterSection] to render Close and
/// Edit buttons.
mixin ClassDetailFooterMixin {
  /// Provides access to BuildContext for navigation.
  BuildContext get context;

  /// Provides access to read-only flag.
  bool get isReadOnly;

  /// Provides access to language provider for translations.
  LanguageProvider get languageProvider;

  /// Provides access to edit callback.
  VoidCallback get onEdit;

  /// Builds the footer section with Close and Edit buttons.
  ///
  /// Returns a bordered Container with a Row of buttons.
  /// The Edit button is conditionally shown based on
  /// [isReadOnly].
  Widget buildFooterSection() {
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ColorUtils.slate100)),
      ),
      child: Row(
        children: [
          _buildCloseButton(),
          if (!isReadOnly) ...[
            const SizedBox(width: AppSpacing.md),
            _buildEditButton(),
          ],
        ],
      ),
    );
  }

  /// Builds the Close button.
  ///
  /// An outlined button that dismisses the dialog.
  Widget _buildCloseButton() {
    return Expanded(
      child: OutlinedButton(
        onPressed: () => AppNavigator.pop(context),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: BorderSide(color: ColorUtils.slate300),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        child: Text(
          languageProvider.getTranslatedText({'en': 'Close', 'id': 'Tutup'}),
          style: TextStyle(
            color: ColorUtils.slate700,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// Builds the Edit button (only shown when not
  /// read-only).
  ///
  /// An elevated button with icon that closes the dialog
  /// and invokes [onEdit] callback.
  Widget _buildEditButton() {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: () {
          AppNavigator.pop(context);
          onEdit();
        },
        icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
        label: Text(
          languageProvider.getTranslatedText({'en': 'Edit', 'id': 'Edit'}),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorUtils.corporateBlue600,
          padding: const EdgeInsets.symmetric(vertical: 13),
          elevation: 2,
          shadowColor: ColorUtils.corporateBlue600.withValues(alpha: 0.4),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    );
  }
}
