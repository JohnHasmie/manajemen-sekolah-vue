// Bottom sheet that shows read-only statistics for one assessment column.
// Like a Vue <AssessmentDetailModal> — shows type, date, title, graded count,
// average. All data is pre-computed by the parent and passed in as plain
// values.
//
// Migrated from `showDialog(Dialog(...))` with a hand-rolled gradient header
// to the shared [AppBottomSheet] + [BottomSheetFooter] chrome so this surface
// participates in the brand design system (drag handle → gradient header →
// scrollable detail rows → Samsung-safe OK footer).

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';

/// A read-only bottom sheet displaying summary statistics for a single
/// assessment column.
///
/// Think of it as a Vue `<AssessmentDetailModal>` component: data comes in
/// via props, nothing is emitted back (no mutations, just "OK" to close).
///
/// The parent screen pre-computes all stats (total students, graded count,
/// average score) and passes them as plain `String` values so this widget
/// stays stateless and easy to test.
class GradeAssessmentDetailDialog extends StatelessWidget {
  /// The primary brand colour used for the header gradient.
  final Color primaryColor;

  // ── Pre-resolved display strings from the parent ───────────────────────────
  final String labelTitle;
  final String labelType;
  final String labelDate;
  final String labelAssessmentTitle;
  final String labelTotalStudents;
  final String labelGraded;
  final String labelAverage;

  /// The resolved grade-type label, e.g. "UH/Ulangan".
  final String gradeTypeLabel;

  /// Formatted date string, e.g. "01/03/2024".
  final String formattedDate;

  /// Assessment title, or null if none.
  final String? assessmentTitle;

  /// Total number of students in the class.
  final int totalStudents;

  /// Number of students who have been graded.
  final int gradedCount;

  /// Class average score, already formatted to 2 decimal places.
  final String averageScore;

  const GradeAssessmentDetailDialog({
    super.key,
    required this.primaryColor,
    required this.labelTitle,
    required this.labelType,
    required this.labelDate,
    required this.labelAssessmentTitle,
    required this.labelTotalStudents,
    required this.labelGraded,
    required this.labelAverage,
    required this.gradeTypeLabel,
    required this.formattedDate,
    this.assessmentTitle,
    required this.totalStudents,
    required this.gradedCount,
    required this.averageScore,
  });

  // ── Small helper row — like a Vue computed `detailRow(label, value)`
  // ────────
  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: ColorUtils.slate800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: labelTitle,
      icon: Icons.assessment_outlined,
      primaryColor: primaryColor,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(labelType, gradeTypeLabel),
          _row(labelDate, formattedDate),
          if (assessmentTitle != null && assessmentTitle!.isNotEmpty)
            _row(labelAssessmentTitle, assessmentTitle!),
          Divider(color: ColorUtils.slate200),
          _row(labelTotalStudents, totalStudents.toString()),
          _row(labelGraded, '$gradedCount / $totalStudents'),
          _row(labelAverage, averageScore),
        ],
      ),
      footer: BottomSheetFooter(
        primaryLabel: 'OK',
        secondaryLabel: 'Tutup',
        primaryColor: primaryColor,
        onPrimary: () => AppNavigator.pop(context),
        onSecondary: () => AppNavigator.pop(context),
      ),
    );
  }
}

/// Opens [GradeAssessmentDetailDialog] as an [AppBottomSheet].
///
/// The screen calls this instead of building the dialog inline.
void showGradeAssessmentDetailDialog({
  required BuildContext context,
  required Color primaryColor,
  required String labelTitle,
  required String labelType,
  required String labelDate,
  required String labelAssessmentTitle,
  required String labelTotalStudents,
  required String labelGraded,
  required String labelAverage,
  required String gradeTypeLabel,
  required String formattedDate,
  String? assessmentTitle,
  required int totalStudents,
  required int gradedCount,
  required String averageScore,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => GradeAssessmentDetailDialog(
      primaryColor: primaryColor,
      labelTitle: labelTitle,
      labelType: labelType,
      labelDate: labelDate,
      labelAssessmentTitle: labelAssessmentTitle,
      labelTotalStudents: labelTotalStudents,
      labelGraded: labelGraded,
      labelAverage: labelAverage,
      gradeTypeLabel: gradeTypeLabel,
      formattedDate: formattedDate,
      assessmentTitle: assessmentTitle,
      totalStudents: totalStudents,
      gradedCount: gradedCount,
      averageScore: averageScore,
    ),
  );
}
