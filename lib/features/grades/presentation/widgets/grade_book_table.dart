// Grade Book Table widget -- the frozen-column spreadsheet view.
// Like a Vue `<GradeBookTable>` presentational component.
//
// Extracted from grade_book_screen.dart (_buildGradeTable).
// Receives all data as constructor props (no Riverpod access here).
// In Laravel terms, this is the View layer only.
//
// Contains:
// - [GradeBookTable] -- the read-only two-panel grade spreadsheet

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// The frozen-column grade spreadsheet for the grade book.
///
/// Like a Vue `<GradeBookTable :students="..." :headers="...">` component.
/// The left panel (120 px) is frozen (student names), the right panel
/// scrolls horizontally. Rows are 60 px tall.
///
/// All interaction callbacks are passed in — this widget contains zero state.
///
/// Props (like Vue props):
/// - [filteredStudentList] -- rows to display (already filtered by search)
/// - [filteredGradeTypeList] -- which grade types are currently visible
/// - [assessmentHeaders] -- per-type column headers from the API
/// - [canEdit] -- whether the logged-in user is a teacher who may edit
/// - [isReadOnly] -- whether the current academic year is read-only
/// - [primaryColor] -- role-based accent color from the parent
/// - [horizontalScrollController] -- shared scroll controller for sync
/// - [languageProvider] -- current UI language
/// - [getGradeTypeLabel] -- label resolver for each grade type code
/// - [getGradeForStudentAndHeader] -- lookup for a single grade record
/// - [formatGradeValue] -- formats a raw grade value for display
/// - [onColumnTap] -- called when a column header is tapped (options menu)
/// - [onAddAssessment] -- called when "add" button for a type is tapped
/// - [onCellTap] -- called when a student cell is tapped to open input form
class GradeBookTable extends StatelessWidget {
  final List<Student> filteredStudentList;
  final List<String> filteredGradeTypeList;
  final Map<String, List<Map<String, dynamic>>> assessmentHeaders;
  final bool canEdit;
  final bool isReadOnly;
  final Color primaryColor;
  final ScrollController horizontalScrollController;
  final LanguageProvider languageProvider;

  // Callbacks passed down from the stateful screen (like Vue $emit)
  final String Function(String type, LanguageProvider lang) getGradeTypeLabel;
  final Map<String, dynamic>? Function(
    Student student,
    String type,
    Map<String, dynamic> header,
  )
  getGradeForStudentAndHeader;
  final String Function(dynamic value) formatGradeValue;
  final void Function(String type, Map<String, dynamic> header) onColumnTap;
  final void Function(String type) onAddAssessment;
  final void Function(
    Student student,
    String type,
    Map<String, dynamic> header,
  )
  onCellTap;

  const GradeBookTable({
    super.key,
    required this.filteredStudentList,
    required this.filteredGradeTypeList,
    required this.assessmentHeaders,
    required this.canEdit,
    required this.isReadOnly,
    required this.primaryColor,
    required this.horizontalScrollController,
    required this.languageProvider,
    required this.getGradeTypeLabel,
    required this.getGradeForStudentAndHeader,
    required this.formatGradeValue,
    required this.onColumnTap,
    required this.onAddAssessment,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    // Left side: Fixed names (120px)
    final leftSide = Container(
      width: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: ColorUtils.slate200, width: 2)),
      ),
      child: Column(
        children: [
          // Header Nama
          Container(
            height: 70,
            width: 120,
            padding: EdgeInsets.all(AppSpacing.md),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: primaryColor,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
            ),
            child: Text(
              languageProvider.getTranslatedText({'en': 'Name', 'id': 'Nama'}),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
          // Student Names
          ...filteredStudentList.map((student) {
            return Container(
              height: 60,
              width: 120,
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: ColorUtils.slate200)),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    student.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      color: ColorUtils.slate800,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    '${languageProvider.getTranslatedText({'en': 'NIS', 'id': 'NIS'})}: ${student.studentNumber}',
                    style: TextStyle(fontSize: 10, color: ColorUtils.slate500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );

    // Right side items calculation
    double rightSideWidth = 0;
    for (var type in filteredGradeTypeList) {
      final headers = assessmentHeaders[type] ?? [];
      rightSideWidth +=
          (headers.length * 90.0) +
          (canEdit && !isReadOnly ? 65.0 : 0.0); // Increased spacer to 65
    }

    final rightSide = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: horizontalScrollController,
      child: SizedBox(
        width: rightSideWidth,
        child: Column(
          children: [
            // Right Header Row
            Container(
              height: 70,
              decoration: BoxDecoration(
                color: primaryColor,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: filteredGradeTypeList.expand((type) {
                  final headers = assessmentHeaders[type] ?? [];
                  final List<Widget> widgets = [];

                  // Existing columns headers
                  for (var header in headers) {
                    final String date = header['date'];
                    final String? title = header['title'];
                    final parts = date.split('-');
                    final displayDate = parts.length == 3
                        ? "${parts[2]}/${parts[1]}"
                        : date;

                    widgets.add(
                      InkWell(
                        onTap: () => onColumnTap(type, header),
                        child: Container(
                          width: 90,
                          padding: EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: ColorUtils.slate200),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                title != null && title.isNotEmpty
                                    ? title
                                    : getGradeTypeLabel(type, languageProvider),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                displayDate,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // Add button header
                  if (canEdit && !isReadOnly) {
                    widgets.add(
                      Container(
                        width: 65,
                        padding: EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: ColorUtils.slate300,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              getGradeTypeLabel(type, languageProvider),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 2),
                            InkWell(
                              onTap: () => onAddAssessment(type),
                              child: Icon(
                                Icons.add_circle_outline,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return widgets;
                }).toList(),
              ),
            ),
            // Right Side Rows (Values)
            ...filteredStudentList.map((student) {
              return Container(
                height: 60,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: ColorUtils.slate200),
                  ),
                ),
                child: Row(
                  children: filteredGradeTypeList.expand((type) {
                    final headers = assessmentHeaders[type] ?? [];
                    final List<Widget> widgets = [];

                    for (var header in headers) {
                      final gradeRecord = getGradeForStudentAndHeader(
                        student,
                        type,
                        header,
                      );
                      final scoreText = gradeRecord?.isNotEmpty == true
                          ? formatGradeValue(gradeRecord!['nilai'])
                          : '-';
                      final hasValue = gradeRecord?.isNotEmpty == true;

                      widgets.add(
                        Container(
                          width: 90,
                          padding: EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: ColorUtils.slate100),
                            ),
                          ),
                          child: GestureDetector(
                            onTap: (canEdit && !isReadOnly)
                                ? () => onCellTap(student, type, header)
                                : null,
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: hasValue
                                    ? ColorUtils.success600.withValues(
                                        alpha: 0.08,
                                      )
                                    : ColorUtils.slate50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: hasValue
                                      ? ColorUtils.success600.withValues(
                                          alpha: 0.3,
                                        )
                                      : ColorUtils.slate200,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  scoreText,
                                  style: TextStyle(
                                    fontWeight: hasValue
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: hasValue
                                        ? ColorUtils.success600
                                        : ColorUtils.slate500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    if (canEdit && !isReadOnly) {
                      widgets.add(
                        Container(
                          width: 65,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: ColorUtils.slate200),
                            ),
                            color: ColorUtils.slate50.withValues(alpha: 0.3),
                          ),
                        ),
                      );
                    }

                    return widgets;
                  }).toList(),
                ),
              );
            }),
          ],
        ),
      ),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          leftSide,
          Expanded(child: rightSide),
        ],
      ),
    );
  }
}
