// Class-selection dropdown for the material browser filter section.
// Extracted from TeacherMaterialScreenState._buildClassDropdown() to keep
// the screen file lean. Like a Vue <ClassDropdown /> sub-component.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Labelled dropdown that lets the teacher pick which class to browse.
///
/// Purely presentational — receives all data as constructor params and
/// calls [onClassChanged] instead of calling setState directly. In Vue
/// terms this is like a controlled <select> component that emits an
/// `update:modelValue` event.
///
/// [classList]       — list of class objects (maps with 'id' and 'name'/'nama').
/// [selectedClassId] — currently selected class ID (may be null before data loads).
/// [languageProvider]— drives the "Class" label translation.
/// [onClassChanged]  — emitted when the user picks a new class.
class MaterialClassDropdown extends StatelessWidget {
  final List<dynamic> classList;
  final String? selectedClassId;
  final LanguageProvider languageProvider;
  final ValueChanged<String> onClassChanged;

  const MaterialClassDropdown({
    super.key,
    required this.classList,
    required this.selectedClassId,
    required this.languageProvider,
    required this.onClassChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
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
              value: selectedClassId,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: ColorUtils.slate500),
              items: classList.map((c) {
                return DropdownMenuItem<String>(
                  value: c['id'],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.class_rounded,
                          size: 16,
                          color: ColorUtils.slate500,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            c['name'] ?? c['nama'] ?? 'Unknown',
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
                  onClassChanged(newValue);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
