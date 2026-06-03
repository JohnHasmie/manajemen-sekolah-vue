// Bottom-sheet widget showing actions for a single assessment column header.
// Like a Vue context-menu component — View Details, Edit, or Delete a column.
// Results are surfaced via callbacks so the parent screen drives navigation.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';

/// A modal bottom sheet that presents column-level actions for one assessment.
///
/// Mirrors what `_showColumnOptions` used to build inline: a gradient header
/// bar
/// then a list of action tiles (View Details, Edit Assessment, Delete
/// Assessment).
/// Think of it like a Vue `<ColumnContextMenu>` component.
///
/// Data flows in via constructor params; results flow out via named callbacks —
/// just like Vue props-in / emit-out.
class GradeColumnOptionsSheet extends StatelessWidget {
  /// Display label for the grade type, e.g. "UH/Ulangan".
  final String gradeTypeLabel;

  /// The formatted display title for the column header, e.g. "Quiz 1 (01/03/2024)".
  final String displayTitle;

  /// The primary brand colour used for the header gradient.
  final Color primaryColor;

  /// Whether the current user has edit permissions.
  final bool canEdit;

  /// Whether the grade book is in read-only mode (e.g. closed academic year).
  final bool isReadOnly;

  /// Called when the user taps "View Details". Parent shows
  /// [GradeAssessmentDetailDialog].
  final VoidCallback onViewDetails;

  /// Called when the user taps "Edit Assessment". Parent enters inline edit
  /// mode.
  final VoidCallback onEditAssessment;

  /// Called when the user taps "Delete Assessment". Parent shows confirm
  /// dialog.
  final VoidCallback onDeleteAssessment;

  // ── Bilingual label strings passed in from the parent ──────────────────────
  final String labelViewDetails;
  final String labelEditAssessment;
  final String labelDeleteAssessment;
  final String labelDeleteSubtitle;

  const GradeColumnOptionsSheet({
    super.key,
    required this.gradeTypeLabel,
    required this.displayTitle,
    required this.primaryColor,
    required this.canEdit,
    required this.isReadOnly,
    required this.onViewDetails,
    required this.onEditAssessment,
    required this.onDeleteAssessment,
    required this.labelViewDetails,
    required this.labelEditAssessment,
    required this.labelDeleteAssessment,
    required this.labelDeleteSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── View Details tile ───────────────────────────────────────────
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Icon(Icons.visibility, color: ColorUtils.corporateBlue600),
          ),
          title: Text(
            labelViewDetails,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate800,
            ),
          ),
          onTap: () {
            Navigator.pop(context);
            onViewDetails();
          },
        ),

        // ── Edit / Delete tiles — only when user can edit ───────────────
        if (canEdit && !isReadOnly) ...[
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: ColorUtils.warning600.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: Icon(Icons.edit, color: ColorUtils.warning600),
            ),
            title: Text(
              labelEditAssessment,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate800,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              onEditAssessment();
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: ColorUtils.error600.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: Icon(Icons.delete_outline, color: ColorUtils.error600),
            ),
            title: Text(
              labelDeleteAssessment,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: ColorUtils.error600,
              ),
            ),
            subtitle: Text(
              labelDeleteSubtitle,
              style: TextStyle(
                fontSize: 12,
                color: ColorUtils.error600.withValues(alpha: 0.7),
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              onDeleteAssessment();
            },
          ),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// Opens [GradeColumnOptionsSheet] as a modal bottom sheet.
///
/// The screen calls this thin wrapper instead of building the sheet inline —
/// like calling a Vue composable `openColumnMenu(header)`.
void showGradeColumnOptionsSheet({
  required BuildContext context,
  required String gradeTypeLabel,
  required String displayTitle,
  required Color primaryColor,
  required bool canEdit,
  required bool isReadOnly,
  required VoidCallback onViewDetails,
  required VoidCallback onEditAssessment,
  required VoidCallback onDeleteAssessment,
  required String labelViewDetails,
  required String labelEditAssessment,
  required String labelDeleteAssessment,
  required String labelDeleteSubtitle,
}) {
  AppBottomSheet.show(
    context: context,
    title: '$gradeTypeLabel - $displayTitle',
    icon: Icons.assessment_outlined,
    primaryColor: primaryColor,
    content: GradeColumnOptionsSheet(
      gradeTypeLabel: gradeTypeLabel,
      displayTitle: displayTitle,
      primaryColor: primaryColor,
      canEdit: canEdit,
      isReadOnly: isReadOnly,
      onViewDetails: onViewDetails,
      onEditAssessment: onEditAssessment,
      onDeleteAssessment: onDeleteAssessment,
      labelViewDetails: labelViewDetails,
      labelEditAssessment: labelEditAssessment,
      labelDeleteAssessment: labelDeleteAssessment,
      labelDeleteSubtitle: labelDeleteSubtitle,
    ),
  );
}
