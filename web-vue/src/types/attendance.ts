/**
 * Attendance types - mirror the Flutter attendance model.
 *
 * Vue's *internal* canonical values stay Indonesian short-form
 * (`hadir`/`sakit`/`izin`/`alpa`) because dozens of components hard-
 * code those keys (picker modals, calendar grids, day rows…).
 * Wire boundary translates to/from the backend's canonical English
 * (`present`/`sick`/`excused`/`absent`) via
 * `normalizeAttendanceStatus` on read and the inverse before POST.
 */

export type AttendanceStatus = 'hadir' | 'sakit' | 'izin' | 'alpa' | null;

/** Map any historical / mixed-case status (Indonesian or English) to the FE canonical Indonesian short-form. */
export function normalizeAttendanceStatus(
  raw: unknown,
): NonNullable<AttendanceStatus> | null {
  const v = String(raw ?? '').toLowerCase().trim();
  if (!v) return null;
  if (v === 'present' || v === 'hadir') return 'hadir';
  if (v === 'sick' || v === 'sakit') return 'sakit';
  if (v === 'excused' || v === 'izin' || v === 'permission') return 'izin';
  if (v === 'absent' || v === 'alpa' || v === 'alfa' || v === 'alpha') return 'alpa';
  return null;
}

/** Inverse — FE canonical → backend canonical English value. */
export function denormalizeAttendanceStatus(
  status: NonNullable<AttendanceStatus>,
): 'present' | 'sick' | 'excused' | 'absent' {
  switch (status) {
    case 'hadir': return 'present';
    case 'sakit': return 'sick';
    case 'izin':  return 'excused';
    case 'alpa':  return 'absent';
  }
}

export interface AttendanceRow {
  student_id: string;
  student_name: string;
  student_number: string;
  /**
   * Backend canonical gender values are `male` | `female`. Vue still
   * accepts legacy `L`/`P` during the rename rollout — auth + entity
   * parsers map both onto English on read.
   */
  gender?: 'male' | 'female' | 'L' | 'P' | null;
  /** Cached "sakit kemarin" / "alpa 2x pekan ini" badge text from backend. */
  alert?: string | null;
  /** Severity of the alert badge - tinted avatar accordingly. */
  alert_tone?: 'warning' | 'danger' | null;
  /** Current attendance status for the selected session/date. */
  status: AttendanceStatus;
  notes?: string;
}

export interface AttendanceSummary {
  hadir: number;
  sakit: number;
  izin: number;
  alpa: number;
  unmarked: number;
  total: number;
  /** 0..100 percentage of hadir / total. */
  rate: number;
}

export const ATTENDANCE_LABELS: Record<NonNullable<AttendanceStatus>, string> = {
  hadir: 'Hadir',
  sakit: 'Sakit',
  izin: 'Izin',
  alpa: 'Alpa',
};

/**
 * One row in a student's attendance history. Each backend `/attendance`
 * record we receive for a single student becomes one of these,
 * representing a specific session on a specific date.
 */
export interface AttendanceHistoryEntry {
  id: string;
  date: string;
  /** Display label for the session — e.g. "Sesi 1 (07.30)" or subject name. */
  session_label?: string | null;
  subject_id?: string | null;
  subject_name?: string | null;
  class_id?: string | null;
  class_name?: string | null;
  teacher_name?: string | null;
  status: NonNullable<AttendanceStatus>;
  notes?: string | null;
  recorded_at?: string | null;
}

/**
 * Aggregated per-student summary derived from a slice of history.
 * Used by the per-student detail modal to drive the KPI strip + trend.
 */
export interface StudentAttendanceSummary {
  hadir: number;
  sakit: number;
  izin: number;
  alpa: number;
  total: number;
  /** % present (hadir / total). */
  rate: number;
  /** Longest current streak of consecutive Hadir days. */
  streak: number;
}

/**
 * One row on the Presensi list page — a single attendance "session"
 * (class × subject × date × jam ke-) with its HSIA aggregate counts
 * and tercatat flag.
 *
 * Mirrors the per-session shape returned by `/attendance/teacher-summary`
 * (Flutter: `groupedAttendance` rows + `getAttendanceSummary`).
 */
export interface SessionReport {
  /** Stable id (server-provided or composed from class+subject+date+hour). */
  id: string;
  class_id: string;
  class_name: string;
  subject_id: string;
  subject_name: string;
  /** ISO date YYYY-MM-DD. */
  date: string;
  /** HH:mm start (optional — falls back to lesson_hour lookup). */
  start_time?: string | null;
  end_time?: string | null;
  /** Lesson hour number (1, 2, 3, …). */
  jam_ke?: number | null;
  lesson_hour_id?: string | null;
  /** Total enrolled students in the class. */
  total: number;
  hadir: number;
  sakit: number;
  izin: number;
  alpa: number;
  /** `true` if the session has been recorded (at least one row saved). */
  filled: boolean;
  /** 0..100 — hadir / total, rounded. */
  percentage: number;
  /** Who recorded it (rendered only in wali-kelas mode). */
  teacher_id?: string | null;
  teacher_name?: string | null;
}

/** KPI overview returned alongside the session list. */
export interface AttendanceKpiSummary {
  sessions_today: number;
  sessions_completed: number;
  sessions_pending: number;
  /** Optional rolling-average percent across the window. */
  avg_present_pct?: number;
}

// ───────────────────────────────────────────────────────────────────
// Admin Kehadiran types
// ───────────────────────────────────────────────────────────────────

export type AttendanceRange = 'today' | 'week' | 'month';

/** One tingkat row in the dashboard's per-tingkat panel. */
export interface TingkatTrend {
  tingkat: number;
  current_pct: number;
  delta_pct: number;
  /** 7-element percentage series (last 7 calendar days). */
  series: number[];
  /** Optional alert copy ("Tren menurun · pantau pekan ini"). */
  alert_copy: string | null;
}

/** Aggregate response from `/attendance/dashboard-summary`. */
export interface AttendanceDashboard {
  range: AttendanceRange | string;
  range_label: string;
  totals: {
    present: number;
    excused: number;
    sick: number;
    alpha: number;
    /** 0..100 share of present / total recorded students. */
    present_pct: number;
  };
  kpi: {
    /** 7-day moving average of present pct. */
    avg_pct: number;
    /** Total siswa "tidak hadir" today (excused + sick + alpha). */
    absent_count: number;
    /** Delta of absent_count vs yesterday (positive = worse). */
    absent_delta: number;
    /** 7-element sparkline series. */
    sparkline: number[];
  };
  tingkats: TingkatTrend[];
  /**
   * The actual date window backing `kpi.avg_pct` + `tingkats[].series`.
   * Usually the rolling 7 days ending today, but falls back to the
   * 7 days ending at MAX(date) when the school hasn't recorded
   * anything in the last week — `is_historical` is true in that case
   * and the UI surfaces a "data presensi terakhir DD MMM YYYY" hint.
   */
  trend_window?: {
    start: string; // YYYY-MM-DD
    end: string;   // YYYY-MM-DD
    is_historical: boolean;
  };
  computed_at?: string;
}

/** Cell state in the per-student calendar heatmap. */
export type HeatmapCellState =
  | 'present'
  | 'excused'
  | 'sick'
  | 'alpha'
  | 'holiday'
  | 'none';

/** One student row in the heatmap view. */
export interface StudentHeatmapEntry {
  id: string;
  name: string;
  student_number?: string | null;
  /** One cell per day in the window. */
  cells: HeatmapCellState[];
  /** Monthly percentage (present / total recorded × 100). */
  monthly_pct: number;
  present_days: number;
  total_days: number;
  /** Alert badge text ("⚠ 3× alpa berturut" / "Kehadiran rendah"). */
  alert_copy: string | null;
  alert: boolean;
}

/** Response from `/attendance/student-heatmap`. */
export interface StudentHeatmapResponse {
  days: number;
  start_date: string;
  end_date: string;
  students: StudentHeatmapEntry[];
  computed_at?: string;
}

/** One row in the admin Laporan list (`/attendance/summary`). */
export interface AdminAttendanceSummary {
  id: string;
  subject_id: string;
  subject_name: string;
  class_id: string;
  class_name: string;
  date: string;
  lesson_hour_id?: string | null;
  lesson_hour_name?: string | null;
  jam_ke?: number | null;
  total_students: number;
  present: number;
  absent: number;
  /** Optional pre-derived percentage. */
  percentage?: number;
  teacher_id?: string | null;
  teacher_name?: string | null;
}
