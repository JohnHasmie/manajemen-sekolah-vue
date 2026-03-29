// Scrollable table for entering grades for multiple students at once.
// Like a spreadsheet component — each row is a student with a grade and description field.
// In Laravel terms, this is the "bulk store" input table for GradeController@store.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// A horizontally and vertically scrollable table of grade inputs,
/// one row per student. Notifies parent via [onGradeChanged] and
/// [onDescriptionChanged] callbacks instead of calling setState directly.
class GradeInputTable extends StatelessWidget {
  final List<Student> studentList;
  final Map<String, TextEditingController> tableControllers;
  final Map<String, FocusNode> tableFocusNodes;
  final LanguageProvider languageProvider;

  /// Called when the grade text field for [studentId] changes.
  final void Function(String studentId, String value) onGradeChanged;

  /// Called when the description text field for [studentId] changes.
  final void Function(String studentId, String value) onDescriptionChanged;

  const GradeInputTable({
    super.key,
    required this.studentList,
    required this.tableControllers,
    required this.tableFocusNodes,
    required this.languageProvider,
    required this.onGradeChanged,
    required this.onDescriptionChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate width for horizontal scroll when screen is narrow
    double tableWidth = 150.0; // Name column
    tableWidth += 100.0; // Grade column
    tableWidth += 200.0; // Description column

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: MediaQuery.of(context).size.width > 600
              ? MediaQuery.of(context).size.width
              : tableWidth,
          child: Column(
            children: [
              // Header row (sticky-like appearance)
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: ColorUtils.corporateBlue600.withValues(alpha: 0.05),
                  border: Border(
                    bottom: BorderSide(color: ColorUtils.slate200),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 150,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Name',
                          'id': 'Nama',
                        }),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      width: 100,
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Grade',
                          'id': 'Nilai',
                        }),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Description',
                            'id': 'Deskripsi',
                          }),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // One data row per student
              ...studentList.map((student) {
                final gradeKey = '${student.id}_nilai';
                final deskripsiKey = '${student.id}_deskripsi';

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: ColorUtils.slate200),
                    ),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      // Name column
                      Container(
                        width: 150,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: ColorUtils.slate900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              student.studentNumber,
                              style: TextStyle(
                                fontSize: 10,
                                color: ColorUtils.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Grade input column
                      Container(
                        width: 100,
                        padding: EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: ColorUtils.slate200),
                            right: BorderSide(color: ColorUtils.slate200),
                          ),
                        ),
                        child: TextFormField(
                          controller: tableControllers[gradeKey],
                          focusNode: tableFocusNodes[gradeKey],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ColorUtils.slate900),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: '-',
                            hintStyle: TextStyle(color: ColorUtils.slate400),
                            errorStyle: TextStyle(fontSize: 10),
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (int.tryParse(value) == null) {
                                return languageProvider.getTranslatedText({
                                  'en': 'Integer only',
                                  'id': 'Hanya angka bulat',
                                });
                              }
                              final numValue = int.parse(value);
                              if (numValue < 0 || numValue > 100) {
                                return languageProvider.getTranslatedText({
                                  'en': '0-100',
                                  'id': '0-100',
                                });
                              }
                            }
                            return null;
                          },
                          onChanged: (value) => onGradeChanged(student.id, value),
                        ),
                      ),
                      // Description input column
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: TextFormField(
                            controller: tableControllers[deskripsiKey],
                            focusNode: tableFocusNodes[deskripsiKey],
                            style: TextStyle(color: ColorUtils.slate900),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: languageProvider.getTranslatedText({
                                'en': 'Add description...',
                                'id': 'Tambah deskripsi...',
                              }),
                              hintStyle: TextStyle(
                                color: ColorUtils.slate400,
                                fontSize: 12,
                              ),
                            ),
                            onChanged: (value) =>
                                onDescriptionChanged(student.id, value),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
