import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan_format.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_admin_detail_page.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_file_card.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_content_formatter.dart';

mixin ContentCardBuilderMixin on State<LessonPlanAdminDetailPage> {
  late Map<String, dynamic> lessonPlan;

  Widget buildContentCard() {
    final format = LessonPlanFormat.fromMap(lessonPlan);
    if (format == LessonPlanFormat.file) {
      return const SizedBox.shrink();
    }

    final sectionKeys = format.sectionKeys;
    final filledSections = sectionKeys.where((key) {
      final val = readLessonPlanSection(lessonPlan, key);
      return val != null && val.isNotEmpty;
    }).toList();

    final filledCount = filledSections.length;
    final totalCount = sectionKeys.length;

    String formatTitle = 'Isi RPP';
    String formatSubtitle = '$filledCount/$totalCount bagian terisi';
    if (format == LessonPlanFormat.k13) {
      formatTitle = 'Bagian K13';
      formatSubtitle = '$filledCount bagian terisi · siap ditinjau';
    } else if (format == LessonPlanFormat.modulAjar) {
      formatTitle = 'Bagian Modul Ajar';
      formatSubtitle = '$filledCount bagian terisi · siap ditinjau';
    } else if (format == LessonPlanFormat.rpp1Halaman) {
      formatTitle = 'RPP 1 Halaman';
      formatSubtitle = '$filledCount komponen inti';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: format.tintColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  format.icon,
                  size: 14,
                  color: format.brandColor,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatTitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.brandDarkBlue,
                      ),
                    ),
                    Text(
                      formatSubtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: ColorUtils.slate500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$filledCount/$totalCount',
                style: TextStyle(
                  fontSize: 10,
                  color: ColorUtils.slate500,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...filledSections.asMap().entries.map((entry) {
            final index = entry.key;
            final key = entry.value;
            final rawContent = readLessonPlanSection(lessonPlan, key) ?? '';
            final content = LessonPlanContentFormatter.stripHtml(rawContent);
            final label = format.sectionLabel(key);
            final isLast = index == filledCount - 1;

            return _buildSectionItem(format, label, content, index, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildSectionItem(
    LessonPlanFormat format,
    String label,
    String content,
    int index,
    bool isLast,
  ) {
    final bottomMargin = isLast ? 0.0 : 10.0;
    if (format == LessonPlanFormat.modulAjar) {
      return Container(
        margin: EdgeInsets.only(bottom: bottomMargin),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE9FE), // soft violet background
          border: Border.all(color: const Color(0xFFDDD6FE)), // light violet border
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7C3AED), // violet-700
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              content,
              style: TextStyle(
                fontSize: 11,
                color: ColorUtils.slate700,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    } else if (format == LessonPlanFormat.rpp1Halaman) {
      final letter = String.fromCharCode(65 + index); // A, B, C...
      return Container(
        margin: EdgeInsets.only(bottom: bottomMargin),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFCCFBF1).withValues(alpha: 0.3), // soft teal background
          border: Border.all(color: const Color(0xFF99F6E4)), // light teal border
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF99F6E4), // circle background
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    letter,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F766E), // teal-700
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              content,
              style: TextStyle(
                fontSize: 11,
                color: ColorUtils.slate600,
                height: 1.55,
              ),
            ),
          ],
        ),
      );
    } else {
      // Default: K13
      final numberStr = (index + 1).toString();
      return Container(
        margin: EdgeInsets.only(bottom: bottomMargin),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ColorUtils.slate50, // neutral container background
          border: Border.all(color: ColorUtils.slate200), // slate border
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE), // blue indicator background
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    numberStr,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E40AF), // blue-700
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              content,
              style: TextStyle(
                fontSize: 11,
                color: ColorUtils.slate600,
                height: 1.55,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget buildAttachmentCard(BuildContext context) {
    final format = LessonPlanFormat.fromMap(lessonPlan);
    final filePath = lessonPlan['file_path']?.toString() ?? '';
    if (filePath.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ColorUtils.slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.attachment_rounded,
                  size: 14,
                  color: ColorUtils.slate700,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lampiran',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.brandDarkBlue,
                      ),
                    ),
                    Text(
                      '1 berkas · diunggah oleh guru',
                      style: TextStyle(
                        fontSize: 10,
                        color: ColorUtils.slate500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LessonPlanFileCard(
            filePath: filePath,
            isDownloading: false,
            primaryColor: format.brandColor,
            onTap: () => downloadAndOpenFile(context, filePath),
          ),
        ],
      ),
    );
  }

  BoxDecoration buildCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      border: Border.all(color: ColorUtils.slate200),
      boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
    );
  }

  // Abstract methods from other mixins
  Future<void> downloadAndOpenFile(BuildContext context, String? filePath);
}
