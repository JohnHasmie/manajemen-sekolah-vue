import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_section_header.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_dropdown.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Step 3: Target configuration widget.
/// Displays dropdowns to select target academic year and class,
/// and button to create a new class.
class ClassPromotionStep3Target extends StatelessWidget {
  final List<dynamic> academicYears;
  final List<dynamic> targetClasses;
  final String? selectedTargetYearId;
  final String? selectedTargetClassId;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final ValueChanged<String?> onYearChanged;
  final ValueChanged<String?> onClassChanged;
  final VoidCallback onCreateClassPressed;

  const ClassPromotionStep3Target({
    super.key,
    required this.academicYears,
    required this.targetClasses,
    required this.selectedTargetYearId,
    required this.selectedTargetClassId,
    required this.primaryColor,
    required this.languageProvider,
    required this.onYearChanged,
    required this.onClassChanged,
    required this.onCreateClassPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PromotionSectionHeader(
          icon: Icons.school_rounded,
          title: languageProvider.getTranslatedText({
            'en': 'Target Configuration',
            'id': 'Konfigurasi Tujuan',
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
            children: [
              PromotionDropdown(
                label: languageProvider.getTranslatedText({
                  'en': 'Target Academic Year',
                  'id': 'Tahun Ajaran Tujuan',
                }),
                value: selectedTargetYearId,
                items: academicYears.map<DropdownMenuItem<String>>((y) {
                  return DropdownMenuItem(
                    value: y['id'].toString(),
                    child: Text(
                      y['year'] ?? 'Unknown',
                      style: TextStyle(
                        color: ColorUtils.slate800,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onYearChanged,
                icon: Icons.calendar_today_rounded,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: AppSpacing.lg),
              PromotionDropdown(
                label: languageProvider.getTranslatedText({
                  'en': 'Target Class',
                  'id': 'Kelas Tujuan',
                }),
                value: selectedTargetClassId,
                items: targetClasses.isEmpty
                    ? []
                    : targetClasses.map<DropdownMenuItem<String>>((c) {
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
                onChanged: onClassChanged,
                hint: targetClasses.isEmpty
                    ? languageProvider.getTranslatedText({
                        'en': 'No classes found',
                        'id': 'Tidak ada kelas',
                      })
                    : null,
                icon: Icons.class_rounded,
                primaryColor: primaryColor,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.add_rounded, size: 18, color: primaryColor),
                  label: Text(
                    languageProvider.getTranslatedText({
                      'en': 'Create New Class',
                      'id': 'Buat Kelas Baru',
                    }),
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: primaryColor),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  onPressed: onCreateClassPressed,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
