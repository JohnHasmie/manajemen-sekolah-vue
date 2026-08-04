/**
 * Type contracts for greenfield bimbel activities + submissions
 * (WEB-13, mirrors BE-23). Kept in a subdir so the tutoring2 domain
 * ends up with one file per resource instead of one god-DTO file.
 *
 * Load-bearing greenfield contract: submissions FK to
 * `bimbel_enrollments.id` (NOT `student_class_id`). Every DTO here
 * honors that.
 */

/**
 * Activity kind enum mirrors `App\Modules\Tutoring\Enums\ActivityKind`.
 *
 * Note: only 3 kinds ship in BE-23 (`tugas | kuis | materi_baca`).
 * The originally-scoped `proyek | latihan` values were dropped in the
 * backend; the tutor UI enumerates over `ACTIVITY_KINDS` below so
 * adding a fourth kind is a one-line change on both sides.
 */
export type ActivityKind = 'tugas' | 'kuis' | 'materi_baca';

export const ACTIVITY_KINDS: ActivityKind[] = ['tugas', 'kuis', 'materi_baca'];

/**
 * A row in the tutor Activities list.
 *
 * Server-side is `bimbel_activities`. `published_at` gates siswa
 * visibility — drafts are only visible to admin/tutor. `submissions_count`
 * ships with the index endpoint (via `withCount('submissions')`).
 */
export interface Activity {
  id: string;
  learning_group_id: string;
  learning_group_name?: string | null;
  program_id?: string | null;
  program_name?: string | null;
  kind: ActivityKind;
  /** Human label rendered by the backend enum (`kind_label`). */
  kind_label?: string | null;
  title: string;
  description?: string | null;
  /** ISO-8601 (from `due_at?.toIso8601String()`). Nullable when open-ended. */
  due_at?: string | null;
  max_points?: number | null;
  created_by_user_id?: string | null;
  /** Null while draft. Published means visible to siswa. */
  published_at?: string | null;
  /** Only present on index/show — via `->withCount('submissions')`. */
  submissions_count?: number;
  created_at?: string;
  updated_at?: string;
}

/**
 * Payload accepted by POST /learning-groups/{groupId}/activities.
 * `kind` + `title` are the only required inputs; `due_at` accepts a
 * `YYYY-MM-DD` from a `<input type="date">` (Laravel `date` rule).
 */
export interface ActivityCreatePayload {
  kind: ActivityKind;
  title: string;
  description?: string | null;
  due_at?: string | null;
  max_points?: number | null;
}

/** Same shape as create — the backend uses UpdateActivityRequest. */
export type ActivityUpdatePayload = Partial<ActivityCreatePayload>;

/**
 * Submission status mirrors `App\Modules\Tutoring\Enums\SubmissionStatus`.
 * DRAFT = siswa saved but not handed in.
 * SUBMITTED = handed in (submitted_at stamped).
 * GRADED = tutor scored (graded_at + graded_by_user_id stamped).
 */
export type SubmissionStatus = 'draft' | 'submitted' | 'graded';

/**
 * One row in the tutor Submissions grader table.
 *
 * The endpoint eager-loads `enrollment.student:id,name,student_number`
 * so `student_name` + `student_id` land alongside the FK. There is
 * NO `feedback` column on the backend today — the grade endpoint only
 * accepts `score`. If BE later adds a `feedback` column, extend this
 * DTO + the payload; the UI already reserves a textarea for it, but
 * it stays client-only until the wire ships.
 */
export interface Submission {
  id: string;
  activity_id: string;
  enrollment_id: string;
  student_id?: string | null;
  student_name?: string | null;
  status: SubmissionStatus;
  status_label?: string | null;
  /** Siswa's text answer (nullable — attachment_url may be the whole thing). */
  body?: string | null;
  attachment_url?: string | null;
  score?: number | null;
  graded_by_user_id?: string | null;
  submitted_at?: string | null;
  graded_at?: string | null;
  created_at?: string;
  updated_at?: string;
}

/**
 * Payload accepted by POST /submissions/{id}/grade — only `score` is
 * on the wire. `feedback` is a client-side field only (see the note on
 * `Submission.body` above); we still ship it as an optional field on
 * this payload so the day BE adds a column, this stays source-compatible.
 */
export interface SubmissionGradePayload {
  score: number | null;
  /** Client-side only for now — see the Submission DTO comment. */
  feedback?: string | null;
}
