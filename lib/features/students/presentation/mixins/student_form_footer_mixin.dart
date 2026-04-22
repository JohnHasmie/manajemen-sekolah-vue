import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Footer UI mixin for student form dialog.
///
/// Provides the sticky footer with Cancel and Save/Update buttons.
mixin StudentFormFooterMixin {
  /// Primary color for button styling.
  Color get primaryColor;

  /// Translation helper — must be implemented by consuming class.
  String t(Map<String, String> translations);

  /// Is edit mode.
  bool get isEditMode;

  /// Is saving flag.
  bool get isSaving;

  /// Save callback.
  Future<void> handleSave();

  /// Access to BuildContext — must be implemented by consuming class.
  BuildContext get buildContext;

  /// Build the sticky footer with buttons.
  Widget buildFooterWidget() {
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
          Expanded(
            child: OutlinedButton(
              onPressed: () => AppNavigator.pop(buildContext),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: ColorUtils.slate300),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              child: Text(
                t({'en': 'Cancel', 'id': 'Batal'}),
                style: TextStyle(
                  color: ColorUtils.slate700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: ElevatedButton(
              onPressed: isSaving ? null : handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                disabledBackgroundColor: primaryColor.withValues(alpha: 0.6),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 2,
                shadowColor: primaryColor.withValues(alpha: 0.4),
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
                      isEditMode
                          ? t({'en': 'Update', 'id': 'Perbarui'})
                          : t({'en': 'Save', 'id': 'Simpan'}),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
