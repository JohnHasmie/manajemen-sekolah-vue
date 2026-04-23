// Elegant polling view shown while the AI job is processing.
// Matches the MaterialAiPollingView design: centered card with
// concentric progress indicator, animated sparkle icon, and
// time-estimate badge.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Full-page centered polling view during AI lesson-plan generation.
///
/// [pollingStatus] is the human-readable status message (e.g. "AI sedang
/// memproses..."). Matches the MaterialAiPollingView design for consistency.
class LessonPlanPollingSkeletonBody extends StatelessWidget {
  final String pollingStatus;

  const LessonPlanPollingSkeletonBody({super.key, required this.pollingStatus});

  @override
  Widget build(BuildContext context) {
    final primaryColor = ColorUtils.getRoleColor('guru');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: ColorUtils.slate300.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Concentric spinner with sparkle icon
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      color: primaryColor.withValues(alpha: 0.15),
                      strokeWidth: 4,
                      value: 1.0,
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      color: primaryColor,
                      strokeWidth: 4,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              Text(
                'AI Sedang Menyusun RPP',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ColorUtils.slate800,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              Text(
                pollingStatus.isNotEmpty
                    ? pollingStatus
                    : 'Menyusun kompetensi, tujuan pembelajaran, dan kegiatan belajar...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: ColorUtils.slate500,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Time estimate badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Bisa memakan waktu ±1 menit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
