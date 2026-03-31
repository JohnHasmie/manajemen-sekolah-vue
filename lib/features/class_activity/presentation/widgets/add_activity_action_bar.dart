import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Bottom action bar with Cancel and Submit/Update buttons.
///
/// Shown at the very bottom of [AddActivityDialog], outside the scroll view so
/// it stays visible at all times.
class AddActivityActionBar extends StatelessWidget {
  final bool isSubmitting;
  final bool isEditMode;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final VoidCallback onSubmit;

  const AddActivityActionBar({
    super.key,
    required this.isSubmitting,
    required this.isEditMode,
    required this.primaryColor,
    required this.languageProvider,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    isSubmitting ? null : () => AppNavigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  side: BorderSide(color: ColorUtils.slate300),
                ),
                child: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Cancel',
                    'id': 'Batal',
                  }),
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
                onPressed: isSubmitting ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  elevation: 1,
                ),
                child: isSubmitting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        isEditMode
                            ? languageProvider.getTranslatedText({
                                'en': 'Update',
                                'id': 'Simpan Perubahan',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'Add',
                                'id': 'Tambah',
                              }),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
