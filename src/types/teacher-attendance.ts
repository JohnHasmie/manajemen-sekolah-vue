/**
 * Teacher daily-attendance types (PRESENSI GURU) — mirror the backend
 * contract for the App\Modules\Attendance TeacherAttendance feature
 * (backend MR !108).
 *
 * These are DISTINCT from `@/types/attendance.ts`, which models *student*
 * per-session attendance (hadir/sakit/izin/alpa). Teacher attendance is a
 * once-per-teaching-day check-in (+ optional check-out) with a camera
 * selfie and/or GPS geofence, configured per school by the admin.
 *
 * Field names match the API JSON 1:1 so the service layer can pass the
 * raw payload straight through. All shapes are intentionally permissive
 * (nullable) — the server decides which fields are populated based on the
 * school's settings.
 */

/** Computed presence status for a day's record. */
export type TeacherAttendanceStatus = 'present' | 'late';

/**
 * Per-school config governing how teachers presensi. Returned by both
 * GET /teacher-attendance/config (teacher bootstrap, `settings` block)
 * and GET /teacher-attendance/settings (admin form). The admin form
 * additionally surfaces `school_latitude` / `school_longitude` as the
 * geofence fallback pin.
 */
export interface TeacherAttendanceSettings {
  /** Selfie mandatory on check-in/out. */
  camera_required: boolean;
  /** GPS mandatory on check-in/out. */
  location_required: boolean;
  /** Whether the check-out flow is enabled for this school. */
  checkout_enabled: boolean;
  /** Geofence centre override (falls back to school pin when null). */
  geofence_lat: number | null;
  geofence_lng: number | null;
  /** Allowed radius from the geofence centre, in metres. */
  geofence_radius_m: number;
  /** Reject (true) vs flag-and-allow (false) out-of-radius check-ins. */
  reject_outside_geofence: boolean;
  /** Minutes after the first teaching start before "late" kicks in. */
  late_grace_minutes: number;
  /**
   * Centre actually used for verification — settings coords, falling
   * back to the school pin. Present in the teacher config payload only.
   */
  effective_geofence_lat?: number | null;
  effective_geofence_lng?: number | null;
  /** School pin — present in the admin settings payload only. */
  school_latitude?: number | null;
  school_longitude?: number | null;
}

/** Sensible client-side defaults mirroring the backend defaults(). */
export const DEFAULT_TEACHER_ATTENDANCE_SETTINGS: TeacherAttendanceSettings = {
  camera_required: true,
  location_required: true,
  checkout_enabled: false,
  geofence_lat: null,
  geofence_lng: null,
  geofence_radius_m: 150,
  reject_outside_geofence: true,
  late_grace_minutes: 0,
  effective_geofence_lat: null,
  effective_geofence_lng: null,
  school_latitude: null,
  school_longitude: null,
};

/** Which methods were captured on a given check-in/out leg. */
export interface TeacherAttendanceMethods {
  camera: boolean;
  location: boolean;
  checkout_camera?: boolean;
  checkout_location?: boolean;
}

/** Minimal teacher identity embedded in records / config. */
export interface TeacherAttendanceTeacher {
  id: string;
  name: string;
  employee_number: string | null;
}

/**
 * One teacher-attendance row (TeacherAttendanceResource). Returned by
 * check-in/out, config.state.record, history items, and admin list items.
 */
export interface TeacherAttendanceRecord {
  id: string;
  school_id: string;
  teacher_id: string;
  teaching_schedule_id: string | null;
  date: string; // YYYY-MM-DD
  status: TeacherAttendanceStatus;

  check_in_at: string | null;
  check_in_photo_path: string | null;
  check_in_photo_url: string | null;
  check_in_lat: number | null;
  check_in_lng: number | null;
  check_in_distance_m: number | null;
  check_in_outside_geofence: boolean;

  check_out_at: string | null;
  check_out_photo_path: string | null;
  check_out_photo_url: string | null;
  check_out_lat: number | null;
  check_out_lng: number | null;
  check_out_distance_m: number | null;
  check_out_outside_geofence: boolean;

  methods_used: TeacherAttendanceMethods | null;
  notes: string | null;

  /** Only present in the admin list (whenLoaded). */
  teacher?: TeacherAttendanceTeacher;

  created_at: string;
  updated_at: string;
}

/** One today-schedule entry from the config bootstrap. */
export interface TeacherAttendanceScheduleItem {
  teaching_schedule_id: string;
  class_id: string;
  class_name: string;
  subject_id: string;
  subject_name: string;
  lesson_hour_id: string;
  lesson_hour_name: string;
  hour_number: number | null;
  start_time: string;
  end_time: string;
}

/** Today's check-in/out state from the config bootstrap. */
export interface TeacherAttendanceState {
  has_checked_in: boolean;
  has_checked_out: boolean;
  can_check_out: boolean;
  record: TeacherAttendanceRecord | null;
}

/** Full GET /teacher-attendance/config bootstrap payload. */
export interface TeacherAttendanceConfig {
  teacher: TeacherAttendanceTeacher;
  date: string; // YYYY-MM-DD
  server_time: string; // ISO8601
  settings: TeacherAttendanceSettings;
  today_schedule: TeacherAttendanceScheduleItem[];
  first_teaching_start: string | null;
  late_after: string | null;
  state: TeacherAttendanceState;
}

/** Coordinates captured from navigator.geolocation. */
export interface TeacherAttendanceGeo {
  latitude: number;
  longitude: number;
  /** Reported accuracy in metres (informational only). */
  accuracy?: number;
}

/** Multipart payload for check-in / check-out. */
export interface TeacherAttendanceSubmission {
  /** Live camera capture (jpeg/png blob). Required if camera_required. */
  photo?: Blob | null;
  latitude?: number | null;
  longitude?: number | null;
  notes?: string | null;
}

/** Pagination meta echoed by Laravel resource collections. */
export interface TeacherAttendancePageMeta {
  current_page: number;
  last_page: number;
  per_page: number;
  total: number;
}

/** A paginated history / admin list response. */
export interface TeacherAttendanceListResult {
  items: TeacherAttendanceRecord[];
  meta: TeacherAttendancePageMeta;
}

/** Filters for the teacher's own history list. */
export interface TeacherAttendanceHistoryFilters {
  start_date?: string;
  end_date?: string;
  per_page?: number;
  page?: number;
}

/** Filters for the admin report list. */
export interface TeacherAttendanceAdminFilters {
  date?: string;
  start_date?: string;
  end_date?: string;
  /** Accepts a Teacher ID OR User ID; server resolves school-scoped. */
  teacher_id?: string;
  status?: TeacherAttendanceStatus;
  per_page?: number;
  page?: number;
}

/** Indonesian label for a status pill. */
export function teacherAttendanceStatusLabel(
  status: TeacherAttendanceStatus | null | undefined,
): string {
  if (status === 'late') return 'Terlambat';
  if (status === 'present') return 'Tepat Waktu';
  return '-';
}

/**
 * Indonesian column header for a DYNAMIC rekap status key. `present`
 * and `late` are always present; further keys (sick / excused / absent)
 * may appear in `meta.statuses`. Falls back to a Title-Cased version of
 * an unknown key so a new backend status never renders blank.
 */
export function teacherAttendanceStatusColumnLabel(status: string): string {
  switch (status) {
    case 'present':
      return 'Hadir';
    case 'late':
      return 'Telat';
    case 'sick':
      return 'Sakit';
    case 'excused':
      return 'Izin';
    case 'absent':
      return 'Alpa';
    default:
      return status.charAt(0).toUpperCase() + status.slice(1);
  }
}

// ───────────────────────────────────────────────────────────────────
// REKAP / SUMMARY (backend MR !110)
//
// The summary endpoints return per-TEACHER (admin) or own-totals
// (teacher) rekap aggregated over a date range. Unlike the per-row
// list above, status columns are DYNAMIC: `present` + `late` are
// ALWAYS present as int keys (the only statuses the check-in flow
// writes today), and any further statuses found in the data (sick /
// excused / absent …) are appended. The AUTHORITATIVE ordered column
// list is `meta.statuses` — read that rather than hardcoding columns.
// ───────────────────────────────────────────────────────────────────

/**
 * Per-status integer counts carried by every rekap row / totals /
 * summary block. Keys are exactly the statuses listed in `meta.statuses`
 * (always includes `present` + `late`). Indexed so a dynamic column
 * can be read as `row[status]` without TS complaining.
 */
export type TeacherAttendanceStatusCounts = Record<string, number>;

/** Shared meta carried by both summary responses. */
export interface TeacherAttendanceSummaryMeta {
  start_date: string; // YYYY-MM-DD
  end_date: string; // YYYY-MM-DD
  /** Authoritative ordered list of status columns present in the data. */
  statuses: string[];
}

/** One per-teacher rekap row (admin/summary `data[]`). */
export interface TeacherAttendanceSummaryRow
  extends TeacherAttendanceStatusCounts {
  teacher_id: string;
  teacher_name: string;
  employee_number: string | null;
  /** Records aggregated for this teacher over the range. */
  total: number;
  /** round((present + late) / total * 100, 1); 0.0 when total is 0. */
  present_pct: number;
}

/** The school-wide totals row (admin/summary `totals`). */
export interface TeacherAttendanceSummaryTotals
  extends TeacherAttendanceStatusCounts {
  total: number;
  present_pct: number;
  teacher_count: number;
}

/** GET /teacher-attendance/admin/summary — per-teacher rekap. */
export interface TeacherAttendanceAdminSummary {
  meta: TeacherAttendanceSummaryMeta;
  data: TeacherAttendanceSummaryRow[];
  totals: TeacherAttendanceSummaryTotals;
}

/** Meta block of the teacher own-summary (history/summary). */
export interface TeacherAttendanceOwnSummaryMeta
  extends TeacherAttendanceSummaryMeta {
  teacher_id: string;
  teacher_name: string;
}

/** The teacher's own totals block (history/summary `summary`). */
export interface TeacherAttendanceOwnSummaryTotals
  extends TeacherAttendanceStatusCounts {
  total: number;
  present_pct: number;
}

/** GET /teacher-attendance/history/summary — auth teacher's own rekap. */
export interface TeacherAttendanceOwnSummary {
  meta: TeacherAttendanceOwnSummaryMeta;
  summary: TeacherAttendanceOwnSummaryTotals;
}

/** Date-range filters shared by both summary endpoints. */
export interface TeacherAttendanceSummaryFilters {
  start_date?: string;
  end_date?: string;
}

/** Admin summary filters add the optional teacher narrowing. */
export interface TeacherAttendanceAdminSummaryFilters
  extends TeacherAttendanceSummaryFilters {
  /** Accepts a Teacher ID OR User ID; server resolves school-scoped. */
  teacher_id?: string;
}
