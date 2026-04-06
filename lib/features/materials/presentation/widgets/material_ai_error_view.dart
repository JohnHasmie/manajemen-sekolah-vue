// Error view shown when content generation fails.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class MaterialAiErrorView extends StatelessWidget {
  final String errorMessage;
  final int? statusCode;
  final Color primaryColor;
  final VoidCallback onRetry;

  const MaterialAiErrorView({
    super.key,
    required this.errorMessage,
    this.statusCode,
    required this.primaryColor,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isLimitReached = statusCode == 429;
    final themeColor = isLimitReached ? ColorUtils.info600 : ColorUtils.error600;
    final icon = isLimitReached ? Icons.access_time_rounded : Icons.error_outline;
    final title = isLimitReached ? 'Batas Tercapai' : 'Gagal Memproses';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: themeColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: themeColor),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ColorUtils.slate900)),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ColorUtils.slate200)),
              child: Text(errorMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: ColorUtils.slate600, height: 1.5)),
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
