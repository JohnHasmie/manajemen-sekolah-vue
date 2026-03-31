import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Student checklist section shown when target is "khusus" and a class is selected.
///
/// Renders a scrollable list of students with checkboxes. Calls [onToggleStudent]
/// when the user taps a row or its checkbox, and [onRefresh] when the refresh
/// icon is tapped.
class AddActivityStudentSelector extends StatelessWidget {
  final List<dynamic> studentList;
  final List<String> selectedStudents;
  final bool isLoading;
  final String initialTarget;
  final VoidCallback onRefresh;
  final void Function(String studentId, bool selected) onToggleStudent;
  final LanguageProvider languageProvider;

  const AddActivityStudentSelector({
    super.key,
    required this.studentList,
    required this.selectedStudents,
    required this.isLoading,
    required this.initialTarget,
    required this.onRefresh,
    required this.onToggleStudent,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Select Students',
                      'id': 'Pilih Siswa',
                    }),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (kDebugMode)
                    Text(
                      'Debug: Target=$initialTarget, Count=${studentList.length}, Loading=$isLoading',
                      style: TextStyle(
                        fontSize: 10,
                        color: ColorUtils.slate400,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh, size: 20),
              onPressed: onRefresh,
              tooltip: 'Refresh Students',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: ColorUtils.slate400),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: isLoading
              ? Center(child: CircularProgressIndicator())
              : studentList.isEmpty
              ? Center(child: Text(AppLocalizations.noStudentsInClass.tr))
              : SingleChildScrollView(
                  child: Column(
                    children: studentList.map((student) {
                      final studentId = student['id'].toString();
                      final isSelected = selectedStudents.contains(studentId);
                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        dense: true,
                        title: Text(
                          student['name']?.toString() ??
                              student['nama']?.toString() ??
                              'Unknown',
                          style: TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          student['student_number']?.toString() ??
                              student['nis']?.toString() ??
                              '',
                          style: TextStyle(fontSize: 11),
                        ),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (bool? checked) {
                            onToggleStudent(studentId, checked == true);
                          },
                        ),
                        onTap: () {
                          onToggleStudent(studentId, !isSelected);
                        },
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }
}
