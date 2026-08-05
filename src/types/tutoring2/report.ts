/**
 * Wire DTOs for BE-28 admin reports (`/api/tutoring-v2/admin/reports/*`).
 *
 * Every field name and every numeric type mirrors
 * `App\Modules\Tutoring\Http\Controllers\AdminReportController` exactly.
 * If the backend ever renames a column, `vue-tsc --build` fails here
 * before the report screens silently render `undefined`.
 *
 * The controller returns amounts as PHP `float` (JSON numbers) — we
 * model them as `number`. `attendance_rate` is a 4dp decimal in [0, 1].
 */

/** One row per calendar day in [from, to]. */
export interface ActivityReportRow {
  date: string; // YYYY-MM-DD
  sessions_scheduled: number;
  sessions_completed: number;
  sessions_cancelled: number;
  attendance_marked_count: number;
}

/**
 * One row per enrollment that had at least one attendance marked in the
 * window. `attendance_rate` is `hadir / (hadir+izin+sakit+alpa)` in
 * [0, 1] — multiply by 100 for percent.
 */
export interface AttendanceReportRow {
  enrollment_id: string;
  student_name: string;
  program_name: string;
  sessions_planned: number;
  hadir: number;
  izin: number;
  sakit: number;
  alpa: number;
  attendance_rate: number;
}

/**
 * One row per calendar day in [from, to]. `refunds_amount` is always 0
 * in BE-28 (contract locked for BE-33).
 */
export interface FinancialReportRow {
  date: string; // YYYY-MM-DD
  bills_created_count: number;
  bills_created_amount: number;
  bills_paid_amount: number;
  bills_overdue_amount: number;
  refunds_amount: number;
}

/** Common range meta echoed back by every endpoint. */
export interface ReportRangeMeta {
  from: string; // YYYY-MM-DD
  to: string; // YYYY-MM-DD
}

/** Envelope returned by every JSON report endpoint. */
export interface ReportEnvelope<T> {
  data: T[];
  meta: ReportRangeMeta;
}

/** Range params shared by every fetch + PDF-URL builder. */
export interface ReportRangeParams {
  from: string; // YYYY-MM-DD
  to: string; // YYYY-MM-DD
}
