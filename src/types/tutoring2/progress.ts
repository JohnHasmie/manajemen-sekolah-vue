/**
 * Tutoring2 · Student progress — the wire shape of
 * `GET /tutoring-v2/students/{id}/progress`.
 *
 * Every number is already normalised onto a 0..100 scale by the backend,
 * to 1 dp, matching the leaderboard's normalisation so the two surfaces
 * can be read against each other without the client doing arithmetic.
 *
 * Crucially `kkm_percent` is rescaled too. The raw KKM is stored on the
 * same scale as the raw score (an assessment out of 200 has a KKM out of
 * 200), so comparing a raw KKM against a percentage renders pass/fail
 * backwards. Never re-derive it client-side from a raw `kkm`.
 */

/** One graded, PUBLISHED assessment. Drafts never appear here. */
export interface ProgressPoint {
  assessment_id: string;
  title: string;
  program_id: string;
  program_name: string | null;
  /** `YYYY-MM-DD`, or null when the tutor left the date blank. */
  date: string | null;
  score: number;
  max_score: number;
  /** `score / max_score * 100`, 1 dp. Null when max_score is 0. */
  percent: number | null;
  /** Passing mark on the SAME 0..100 scale. Null when unset. */
  kkm_percent: number | null;
  notes: string | null;
}

/** Aggregates over every point, computed server-side. */
export interface ProgressSummary {
  graded_count: number;
  average: number | null;
  highest: number | null;
  lowest: number | null;
  /** Points are oldest-first, so this is the NEWEST score. */
  latest: number | null;
}

export interface StudentProgress {
  /** Oldest-first — the chart reads left to right. Undated points sink last. */
  points: ProgressPoint[];
  programs: Array<{ id: string; name: string }>;
  summary: ProgressSummary;
  /**
   * programId → mean percentage across EVERY participant's published
   * scores in that programme. Absent key = no comparable cohort data,
   * in which case the baseline is not drawn rather than faked.
   */
  peer_average_by_program: Record<string, number>;
}
