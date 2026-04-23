import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Mixin providing footer building for filter sheet.
mixin SubjectFilterSheetFooterMixin {
  /// Provides access to BuildContext.
  BuildContext get context;

  /// Provides access to ref for language translation.
  WidgetRef get ref;

  /// Gets the onApply callback to execute on apply.
  void Function(
    String? status,
    String? classStatus,
    String? gradeLevel,
    String? className,
  )
  getOnApply();

  /// Gets current temp status.
  String? getTempStatus();

  /// Gets current temp class status.
  String? getTempClassStatus();

  /// Gets current temp grade level.
  String? getTempGradeLevel();

  /// Gets current temp class name.
  String? getTempClassName();

  /// Handles apply button press.
  void _onApplyPressed() {
    getOnApply()(
      getTempStatus(),
      getTempClassStatus(),
      getTempGradeLevel(),
      getTempClassName(),
    );
    AppNavigator.pop(context);
  }

  /// Builds cancel button.
  Widget _buildCancelButton(String cancelText) {
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
          cancelText,
          style: TextStyle(
            color: ColorUtils.slate600,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Builds apply button.
  Widget _buildApplyButton(String applyText) {
    return Expanded(
      child: ElevatedButton(
        onPressed: _onApplyPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: ColorUtils.corporateBlue600,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          elevation: 2,
        ),
        child: Text(
          applyText,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Builds the footer with Cancel and Apply buttons.
  Widget buildFooter() {
    final lang = ref.watch(languageRiverpod);
    final cancelText = lang.getTranslatedText({'en': 'Cancel', 'id': 'Batal'});
    final applyText = lang.getTranslatedText({
      'en': 'Apply Filter',
      'id': 'Terapkan Filter',
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate100)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildCancelButton(cancelText),
          const SizedBox(width: AppSpacing.md),
          _buildApplyButton(applyText),
        ],
      ),
    );
  }
}
