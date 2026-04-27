import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';

class FilterDialogContent extends StatelessWidget {
  final String? selectedClassId;
  final String? selectedClassName;
  final String? selectedSubjectId;
  final String? selectedSubjectName;
  final List<Map<String, String>> availableClasses;
  final List<dynamic> subjectList;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final ValueChanged<String?> onClassIdChanged;
  final ValueChanged<String?> onClassNameChanged;
  final ValueChanged<String?> onSubjectIdChanged;
  final ValueChanged<String?> onSubjectNameChanged;
  final ValueChanged<List<dynamic>> onSubjectListChanged;
  final VoidCallback onReset;
  final VoidCallback onApply;
  final VoidCallback onCancel;

  const FilterDialogContent({
    super.key,
    required this.selectedClassId,
    required this.selectedClassName,
    required this.selectedSubjectId,
    required this.selectedSubjectName,
    required this.availableClasses,
    required this.subjectList,
    required this.primaryColor,
    required this.languageProvider,
    required this.onClassIdChanged,
    required this.onClassNameChanged,
    required this.onSubjectIdChanged,
    required this.onSubjectNameChanged,
    required this.onSubjectListChanged,
    required this.onReset,
    required this.onApply,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AppFilterBottomSheet(
      title: languageProvider.getTranslatedText({
        'en': 'Filter Grades',
        'id': 'Filter Nilai',
      }),
      icon: Icons.tune_rounded,
      primaryColor: primaryColor,
      maxHeightFactor: 0.75,
      onApply: onApply,
      onReset: onReset,
      content: TeacherFilterContent(
        sections: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: languageProvider.getTranslatedText({
                  'en': 'Class',
                  'id': 'Kelas',
                }),
                icon: Icons.class_outlined,
                primaryColor: primaryColor,
              ),
              FilterChipGrid<String>(
                options: availableClasses.map((c) {
                  return FilterOption<String>(
                    value: c['id']!,
                    label: c['name']!,
                  );
                }).toList(),
                selectedValue: selectedClassId,
                onSelected: (classId) {
                  final isSelected = classId == selectedClassId;
                  onClassIdChanged(isSelected ? null : classId);
                  final match = availableClasses.where(
                    (c) => c['id'] == classId,
                  );
                  final className = match.isNotEmpty
                      ? match.first['name']
                      : null;
                  onClassNameChanged(isSelected ? null : className);
                  onSubjectIdChanged(null);
                  onSubjectNameChanged(null);
                  onSubjectListChanged([]);
                },
                selectedColor: primaryColor,
              ),
            ],
          ),
          if (subjectList.isNotEmpty || selectedClassId != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilterSectionHeader(
                  title: languageProvider.getTranslatedText({
                    'en': 'Subject',
                    'id': 'Mapel',
                  }),
                  icon: Icons.book_outlined,
                  primaryColor: primaryColor,
                ),
                if (subjectList.isEmpty && selectedClassId != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Loading subjects...',
                        'id': 'Memuat mapel...',
                      }),
                      style: TextStyle(
                        color: ColorUtils.slate500,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  FilterChipGrid<String>(
                    options: subjectList.map((s) {
                      final sid = s['id']?.toString() ?? '';
                      final sname = (s['name'] ?? s['nama'] ?? '-').toString();
                      return FilterOption<String>(value: sid, label: sname);
                    }).toList(),
                    selectedValue: selectedSubjectId,
                    onSelected: (subjectId) {
                      final isSelected = subjectId == selectedSubjectId;
                      onSubjectIdChanged(isSelected ? null : subjectId);
                      final subjectName =
                          subjectList.firstWhere(
                            (s) => s['id']?.toString() == subjectId,
                            orElse: () => {'name': null, 'nama': null},
                          )['name'] ??
                          subjectList.firstWhere(
                            (s) => s['id']?.toString() == subjectId,
                            orElse: () => {'nama': null},
                          )['nama'];
                      onSubjectNameChanged(isSelected ? null : subjectName);
                    },
                    selectedColor: primaryColor,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
