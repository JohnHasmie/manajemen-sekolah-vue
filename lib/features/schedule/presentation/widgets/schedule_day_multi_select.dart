import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

class ScheduleDayMultiSelect extends StatelessWidget {
  final List<dynamic> days;
  final List<String> selectedDayIds;
  final Function(List<String>) onChanged;
  final LanguageProvider languageProvider;
  final Color primaryColor;
  final bool showValidationError;

  const ScheduleDayMultiSelect({
    super.key,
    required this.days,
    required this.selectedDayIds,
    required this.onChanged,
    required this.languageProvider,
    required this.primaryColor,
    this.showValidationError = false,
  });

  String _translateDayName(String dayName, String languageCode) {
    if (languageCode == 'en') return dayName;
    const dayMap = {
      'Monday': 'Senin',
      'Tuesday': 'Selasa',
      'Wednesday': 'Rabu',
      'Thursday': 'Kamis',
      'Friday': 'Jumat',
      'Saturday': 'Sabtu',
      'Sunday': 'Minggu',
    };
    return dayMap[dayName] ?? dayName;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({'en': 'Days', 'id': 'Hari'}),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: ColorUtils.slate700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: days.map((day) {
                  final dayId = day['id'].toString();
                  final isSelected = selectedDayIds.contains(dayId);
                  return FilterChip(
                    label: Text(
                      _translateDayName(
                        day['name'] ?? day['nama'] ?? 'Unknown',
                        languageProvider.currentLanguage,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      if (selected) {
                        onChanged([dayId]);
                      } else {
                        onChanged([]);
                      }
                    },
                    backgroundColor: Colors.white,
                    selectedColor: primaryColor.withValues(alpha: 0.12),
                    checkmarkColor: primaryColor,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: isSelected ? primaryColor : ColorUtils.slate600,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? primaryColor : ColorUtils.slate300,
                      width: 1,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  );
                }).toList(),
              ),
              if (showValidationError && selectedDayIds.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    languageProvider.getTranslatedText({
                      'en': 'Please select at least one day',
                      'id': 'Harap pilih minimal satu hari',
                    }),
                    style: TextStyle(color: Colors.red[700], fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
