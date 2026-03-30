// Full-page error state shown when AI lesson-plan polling fails.
// Like a Vue <ErrorState> component — receives the error message and
// an onBack callback instead of calling AppNavigator directly.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Centred error card shown after a failed AI generation poll.
///
/// [pollingError] is the error message string to display.
/// [onBack] is called when the user taps the "Kembali" button —
/// the parent decides how to navigate (like an `@click` emit in Vue).
class LessonPlanPollingErrorBody extends StatelessWidget {
  final String? pollingError;
  final VoidCallback onBack;

  const LessonPlanPollingErrorBody({
    super.key,
    required this.pollingError,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ColorUtils.error600.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: ColorUtils.error600,
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            Text(
              AppLocalizations.failedToGenerateLessonPlan.tr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate700,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              pollingError ?? '',
              style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: onBack,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.getRoleColor('guru'),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }
}
