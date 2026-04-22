import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

mixin FilterHeaderMixin {
  // Abstract state access
  void setState(VoidCallback fn);
  BuildContext get context;

  // State getters/setters
  String? get tempSelectedPrioritas;
  set tempSelectedPrioritas(String? value);

  String? get tempSelectedTarget;
  set tempSelectedTarget(String? value);

  String? get tempSelectedStatus;
  set tempSelectedStatus(String? value);

  // Access to widget properties
  LanguageProvider get languageProvider;
  Color get primaryColor;

  /// Builds the gradient header with title and reset button.
  Widget buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_buildTitleRow(), _buildResetButton()],
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      children: [
        const Icon(Icons.filter_list_rounded, color: Colors.white, size: 22),
        const SizedBox(width: AppSpacing.md),
        Text(
          languageProvider.getTranslatedText({'en': 'Filter', 'id': 'Filter'}),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildResetButton() {
    return TextButton(
      onPressed: () {
        setState(() {
          tempSelectedPrioritas = null;
          tempSelectedTarget = null;
          tempSelectedStatus = null;
        });
      },
      child: Text(
        languageProvider.getTranslatedText({'en': 'Reset', 'id': 'Reset'}),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
