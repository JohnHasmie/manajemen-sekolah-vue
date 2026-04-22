import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/form_field_section.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

class ScheduleAcademicYearDropdown extends StatelessWidget {
  final List<dynamic> academicYears;
  final String selectedValue;
  final String defaultYear;
  final Function(String) onChanged;
  final LanguageProvider languageProvider;
  final Color primaryColor;

  const ScheduleAcademicYearDropdown({
    super.key,
    required this.academicYears,
    required this.selectedValue,
    required this.defaultYear,
    required this.onChanged,
    required this.languageProvider,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final items = academicYears.isNotEmpty
        ? academicYears
        : [
            {'id': defaultYear, 'year': 'Current'},
          ];

    return FormDropdownField<String>(
      label: languageProvider.getTranslatedText({
        'en': 'Academic Year',
        'id': 'Tahun Ajaran',
      }),
      isRequired: true,
      value: selectedValue.isEmpty ? null : selectedValue,
      items: items
          .where((y) => (y['id']?.toString() ?? '').isNotEmpty)
          .map<DropdownMenuItem<String>>((year) {
            return DropdownMenuItem<String>(
              value: year['id'].toString(),
              child: Text(year['year'] ?? year['name'] ?? 'Unknown'),
            );
          })
          .toList(),
      onChanged: (value) => onChanged(value ?? ''),
      hintText: languageProvider.getTranslatedText({
        'en': 'Select Academic Year',
        'id': 'Pilih Tahun Ajaran',
      }),
      errorText: selectedValue.isEmpty
          ? languageProvider.getTranslatedText({
              'en': 'Please select an academic year',
              'id': 'Harap pilih tahun ajaran',
            })
          : null,
    );
  }
}
