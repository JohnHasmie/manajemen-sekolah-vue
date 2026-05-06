// DEPRECATED — retired during the AI/manual RPP detail-screen split.
//
// AI regeneration (per-field + all-fields, including 202-poll) is now
// inlined into `screens/ai/ai_rpp_detail_screen.dart`, the only place
// that ever ran it. Manual-upload RPPs never had access to AI regen
// in the first place, so the new manual screen doesn't carry these
// methods at all.
//
// This file is kept as an empty stub because the in-sandbox filesystem
// doesn't allow `unlink`. A follow-up `git rm` on a real dev machine
// will retire it physically.
