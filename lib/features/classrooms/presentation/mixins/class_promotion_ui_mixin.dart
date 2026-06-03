import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/classrooms/presentation/screens/class_promotion_wizard.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// Mixin for UI building methods in ClassPromotionWizard.
mixin ClassPromotionUIMixin on State<ClassPromotionWizard> {
  int get currentStep;
  Color getPrimaryColor();
  LinearGradient getCardGradient();
  bool get isLoading;
  VoidCallback get onStepCancel;
  void onStepContinue();

  /// Build the gradient header with title and back button.
  Widget buildGradientHeader(
    LanguageProvider languageProvider,
    List<String> steps,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: getCardGradient(),
        boxShadow: [
          BoxShadow(
            color: getPrimaryColor().withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (currentStep > 0) {
                onStepCancel();
              } else {
                AppNavigator.pop(context);
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Promote Class',
                    'id': 'Naik Kelas',
                  }),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  languageProvider.getTranslatedText({
                    'en':
                        'Step ${currentStep + 1} of ${steps.length}: '
                        '${steps[currentStep]}',
                    'id':
                        'Langkah ${currentStep + 1} dari ${steps.length}: '
                        '${steps[currentStep]}',
                  }),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build a step container with scroll view.
  Widget buildStepContainer(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );
  }

  /// Build bottom control buttons (back and continue/finish).
  Widget buildBottomControls(LanguageProvider languageProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (currentStep > 0) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onStepCancel,
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: ColorUtils.slate700,
                  ),
                  label: Text(
                    languageProvider.getTranslatedText({
                      'en': 'Back',
                      'id': 'Kembali',
                    }),
                    style: TextStyle(
                      color: ColorUtils.slate700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: ColorUtils.slate300),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onStepContinue,
                icon: Icon(
                  currentStep == 3
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  currentStep == 3
                      ? languageProvider.getTranslatedText({
                          'en': 'Finish',
                          'id': 'Selesai',
                        })
                      : languageProvider.getTranslatedText({
                          'en': 'Continue',
                          'id': 'Lanjut',
                        }),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: currentStep == 3
                      ? ColorUtils.success600
                      : getPrimaryColor(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  elevation: 2,
                  shadowColor: getPrimaryColor().withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build loading overlay.
  Widget buildLoadingOverlay() {
    if (!isLoading) return const SizedBox.shrink();
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: Center(
        child: Container(
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
      ),
    );
  }
}
