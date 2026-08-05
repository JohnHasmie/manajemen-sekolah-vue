/**
 * Type contracts for the tutor Ratings summary (WEB-13, mirrors
 * BE-20 `TutorRatingsSummaryResource`).
 *
 * Wire keys are intentionally the BACKEND names (avg_rating /
 * total_ratings / distribution / last_5_notes) rather than the
 * prose ones the UI displays (avg / count / recent_comments). One
 * fewer round of key-renaming to keep in sync.
 */

/**
 * Distribution is always keyed 1..5 — the backend fills zeros so
 * the mobile bar chart can render zero-height bars without a null
 * guard. Represented as a plain object here to match JSON's numeric
 * keys after JSON.parse (object with string keys "1".."5").
 */
export interface RatingDistribution {
  1: number;
  2: number;
  3: number;
  4: number;
  5: number;
}

/**
 * Latest N (default 5) feedback notes with a note attached — used
 * for the "Komentar terakhir" panel. `created_at` is ISO-8601;
 * `notes` is trimmed non-empty on the backend so it's safe to render
 * without a null guard.
 */
export interface RatingNote {
  rating: number;
  notes: string | null;
  created_at: string | null;
}

/**
 * Aggregate response from GET /tutors/me/ratings (self) and
 * GET /tutors/{tutorId}/ratings (admin).
 */
export interface TutorRatingSummary {
  tutor_id: string;
  /** Rounded to 2dp on the server; null when no ratings yet. */
  avg_rating: number | null;
  total_ratings: number;
  distribution: RatingDistribution;
  last_5_notes: RatingNote[];
}
