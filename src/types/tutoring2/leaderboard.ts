/**
 * Type contracts for the greenfield bimbel leaderboard (BE-21).
 *
 * Mirrors `App\Modules\Tutoring\Http\Controllers\LeaderboardController`:
 *
 *   GET /api/tutoring-v2/learning-groups/{groupId}/leaderboard
 *   GET /api/tutoring-v2/programs/{programId}/leaderboard
 *     ?assessment_id=&limit=
 *
 * Load-bearing greenfield contract: rows are keyed by `enrollment_id`
 * (FK to `bimbel_enrollments.id`) — NOT the legacy `student_class_id`.
 *
 * `avg_score` is a 0..100 normalised percentage so mixed-max_score
 * assessments compare apples-to-apples (rounded to 1 dp server-side).
 * `rank` is a 1-indexed DENSE rank on avg_score DESC — ties share a
 * rank and the next distinct value is rank+1.
 */

/**
 * One row in the leaderboard response. Field names match the wire
 * shape verbatim (snake_case) so the FE never has to translate.
 */
export interface LeaderboardRow {
  /** Greenfield anchor: FK to `bimbel_enrollments.id`. */
  enrollment_id: string;
  student_id: string;
  student_name: string;
  student_number?: string | null;
  /** Normalised avg on the 0..100 scale, 1 dp. */
  avg_score: number;
  /**
   * Number of PUBLISHED, GRADED assessments this row averages over.
   * Wire name — the task spec calls this `assessments_count` but the
   * backend DTO uses `assessments_taken`; we honor the wire.
   */
  assessments_taken: number;
  /** 1-indexed dense rank on avg_score DESC. */
  rank: number;
  /**
   * MVP shortcut — backend does NOT emit `streak_days` yet. Flagged as
   * optional so the FE can start rendering the column once a future BE
   * MR adds it, without a follow-up type change. Undefined for now.
   */
  streak_days?: number | null;
}

/**
 * Full response envelope from both endpoints.
 */
export interface LeaderboardResponse {
  items: LeaderboardRow[];
  /** ISO8601 timestamp the aggregate was computed at. */
  generated_at: string;
}

/**
 * Query params shared by both endpoints — optional scoping to a
 * single assessment + pagination cap.
 */
export interface LeaderboardQuery {
  assessment_id?: string;
  /** Hard cap 100 server-side; default 50 if omitted. */
  limit?: number;
}
