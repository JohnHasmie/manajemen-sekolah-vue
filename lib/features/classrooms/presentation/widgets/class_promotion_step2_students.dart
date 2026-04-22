import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_section_header.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_stat_row.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Step 2: Student selection widget.
/// Displays statistics and buttons to select students for promotion.
class ClassPromotionStep2Students extends StatelessWidget {
  final List<dynamic> students;
  final Set<String> selectedStudentIds;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final Function(dynamic) isAlreadyPromoted;
  final VoidCallback onSelectEligible;
  final VoidCallback onSelectManually;

  const ClassPromotionStep2Students({
    super.key,
    required this.students,
    required this.selectedStudentIds,
    required this.primaryColor,
    required this.languageProvider,
    required this.isAlreadyPromoted,
    required this.onSelectEligible,
    required this.onSelectManually,
  });

  @override
  Widget build(BuildContext context) {
    final eligibleStudents = students
        .where((s) => !isAlreadyPromoted(s))
        .length;
    final alreadyPromotedCount = students.length - eligibleStudents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PromotionSectionHeader(
          icon: Icons.people_rounded,
          title: languageProvider.getTranslatedText({
            'en': 'Student Selection',
            'id': 'Pilih Siswa',
          }),
          primaryColor: primaryColor,
        ),
        const SizedBox(height: AppSpacing.xs),

        // Stats card
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          child: Column(
            children: [
              PromotionStatRow(
                icon: Icons.groups_rounded,
                label: languageProvider.getTranslatedText({
                  'en': 'Total Students',
                  'id': 'Total Siswa',
                }),
                value: students.length.toString(),
                color: primaryColor,
              ),
              const SizedBox(height: AppSpacing.sm),
              PromotionStatRow(
                icon: Icons.check_circle_rounded,
                label: languageProvider.getTranslatedText({
                  'en': 'Eligible for Promotion',
                  'id': 'Bisa Naik Kelas',
                }),
                value: eligibleStudents.toString(),
                color: ColorUtils.success600,
              ),
              if (alreadyPromotedCount > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                PromotionStatRow(
                  icon: Icons.warning_rounded,
                  label: languageProvider.getTranslatedText({
                    'en': 'Already Promoted',
                    'id': 'Sudah Naik Kelas',
                  }),
                  value: alreadyPromotedCount.toString(),
                  color: ColorUtils.warning600,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(
                  Icons.select_all_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Eligible',
                    'id': 'Pilih Semua',
                  }),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: primaryColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  elevation: 0,
                ),
                onPressed: onSelectEligible,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                icon: Icon(
                  Icons.checklist_rounded,
                  size: 18,
                  color: primaryColor,
                ),
                label: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Manually',
                    'id': 'Pilih Siswa',
                  }),
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: primaryColor),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                onPressed: onSelectManually,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // Selected count badge
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selectedStudentIds.isNotEmpty
                ? ColorUtils.success600.withValues(alpha: 0.08)
                : ColorUtils.slate50,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(
              color: selectedStudentIds.isNotEmpty
                  ? ColorUtils.success600.withValues(alpha: 0.25)
                  : ColorUtils.slate200,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selectedStudentIds.isNotEmpty
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                size: 20,
                color: selectedStudentIds.isNotEmpty
                    ? ColorUtils.success600
                    : ColorUtils.slate500,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Selected: ${selectedStudentIds.length} students',
                  'id': 'Terpilih: ${selectedStudentIds.length} siswa',
                }),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: selectedStudentIds.isNotEmpty
                      ? ColorUtils.success600
                      : ColorUtils.slate700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
