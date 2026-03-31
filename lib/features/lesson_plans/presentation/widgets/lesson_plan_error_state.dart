// Error-state widget for the RPP (lesson plan) list screen.
// Like a Vue component `<ErrorState :message="..." @retry="reload()" />`.
// Displays error icon, message, and a retry button backed by a callback.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Shown in the RPP list when an API error has occurred.
///
/// [errorMessage] is the human-friendly error string.
/// [onRetry] is fired when the user taps "Retry" — like Vue `$emit('retry')`.
/// [primaryColor] is the school-role accent colour used for the button.
class LessonPlanErrorState extends StatelessWidget {
  final LanguageProvider languageProvider;
  final String? errorMessage;
  final VoidCallback onRetry;
  final Color primaryColor;

  const LessonPlanErrorState({
    super.key,
    required this.languageProvider,
    required this.errorMessage,
    required this.onRetry,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ColorUtils.error600.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: ColorUtils.error600,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              languageProvider.getTranslatedText({
                'en': 'Error',
                'id': 'Terjadi Kesalahan',
              }),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              errorMessage ?? '',
              style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                languageProvider.getTranslatedText({
                  'en': 'Retry',
                  'id': 'Coba Lagi',
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
