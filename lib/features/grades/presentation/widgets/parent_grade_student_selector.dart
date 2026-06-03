// Dropdown widget for selecting a child student in the parent grade screen.
// Mirrors the "Select Child" step in the UI; like a Vue `<StudentSelector>`
// component.
// Emits `onStudentChanged` instead of calling setState directly (callback
// pattern).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Dropdown that lets a parent pick one of their linked children.
///
/// In Laravel terms this is a `<select>` rendered from `$students` (the
/// [studentList]).  The [onStudentChanged] callback replaces `setState` —
/// the parent screen owns the selected value and reloads grades itself.
class ParentGradeStudentSelector extends StatelessWidget {
  /// All children linked to this parent account.
  final List<dynamic> studentList;

  /// The currently selected student ID (nullable when nothing selected yet).
  final String? selectedStudentId;

  /// Key used to anchor the onboarding tour spotlight on this widget.
  final GlobalKey selectorKey;

  /// Called when the user picks a different child from the dropdown.
  /// Passes the new student ID (nullable) — equivalent to `$emit('change',
  /// id)`.
  final ValueChanged<String?> onStudentChanged;

  const ParentGradeStudentSelector({
    super.key,
    required this.studentList,
    required this.selectedStudentId,
    required this.selectorKey,
    required this.onStudentChanged,
  });

  @override
  Widget build(BuildContext context) {
    // No children linked — show a warning banner instead of the dropdown.
    if (studentList.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: ColorUtils.warning600.withValues(alpha: 0.08),
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(
            color: ColorUtils.warning600.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ColorUtils.warning600.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: ColorUtils.warning600,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                AppLocalizations.noChildrenLinked.tr,
                style: TextStyle(
                  color: ColorUtils.slate700,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: selectorKey,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              AppLocalizations.selectChild.tr,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: ColorUtils.slate700,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DropdownButton<String>(
              value: selectedStudentId,
              isExpanded: true,
              underline: const SizedBox(),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: ColorUtils.slate500,
              ),
              items: studentList.map((student) {
                final model = Student.fromJson(student as Map<String, dynamic>);
                final className = model.className.isNotEmpty
                    ? model.className
                    : '-';
                final nis = model.studentNumber.isNotEmpty
                    ? model.studentNumber
                    : '-';
                return DropdownMenuItem<String>(
                  value: model.id,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          model.name.isNotEmpty
                              ? model.name
                              : AppLocalizations.nameNotAvailable.tr,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: ColorUtils.slate900,
                          ),
                        ),
                        Text(
                          '${AppLocalizations.classString.tr}: $className • '
                          'NIS: $nis',
                          style: TextStyle(
                            fontSize: 12,
                            color: ColorUtils.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              // Notify the parent screen; it owns setState and grade reload.
              onChanged: onStudentChanged,
            ),
          ),
        ],
      ),
    );
  }
}
