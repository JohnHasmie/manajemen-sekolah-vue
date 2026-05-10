// Deprecation shim — the per-section editor lives back in a draggable
// bottom sheet (`AppDraggableSheet`) at 96% viewport, not a full-page
// route. This keeps the sheet feel (covers the bottom nav, status
// bar peeks above) while still giving Quill almost the entire
// screen.
//
// New entry point:
//   `showLessonPlanSectionEditorSheet(...)` in
//   `lib/features/lesson_plans/presentation/widgets/lesson_plan_section_editor_sheet.dart`
//
// This file stays only to keep stale imports compiling — the
// `LessonPlanSectionEditorScreen.show(...)` factory now forwards to
// the sheet helper. Delete this file once `dart analyze` reports no
// remaining imports.

import 'package:flutter/material.dart';

import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_section_editor_sheet.dart';

export 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_section_editor_sheet.dart'
    show SectionEditResult, showLessonPlanSectionEditorSheet;

/// Forwards to [showLessonPlanSectionEditorSheet] so legacy callers
/// keep working while we sweep the codebase. Prefer the sheet helper
/// directly in new code.
@Deprecated(
  'Use showLessonPlanSectionEditorSheet instead — the per-section '
  'editor is a draggable sheet again, not a full-page route.',
)
class LessonPlanSectionEditorScreen {
  const LessonPlanSectionEditorScreen._();

  static Future<SectionEditResult?> show({
    required BuildContext context,
    required String lessonPlanId,
    required String fieldKey,
    required String fieldLabel,
    required String currentHtml,
    Map<String, dynamic>? regenInfo,
    String? formatLabel,
  }) {
    return showLessonPlanSectionEditorSheet(
      context: context,
      lessonPlanId: lessonPlanId,
      fieldKey: fieldKey,
      fieldLabel: fieldLabel,
      currentHtml: currentHtml,
      regenInfo: regenInfo,
      formatLabel: formatLabel,
    );
  }
}
