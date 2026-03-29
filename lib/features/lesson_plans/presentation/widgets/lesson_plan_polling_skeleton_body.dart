// Skeleton loading body shown while the AI job is still processing.
// Like a Vue `<SkeletonLoader>` component — receives polling status text
// as a prop so it never touches parent state directly.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_skeleton_section.dart';

/// Full-page skeleton shown during AI lesson-plan generation polling.
///
/// [pollingStatus] is the human-readable status message to display under
/// the spinner (e.g. "AI sedang memproses... (10s)").
class LessonPlanPollingSkeletonBody extends StatelessWidget {
  final String pollingStatus;

  const LessonPlanPollingSkeletonBody({
    super.key,
    required this.pollingStatus,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status banner — like an <Alert> component in Vue
          Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: ColorUtils.getRoleColor('guru'),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI sedang menyusun RPP...',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.getRoleColor('guru'),
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        pollingStatus,
                        style: TextStyle(
                          color: ColorUtils.slate500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.xxl),
          // Skeleton placeholders for each RPP section
          LessonPlanSkeletonSection(title: 'Judul RPP', height: 48),
          SizedBox(height: AppSpacing.xl),
          LessonPlanSkeletonSection(title: 'Informasi Umum', height: 200),
          SizedBox(height: AppSpacing.xl),
          LessonPlanSkeletonSection(title: 'A. Kompetensi Inti (KI)', height: 120),
          SizedBox(height: AppSpacing.xl),
          LessonPlanSkeletonSection(title: 'B. Kompetensi Dasar (KD)', height: 120),
          SizedBox(height: AppSpacing.xl),
          LessonPlanSkeletonSection(title: 'C. Tujuan Pembelajaran', height: 120),
          SizedBox(height: AppSpacing.xl),
          LessonPlanSkeletonSection(title: 'D. Kegiatan Pembelajaran', height: 150),
          SizedBox(height: AppSpacing.xl),
          LessonPlanSkeletonSection(title: 'E. Penilaian (Asesmen)', height: 120),
        ],
      ),
    );
  }
}
