import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_admin_detail_page.dart';

mixin ContentCardBuilderMixin on State<LessonPlanAdminDetailPage> {
  late Map<String, dynamic> lessonPlan;

  Widget buildContentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildContentTitle(),
          const SizedBox(height: AppSpacing.md),
          buildAllContentSections(),
        ],
      ),
    );
  }

  Widget buildContentTitle() {
    return Text(
      'Isi RPP',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: ColorUtils.slate600,
      ),
    );
  }

  Widget buildAllContentSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildContentSection('Kompetensi Inti', lessonPlan['core_competence']),
        buildContentSection('Kompetensi Dasar', lessonPlan['basic_competence']),
        buildContentSection('Indikator', lessonPlan['indicator']),
        buildContentSection(
          'Tujuan Pembelajaran',
          lessonPlan['learning_objective'],
        ),
        buildContentSection('Materi Pokok', lessonPlan['main_material']),
        buildContentSection(
          'Metode Pembelajaran',
          lessonPlan['learning_method'],
        ),
        buildContentSection('Media/Alat', lessonPlan['media_tools']),
        buildContentSection('Sumber Belajar', lessonPlan['learning_source']),
        buildContentSection(
          'Langkah-langkah Pembelajaran',
          lessonPlan['learning_activities'],
        ),
        buildContentSection('Penilaian', lessonPlan['assessment']),
      ],
    );
  }

  Widget buildAttachmentCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildAttachmentTitle(),
          const SizedBox(height: AppSpacing.md),
          buildDownloadButton(context),
        ],
      ),
    );
  }

  Widget buildAttachmentTitle() {
    return Text(
      'Lampiran',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: ColorUtils.slate600,
      ),
    );
  }

  Widget buildDownloadButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => downloadAndOpenFile(context, lessonPlan['file_path']),
      icon: const Icon(Icons.download),
      label: const Text('Download RPP'),
      style: ElevatedButton.styleFrom(
        backgroundColor: ColorUtils.primaryColor,
        foregroundColor: Colors.white,
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
  Widget buildContentSection(String title, String? content);
  Future<void> downloadAndOpenFile(BuildContext context, String? filePath);
}
