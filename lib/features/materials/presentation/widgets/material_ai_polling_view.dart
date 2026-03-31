// Polling / loading view shown while the AI job is being processed.
// Displayed in the centre of the screen with a spinner and status message.
// Like a Vue `<AiPollingView :status="pollingStatus" />` skeleton component.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Full-screen polling indicator shown while waiting for the AI to finish.
///
/// Renders a centred spinner, a bold status line ([pollingStatus]), and a
/// subtitle asking the user to wait.  No interaction — purely presentational.
class MaterialAiPollingView extends StatelessWidget {
  /// Live status text received from the polling loop,
  /// e.g. "AI sedang memproses materi (percobaan 3)..."
  final String pollingStatus;

  /// Accent colour for the circular progress indicator.
  final Color primaryColor;

  const MaterialAiPollingView({
    super.key,
    required this.pollingStatus,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              pollingStatus,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Mohon tunggu, proses ini membutuhkan waktu beberapa saat...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
            ),
          ],
        ),
      ),
    );
  }
}
