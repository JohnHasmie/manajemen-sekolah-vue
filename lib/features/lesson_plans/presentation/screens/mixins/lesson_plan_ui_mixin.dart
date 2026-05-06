// DEPRECATED — retired during the AI/manual RPP detail-screen split.
//
// The detail-screen UI helpers (export menu, regen-confirmation
// dialogs, "limit reached" alert) now live inline in each kind-
// specific screen:
//   • screens/ai/ai_rpp_detail_screen.dart     (AI-generated RPPs)
//   • screens/manual/manual_rpp_detail_screen.dart  (manual uploads)
//
// The AI-result-screen launcher (`openAiLessonPlanScreen`) has no
// remaining call sites either — the post-generation flow already
// uses `LessonPlanAiResultScreen.show(...)` directly.
//
// This file is kept as an empty stub because the in-sandbox filesystem
// doesn't allow `unlink`. A follow-up `git rm` on a real dev machine
// will retire it physically.
