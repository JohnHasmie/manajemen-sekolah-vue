import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/form_field_section.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

class ScheduleTermDropdown extends StatelessWidget {
  final List<dynamic> semesters;
  final String selectedValue;
  final Function(String) onChanged;
  final LanguageProvider languageProvider;
  final Color primaryColor;

  const ScheduleTermDropdown({
    super.key,
    required this.semesters,
    required this.selectedValue,
    required this.onChanged,
    required this.languageProvider,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return FormDropdownField<String>(
      label: languageProvider.getTranslatedText({
        'en': 'Semester',
        'id': 'Semester',
      }),
      isRequired: true,
      value: selectedValue.isEmpty ? null : selectedValue,
      items: semesters
          .where((sm) => (sm['id']?.toString() ?? '').isNotEmpty)
          .map<DropdownMenuItem<String>>((semester) {
            return DropdownMenuItem<String>(
              value: semester['id'].toString(),
              child: Text(semester['name'] ?? semester['nama'] ?? 'Unknown'),
            );
          })
          .toList(),
      onChanged: (value) => onChanged(value ?? ''),
      hintText: languageProvider.getTranslatedText({
        'en': 'Select Semester',
        'id': 'Pilih Semester',
      }),
      errorText: selectedValue.isEmpty
          ? languageProvider.getTranslatedText({
              'en': 'Please select a semester',
              'id': 'Harap pilih semester',
            })
          : null,
    );
  }
}
