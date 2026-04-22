import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/form_field_section.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';

class ScheduleClassDropdown extends StatelessWidget {
  final List<dynamic> classes;
  final String selectedValue;
  final Function(String) onChanged;
  final LanguageProvider languageProvider;
  final Color primaryColor;

  const ScheduleClassDropdown({
    super.key,
    required this.classes,
    required this.selectedValue,
    required this.onChanged,
    required this.languageProvider,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return FormDropdownField<String>(
      label: languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
      isRequired: true,
      value: selectedValue.isEmpty ? null : selectedValue,
      items: classes
          .where((c) => (c['id']?.toString() ?? '').isNotEmpty)
          .map<DropdownMenuItem<String>>((classItem) {
            final model =
                Classroom.fromJson(classItem as Map<String, dynamic>);
            return DropdownMenuItem<String>(
              value: model.id,
              child: Text(model.name),
            );
          })
          .toList(),
      onChanged: (value) => onChanged(value ?? ''),
      hintText: languageProvider.getTranslatedText({
        'en': 'Select Class',
        'id': 'Pilih Kelas',
      }),
      errorText: selectedValue.isEmpty
          ? languageProvider.getTranslatedText({
              'en': 'Please select a class',
              'id': 'Harap pilih kelas',
            })
          : null,
    );
  }
}
