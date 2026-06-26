/**
 * Schedule types — teaching schedule for teacher + admin.
 *
 * Mirrors Flutter's `lib/features/schedule/domain/models/*.dart` plus
 * the admin-facing shapes (`ScheduleRow`, `FilterOptions`, `ScheduleStats`,
 * `ScheduleConflict`, `LessonHour`, `Day`).
 *
 * Two co-existing models:
 *   - `ScheduleSession` — teacher / parent / parent read view (light shape,
 *     normalized day-short-key `mon`..`sat`).
 *   - `ScheduleRow`     — admin CRUD view (full nested entity rows with
 *     UUID `day_id` + `lesson_hour_days_id`).
 *
 * Both are produced from the same `/teaching-schedule` endpoint family —
 * pick the parser that fits your screen.
 */

export type DayKey = 'mon' | 'tue' | 'wed' | 'thu' | 'fri' | 'sat';

// ───────────────────────────────────────────────────────────────────
// Teacher / parent / parent read shape
// ───────────────────────────────────────────────────────────────────

export interface ScheduleSession {
  id: string;
  /**
   * UUID of the `lesson_hour` slot row this session occupies (each
   * day×hour tuple owns a distinct UUID). Distinct from `id`, which is
   * the teaching-schedule row id. Carried so the Activity form can tag
   * a new activity with the exact lesson-hour the teacher picked —
   * mirrors Flutter's `Schedule.lessonHourId`.
   */
  lesson_hour_id?: string | null;
  day: DayKey;
  /** "07:30" HH:mm 24h. */
  start_time: string;
  end_time: string;
  /** Lesson hour ordinal (1, 2, 3...). */
  hour_index?: number;
  /** Day display label e.g. "Senin". */
  day_name?: string | null;
  class_id: string;
  class_name: string;
  subject_id: string;
  subject_name: string;
  room?: string | null;
  teacher_id?: string | null;
  teacher_name?: string | null;
  semester_name?: string | null;
  academic_year?: string | null;
}

// ───────────────────────────────────────────────────────────────────
// Admin CRUD shape — full row with all FK + UUID slot reference
// ───────────────────────────────────────────────────────────────────

export interface ScheduleRow {
  id: string;
  /** UUID of the (lesson_hour × day) slot row — what `store` / `reschedule`
   * write back as `lesson_hour_days_id`. */
  lesson_hour_days_id: string;
  /** Convenience day-short-key derived from day name. */
  day: DayKey;
  /** UUID of the day row. */
  day_id?: string | null;
  day_name?: string | null;
  /** Day ordering (1..6) from `days.order_number`. */
  day_order?: number | null;
  /** "07:30" — comes from the lesson_hour row. */
  start_time: string;
  end_time: string;
  /** 1..N ordinal jam ke-N. */
  hour_number: number;

  teacher_id?: string | null;
  teacher_name?: string | null;
  /** `teachers.user_id` — sometimes carried alongside the teacher_profile.id. */
  teacher_user_id?: string | null;

  subject_id: string;
  subject_name: string;

  class_id: string;
  class_name: string;
  class_grade_level?: string | null;

  semester_id?: string | null;
  semester_name?: string | null;
  academic_year_id?: string | number | null;
  academic_year?: string | null;

  room?: string | null;

  /** Backend may attach `conflict_with` IDs when /all is hit. */
  conflict_with?: string[] | null;
}

// ───────────────────────────────────────────────────────────────────
// Filter-options dropdown payload
// ───────────────────────────────────────────────────────────────────

export interface FilterOptionTeacher {
  id: string;
  name: string;
  user_id?: string | null;
}
export interface FilterOptionClass {
  id: string;
  name: string;
  grade_level?: string | null;
}
export interface FilterOptionDay {
  id: string;
  name: string;
  order_number: number;
}
export interface FilterOptionSemester {
  id: string;
  name: string;
}
export interface FilterOptionAcademicYear {
  id: string | number;
  year: string;
}

export interface ScheduleFilterOptions {
  teachers: FilterOptionTeacher[];
  classes: FilterOptionClass[];
  days: FilterOptionDay[];
  semesters: FilterOptionSemester[];
  academic_years: FilterOptionAcademicYear[];
}

// ───────────────────────────────────────────────────────────────────
// KPI stats (admin hub hero)
// ───────────────────────────────────────────────────────────────────

export interface ScheduleStats {
  total: number;
  total_teachers: number;
  total_classes: number;
  total_subjects: number;
  /** Sessions running today (based on server's current day). */
  today: number;
  /** Sessions whose slot collides with another (same teacher OR same class). */
  conflicts: number;
}

// ───────────────────────────────────────────────────────────────────
// Conflict row (pre-save probe + 409 response)
// ───────────────────────────────────────────────────────────────────

export interface ScheduleConflict {
  id: string;
  /** "teacher_conflict" | "class_conflict" | "slot_conflict" (server-decided). */
  type?: string | null;
  message?: string | null;
  teacher_id?: string | null;
  teacher_name?: string | null;
  class_id?: string | null;
  class_name?: string | null;
  subject_name?: string | null;
  day_name?: string | null;
  start_time?: string | null;
  end_time?: string | null;
  hour_number?: number | null;
  lesson_hour_days_id?: string | null;
}

// ───────────────────────────────────────────────────────────────────
// Lesson hour matrix (admin /lesson-hour CRUD)
// ───────────────────────────────────────────────────────────────────

export interface LessonHour {
  id: string;
  day_id: string;
  day_name?: string | null;
  day_order?: number | null;
  hour_number: number;
  start_time: string;
  end_time: string;
  room?: string | null;
}

export interface LessonHourPayload {
  day_id: string;
  hour_number: number;
  start_time: string; // HH:mm
  end_time: string;
  room?: string | null;
}

export interface LessonHourCopyDayPayload {
  source_day_id: string;
  target_day_id: string;
  overwrite?: boolean;
}

// ───────────────────────────────────────────────────────────────────
// Schedule write payload (create + update)
// ───────────────────────────────────────────────────────────────────

export interface SchedulePayload {
  teacher_id: string;
  subject_id: string;
  class_id: string;
  /** Multi-day fan-out — one create per day_id, all sharing the same
   * lesson_hour hour_number. Used in Frame D form. */
  days_ids?: string[];
  /** The reference lesson_hour row (its day determines hour_number).
   * Backend maps each day in days_ids to its own lesson_hour with the
   * same hour_number. */
  lesson_hour_id?: string;
  /** Direct slot ID — alternative to days_ids+lesson_hour_id. */
  lesson_hour_days_id?: string;
  semester_id: string;
  academic_year_id: string | number;
  room?: string | null;
}

// ───────────────────────────────────────────────────────────────────
// Bulk operation payloads
// ───────────────────────────────────────────────────────────────────

export interface BulkMovePayload {
  ids: string[];
  target_day_id: string;
  force?: boolean;
}

export interface BulkChangeTeacherPayload {
  ids: string[];
  teacher_id: string;
  force?: boolean;
}

export interface BulkOpResult {
  /** Returned by /bulk/move + /bulk/change-teacher when rows succeed. */
  moved?: string[];
  changed?: string[];
  /** Rows that were not applied due to validation/conflict. */
  skipped: Array<{
    id: string;
    reason: string;
    conflicts?: ScheduleConflict[];
    conflict_with?: string;
  }>;
  moved_count?: number;
  changed_count?: number;
}

export interface BulkDestroyResult {
  deleted_count: number;
}

// ───────────────────────────────────────────────────────────────────
// Per-session summary (teacher view)
// ───────────────────────────────────────────────────────────────────

export interface SessionSummary {
  attendance?: {
    filled?: boolean;
    hadir?: number;
    total?: number;
  } | null;
  class_activity?: {
    count?: number;
  } | null;
  material_progress?: {
    checked?: number;
    total?: number;
  } | null;
}

// ───────────────────────────────────────────────────────────────────
// Print PDF scope
// ───────────────────────────────────────────────────────────────────

export type PrintScope = 'all' | 'class' | 'teacher' | 'day';

export interface PrintPayload {
  scope: PrintScope;
  class_id?: string;
  teacher_id?: string;
  day_id?: string;
  semester_id?: string;
  academic_year_id?: string | number;
  orientation?: 'portrait' | 'landscape';
}

// ───────────────────────────────────────────────────────────────────
// Labels
// ───────────────────────────────────────────────────────────────────

export const DAY_LABELS: Record<DayKey, string> = {
  mon: 'Senin',
  tue: 'Selasa',
  wed: 'Rabu',
  thu: 'Kamis',
  fri: 'Jumat',
  sat: 'Sabtu',
};

export const DAY_ORDER: DayKey[] = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'];

/** Compose the same key the daily-summary endpoint uses. */
export function sessionSummaryKey(classId: string, subjectId: string): string {
  return `${classId}__${subjectId}`;
}

/** Day name → short key (server returns "Senin"/"Monday"). */
export function normalizeDayKey(raw: unknown): DayKey {
  const s = String(raw ?? '').toLowerCase();
  if (s.startsWith('sen') || s.startsWith('mon')) return 'mon';
  if (s.startsWith('sel') || s.startsWith('tue')) return 'tue';
  if (s.startsWith('rab') || s.startsWith('wed')) return 'wed';
  if (s.startsWith('kam') || s.startsWith('thu')) return 'thu';
  if (s.startsWith('jum') || s.startsWith('fri')) return 'fri';
  if (s.startsWith('sab') || s.startsWith('sat')) return 'sat';
  return 'mon';
}
