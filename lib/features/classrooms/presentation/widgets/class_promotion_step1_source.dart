import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_section_header.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Step 1: Source class selection widget.
/// Displays dropdown to select the source class and shows student count info.
class ClassPromotionStep1Source extends StatelessWidget {
  final List<dynamic> classes;
  final String? selectedSourceClassId;
  final int studentCount;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final ValueChanged<String?> onClassSelected;
  final VoidCallback onClassLoadRequested;

  const ClassPromotionStep1Source({
    super.key,
    required this.classes,
    required this.selectedSourceClassId,
    required this.studentCount,
    required this.primaryColor,
    required this.languageProvider,
    required this.onClassSelected,
    required this.onClassLoadRequested,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PromotionSectionHeader(
          icon: Icons.school_rounded,
          title: languageProvider.getTranslatedText({
            'en': 'Select Source Class',
            'id': 'Pilih Kelas Asal',
          }),
          primaryColor: primaryColor,
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Source Class',
                  'id': 'Kelas Asal',
                }),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: ColorUtils.slate50,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(color: ColorUtils.slate200),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedSourceClassId,
                    isExpanded: true,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: ColorUtils.slate500,
                    ),
                    hint: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Select a class',
                        'id': 'Pilih kelas',
                      }),
                      style: TextStyle(
                        color: ColorUtils.slate400,
                        fontSize: 14,
                      ),
                    ),
                    items: classes.map<DropdownMenuItem<String>>((c) {
                      return DropdownMenuItem(
                        value: c['id'].toString(),
                        child: Text(
                          c['name'] ?? 'Unknown',
                          style: TextStyle(
                            color: ColorUtils.slate800,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      onClassSelected(val);
                      if (val != null) {
                        onClassLoadRequested();
                      }
                    },
                  ),
                ),
              ),
              if (selectedSourceClassId != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.06),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(8),
                          ),
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': '$studentCount students found in this class',
                            'id': '$studentCount siswa ditemukan di kelas ini',
                          }),
                          style: TextStyle(
                            fontSize: 13,
                            color: primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
