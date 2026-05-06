// Manual-RPP read-only preview.
//
// Renders the simpler upload-first layout: a file-attachment card
// up top (the teacher's uploaded PDF/DOCX/image), then the header
// info card, then the formatted long-form content, and finally the
// signature card. No regen banner, no per-section edit cards — those
// are AI-only and live in [AiRppPreviewView]. The dispatcher decides
// the kind once at entry.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_file_card.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_formatted_content.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_header_info_card.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_signature_card.dart';

class ManualRppPreviewView extends StatelessWidget {
  final Map<String, dynamic> lessonPlanData;

  /// Pre-formatted long-form content (header info card + everything
  /// the manual upload included as plain text). Already trimmed of
  /// HTML by the parent.
  final String formattedContent;

  final Color primaryColor;
  final String? filePath;
  final bool isDownloading;
  final VoidCallback onFileDownloadTap;

  const ManualRppPreviewView({
    super.key,
    required this.lessonPlanData,
    required this.formattedContent,
    required this.primaryColor,
    required this.filePath,
    required this.isDownloading,
    required this.onFileDownloadTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          if (filePath != null) ...[
            LessonPlanFileCard(
              filePath: filePath!,
              isDownloading: isDownloading,
              primaryColor: primaryColor,
              onTap: onFileDownloadTap,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          LessonPlanHeaderInfoCard(
            lessonPlanData: lessonPlanData,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: LessonPlanFormattedContent(
                content: formattedContent,
                primaryColor: primaryColor,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LessonPlanSignatureCard(
            isAiGenerated: false,
            primaryColor: primaryColor,
          ),
        ],
      ),
    );
  }
}
