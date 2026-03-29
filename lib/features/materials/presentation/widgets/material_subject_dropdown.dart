// Subject-selection dropdown for the material browser filter section.
// Extracted from TeacherMaterialScreenState._buildSubjectDropdown() to keep
// the screen file lean. Like a Vue <SubjectDropdown /> sub-component.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Labelled dropdown that lets the teacher pick which subject to browse.
///
/// Purely presentational — receives all data as constructor params and
/// calls [onSubjectChanged] instead of calling setState directly. In Vue
/// terms this is like a controlled <select> component that emits an
/// `update:modelValue` event.
///
/// [subjectList]       — list of subject objects (maps with 'id' and 'name'/'nama').
/// [selectedSubjectId] — currently selected subject ID (may be null before data loads).
/// [languageProvider]  — drives the "Subject" label translation.
/// [onSubjectChanged]  — emitted when the user picks a new subject.
class MaterialSubjectDropdown extends StatelessWidget {
  final List<dynamic> subjectList;
  final String? selectedSubjectId;
  final LanguageProvider languageProvider;
  final ValueChanged<String> onSubjectChanged;

  const MaterialSubjectDropdown({
    super.key,
    required this.subjectList,
    required this.selectedSubjectId,
    required this.languageProvider,
    required this.onSubjectChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({
            'en': 'Subject',
            'id': 'Mata Pelajaran',
          }),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate600,
          ),
        ),
        SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedSubjectId,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: ColorUtils.slate500),
              items: subjectList.map((mp) {
                return DropdownMenuItem<String>(
                  value: mp['id'],
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 16,
                          color: ColorUtils.slate500,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            mp['name'] ?? mp['nama'] ?? 'Unknown',
                            style: TextStyle(
                              color: ColorUtils.slate800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  onSubjectChanged(newValue);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
