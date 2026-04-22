import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/form_field_section.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';

class ScheduleSubjectDropdown extends StatelessWidget {
  final List<dynamic> subjects;
  final String selectedValue;
  final Function(String) onChanged;
  final LanguageProvider languageProvider;
  final Color primaryColor;
  final bool isLoading;

  const ScheduleSubjectDropdown({
    super.key,
    required this.subjects,
    required this.selectedValue,
    required this.onChanged,
    required this.languageProvider,
    required this.primaryColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return FormDropdownField<String>(
      label: languageProvider.getTranslatedText({
        'en': 'Subject',
        'id': 'Mata Pelajaran',
      }),
      isRequired: true,
      value: selectedValue.isEmpty ? null : selectedValue,
      items: subjects
          .map((s) => Subject.fromJson(s as Map<String, dynamic>))
          .where((model) => model.id.isNotEmpty)
          .map<DropdownMenuItem<String>>((model) {
            return DropdownMenuItem<String>(
              value: model.id,
              child: Text(model.name.isEmpty ? 'Unknown' : model.name),
            );
          })
          .toList(),
      onChanged: (value) {
        if (!isLoading) onChanged(value ?? '');
      },
      hintText: languageProvider.getTranslatedText({
        'en': 'Select Subject',
        'id': 'Pilih Mata Pelajaran',
      }),
      isLoading: isLoading,
      errorText: selectedValue.isEmpty
          ? languageProvider.getTranslatedText({
              'en': 'Please select a subject',
              'id': 'Harap pilih mata pelajaran',
            })
          : null,
    );
  }
}
