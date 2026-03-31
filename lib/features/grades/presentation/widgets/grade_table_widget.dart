// GradeTableWidget -- the frozen-left-column spreadsheet table for grade display.
//
// Like a Vue `<GradeTable>` component. Extracted from
// GradeBookPageState._buildGradeTable so the table layout lives in its own
// file and can be tested independently.
//
// Layout:
//   [ Fixed name column (120 px) | Horizontally scrollable grade columns ]
//
// The name column never scrolls; only the grade columns scroll horizontally.
// This is the "read mode" table. Edit mode uses a separate widget (EditTable).
//
// Props (like Vue props):
// - [filteredStudentList]        -- students to display (already filtered by search)
// - [filteredGradeTypeList]      -- which grade types are visible ('uh', 'tugas', ...)
// - [assessmentHeaders]          -- { type -> [{id, date, title}] } from the API
// - [gradeList]                  -- flat list of all grade records for cell lookup
// - [horizontalScrollController] -- shared controller for header/row sync
// - [canEdit]                    -- whether the logged-in user can edit grades
// - [isReadOnly]                 -- whether the academic year is locked
// - [primaryColor]               -- role-based accent color
// - [languageProvider]           -- for translated strings
// - [onColumnTap]                -- tapped an assessment header cell (shows detail)
// - [onCellTap]                  -- tapped a grade cell (opens input form)
// - [onAddAssessment]            -- tapped the + button at the end of a column group

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// The grade spreadsheet table used in [GradeBookPage] view (non-edit) mode.
///
/// Stateless -- all data and action callbacks are passed via constructor,
/// identical to how a Vue component receives props and emits events.
class GradeTableWidget extends StatelessWidget {
  final List<Student> filteredStudentList;
  final List<String> filteredGradeTypeList;
  final Map<String, List<Map<String, dynamic>>> assessmentHeaders;

  /// Flat list of all resolved grade records -- same as the state's [_gradeList].
  /// Used by [_getGradeForStudentAndHeader] to look up scores for each cell.
  final List<Map<String, dynamic>> gradeList;

  final ScrollController horizontalScrollController;
  final bool canEdit;
  final bool isReadOnly;
  final Color primaryColor;
  final LanguageProvider languageProvider;

  /// Called when the user taps an assessment column header.
  /// Args: (gradeType, header)
  final void Function(String type, Map<String, dynamic> header) onColumnTap;

  /// Called when the user taps a grade cell (to open the input form).
  /// Args: (student, gradeType, header)
  final void Function(
    Student student,
    String type,
    Map<String, dynamic> header,
  ) onCellTap;

  /// Called when the user taps the "+" add-assessment button for a grade type.
  /// Args: (gradeType)
  final void Function(String type) onAddAssessment;

  const GradeTableWidget({
    super.key,
    required this.filteredStudentList,
    required this.filteredGradeTypeList,
    required this.assessmentHeaders,
    required this.gradeList,
    required this.horizontalScrollController,
    required this.canEdit,
    required this.isReadOnly,
    required this.primaryColor,
    required this.languageProvider,
    required this.onColumnTap,
    required this.onCellTap,
    required this.onAddAssessment,
  });

  // ---------------------------------------------------------------------------
  // Grade lookup helpers (mirrors GradeBookPageState logic, no side effects)
  // ---------------------------------------------------------------------------

  /// Finds the grade record for [student] + [type] + [header] in [gradeList].
  ///
  /// Mirrors GradeBookPageState._getGradeForStudentAndHeader exactly --
  /// pure lookup, no setState, no API calls.
  Map<String, dynamic>? _getGradeForStudentAndHeader(
    Student student,
    String type,
    Map<String, dynamic> header,
  ) {
    try {
      final studentId = student.id.toString();
      final studentClassId = student.studentClassId?.toString();

      final result = gradeList.firstWhere((gradeItem) {
        final gradeStudentId = gradeItem['siswa_id']?.toString();
        final gradeStudentClassId = gradeItem['student_class_id']?.toString();

        bool studentMatch = gradeStudentId == studentId;
        if (!studentMatch &&
            (studentClassId != null || gradeStudentClassId != null)) {
          studentMatch =
              gradeStudentClassId == studentClassId ||
              gradeStudentId == studentClassId;
        }
        if (!studentMatch) return false;

        final headerId = header['id']?.toString();
        final currentAssessmentId = gradeItem['assessment_id']?.toString();

        if (headerId != null && currentAssessmentId != null) {
          if (headerId != currentAssessmentId) return false;
        } else if (headerId != null || currentAssessmentId != null) {
          return false;
        }

        final gradeDate = gradeItem['tanggal']?.toString().split('T')[0];
        final gradeType = gradeItem['jenis']?.toString().toLowerCase();
        final nTitle = (gradeItem['title'] ?? '').toString().trim();
        final hTitle = (header['title'] ?? '').toString().trim();

        return gradeType == type.toLowerCase() &&
            gradeDate == header['date'] &&
            nTitle == hTitle;
      }, orElse: () => <String, dynamic>{});

      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  /// Formats a raw grade value for display (e.g. 85.0 -> "85").
  String _formatGradeValue(dynamic value) {
    if (value == null) return '-';
    final d = double.tryParse(value.toString());
    if (d == null) return value.toString();
    return d % 1 == 0 ? d.toInt().toString() : d.toString();
  }

  // ---------------------------------------------------------------------------
  // Label helper
  // ---------------------------------------------------------------------------

  /// Human-readable label for each grade type key.
  /// Mirrors GradeBookPageState._getGradeTypeLabel.
  String _getGradeTypeLabel(String type) {
    switch (type) {
      case 'uh':
        return languageProvider.getTranslatedText({
          'en': 'Daily/Quiz',
          'id': 'UH/Ulangan',
        });
      case 'tugas':
        return languageProvider.getTranslatedText({
          'en': 'Assignment',
          'id': 'Tugas',
        });
      case 'uts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm',
          'id': 'UTS',
        });
      case 'uas':
        return languageProvider.getTranslatedText({
          'en': 'Final',
          'id': 'UAS',
        });
      case 'pts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm Exam',
          'id': 'PTS',
        });
      case 'pas':
        return languageProvider.getTranslatedText({
          'en': 'Final Exam',
          'id': 'PAS',
        });
      default:
        return type.toUpperCase();
    }
  }

  // ---------------------------------------------------------------------------
  // Build helpers
  // ---------------------------------------------------------------------------

  /// Fixed left column: student names.
  Widget _buildLeftColumn() {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: ColorUtils.slate200, width: 2)),
      ),
      child: Column(
        children: [
          // Header cell
          Container(
            height: 70,
            width: 120,
            padding: const EdgeInsets.all(AppSpacing.md),
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
          // Student name rows
          ...filteredStudentList.map(_buildNameCell),
        ],
      ),
    );
  }

  /// One name cell in the fixed left column.
  Widget _buildNameCell(Student student) {
    return Container(
      height: 60,
      width: 120,
      padding: const EdgeInsets.all(AppSpacing.sm),
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
  }

  /// Horizontally scrollable right section: assessment headers + grade cells.
  Widget _buildRightSection() {
    double rightSideWidth = 0;
    for (final type in filteredGradeTypeList) {
      final headers = assessmentHeaders[type] ?? [];
      rightSideWidth +=
          (headers.length * 90.0) + (canEdit && !isReadOnly ? 65.0 : 0.0);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: horizontalScrollController,
      child: SizedBox(
        width: rightSideWidth,
        child: Column(
          children: [
            _buildHeaderRow(),
            // Tearoff: _buildStudentRow is a named method so no closure needed
            ...filteredStudentList.map(_buildStudentRow),
          ],
        ),
      ),
    );
  }

  /// The header row with assessment date/title cells and "add" buttons.
  Widget _buildHeaderRow() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: primaryColor,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: filteredGradeTypeList.expand(_buildHeaderCells).toList(),
      ),
    );
  }

  /// Column header cells (assessment columns + optional add-button) for [type].
  Iterable<Widget> _buildHeaderCells(String type) {
    final headers = assessmentHeaders[type] ?? [];
    final List<Widget> widgets = [];

    for (final header in headers) {
      final String date = header['date'] as String;
      final String? title = header['title'] as String?;
      final parts = date.split('-');
      final displayDate = parts.length == 3 ? "${parts[2]}/${parts[1]}" : date;

      widgets.add(
        InkWell(
          onTap: () => onColumnTap(type, header),
          child: Container(
            width: 90,
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: ColorUtils.slate200)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title != null && title.isNotEmpty
                      ? title
                      : _getGradeTypeLabel(type),
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

    if (canEdit && !isReadOnly) {
      widgets.add(
        Container(
          width: 65,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: ColorUtils.slate300, width: 1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _getGradeTypeLabel(type),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
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
  }

  /// A single student's grade row across all visible columns.
  Widget _buildStudentRow(Student student) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ColorUtils.slate200)),
      ),
      child: Row(
        children: filteredGradeTypeList
            .expand((type) => _buildGradeCells(student, type))
            .toList(),
      ),
    );
  }

  /// Grade cells (and optional spacer) for [student] in column group [type].
  Iterable<Widget> _buildGradeCells(Student student, String type) {
    final headers = assessmentHeaders[type] ?? [];
    final List<Widget> widgets = [];

    for (final header in headers) {
      final gradeRecord = _getGradeForStudentAndHeader(student, type, header);
      final scoreText = gradeRecord?.isNotEmpty == true
          ? _formatGradeValue(gradeRecord!['score'])
          : '-';
      final hasValue = gradeRecord?.isNotEmpty == true;

      widgets.add(
        Container(
          width: 90,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: ColorUtils.slate100)),
          ),
          child: GestureDetector(
            onTap: (canEdit && !isReadOnly)
                ? () => onCellTap(student, type, header)
                : null,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: hasValue
                    ? ColorUtils.success600.withValues(alpha: 0.08)
                    : ColorUtils.slate50,
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                border: Border.all(
                  color: hasValue
                      ? ColorUtils.success600.withValues(alpha: 0.3)
                      : ColorUtils.slate200,
                ),
              ),
              child: Center(
                child: Text(
                  scoreText,
                  style: TextStyle(
                    fontWeight:
                        hasValue ? FontWeight.bold : FontWeight.normal,
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
            border: Border(right: BorderSide(color: ColorUtils.slate200)),
            color: ColorUtils.slate50.withValues(alpha: 0.3),
          ),
        ),
      );
    }

    return widgets;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLeftColumn(),
          Expanded(child: _buildRightSection()),
        ],
      ),
    );
  }
}
