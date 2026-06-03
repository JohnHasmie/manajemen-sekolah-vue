import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_ai_polling_view.dart';

/// Empty state view for sub-chapter with polling or error display.
class SubChapterEmptyContent extends StatelessWidget {
  final bool isPollingAi;
  final String pollingStatus;
  final String? pollingError;
  final Color primaryColor;
  final bool isLoadingAi;
  final VoidCallback onGenerateTap;

  const SubChapterEmptyContent({
    super.key,
    required this.isPollingAi,
    required this.pollingStatus,
    required this.pollingError,
    required this.primaryColor,
    required this.isLoadingAi,
    required this.onGenerateTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isPollingAi) {
      return MaterialAiPollingView(
        pollingStatus: pollingStatus,
        primaryColor: primaryColor,
      );
    }

    if (pollingError != null) {
      return _buildErrorView(context);
    }

    return _buildEmptyView(context);
  }

  Widget _buildErrorView(BuildContext context) {
    final isRateLimit =
        pollingError!.toLowerCase().contains('tunggu') ||
        pollingError!.toLowerCase().contains('menit') ||
        pollingError!.toLowerCase().contains('batas');

    final title = isRateLimit ? 'Istirahat Sejenak' : 'Mohon Maaf, Ada Kendala';
    final icon = isRateLimit
        ? Icons.hourglass_empty_rounded
        : Icons.info_outline_rounded;
    final iconColor = isRateLimit ? Colors.orange[600] : Colors.red[400];
    final bgColor = isRateLimit
        ? Colors.orange.withValues(alpha: 0.1)
        : Colors.red.withValues(alpha: 0.05);

    String displayMessage = pollingError!;
    if (isRateLimit) {
      displayMessage =
          'Sistem membutuhkan sedikit waktu pemulihan untuk hasil terbaik. '
          '$pollingError';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: ColorUtils.slate200.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: ColorUtils.slate100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 42, color: iconColor),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ColorUtils.slate800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                displayMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: ColorUtils.slate500,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text(
                    'Coba Lagi',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: onGenerateTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: ColorUtils.info600.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 48,
              color: ColorUtils.info600,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Belum Ada Konten',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Materi, soal, dan referensi belum tersedia untuk sub-bab ini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: ColorUtils.slate500,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: ElevatedButton.icon(
                onPressed: isLoadingAi ? null : onGenerateTap,
                icon: isLoadingAi
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 22),
                label: Text(
                  isLoadingAi ? ' Sedang Memproses...' : ' Generate Materi AI',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: primaryColor.withValues(alpha: 0.7),
                  disabledForegroundColor: Colors.white,
                  elevation: isLoadingAi ? 0 : 8,
                  shadowColor: primaryColor.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
