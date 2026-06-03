// Reusable form field widgets for the classroom add/edit bottom sheet.
//
// Like Vue `<BaseInput>`, `<GradeDropdown>`, and `<TeacherDropdown>` components
// that are used inside a form modal.  Stateless — all state lives in the
// parent [_showAddEditDialog] StatefulBuilder.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// A styled text field matching the classroom management bottom-sheet design.
///
/// Props:
/// - [controller] — the [TextEditingController] owned by the parent
/// - [label] — the floating label text
/// - [icon] — prefix icon (e.g. [Icons.school])
class ClassroomDialogTextField extends StatelessWidget {
  const ClassroomDialogTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(icon, color: ColorUtils.corporateBlue600, size: 18),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(
              color: ColorUtils.corporateBlue600,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
      ),
    );
  }
}

/// A styled grade-level dropdown for the classroom form.
///
/// Props:
/// - [value] — currently selected grade string (e.g. "7")
/// - [onChanged] — callback when the user picks a different grade
/// - [availableGradeLevels] — list of grade strings available for this school
/// - [languageProvider] — for translating the label
class ClassroomGradeLevelDropdown extends StatelessWidget {
  const ClassroomGradeLevelDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    required this.availableGradeLevels,
    required this.languageProvider,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final List<String> availableGradeLevels;
  final LanguageProvider languageProvider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: languageProvider.getTranslatedText({
            'en': 'Grade Level',
            'id': 'Tingkat Kelas',
          }),
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(
            Icons.layers_outlined,
            color: ColorUtils.corporateBlue600,
            size: 18,
          ),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(
              color: ColorUtils.corporateBlue600,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        items: availableGradeLevels.map((gradeStr) {
          final grade = int.tryParse(gradeStr) ?? 0;
          String gradeText;
          if (grade <= 6) {
            gradeText = 'Kelas $grade SD';
          } else if (grade <= 9) {
            gradeText = 'Kelas $grade SMP';
          } else {
            gradeText = 'Kelas $grade SMA';
          }
          return DropdownMenuItem<String>(
            value: gradeStr,
            child: Text(gradeText),
          );
        }).toList(),
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        dropdownColor: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: ColorUtils.slate500,
        ),
      ),
    );
  }
}

/// A styled homeroom-teacher dropdown for the classroom form.
///
/// Deduplicates teachers by ID and validates that [value] exists in the list
/// (falls back to null if the previously-assigned teacher was deleted).
///
/// Props:
/// - [value] — currently selected teacher ID string, or null
/// - [onChanged] — callback with the newly selected teacher ID
/// - [teachers] — raw teacher list from API ([_teachers] in parent state)
/// - [languageProvider] — for translating labels
class ClassroomHomeroomTeacherDropdown extends StatelessWidget {
  const ClassroomHomeroomTeacherDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    required this.teachers,
    required this.languageProvider,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final List<dynamic> teachers;
  final LanguageProvider languageProvider;

  @override
  Widget build(BuildContext context) {
    // Deduplicate teachers based on ID (API may return duplicates)
    final uniqueTeachers = <String, Map<String, dynamic>>{};
    for (final teacher in teachers) {
      final model = Teacher.fromJson(teacher);
      if (model.id.isNotEmpty) {
        uniqueTeachers[model.id] = Map<String, dynamic>.from(teacher);
      }
    }

    // Validate value — if the teacher no longer exists in the list, reset to
    // null
    String? validValue = value;
    if (validValue != null && !uniqueTeachers.containsKey(validValue)) {
      validValue = null;
    }

    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: validValue,
        decoration: InputDecoration(
          labelText: languageProvider.getTranslatedText({
            'en': 'Homeroom Teacher',
            'id': 'Wali Kelas',
          }),
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(
            Icons.person_outline,
            color: ColorUtils.corporateBlue600,
            size: 18,
          ),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(
              color: ColorUtils.corporateBlue600,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'No Homeroom Teacher',
                'id': 'Tidak ada wali kelas',
              }),
            ),
          ),
          ...uniqueTeachers.values.map((teacher) {
            final model = Teacher.fromJson(teacher);
            final teacherName = model.name.isNotEmpty ? model.name : 'Unknown';
            final teacherNip = model.employeeNumber ?? '';
            final displayText = teacherNip.isNotEmpty
                ? '$teacherName (NIP: $teacherNip)'
                : teacherName;
            return DropdownMenuItem<String>(
              value: model.id,
              child: Text(displayText, overflow: TextOverflow.ellipsis),
            );
          }),
        ],
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        dropdownColor: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: ColorUtils.slate500,
        ),
      ),
    );
  }
}
