// DEPRECATED — retired during the AI/manual RPP detail-screen split.
//
// The dual-mode preview (structured-fields view gated on `canRegen`
// vs formatted-content fallback) has been replaced by two kind-
// specific widgets:
//
//   • screens/ai/ai_rpp_preview_view.dart       — structured cards
//                                                 + Regenerasi Semua
//                                                 banner (AI only).
//   • screens/manual/manual_rpp_preview_view.dart — file card +
//                                                 formatted long-form
//                                                 (manual upload).
//
// Splitting let us drop `canRegen` and `_contentWasEdited` from the
// preview — which used to flip the layout to the manual-style
// fallback right after a save and required a screen refresh to
// recover.
//
// This file is kept as an empty stub because the in-sandbox filesystem
// doesn't allow `unlink`. A follow-up `git rm` on a real dev machine
// will retire it physically.
