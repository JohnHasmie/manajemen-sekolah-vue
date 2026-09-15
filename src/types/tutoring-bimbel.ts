/**
 * Type contracts for the greenfield bimbel UI components — mirrors of
 * the backend BE-1..7 DTOs. Deliberately isolated from the legacy
 * `types/tutoring.ts` so the rebuild doesn't drag legacy naming.
 *
 * Load-bearing greenfield contract: `enrollment_id` replaces the school
 * side's `student_class_id`; `session_id` replaces `class_id +
 * lesson_hour_id`. Every DTO here honors that.
 */
import type { AttendanceStatus } from '@/types/attendance';

/**
 * One row in the TutoringAttendanceRoster. Modeled directly on
 * `AttendanceRow` from `types/attendance.ts` — but keyed by
 * `enrollment_id` because bimbel attendance rows FK to
 * `bimbel_enrollments`, not `student_classes`.
 */
export interface TutoringAttendanceRow {
  /** Greenfield anchor: FK to `bimbel_enrollments.id`. */
  enrollment_id: string;
  student_id: string;
  student_name: string;
  student_number?: string | null;
  /** Cached badge text (e.g. "sakit sesi lalu") from the server. */
  alert?: string | null;
  alert_tone?: 'warning' | 'danger' | null;
  /** Current status for this session; null = unmarked. */
  status: AttendanceStatus;
  notes?: string;
}

/**
 * A single row in the TutoringScoreEntryList. Analogue of
 * `GradeRow`+`GradeCell` collapsed into one row (bimbel scores one
 * assessment at a time, not the full matrix).
 */
export interface TutoringScoreRow {
  /** Greenfield anchor: FK to `bimbel_enrollments.id`. */
  enrollment_id: string;
  student_id: string;
  student_name: string;
  student_number?: string | null;
  /** Numeric mark 0..maxScore; null = unentered. */
  score: number | null;
  notes?: string | null;
  /**
   * ISO instant: when a tutor last SUBMITTED this mark, or null/absent
   * on a row nobody has scored.
   *
   * This is the honest "last changed" stamp, not `updated_at`.
   * `UpsertScoresAction` puts `'marked_at' => now()` in the values array
   * of `Score::updateOrCreate`, so it is rewritten on re-mark as well as
   * on first mark; `updated_at` is a generic row-touch column that the
   * demo seeder and the v1→v2 backfill also move, independently of any
   * tutor.
   *
   * The wire has carried it since WEB-2 (`ScoreResource`); this type
   * simply dropped it, which is why the entry list had no way to say a
   * row was already scored.
   *
   * There is deliberately no `marked_by` here. The backend emits it as
   * a raw `users.id` uuid with no name resolution, and a uuid on screen
   * is not an author — render a name or nothing.
   */
  marked_at?: string | null;
}

/**
 * A downloadable materi/lampiran. Modeled on the lesson-plan `file_*`
 * shape (the richest file schema in the codebase — carries size + mime
 * + derived MB).
 */
export interface TutoringMaterial {
  id: string;
  title: string;
  description?: string | null;
  file_url?: string | null;
  file_name?: string | null;
  /** Raw byte count. */
  file_size?: number | null;
  /** Backend-derived, rounded to 2 dp. */
  file_size_mb?: number | null;
  file_mime?: string | null;
  /** Display label — "PDF", "MP4", "DOCX", … */
  kind?: string | null;
  /** Program / paket context so the row can render without eager join. */
  program_label?: string | null;
  created_at?: string | null;
}
