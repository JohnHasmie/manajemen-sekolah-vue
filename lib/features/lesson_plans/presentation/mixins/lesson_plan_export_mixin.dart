// DEPRECATED — retired during the AI/manual RPP detail-screen split.
//
// PDF + text export and the file-attachment download now live inline
// in each kind-specific screen:
//   • screens/ai/ai_rpp_detail_screen.dart     (AI-generated RPPs)
//   • screens/manual/manual_rpp_detail_screen.dart  (manual uploads)
//
// Both copies share the same logic body — kept duplicated rather than
// extracted because the duplication is a few dozen lines and the
// previous "share via mixin" arrangement made it impossible to evolve
// either side without breaking the other.
//
// This file is kept as an empty stub because the in-sandbox filesystem
// doesn't allow `unlink`. A follow-up `git rm` on a real dev machine
// will retire it physically.
