import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/generate_lesson_plan_form_dialog.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/generate_lesson_plan_utils_mixin.dart';

/// Marker mixin for UI-related dependencies in the generate lesson plan flow.
///
/// Previously contained custom field builders (buildDialogTextField,
/// buildDialogDropdown). Those have been replaced by shared widgets
/// (FormTextField, FormDropdownField, FilterChipGrid) used directly
/// in the form dialog.
mixin GenerateLessonPlanUiMixin
    on
        ConsumerState<GenerateLessonPlanFormDialog>,
        GenerateLessonPlanUtilsMixin {}
