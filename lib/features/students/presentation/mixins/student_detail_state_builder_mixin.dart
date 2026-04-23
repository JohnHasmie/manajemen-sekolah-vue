import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Builds UI for different loading/error/content states.
mixin StudentDetailStateBuilderMixin {
  /// Gets primary color for UI.
  Color getPrimaryColor();

  /// Builds loading spinner state.
  Widget buildLoadingState(LanguageProvider languageProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: getPrimaryColor().withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(getPrimaryColor()),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            languageProvider.getTranslatedText({
              'en': 'Loading student detail...',
              'id': 'Memuat detail siswa...',
            }),
            style: TextStyle(color: ColorUtils.slate600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// Builds error state with retry button.
  Widget buildErrorState(
    LanguageProvider languageProvider,
    String? errorMessage,
    VoidCallback onRetry,
  ) {
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
                color: ColorUtils.error600.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: ColorUtils.error600.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: ColorUtils.error600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              languageProvider.getTranslatedText({
                'en': 'An error occurred',
                'id': 'Terjadi kesalahan',
              }),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              errorMessage ?? 'Unknown error',
              style: TextStyle(color: ColorUtils.slate600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                languageProvider.getTranslatedText({
                  'en': 'Try Again',
                  'id': 'Coba Lagi',
                }),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: getPrimaryColor(),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
