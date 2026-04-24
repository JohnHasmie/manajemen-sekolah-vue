// ParentStudentSelector — dropdown for a parent to pick which child's activities to view.
//
// Extracted from `ParentClassActivityScreenState._buildStudentSelector`.
// Like a Vue `<StudentSelector :students="list" :selected="id" @change="onChanged" />`.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// A student-picker dropdown used by the parent class activity screen.
///
/// When a parent has multiple children this renders a labelled [DropdownButton]
/// so they can switch between them. When [studentList] is empty it shows a
/// warning banner instead (no children are linked to this account).
///
/// Props (constructor params — like Vue props):
/// - [studentList]        — raw API list of student maps for this parent
/// - [selectedStudentId]  — currently selected student id (null = none chosen)
/// - [selectorKey]        — [GlobalKey] for the tutorial coach-mark target
/// - [onStudentChanged]   — callback fired with the newly selected student id;
///                          the parent is responsible for calling setState and
///                          re-loading activities — no setState inside this widget
class ParentStudentSelector extends StatelessWidget {
  final List<dynamic> studentList;
  final String? selectedStudentId;
  final GlobalKey selectorKey;

  /// Called when the user picks a different student from the dropdown.
  /// Receives the new student id. Parent handles setState + data reload.
  final ValueChanged<String?> onStudentChanged;

  const ParentStudentSelector({
    super.key,
    required this.studentList,
    required this.selectedStudentId,
    required this.selectorKey,
    required this.onStudentChanged,
  });

  @override
  Widget build(BuildContext context) {
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
                          '${AppLocalizations.classString.tr}: $className • NIS: $nis',
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
              onChanged: onStudentChanged,
            ),
          ),
        ],
      ),
    );
  }
}
