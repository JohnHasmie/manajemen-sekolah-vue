/**
 * Type contracts for one student's attendance history.
 *
 * Mirrors `App\Modules\Tutoring\Http\Controllers\StudentAttendanceController`:
 *
 *   GET /api/tutoring-v2/students/{id}/attendance?from=&to=&per_page=
 *
 * The response is NOT the shared `{data, meta}` list envelope — it
 * carries a `summary` alongside, because the counts are computed over
 * the WHOLE range server-side, not over the page. A client that
 * tallied the rows it happened to receive would report the current
 * page's attendance as the term's.
 *
 * Gated on `tutoring.attendance.view` / `.view_own`; a wali reading
 * their own child goes through the `_view_own` branch, which resolves
 * ownership by `students.user_id` OR `students.guardian_email`.
 */

/** Attendance status vocabulary — mirrors the PHP `AttendanceStatus`. */
export type AttendanceStatusValue = 'hadir' | 'izin' | 'sakit' | 'alpa' | string;

export interface StudentAttendanceRow {
  id: string;
  session_id: string;
  /** Greenfield anchor: FK to `bimbel_enrollments.id`. */
  enrollment_id: string;
  status: AttendanceStatusValue;
  /** The server's own wording — prefer it over a client-side map. */
  status_label: string | null;
  notes: string | null;
  marked_at: string | null;
  /**
   * The SESSION's status, aliased so it cannot collide with the
   * attendance `status` above. A cancelled session is not an absence.
   */
  session_status: string | null;
  starts_at: string | null;
  ends_at: string | null;
  learning_group_id?: string | null;
  learning_group_name?: string | null;
  program_name?: string | null;
}

export interface StudentAttendanceSummary {
  total: number;
  hadir: number;
  izin: number;
  sakit: number;
  alpa: number;
  /**
   * Percentage 0..100 with 1 dp, or NULL when nothing has been marked.
   * Null is deliberate and must not be rendered as 0 — "no register
   * taken yet" and "attended none" are different facts about a child.
   */
  attendance_rate: number | null;
}

export interface StudentAttendanceResult {
  rows: StudentAttendanceRow[];
  summary: StudentAttendanceSummary;
  meta: {
    student_id: string;
    current_page: number;
    last_page: number;
    per_page: number;
    total: number;
  };
}

export interface StudentAttendanceParams {
  from?: string;
  to?: string;
  page?: number;
  per_page?: number;
}
