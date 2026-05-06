// DEPRECATED — retired during the AI/manual RPP detail-screen split.
//
// The dual-mode editor (sectioned Quill for AI / single text-field
// fallback for manual) has been replaced by a kind-specific widget:
//
//   • screens/ai/ai_rpp_editor_view.dart  — sectioned Quill only,
//     with the document-change listener that propagates edits back
//     into `lessonPlanData` (the listener was missing on the old
//     dual-mode widget, which is what caused saves to silently send
//     the original AI content untouched).
//
// Manual-upload RPPs no longer have an inline editor at all — edits
// go through `LessonPlanFormDialog`.
//
// This file is kept as an empty stub because the in-sandbox filesystem
// doesn't allow `unlink`. A follow-up `git rm` on a real dev machine
// will retire it physically.
