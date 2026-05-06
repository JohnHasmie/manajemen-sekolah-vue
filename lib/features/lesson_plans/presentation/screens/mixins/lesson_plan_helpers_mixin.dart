// DEPRECATED — retired during the AI/manual RPP detail-screen split.
//
// The thin field-lookup / display-title / strip-html helpers that
// used to live here are now inlined into the two kind-specific
// screens:
//   • screens/ai/ai_rpp_detail_screen.dart     (AI-generated RPPs)
//   • screens/manual/manual_rpp_detail_screen.dart  (manual uploads)
//
// Each screen carries its own copy because the helpers are tiny and
// the previous mixin coupling forced both kinds to share decisions
// (e.g. `hasAiAdditionalData`) that should have been made once at
// the dispatcher layer instead.
//
// This file is kept as an empty stub because the in-sandbox filesystem
// doesn't allow `unlink`. A follow-up `git rm` on a real dev machine
// will retire it physically.
