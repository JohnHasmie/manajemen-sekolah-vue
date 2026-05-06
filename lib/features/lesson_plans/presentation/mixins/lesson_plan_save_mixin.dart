// DEPRECATED — retired during the AI/manual RPP detail-screen split.
//
// The old `RPPDetailPage` was a single screen that branched between
// AI-generated and manually-uploaded RPPs at runtime, and this mixin
// owned the dual-target save handler (PATCH AI backend OR core /rpp).
// That branching was the source of the "saves silently / UI flips
// after save" regressions.
//
// Each kind now has its own screen with its own save:
//   • AI-generated   → screens/ai/ai_rpp_detail_screen.dart
//   • Manual upload  → screens/manual/manual_rpp_detail_screen.dart
//
// This file is kept as an empty stub because the in-sandbox filesystem
// doesn't allow `unlink`. A follow-up `git rm` on a real dev machine
// will retire it physically.
