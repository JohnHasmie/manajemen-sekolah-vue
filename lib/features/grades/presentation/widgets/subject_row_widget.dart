// Retired 2026-05-09 — replaced by the flat (class × subject) card
// rendered directly inside `GradeInputContentMixin._buildClassSubjectCard`.
//
// The legacy widget rendered a single subject row inside a parent
// "class card" container. The new Frame A overview flattens the data
// into one card per (class × subject) combo, so the parent container
// + repeating subject rows pattern is gone.
//
// Keeping the file empty (rather than deleting) because the sandbox
// blocks file deletion; the file can be safely removed in a follow-up
// commit once `dart analyze` reports no remaining imports.
