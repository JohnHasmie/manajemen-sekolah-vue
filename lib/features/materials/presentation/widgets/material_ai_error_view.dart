// Error view shown when AI generation or polling fails.
// Displays the error message and a retry button that fires [onRetry].
// Like a Vue `<AiErrorView :message="error" @retry="generateMaterial()" />`.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Full-screen error state for [MaterialAiResultScreen].
///
/// Shows an error icon, localised title, the raw [errorMessage] received from
/// the API or network, and an elevated "Try Again" button.
/// All recoverable actions are delegated to [onRetry] (callback pattern),
/// so this widget stays stateless and side-effect-free.
class MaterialAiErrorView extends StatelessWidget {
  /// Human-readable error message returned from the API or network layer.
  final String errorMessage;

  /// Accent colour for the retry button background.
  final Color primaryColor;

  /// Called when the user taps the retry button.
  /// Parent is responsible for re-triggering AI generation.
  final VoidCallback onRetry;

  const MaterialAiErrorView({
    super.key,
    required this.errorMessage,
    required this.primaryColor,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red.shade400),
            SizedBox(height: AppSpacing.lg),
            Text(
              AppLocalizations.failedToGenerateMaterial.tr,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ColorUtils.slate800,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: ColorUtils.slate600),
            ),
            SizedBox(height: AppSpacing.xxl),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.tryAgain.tr),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
