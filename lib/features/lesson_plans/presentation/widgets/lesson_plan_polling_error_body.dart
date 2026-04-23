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
    // SingleChildScrollView so a long error message (e.g. a raw SQL error or
    // stack trace bubbled up from the backend) can scroll instead of
    // overflowing the viewport. The Column uses `mainAxisSize.min` + a top
    // SizedBox to approximate the old centered look while still letting the
    // whole body scroll when the message is taller than the screen.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: AppSpacing.xxl),
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
                  AppLocalizations.failedToGenerateLessonPlan.tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Keep the raw message visible but capped — a full SQL error
                // can be thousands of pixels tall, which pushes the Kembali
                // button off-screen and looks broken. Cap at ~600 chars with
                // an ellipsis; the full message is still in the app logs for
                // debugging.
                SelectableText(
                  _truncate(pollingError ?? ''),
                  style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: onBack,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.getRoleColor('guru'),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Kembali'),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        );
      },
    );
  }

  String _truncate(String value, {int max = 600}) {
    if (value.length <= max) return value;
    return '${value.substring(0, max)}…';
  }
}
