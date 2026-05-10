// Deprecated — replaced by the format chooser sheet (Frame B).
//
// The legacy two-tile Manual-vs-AI picker has been replaced by
// `lesson_plan_format_chooser_sheet.dart` which presents 4 format
// options (K13 / RPP 1 Halaman / Modul Ajar / Upload File). AI vs
// Manual is now a sub-axis surfaced inside the setup form (Frame C)
// for the structured formats.
//
// Kept as an empty shim so any in-flight imports don't break the
// build. Safe to delete once all branches have been updated.
//
// See: lib/features/lesson_plans/presentation/widgets/
//      lesson_plan_format_chooser_sheet.dart
library;

@Deprecated(
  'Use showLessonPlanFormatChooserSheet() instead — the legacy '
  'AddLessonPlanActionSheet two-tile picker has been replaced by the '
  '4-format chooser. See lesson_plan_format_chooser_sheet.dart.',
)
class AddLessonPlanActionSheet {
  const AddLessonPlanActionSheet._();
}
