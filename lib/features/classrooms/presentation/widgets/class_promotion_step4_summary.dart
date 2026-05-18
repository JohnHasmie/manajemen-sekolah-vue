import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_section_header.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_info_row.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Step 4: Summary widget.
/// Displays a summary of the promotion configuration and selected students.
class ClassPromotionStep4Summary extends StatelessWidget {
  final List<dynamic> classes;
  final List<dynamic> targetClasses;
  final List<dynamic> academicYears;
  final List<dynamic> students;
  final Set<String> selectedStudentIds;
  final String? selectedSourceClassId;
  final String? selectedTargetClassId;
  final String? selectedTargetYearId;
  final Color primaryColor;
  final LanguageProvider languageProvider;

  const ClassPromotionStep4Summary({
    super.key,
    required this.classes,
    required this.targetClasses,
    required this.academicYears,
    required this.students,
    required this.selectedStudentIds,
    required this.selectedSourceClassId,
    required this.selectedTargetClassId,
    required this.selectedTargetYearId,
    required this.primaryColor,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    final sourceClass = classes.firstWhere(
      (c) => c['id'].toString() == selectedSourceClassId,
      orElse: () => {'name': 'Unknown'},
    );
    final targetClass = targetClasses.firstWhere(
      (c) => c['id'].toString() == selectedTargetClassId,
      orElse: () => {'name': 'Unknown'},
    );
    final targetYear = academicYears.firstWhere(
      (y) => y['id'].toString() == selectedTargetYearId,
      orElse: () => {'year': 'Unknown'},
    );

    final selectedStudentsList = students
        .where((s) => selectedStudentIds.contains(s['id'].toString()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PromotionSectionHeader(
          icon: Icons.summarize_rounded,
          title: languageProvider.getTranslatedText({
            'en': 'Promotion Summary',
            'id': 'Ringkasan Kenaikan',
          }),
          primaryColor: primaryColor,
        ),
        const SizedBox(height: AppSpacing.xs),

        // Summary info card
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
              PromotionInfoRow(
                icon: Icons.school_rounded,
                label: languageProvider.getTranslatedText({
                  'en': 'Source Class',
                  'id': 'Kelas Asal',
                }),
                value: sourceClass['name'] ?? '-',
                primaryColor: primaryColor,
              ),
              PromotionInfoRow(
                icon: Icons.arrow_forward_rounded,
                label: languageProvider.getTranslatedText({
                  'en': 'Target Class',
                  'id': 'Kelas Tujuan',
                }),
                value: targetClass['name'] ?? '-',
                primaryColor: primaryColor,
              ),
              PromotionInfoRow(
                icon: Icons.calendar_today_rounded,
                label: languageProvider.getTranslatedText({
                  'en': 'Target Academic Year',
                  'id': 'Tahun Ajaran Tujuan',
                }),
                value: targetYear['year'] ?? '-',
                primaryColor: primaryColor,
              ),
              PromotionInfoRow(
                icon: Icons.people_rounded,
                label: languageProvider.getTranslatedText({
                  'en': 'Students to Promote',
                  'id': 'Siswa yang Dinaikkan',
                }),
                value: '${selectedStudentsList.length} siswa',
                primaryColor: primaryColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Student list
        PromotionSectionHeader(
          icon: Icons.list_rounded,
          title: languageProvider.getTranslatedText({
            'en': 'Selected Students (${selectedStudentsList.length})',
            'id': 'Siswa Terpilih (${selectedStudentsList.length})',
          }),
          primaryColor: primaryColor,
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: selectedStudentsList.length,
            separatorBuilder: (ctx, i) =>
                Divider(height: 1, color: ColorUtils.slate100),
            itemBuilder: (context, index) {
              final student = selectedStudentsList[index];
              final s = Student.fromJson(student as Map<String, dynamic>);
              final nameStr = s.name.isNotEmpty ? s.name : '-';
              final nameHash = nameStr.codeUnits.fold(0, (sum, c) => sum + c);
              final avatarColor = ColorUtils.getColorForIndex(nameHash);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: avatarColor.withValues(alpha: 0.15),
                      child: Text(
                        nameStr.isNotEmpty ? nameStr[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: avatarColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${index + 1}. $nameStr',
                        style: TextStyle(
                          fontSize: 13,
                          color: ColorUtils.slate800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
