import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

mixin FilterFooterMixin {
  // Abstract state access
  void setState(VoidCallback fn);
  BuildContext get context;

  // State getters
  String? get tempSelectedPrioritas;
  String? get tempSelectedTarget;
  String? get tempSelectedStatus;

  // Access to widget properties
  LanguageProvider get languageProvider;
  Color get primaryColor;
  void Function(String? priority, String? target, String? status) get onApply;

  /// Builds the footer with Cancel and Apply Filter buttons.
  Widget buildFooter() {
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
          Expanded(child: _buildApplyButton()),
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
        languageProvider.getTranslatedText({'en': 'Cancel', 'id': 'Batal'}),
        style: TextStyle(
          color: ColorUtils.slate700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Builds the apply filter button.
  Widget _buildApplyButton() {
    return ElevatedButton(
      onPressed: () {
        onApply(tempSelectedPrioritas, tempSelectedTarget, tempSelectedStatus);
        AppNavigator.pop(context);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 14),
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      child: Text(
        languageProvider.getTranslatedText({
          'en': 'Apply Filter',
          'id': 'Terapkan Filter',
        }),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
