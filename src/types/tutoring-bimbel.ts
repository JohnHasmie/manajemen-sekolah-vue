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
  /** Client-side dirty flag drives the pending-save UI. */
  dirty?: boolean;
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
