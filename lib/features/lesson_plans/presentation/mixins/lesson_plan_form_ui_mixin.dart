import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_form_dialog.dart';

/// Mixin providing utility methods for the manual lesson plan form.
///
/// Previously contained custom field builders (buildDialogTextField,
/// buildDialogDropdown). Those have been replaced by shared widgets
/// (FormTextField, FormDropdownField, FilterChipGrid) used directly
/// in the form dialog.
mixin LessonPlanFormUiMixin on State<LessonPlanFormDialog> {
  /// Gets the primary color for the teacher role.
  Color getPrimaryColor() => ColorUtils.getRoleColor('guru');
}
