import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/form_field_section.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

class ScheduleTeacherDropdown extends StatelessWidget {
  final List<dynamic> teachers;
  final String selectedValue;
  final Function(String) onChanged;
  final LanguageProvider languageProvider;
  final Color primaryColor;

  const ScheduleTeacherDropdown({
    super.key,
    required this.teachers,
    required this.selectedValue,
    required this.onChanged,
    required this.languageProvider,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    // Normalise FIRST, filter SECOND. The previous order
    // (`teachers.where((t) => t['id']...)`) silently dropped every
    // entry whose API shape used `teacher_id` instead of `id` — the
    // `Teacher.fromJson` aliasing only kicks in after the model is
    // constructed. That left the dropdown empty even when teachers
    // were loaded, so admins couldn't pick anyone in the add-jadwal
    // form.
    final items = teachers
        .whereType<Map<String, dynamic>>()
        .map(Teacher.fromJson)
        .where((t) => t.id.isNotEmpty)
        .map<DropdownMenuItem<String>>(
          (model) => DropdownMenuItem<String>(
            value: model.id,
            child: Text(model.name.isNotEmpty ? model.name : 'Unknown'),
          ),
        )
        .toList();

    return FormDropdownField<String>(
      label: languageProvider.getTranslatedText({
        'en': 'Teacher',
        'id': 'Guru',
      }),
      isRequired: true,
      value: selectedValue.isEmpty ? null : selectedValue,
      items: items,
      onChanged: (value) => onChanged(value ?? ''),
      hintText: languageProvider.getTranslatedText({
        'en': 'Select Teacher',
        'id': 'Pilih Guru',
      }),
      errorText: selectedValue.isEmpty
          ? languageProvider.getTranslatedText({
              'en': 'Please select a teacher',
              'id': 'Harap pilih guru',
            })
          : null,
    );
  }
}
