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

/**
 * Computed presence status for a day's record. Written by the
 * check-in / check-out actions (present, late, early_leave) or the
 * nightly CloseUncheckedOutDaysJob (no_checkout). `sick`/`excused`/
 * `absent` are reserved for a future manual-mark scope.
 */
export type TeacherAttendanceStatus =
  | 'present'
  | 'late'
  | 'early_leave'
  | 'no_checkout';

/**
 * Non-dominant status flags on the same row. Backend column is a
 * nullable JSON blob (`teacher_attendances.secondary_flags`). Populated
 * by check-out when the row was `late` at check-in AND the pulang time
 * fell before the early-leave boundary — dominant stays `late` for
 * rekap counts, this side-channel drives the second pill in the UI.
 */
export interface TeacherAttendanceSecondaryFlags {
  early_leave_secondary?: boolean;
}

/**
 * Shift attached to a teacher_attendances row. Populated on the
 * history + admin-list endpoints via `whenLoaded('shift')` — one
 * eager-load per collection, no N+1.
 */
export interface TeacherAttendanceShift {
  id: string;
  name: string;
  start_time: string;
  end_time: string;
}

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
  /**
   * Which check-in methods are allowed for THIS school (MR !226).
   * Subset of SELFIE / QR_GATE / QR_CARD — backend enforces ≥1 entry.
   */
  allowed_methods?: import('./attendance-qr').CheckInMethod[];
  /**
   * Auto-rotate interval (minutes) for the school's gate QR token.
   * Server clamps to 5..60. Lower = harder to photograph-and-replay,
   * higher = fewer poster reprints.
   */
  gate_qr_rotation_minutes?: number;
  /**
   * Apply the existing geofence radius to QR check-ins too. When
   * false, a teacher who scans the gate / card QR from anywhere
   * passes — handy for off-site staff.
   */
  geofence_required_for_qr?: boolean;
  /**
   * Also mint student personnel cards (vs teachers/staff only).
   * Off by default — most schools start with teacher cards.
   */
  issue_student_cards?: boolean;
  /**
   * Workweek bitmask — bit0=Sunday..bit6=Saturday. Default 62 (Mon–Fri).
   * Days outside this mask short-circuit to `is_workday=false`. Written
   * by the Kalender panel (MR 3c).
   */
  workweek_days_bitmask?: number;
  /**
   * Daily cap on how many check-ins one person can register across all
   * shifts. Default 1 (single-shift schools); bimbel wizards bump it
   * to 3. Written by the Shift panel (MR 4c).
   */
  max_daily_shifts_per_person?: number;
}

/**
 * Multi-location geofence — one campus/site in a school with N
 * physical locations. Backend contract (Slack 1783559232 + backend
 * MR !375). Empty list means the school hasn't migrated to multi-
 * loc yet; the check-in falls back to the legacy single-loc
 * columns above.
 */
export interface TeacherAttendanceGeofence {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  radius_m: number;
  is_primary: boolean;
  is_active: boolean;
}

/**
 * Client-side draft used by the add/edit modal. `id` absent = create
 * mode; present = update. Backend accepts partial updates so unset
 * flags fall through to their prior values.
 */
export interface TeacherAttendanceGeofenceDraft {
  id?: string;
  name: string;
  latitude: number;
  longitude: number;
  radius_m: number;
  is_primary: boolean;
  is_active: boolean;
}

/**
 * Who the daily attendance-reminder push fans out to (backend MR1 !413 +
 * scheduler MR2 !415, Slack 1783935842).
 *   · all_workdays        — every teacher on each workday of the school.
 *   · teaching_days_only  — only teachers who actually have a class that
 *                           day (roadmap; the value is wired now so the
 *                           setting survives once the scheduler honours it).
 */
export type TeacherAttendanceReminderScope =
  | 'all_workdays'
  | 'teaching_days_only';

/**
 * Per-school teacher attendance-reminder config. Distinct endpoint from
 * TeacherAttendanceSettings: GET/PUT /teacher-attendance/reminder-settings.
 * The scheduler reads `checkin_offsets_minutes` / `checkout_offsets_minutes`
 * per tenant and pushes a reminder that many minutes BEFORE the person's
 * check-in / check-out time.
 */
export interface TeacherAttendanceReminderSettings {
  /** Master switch — when false the scheduler skips this school entirely. */
  enabled: boolean;
  /** Audience for the reminder (see TeacherAttendanceReminderScope). */
  scope: TeacherAttendanceReminderScope;
  /** Minutes before the check-in time to fire each reminder. */
  checkin_offsets_minutes: number[];
  /** Minutes before the check-out time to fire each reminder. */
  checkout_offsets_minutes: number[];
}

/**
 * Client-side fallback used before the GET resolves / on load error.
 * The API returns the authoritative per-school defaults; this only
 * seeds the form so it never renders an empty, offset-less card.
 */
export const DEFAULT_TEACHER_ATTENDANCE_REMINDER_SETTINGS: TeacherAttendanceReminderSettings =
  {
    enabled: false,
    scope: 'all_workdays',
    checkin_offsets_minutes: [15],
    checkout_offsets_minutes: [15],
  };

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
  allowed_methods: ['SELFIE'],
  gate_qr_rotation_minutes: 15,
  geofence_required_for_qr: false,
  issue_student_cards: false,
  workweek_days_bitmask: 62,
  max_daily_shifts_per_person: 1,
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
 * Which personnel kind a teacher_attendances row belongs to. The one
 * table holds BOTH teachers and staff behind this discriminator; the
 * admin report (adminIndex) returns both. Teacher rows populate the
 * `teacher` relation, staff rows populate `user`.
 */
export type TeacherAttendancePersonnelType = 'teacher' | 'staff';

/**
 * Minimal staff identity embedded in a `personnel_type='staff'` row.
 * Mirrors the API `user` relation (no employee_number — staff aren't
 * in the teachers table).
 */
export interface TeacherAttendanceUser {
  id: string;
  name: string;
  email: string | null;
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
  secondary_flags: TeacherAttendanceSecondaryFlags | null;
  /**
   * Runtime-computed by the backend from WorkdayCalendar (workweek
   * bitmask AND NOT holidays). Not persisted — an admin adding a
   * holiday tomorrow doesn't rewrite past rows' status; the UI just
   * renders a neutral "Libur" pill from this flag.
   */
  is_workday: boolean;
  /**
   * Multi-shift schools (bimbel + rotating staff) get one row per
   * (person, day, shift). Null on single-shift schools — the row is
   * "the whole day" and the FE hides the shift chip.
   */
  shift_id: string | null;
  shift?: TeacherAttendanceShift;
  /**
   * Minutes past (checkout_threshold + grace) at pulang. 0 on rows
   * closed on time or early. Absent on responses issued before MR 5
   * — treat as 0 to keep older FE builds compatible.
   */
  overtime_minutes: number;

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

  /**
   * Personnel discriminator on the admin report rows (adminIndex).
   * Absent on the teacher-facing history/config responses — treat a
   * missing value as 'teacher' (the historical default).
   */
  personnel_type?: TeacherAttendancePersonnelType;

  /** Present on teacher rows (whenLoaded('teacher')). Null for staff. */
  teacher?: TeacherAttendanceTeacher;
  /** Present on staff rows (whenLoaded('user')). Null for teachers. */
  user?: TeacherAttendanceUser;

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
  /**
   * Every row for today across all shifts, newest first (backend
   * MR !367). Single-shift schools get 0-or-1 elements; multi-shift
   * schools get one per completed shift. Optional so older FE builds
   * that don't read this key keep working — the shift picker
   * gracefully treats missing as "no completed shifts".
   */
  today_records?: TeacherAttendanceRecord[];
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
  /**
   * Full shift list for this school, embedded in /config so the check-in
   * shift picker (MR 4d) can render without a second /attendance-shifts
   * round-trip. Empty on single-shift schools — the picker renders nothing
   * and the caller falls through to the single-shift path.
   */
  shifts?: import('@/services/attendance-shifts.service').AttendanceShift[];
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
  /**
   * Which shift this check-in applies to (MR 4d). Null on single-shift
   * schools — server treats null as "no shift" and enforces the
   * (school, person, date) unique via NULLS NOT DISTINCT.
   */
  shift_id?: string | null;
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

/**
 * Personnel-type narrowing for the admin report. `all` (or omitted)
 * returns teachers + staff; the other two narrow to one kind. Mirrors
 * the backend `personnel_type` query param.
 */
export type TeacherAttendancePersonnelFilter = 'all' | 'teacher' | 'staff';

/** Filters for the admin report list. */
export interface TeacherAttendanceAdminFilters {
  date?: string;
  start_date?: string;
  end_date?: string;
  /** Accepts a Teacher ID OR User ID; server resolves school-scoped. */
  teacher_id?: string;
  status?: TeacherAttendanceStatus;
  /** teacher | staff | all — narrows the unified personnel report. */
  personnel_type?: TeacherAttendancePersonnelFilter;
  per_page?: number;
  page?: number;
}

/**
 * Resolve the display name for a personnel attendance row. The
 * teacher_attendances table carries BOTH teachers and staff behind
 * `personnel_type`; teacher rows populate the `teacher` relation, staff
 * rows populate `user`. Reading only `teacher.name` left staff rows
 * blank on the admin report (MTs Muhammadiyah). Prefer the relation
 * matching the discriminator, fall back to the other, then to '-'.
 */
export function teacherAttendancePersonName(
  row: Pick<TeacherAttendanceRecord, 'personnel_type' | 'teacher' | 'user'>,
): string {
  const teacherName = row.teacher?.name?.trim() || '';
  const userName = row.user?.name?.trim() || '';
  if (row.personnel_type === 'staff') return userName || teacherName || '-';
  return teacherName || userName || '-';
}

/**
 * Employee number sub-line for a personnel row. Only teachers carry a
 * NIP (employee_number); staff have none, so this returns null for them
 * and the caller renders nothing.
 */
export function teacherAttendanceEmployeeNumber(
  row: Pick<TeacherAttendanceRecord, 'teacher'>,
): string | null {
  const nip = row.teacher?.employee_number?.trim();
  return nip ? nip : null;
}

/** Indonesian chip label for the personnel discriminator (Guru / Staf). */
export function teacherAttendancePersonnelLabel(
  type: TeacherAttendancePersonnelType | null | undefined,
): string {
  return type === 'staff' ? 'Staf' : 'Guru';
}

/** Indonesian label for the MASUK pill (derived from the dominant status). */
export function teacherAttendanceStatusLabel(
  status: TeacherAttendanceStatus | null | undefined,
): string {
  if (status === 'late') return 'Terlambat';
  if (status === 'early_leave') return 'Tepat waktu';
  if (status === 'no_checkout') return 'Tepat waktu';
  if (status === 'present') return 'Tepat waktu';
  return '-';
}

/**
 * PULANG pill label — the second pill next to the masuk pill on
 * TeacherAttendanceHistoryView. Renders 'Pulang cepat' when the row is
 * `early_leave` OR when the row is `late` with the secondary flag set
 * (both cases share the same UI truth: pulang before threshold).
 * Returns null when there's nothing to show — either no check-out yet,
 * or check-out happened on time.
 */
export function teacherAttendancePulangLabel(
  status: TeacherAttendanceStatus | null | undefined,
  secondary: TeacherAttendanceSecondaryFlags | null | undefined,
  hasCheckOut: boolean,
): { text: string; tone: 'good' | 'bad' | 'warn' } | null {
  if (status === 'no_checkout') {
    return { text: 'Belum absen pulang', tone: 'warn' };
  }
  if (!hasCheckOut) {
    return null;
  }
  if (status === 'early_leave' || secondary?.early_leave_secondary) {
    return { text: 'Pulang cepat', tone: 'bad' };
  }
  return { text: 'Pulang tepat', tone: 'good' };
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
  /** Stable unique key per person — teacher's id or staff's user id.
   *  Use this as the row key: `teacher_id` is null for staff rows. */
  person_id: string;
  /** 'teacher' | 'staff' — the rekap now covers both personnel types. */
  personnel_type?: TeacherAttendancePersonnelType;
  /** Null for staff rows (they key on user id via person_id). */
  teacher_id: string | null;
  /** Teacher's name, or the staff member's user name for staff rows. */
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
  /**
   * Sum of `overtime_minutes` across every row in the period. Absent
   * from responses issued before MR 5 shipped — treat as 0.
   */
  overtime_minutes?: number;
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
  /**
   * Narrow the rekap to a single personnel kind. Same values as the
   * detail-report filter so the top-of-page Tipe segmented control can
   * drive BOTH sections in lock-step. `all`/omitted returns both.
   * Backend: `TeacherAttendanceSummaryRequest` validates
   * `nullable|in:teacher,staff,all`.
   */
  personnel_type?: TeacherAttendancePersonnelFilter;
}
