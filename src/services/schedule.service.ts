/**
 * ScheduleService — `/teaching-schedule/*` wrapper.
 *
 * Mirrors Flutter's `lib/features/schedule/data/schedule_service.dart`
 * plus the admin-side `schedule_admin_actions_service.dart` (reschedule,
 * bulk move, bulk change teacher, bulk delete, print, import).
 *
 * Two surfaces:
 *   - Teacher / parent read methods (`myWeek`, `classWeek`, summaries).
 *   - Admin CRUD + management methods (`list`, `getStats`,
 *     `getFilterOptions`, `create`, `update`, `destroy`, `reschedule`,
 *     `bulkMove`, `bulkChangeTeacher`, `bulkDestroy`, `getConflicts`,
 *     `printPdf`, `importExcel`).
 */
import { api } from '@/lib/http';
import { subjectFromJson, type Subject } from '@/types/entities';
import {
  normalizeDayKey,
  type BulkChangeTeacherPayload,
  type BulkDestroyResult,
  type BulkMovePayload,
  type BulkOpResult,
  type DayKey,
  type PrintPayload,
  type SchedulePayload,
  type ScheduleConflict,
  type ScheduleFilterOptions,
  type ScheduleRow,
  type ScheduleSession,
  type ScheduleStats,
  type SessionSummary,
} from '@/types/schedule';

// ───────────────────────────────────────────────────────────────────
// Helpers
// ───────────────────────────────────────────────────────────────────

function asStr(v: unknown, fallback = ''): string {
  if (v === null || v === undefined) return fallback;
  return String(v);
}

function asNum(v: unknown, fallback = 0): number {
  if (typeof v === 'number') return v;
  if (typeof v === 'string') {
    const n = Number(v);
    return Number.isFinite(n) ? n : fallback;
  }
  return fallback;
}

function sanitize(obj: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v === undefined || v === null || v === '') continue;
    if (Array.isArray(v) && v.length === 0) continue;
    out[k] = v;
  }
  return out;
}

/**
 * Fold a create payload's `class_id` (scalar, legacy) / `class_ids`
 * (array, jadwal-gabung) into the single wire shape the backend sees.
 * We always emit `class_ids: [...]`; the request validator accepts
 * both shapes, but the network payload becomes predictable this way.
 *
 * If both are set, `class_ids` wins (caller-intent is explicit —
 * they'd only pass an array when they mean to fan out to N classes).
 * If neither is set the field is simply omitted and the backend
 * returns its own validation error, which is the right behaviour —
 * silently defaulting here would mask a caller bug.
 */
function normaliseCreatePayload(
  payload: SchedulePayload,
): Record<string, unknown> {
  const out: Record<string, unknown> = { ...payload };
  // If caller passed `class_ids` use it; otherwise wrap the legacy
  // `class_id` scalar. `sanitize` strips empty arrays so a caller that
  // passed neither still yields no `class_ids` on the wire (rather
  // than sending `class_ids: []` which is a different validation
  // error than "field missing").
  if (Array.isArray(payload.class_ids) && payload.class_ids.length > 0) {
    out.class_ids = payload.class_ids;
    delete out.class_id;
  } else if (payload.class_id) {
    out.class_ids = [payload.class_id];
    delete out.class_id;
  }
  return sanitize(out);
}

function humanError(e: unknown, fallback: string): string {
  const ax = e as any;
  if (ax?.response?.data) {
    const data = ax.response.data;
    if (typeof data === 'string') return data;
    if (data?.message) return String(data.message);
    if (data?.error) return String(data.error);
    if (data?.errors && typeof data.errors === 'object') {
      const first = Object.values(data.errors)[0];
      if (Array.isArray(first) && first.length > 0) return String(first[0]);
    }
  }
  if (e instanceof Error) return e.message;
  return fallback;
}

// ───────────────────────────────────────────────────────────────────
// Parsers
// ───────────────────────────────────────────────────────────────────

/** Light parser — teacher / parent / parent read view. */
function sessionFromJson(raw: any): ScheduleSession {
  const subject =
    typeof raw.subject === 'object' && raw.subject !== null
      ? raw.subject
      : typeof raw.mata_pelajaran === 'object' && raw.mata_pelajaran !== null
        ? raw.mata_pelajaran
        : null;
  const cls =
    typeof raw.class === 'object' && raw.class !== null
      ? raw.class
      : typeof raw.kelas === 'object' && raw.kelas !== null
        ? raw.kelas
        : null;
  const teacher =
    typeof raw.teacher === 'object' && raw.teacher !== null
      ? raw.teacher
      : typeof raw.guru === 'object' && raw.guru !== null
        ? raw.guru
        : null;
  const lessonHour =
    typeof raw.lesson_hour === 'object' && raw.lesson_hour !== null
      ? raw.lesson_hour
      : null;
  const dayObj =
    (lessonHour && typeof lessonHour.day === 'object' ? lessonHour.day : null) ??
    (typeof raw.day === 'object' && raw.day !== null ? raw.day : null) ??
    (typeof raw.hari === 'object' && raw.hari !== null ? raw.hari : null);

  const startRaw =
    lessonHour?.start_time ??
    lessonHour?.jam_mulai ??
    raw.start_time ??
    raw.jam_mulai ??
    '';
  const endRaw =
    lessonHour?.end_time ??
    lessonHour?.jam_selesai ??
    raw.end_time ??
    raw.jam_selesai ??
    '';
  const hourNumRaw =
    lessonHour?.hour_number ??
    lessonHour?.jam_ke ??
    raw.hour_index ??
    raw.hour_number ??
    raw.jam_ke ??
    raw.lesson_hour;
  const hourNum =
    typeof hourNumRaw === 'number'
      ? hourNumRaw
      : Number(hourNumRaw) || undefined;

  const dayName =
    dayObj?.name ??
    dayObj?.nama ??
    raw.day_name ??
    raw.hari_nama ??
    (typeof raw.day === 'string' ? raw.day : null) ??
    (typeof raw.hari === 'string' ? raw.hari : null) ??
    null;

  const subjectName =
    subject?.name ??
    subject?.nama ??
    raw.subject_name ??
    raw.mata_pelajaran_nama ??
    (typeof raw.mata_pelajaran === 'string' ? raw.mata_pelajaran : null) ??
    raw.mapel ??
    '';
  const subjectId =
    subject?.id ?? raw.subject_id ?? raw.mata_pelajaran_id ?? '';
  const className =
    cls?.name ??
    cls?.nama ??
    raw.class_name ??
    raw.kelas_nama ??
    (typeof raw.kelas === 'string' ? raw.kelas : null) ??
    '';
  const classId = cls?.id ?? raw.class_id ?? raw.kelas_id ?? '';
  const teacherName =
    teacher?.name ??
    teacher?.nama ??
    raw.teacher_name ??
    raw.guru_nama ??
    (typeof raw.guru === 'string' ? raw.guru : null) ??
    null;
  const teacherId = teacher?.id ?? raw.teacher_id ?? raw.guru_id ?? null;

  let ay = raw.academic_year;
  if (ay && typeof ay === 'object') {
    ay = ay.year ?? ay.name ?? ay.nama ?? null;
  }

  let semesterName: string | null =
    raw.semester_name ?? raw.semester_nama ?? null;
  if (!semesterName) {
    const sem = raw.semester;
    if (typeof sem === 'string') semesterName = sem;
    else if (sem && typeof sem === 'object') {
      semesterName = sem.name ?? sem.nama ?? null;
    }
  }

  // Eager-loaded TeachingSchedule responses nest the slot under
  // `lesson_hour.id`; legacy/flat rows expose `lesson_hour_id` /
  // `jam_pelajaran_id` directly. Mirror Flutter's Schedule.fromJson
  // precedence so the Activity form can persist the exact slot UUID.
  const lessonHourId =
    lessonHour?.id ?? raw.lesson_hour_id ?? raw.jam_pelajaran_id ?? null;

  // ── Combined-class group fields ────────────────────────────────
  // A pre-deploy backend never ships these; parse defensively so the
  // UI treats a missing group_id as a plain single-class slot.
  const groupId = raw.schedule_group_id ?? null;
  const isGrouped =
    typeof raw.is_grouped === 'boolean' ? raw.is_grouped : !!groupId;
  const groupedNames = parseGroupedClassNames(raw.grouped_class_names);

  return {
    id: String(raw.id ?? ''),
    lesson_hour_id: lessonHourId ? String(lessonHourId) : null,
    day: normalizeDayKey(dayName ?? raw.day ?? raw.hari),
    day_name: dayName,
    start_time: String(startRaw).slice(0, 5),
    end_time: String(endRaw).slice(0, 5),
    hour_index: hourNum,
    class_id: String(classId),
    class_name: String(className),
    subject_id: String(subjectId),
    subject_name: String(subjectName),
    room: raw.room ?? raw.ruangan ?? lessonHour?.room ?? null,
    teacher_id: teacherId ?? null,
    teacher_name: teacherName,
    semester_name: semesterName,
    academic_year: ay ?? raw.tahun_ajaran ?? null,
    schedule_group_id: groupId ? String(groupId) : null,
    is_grouped: isGrouped,
    grouped_class_names: groupedNames,
  };
}

/**
 * Normalise the `grouped_class_names` field — the backend ships an
 * array of `{id, name}` refs for sibling classes in the same
 * jadwal-gabung group. Missing/malformed input becomes `[]` so
 * downstream code can always iterate.
 */
function parseGroupedClassNames(
  raw: unknown,
): Array<{ id: string; name: string }> {
  if (!Array.isArray(raw)) return [];
  const out: Array<{ id: string; name: string }> = [];
  for (const entry of raw) {
    if (!entry || typeof entry !== 'object') continue;
    const e = entry as AnyRecordLoose;
    const id = e.id ?? e.class_id ?? e.kelas_id;
    const name = e.name ?? e.nama ?? e.class_name;
    if (id == null || name == null) continue;
    out.push({ id: String(id), name: String(name) });
  }
  return out;
}

type AnyRecordLoose = Record<string, unknown>;

/** Full parser — admin CRUD row with UUID slot reference + day_id. */
function rowFromJson(raw: any): ScheduleRow {
  const lessonHour =
    typeof raw.lesson_hour === 'object' && raw.lesson_hour !== null
      ? raw.lesson_hour
      : typeof raw.lessonHour === 'object' && raw.lessonHour !== null
        ? raw.lessonHour
        : null;
  const dayObj =
    (lessonHour && typeof lessonHour.day === 'object' ? lessonHour.day : null) ??
    (typeof raw.day === 'object' && raw.day !== null ? raw.day : null) ??
    null;
  const subject =
    typeof raw.subject === 'object' && raw.subject !== null ? raw.subject : null;
  const cls =
    typeof raw.class === 'object' && raw.class !== null ? raw.class : null;
  const teacher =
    typeof raw.teacher === 'object' && raw.teacher !== null ? raw.teacher : null;
  const semester =
    typeof raw.semester === 'object' && raw.semester !== null
      ? raw.semester
      : null;
  const ay =
    typeof raw.academic_year === 'object' && raw.academic_year !== null
      ? raw.academic_year
      : typeof raw.academicYear === 'object' && raw.academicYear !== null
        ? raw.academicYear
        : null;

  const dayName = dayObj?.name ?? dayObj?.nama ?? raw.day_name ?? null;
  const startTime = String(
    lessonHour?.start_time ?? raw.start_time ?? '',
  ).slice(0, 5);
  const endTime = String(
    lessonHour?.end_time ?? raw.end_time ?? '',
  ).slice(0, 5);
  const hourNumber = asNum(
    lessonHour?.hour_number ?? raw.hour_number ?? raw.hour_index ?? 0,
  );

  return {
    id: asStr(raw.id),
    lesson_hour_days_id: asStr(
      raw.lesson_hour_days_id ?? raw.lesson_hour_id ?? lessonHour?.id ?? '',
    ),
    day: normalizeDayKey(dayName),
    day_id: dayObj?.id ?? lessonHour?.day_id ?? raw.day_id ?? null,
    day_name: dayName,
    day_order:
      dayObj?.order_number !== undefined ? asNum(dayObj.order_number) : null,
    start_time: startTime,
    end_time: endTime,
    hour_number: hourNumber,

    teacher_id: teacher?.id ?? raw.teacher_id ?? null,
    teacher_name: teacher?.name ?? teacher?.nama ?? raw.teacher_name ?? null,
    teacher_user_id: teacher?.user_id ?? raw.teacher_user_id ?? null,

    subject_id: asStr(subject?.id ?? raw.subject_id),
    subject_name: asStr(subject?.name ?? raw.subject_name),

    class_id: asStr(cls?.id ?? raw.class_id),
    class_name: asStr(cls?.name ?? raw.class_name),
    class_grade_level: cls?.grade_level ?? raw.class_grade_level ?? null,

    semester_id: semester?.id ?? raw.semester_id ?? null,
    semester_name: semester?.name ?? raw.semester_name ?? null,
    academic_year_id: ay?.id ?? raw.academic_year_id ?? null,
    academic_year: ay?.year ?? ay?.name ?? raw.academic_year ?? null,

    room: raw.room ?? lessonHour?.room ?? null,
    conflict_with: Array.isArray(raw.conflict_with)
      ? raw.conflict_with.map(String)
      : null,
    // ── Combined-class group fields (defensive against pre-deploy) ─
    schedule_group_id: raw.schedule_group_id
      ? String(raw.schedule_group_id)
      : null,
    is_grouped:
      typeof raw.is_grouped === 'boolean'
        ? raw.is_grouped
        : !!raw.schedule_group_id,
    grouped_class_names: parseGroupedClassNames(raw.grouped_class_names),
  };
}

function conflictFromJson(raw: any): ScheduleConflict {
  const lessonHour =
    typeof raw.lesson_hour === 'object' && raw.lesson_hour !== null
      ? raw.lesson_hour
      : null;
  const subject =
    typeof raw.subject === 'object' && raw.subject !== null ? raw.subject : null;
  const teacher =
    typeof raw.teacher === 'object' && raw.teacher !== null ? raw.teacher : null;
  const cls =
    typeof raw.class === 'object' && raw.class !== null ? raw.class : null;
  const dayObj = lessonHour?.day ?? null;

  return {
    id: asStr(raw.id),
    type: raw.type ?? null,
    message: raw.message ?? null,
    teacher_id: teacher?.id ?? raw.teacher_id ?? null,
    teacher_name: teacher?.name ?? raw.teacher_name ?? null,
    class_id: cls?.id ?? raw.class_id ?? null,
    class_name: cls?.name ?? raw.class_name ?? null,
    subject_name: subject?.name ?? raw.subject_name ?? null,
    day_name: dayObj?.name ?? raw.day_name ?? null,
    start_time: lessonHour?.start_time
      ? String(lessonHour.start_time).slice(0, 5)
      : raw.start_time ?? null,
    end_time: lessonHour?.end_time
      ? String(lessonHour.end_time).slice(0, 5)
      : raw.end_time ?? null,
    hour_number:
      lessonHour?.hour_number !== undefined
        ? asNum(lessonHour.hour_number)
        : raw.hour_number ?? null,
    lesson_hour_days_id:
      raw.lesson_hour_days_id ?? lessonHour?.id ?? null,
  };
}

function summaryFromJson(raw: any): SessionSummary {
  const att = raw?.attendance;
  const act = raw?.class_activity;
  const mat = raw?.material_progress;
  return {
    attendance:
      att && typeof att === 'object'
        ? {
            filled: Boolean(att.filled ?? att.is_filled ?? false),
            hadir: Number(att.hadir ?? att.present ?? 0),
            total: Number(att.total ?? att.count ?? 0),
          }
        : null,
    class_activity:
      act && typeof act === 'object'
        ? { count: Number(act.count ?? act.total ?? 0) }
        : null,
    material_progress:
      mat && typeof mat === 'object'
        ? {
            checked: Number(mat.checked ?? mat.done ?? 0),
            total: Number(mat.total ?? 0),
          }
        : null,
  };
}

// ───────────────────────────────────────────────────────────────────
// Admin filters
// ───────────────────────────────────────────────────────────────────

export interface AdminScheduleFilters {
  teacher_id?: string;
  class_id?: string;
  subject_id?: string;
  day_id?: string;
  semester_id?: string;
  academic_year_id?: string | number;
  lesson_hour_id?: string;
  hour_number?: number;
  search?: string;
  page?: number;
  per_page?: number;
}

export interface PaginatedSchedules {
  items: ScheduleRow[];
  total: number;
  current_page: number;
  last_page: number;
  per_page: number;
}

// ───────────────────────────────────────────────────────────────────
// Import discriminated union — mirrors ImportSchedulesAction's four
// possible responses. Callers switch on `status` to render each screen
// (missing hours dialog, missing subjects dialog, validation report,
// success toast).
// ───────────────────────────────────────────────────────────────────

/** Individual lesson-hour row missing from school settings. */
export interface MissingLessonHourRow {
  day_name?: string;
  hour_number?: number;
  start_time?: string | null;
  end_time?: string | null;
}

/** (teacher, subject) pair from the Excel that isn't assigned in the DB. */
export interface MissingSubjectPerTeacher {
  teacher_name: string;
  subject_name: string;
}

/** Per-row failure entry inside a VALIDATION_FAILED payload. */
export interface ImportValidationDetail {
  row?: number;
  label?: string;
  sublabel?: string;
  reason?: string;
}

/** Success bucket-counts + optional per-row details. */
export interface ScheduleImportResults {
  created: number;
  restored: number;
  skipped: number;
  failed: number;
  details?: ImportValidationDetail[];
}

/**
 * Known discriminators. Kept exported so callers can enumerate them
 * for exhaustiveness / feature-flag work.
 */
export type ScheduleImportStatus =
  | 'SUCCESS'
  | 'MISSING_LESSON_HOURS'
  | 'MISSING_SUBJECTS_PER_TEACHER'
  | 'VALIDATION_FAILED';

/**
 * Discriminated union of every recognised import response. Callers
 * `switch (res.status)` on the literal to unwrap safely. Unknown
 * status strings from a newer backend fall through to the type-`never`
 * else branch — surface them as an error toast rather than trying to
 * read fields that don't exist on the actual payload.
 */
export type ScheduleImportResponse =
  | { status: 'SUCCESS'; results: ScheduleImportResults }
  | {
      status: 'MISSING_LESSON_HOURS';
      missing_hours: MissingLessonHourRow[];
    }
  | {
      status: 'MISSING_SUBJECTS_PER_TEACHER';
      missing_subjects: MissingSubjectPerTeacher[];
    }
  | {
      status: 'VALIDATION_FAILED';
      results: { details: ImportValidationDetail[] } & Partial<ScheduleImportResults>;
    };

// ───────────────────────────────────────────────────────────────────
// Setup-first — GET /schedule/prereq-check
// ───────────────────────────────────────────────────────────────────
//
// Sprint 2 (MR A backend) — asks the server whether the four things a
// schedule row depends on are in place BEFORE the admin lands on the
// form. If any of them are missing, the ScheduleFormModal renders
// ScheduleSetupChecklist instead of the form so the admin can seed
// the school without leaving the drawer. `ready` collapses the four
// bools into the single value the modal reads to decide "form or
// checklist".

/** One row inside a prereq-check response. */
export interface PrereqCheckSection {
  count: number;
  has_any: boolean;
}

/** Full prereq-check payload. `ready === true` unlocks the form. */
export interface SchedulePrereqCheck {
  teachers: PrereqCheckSection;
  classes: PrereqCheckSection;
  lesson_hours: PrereqCheckSection;
  rooms: PrereqCheckSection;
  ready: boolean;
}

// ───────────────────────────────────────────────────────────────────
// Lesson-hours seed — POST /lesson-hours/seed
// ───────────────────────────────────────────────────────────────────
//
// One-tap "install the 8-hour SMP grid" (or the 9-hour SMA one).
// Discriminated so callers can tell a genuine seed from a skip caused
// by pre-existing hours (existing school re-visiting the checklist).

/** Preset name accepted by the seed endpoint. */
export type LessonHourSeedPreset = 'smp' | 'sma';

/** Body sent to `/lesson-hours/seed`. */
export interface LessonHourSeedPayload {
  preset: LessonHourSeedPreset;
  overwrite?: boolean;
}

/** Response from `/lesson-hours/seed`. */
export type LessonHourSeedResponse =
  | { status: 'SUCCESS'; created: number; skipped: number }
  | { status: 'SKIPPED'; created: number; skipped: number; existing?: number };

// ───────────────────────────────────────────────────────────────────
// Slot-filtered teacher picker — GET /teaching-schedules/available-teachers
// ───────────────────────────────────────────────────────────────────
//
// Pola B — after Kelas + Slot (day + lesson-hour) are set, the Guru
// dropdown lists only teachers who are FREE for that slot (no other
// schedule row occupies them in the same semester/AY). The wali kelas
// flag lets the form sort the class's homeroom teacher first + render
// a "Wali Kelas" badge next to their name.

/** One row inside the /available-teachers response. */
export interface AvailableTeacher {
  id: string;
  name: string;
  subjects_count: number;
  is_wali_kelas_of_this_class: boolean;
}

/** Query params for /available-teachers. Semester/AY are optional —
 *  the backend defaults to the active semester + AY on the tenant. */
export interface AvailableTeachersQuery {
  classId: string;
  dayId: string;
  lessonHourId: string;
  semesterId?: string;
  academicYearId?: string | number;
}

// ───────────────────────────────────────────────────────────────────
// Timetable matrix — GET /teaching-schedules/matrix
// ───────────────────────────────────────────────────────────────────
//
// Sprint 3 Pola C — the per-class week grid entry mode. Backend
// contract (MR A of Sprint 3):
//
//   GET /teaching-schedules/matrix?class_id=&semester_id=&academic_year_id=
//
// Returns days + hours + a cell map keyed by `${day_id}:${hour_number}`.
// Empty cells simply have no key. The grid clicks a filled cell to
// EDIT (pass schedule_id) and an empty one to CREATE (pass day_id +
// lesson_hour_id pre-filled so the admin doesn't have to re-pick the
// slot they just clicked).

/** One day row in the matrix header. `display_name` is the Bahasa
 *  version ("Senin") shown to the user; `name` is the canonical
 *  English key ("Monday") the DB stores. */
export interface TimetableDay {
  id: string;
  name: string;
  display_name: string;
  order_number: number;
}

/** One row on the left of the grid — a lesson-hour slot. `day_id` is
 *  the hour's OWNER day (each day×hour tuple gets its own UUID) but
 *  the grid only reads `hour_number` because that's what stitches
 *  cells across all days into a single row. */
export interface TimetableHour {
  id: string;
  hour_number: number;
  name: string;
  start_time: string;
  end_time: string;
  day_id: string;
}

/** Filled cell — a teaching-schedule row exposed at the cell's
 *  position. Empty cells are simply absent from `cells`. */
export interface TimetableCell {
  schedule_id: string;
  teacher: { id: string; name: string };
  subject: { id: string; name: string; code?: string | null };
  room?: string | null;
  /**
   * When the underlying row belongs to a jadwal-gabung group, the
   * backend surfaces the group id here so the timetable grid can
   * route the render into the "⚭ GABUNG" virtual column instead of
   * the class's own column. `null`/`undefined` for a plain slot or
   * a pre-deploy backend that hasn't shipped the field.
   */
  schedule_group_id?: string | null;
  /** Sibling class refs for the group (empty for plain slots). */
  grouped_class_names?: Array<{ id: string; name: string }>;
}

/** Matrix meta strip — counters + IDs surfaced under the grid. */
export interface TimetableMeta {
  class_id: string;
  class_name: string;
  semester_id: string;
  academic_year_id: string | number;
  total_filled: number;
  total_slots: number;
}

/** Full matrix payload — days + hours + cell map + meta. */
export interface TimetableMatrix {
  days: TimetableDay[];
  hours: TimetableHour[];
  /** Keyed `${day_id}:${hour_number}` — a Record, not a Map, so it
   *  survives JSON round-trips and Vue reactivity untouched. */
  cells: Record<string, TimetableCell>;
  meta: TimetableMeta;
}

/** Query params for /teaching-schedules/matrix. */
export interface TimetableMatrixQuery {
  classId: string;
  semesterId?: string;
  academicYearId?: string | number;
}

// ───────────────────────────────────────────────────────────────────
// Service
// ───────────────────────────────────────────────────────────────────

export const ScheduleService = {
  // ═════════════════════════════════════════════════════════════════
  // Teacher / parent / parent read methods (existing)
  // ═════════════════════════════════════════════════════════════════

  /**
   * Teacher's own schedule for the week.
   *
   * Always uses `/teaching-schedule/current` — that endpoint resolves
   * the teacher from the auth context (Sanctum token + X-School-ID).
   *
   * NOTE: the Flutter app passes a `teacher_id` to the alternate
   * `/teaching-schedule/teacher/{id}` route, but that id is the
   * `teacher_profile.id` row, not `user.id`. The auth payload only
   * gives us `user.id`, so using the `/current` route is the only
   * way to avoid a silent 0-result response.
   */
  async myWeek(
    teacherId?: string,
    opts: {
      day_id?: string;
      semester_id?: string;
      academic_year_id?: string;
    } = {},
  ): Promise<ScheduleSession[]> {
    try {
      const url = teacherId
        ? `/teaching-schedule/teacher/${teacherId}`
        : '/teaching-schedule/current';
      const res = await api.get(url, {
        params: {
          ...(opts.day_id ? { day_id: opts.day_id } : {}),
          ...(opts.semester_id ? { semester_id: opts.semester_id } : {}),
          ...(opts.academic_year_id
            ? { academic_year_id: opts.academic_year_id }
            : {}),
        },
      });
      const body = res.data?.data ?? res.data ?? [];
      return (Array.isArray(body) ? body : []).map(sessionFromJson);
    } catch {
      return [];
    }
  },

  /** Parent-kelas view — full week for one class. */
  async classWeek(
    classId: string,
    opts: {
      semester_id?: string;
      academic_year_id?: string;
    } = {},
  ): Promise<ScheduleSession[]> {
    if (!classId) return [];
    try {
      const res = await api.get('/teaching-schedule', {
        params: {
          class_id: classId,
          ...(opts.semester_id ? { semester_id: opts.semester_id } : {}),
          ...(opts.academic_year_id
            ? { academic_year_id: opts.academic_year_id }
            : {}),
        },
      });
      const body = res.data?.data ?? res.data ?? [];
      return (Array.isArray(body) ? body : []).map(sessionFromJson);
    } catch {
      return [];
    }
  },

  /** Daily summary keyed by `{class_id}__{subject_id}`. */
  async getDailySummary(args: {
    teacher_id: string;
    date?: string;
    academic_year_id?: string;
  }): Promise<Record<string, SessionSummary>> {
    try {
      const res = await api.get('/teaching-schedule/daily-summary', {
        params: {
          teacher_id: args.teacher_id,
          ...(args.date ? { date: args.date } : {}),
          ...(args.academic_year_id
            ? { academic_year_id: args.academic_year_id }
            : {}),
        },
      });
      const body = res.data?.data ?? res.data ?? {};
      const out: Record<string, SessionSummary> = {};
      if (body && typeof body === 'object') {
        for (const [k, v] of Object.entries(body)) {
          out[k] = summaryFromJson(v);
        }
      }
      return out;
    } catch {
      return {};
    }
  },

  /** Week summary returns `{ days, progress }`. */
  async getWeekSummary(args: {
    teacher_id: string;
    week_start?: string;
    academic_year_id?: string;
  }): Promise<{
    days: Record<string, Record<string, SessionSummary>>;
    progress: Record<string, unknown>;
  }> {
    try {
      const res = await api.get('/teaching-schedule/week-summary', {
        params: {
          teacher_id: args.teacher_id,
          ...(args.week_start ? { week_start: args.week_start } : {}),
          ...(args.academic_year_id
            ? { academic_year_id: args.academic_year_id }
            : {}),
        },
      });
      const body = res.data?.data ?? res.data ?? {};
      const days: Record<string, Record<string, SessionSummary>> = {};
      if (body?.days && typeof body.days === 'object') {
        for (const [date, perKey] of Object.entries(
          body.days as Record<string, any>,
        )) {
          if (perKey && typeof perKey === 'object') {
            const inner: Record<string, SessionSummary> = {};
            for (const [k, v] of Object.entries(perKey)) {
              inner[k] = summaryFromJson(v);
            }
            days[date] = inner;
          }
        }
      }
      return { days, progress: body.progress ?? {} };
    } catch {
      return { days: {}, progress: {} };
    }
  },

  /** Records material view from a schedule slot. */
  async recordMaterialView(args: {
    teacher_id: string;
    class_id: string;
    subject_id: string;
    date: string;
    lesson_hour_id?: string;
  }): Promise<void> {
    try {
      await api.post('/teaching-schedule/record-material-view', {
        teacher_id: args.teacher_id,
        class_id: args.class_id,
        subject_id: args.subject_id,
        date: args.date,
        ...(args.lesson_hour_id ? { lesson_hour_id: args.lesson_hour_id } : {}),
      });
    } catch {
      // non-fatal
    }
  },

  // ═════════════════════════════════════════════════════════════════
  // Admin CRUD + management
  // ═════════════════════════════════════════════════════════════════

  /**
   * GET /teaching-schedule — paginated list with filters. School-wide,
   * NOT the signed-in teacher's. This is the admin hub's primary read.
   */
  async list(filters: AdminScheduleFilters = {}): Promise<PaginatedSchedules> {
    try {
      const params = sanitize({ per_page: 200, ...filters });
      // The backend forwards to getFilteredSchedule when any filter is
      // present — same endpoint either way.
      const res = await api.get('/teaching-schedule', { params });
      const body = res.data;
      // Backend may wrap pagination or return a plain array depending
      // on whether filters were present.
      const items = Array.isArray(body?.data)
        ? body.data
        : Array.isArray(body)
          ? body
          : Array.isArray(body?.schedules)
            ? body.schedules
            : [];
      return {
        items: items.map(rowFromJson),
        total: asNum(body?.total ?? items.length),
        current_page: asNum(body?.current_page ?? 1),
        last_page: asNum(body?.last_page ?? 1),
        per_page: asNum(body?.per_page ?? items.length ?? 0),
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat jadwal.'));
    }
  },

  /**
   * GET /teaching-schedule/all — full timetable (no pagination), used
   * by the matrix grid view.
   */
  async listAll(filters: AdminScheduleFilters = {}): Promise<ScheduleRow[]> {
    try {
      const params = sanitize(filters);
      const res = await api.get('/teaching-schedule/all', { params });
      const body = res.data?.data ?? res.data ?? [];
      return (Array.isArray(body) ? body : []).map(rowFromJson);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat matrix jadwal.'));
    }
  },

  /** GET /teaching-schedule/stats — KPI strip data. */
  async getStats(filters: AdminScheduleFilters = {}): Promise<ScheduleStats> {
    try {
      const res = await api.get('/teaching-schedule/stats', {
        params: sanitize(filters),
      });
      const body = res.data ?? {};
      return {
        total: asNum(body.total),
        total_teachers: asNum(body.total_teachers ?? body.totalTeachers),
        total_classes: asNum(body.total_classes ?? body.totalClasses),
        total_subjects: asNum(body.total_subjects ?? body.totalSubjects),
        today: asNum(body.today),
        conflicts: asNum(body.conflicts),
      };
    } catch {
      return {
        total: 0,
        total_teachers: 0,
        total_classes: 0,
        total_subjects: 0,
        today: 0,
        conflicts: 0,
      };
    }
  },

  /** GET /teaching-schedule/filter-options. */
  async getFilterOptions(opts: {
    academic_year_id?: string | number;
  } = {}): Promise<ScheduleFilterOptions> {
    try {
      const res = await api.get('/teaching-schedule/filter-options', {
        params: sanitize(opts),
      });
      const body = res.data?.data ?? res.data ?? {};
      return {
        teachers: Array.isArray(body.teachers)
          ? body.teachers.map((t: any) => ({
              id: asStr(t.id),
              name: asStr(t.name),
              user_id: t.user_id ?? null,
            }))
          : [],
        classes: Array.isArray(body.classes)
          ? body.classes.map((c: any) => ({
              id: asStr(c.id),
              name: asStr(c.name),
              grade_level: c.grade_level ?? null,
            }))
          : [],
        days: Array.isArray(body.days)
          ? body.days.map((d: any) => ({
              id: asStr(d.id),
              name: asStr(d.name),
              order_number: asNum(d.order_number),
            }))
          : [],
        semesters: Array.isArray(body.semesters)
          ? body.semesters.map((s: any) => ({
              id: asStr(s.id),
              name: asStr(s.name),
            }))
          : [],
        academic_years: Array.isArray(body.academic_years)
          ? body.academic_years.map((ay: any) => ({
              id: ay.id,
              year: asStr(ay.year ?? ay.name),
            }))
          : [],
      };
    } catch {
      return {
        teachers: [],
        classes: [],
        days: [],
        semesters: [],
        academic_years: [],
      };
    }
  },

  /**
   * GET /teaching-schedule/conflicts — pre-save probe.
   * Returns the rows that would collide with the proposed slot.
   */
  async getConflicts(args: {
    class_id: string;
    teacher_id?: string;
    semester_id: string;
    academic_year_id: string | number;
    lesson_hour_id: string;
    days_ids: string[];
    exclude_id?: string;
  }): Promise<ScheduleConflict[]> {
    try {
      const res = await api.get('/teaching-schedule/conflicts', {
        params: sanitize({
          class_id: args.class_id,
          teacher_id: args.teacher_id,
          semester_id: args.semester_id,
          academic_year_id: args.academic_year_id,
          lesson_hour_id: args.lesson_hour_id,
          days_ids: args.days_ids.join(','),
          exclude_id: args.exclude_id,
        }),
      });
      const body = res.data ?? [];
      return (Array.isArray(body) ? body : []).map(conflictFromJson);
    } catch {
      return [];
    }
  },

  /**
   * POST /teaching-schedule — create (with optional multi-day AND
   * multi-class fan-out).
   *
   * Payload normalisation:
   * - Caller may pass either `class_id` (scalar, legacy single-class
   *   flow) or `class_ids` (array, jadwal-gabung flow).
   * - We always send `class_ids` on the wire — the backend's request
   *   validator accepts both, but standardising here means the network
   *   inspector shows a consistent shape and the field-order in the
   *   payload never surprises the QA reviewer.
   * - If both are set, `class_ids` wins (caller-intent explicit).
   *
   * A group of 2+ classes triggers backend to mint a shared
   * `schedule_group_id`; a single class stays plain.
   */
  async create(payload: SchedulePayload): Promise<ScheduleRow[]> {
    try {
      const body = normaliseCreatePayload(payload);
      const res = await api.post('/teaching-schedule', body);
      const data = res.data?.data ?? res.data;
      // Server may return single row, array (multi-day/multi-class),
      // or a `{group_id, schedules: [...]}` envelope for jadwal gabung.
      if (Array.isArray(data)) return data.map(rowFromJson);
      if (data && typeof data === 'object') {
        const envelope = data as Record<string, unknown>;
        if (Array.isArray(envelope.schedules)) {
          return (envelope.schedules as unknown[]).map((r) =>
            rowFromJson(r as any),
          );
        }
        return [rowFromJson(data)];
      }
      return [];
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menyimpan jadwal.'));
    }
  },

  /**
   * PUT /teaching-schedule/{id} — update single row (or group scope).
   *
   * When editing a grouped row (`schedule_group_id != null`), passing
   * `class_ids` sync-changes the group's class membership: siblings
   * added, removed, or kept per the array. The backend keeps the
   * shared `schedule_group_id` on any surviving sibling. Callers
   * editing a plain single-class slot can keep sending `class_id`
   * exactly as before — the payload normaliser handles both.
   */
  async update(
    id: string,
    payload: Partial<SchedulePayload>,
  ): Promise<ScheduleRow> {
    try {
      const body = normaliseCreatePayload(payload as SchedulePayload);
      const res = await api.put(`/teaching-schedule/${id}`, body);
      const data = res.data?.data ?? res.data;
      return rowFromJson(data);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memperbarui jadwal.'));
    }
  },

  /**
   * DELETE /teaching-schedule/{id}.
   *
   * `scope: 'row'` (default) deletes only this row — safe for a plain
   * single-class schedule and for pruning one member from a group.
   * `scope: 'group'` cascades to every sibling row that shares the
   * row's `schedule_group_id` — used when the admin confirms "hapus
   * semua kelas dalam gabungan (N kelas)". Backend contract: query
   * param `scope=group` opts into the cascade; anything else is a
   * plain single-row delete.
   */
  async destroy(
    id: string,
    opts: { scope?: 'row' | 'group' } = {},
  ): Promise<void> {
    try {
      const config =
        opts.scope === 'group' ? { params: { scope: 'group' } } : undefined;
      await api.delete(`/teaching-schedule/${id}`, config);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menghapus jadwal.'));
    }
  },

  /**
   * PATCH /teaching-schedule/{id}/reschedule — drag-drop reschedule.
   * Body: { lesson_hour_days_id, force? }
   * Throws an Error with a `.conflicts` annotation when the server
   * returns 409 (the UI should show "Paksa Simpan").
   */
  async reschedule(
    id: string,
    payload: { lesson_hour_days_id: string; force?: boolean },
  ): Promise<ScheduleRow> {
    try {
      const res = await api.patch(`/teaching-schedule/${id}/reschedule`, payload);
      const data = res.data?.data ?? res.data;
      return rowFromJson(data);
    } catch (e) {
      const ax = e as any;
      if (ax?.response?.status === 409 && ax.response.data?.conflicts) {
        const err = new Error('Slot bentrok dengan jadwal lain.') as Error & {
          conflicts?: ScheduleConflict[];
        };
        err.conflicts = (ax.response.data.conflicts as any[]).map(conflictFromJson);
        throw err;
      }
      throw new Error(humanError(e, 'Gagal memindahkan slot.'));
    }
  },

  /** PATCH /teaching-schedule/bulk/move. */
  async bulkMove(payload: BulkMovePayload): Promise<BulkOpResult> {
    try {
      const res = await api.patch('/teaching-schedule/bulk/move', payload);
      const body = res.data ?? {};
      return {
        moved: Array.isArray(body.moved) ? body.moved.map(String) : [],
        moved_count: asNum(body.moved_count),
        skipped: Array.isArray(body.skipped) ? body.skipped : [],
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memindahkan jadwal massal.'));
    }
  },

  /** PATCH /teaching-schedule/bulk/change-teacher. */
  async bulkChangeTeacher(
    payload: BulkChangeTeacherPayload,
  ): Promise<BulkOpResult> {
    try {
      const res = await api.patch(
        '/teaching-schedule/bulk/change-teacher',
        payload,
      );
      const body = res.data ?? {};
      return {
        changed: Array.isArray(body.changed) ? body.changed.map(String) : [],
        changed_count: asNum(body.changed_count),
        skipped: Array.isArray(body.skipped) ? body.skipped : [],
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal ganti guru massal.'));
    }
  },

  /** DELETE /teaching-schedule/bulk. */
  async bulkDestroy(ids: string[]): Promise<BulkDestroyResult> {
    try {
      const res = await api.delete('/teaching-schedule/bulk', {
        data: { ids },
      });
      return { deleted_count: asNum(res.data?.deleted_count) };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menghapus jadwal massal.'));
    }
  },

  /**
   * POST /teaching-schedule/print-pdf — streams a PDF blob.
   * Returns a Blob — caller wraps in URL.createObjectURL or downloads.
   */
  async printPdf(payload: PrintPayload): Promise<Blob> {
    const res = await api.post('/teaching-schedule/print-pdf', payload, {
      responseType: 'blob',
    });
    return res.data as Blob;
  },

  /** Convenience: triggers a download. */
  async downloadPdf(
    payload: PrintPayload,
    suggestedName = 'jadwal-sekolah.pdf',
  ): Promise<void> {
    const blob = await this.printPdf(payload);
    const url = URL.createObjectURL(blob);
    try {
      const a = document.createElement('a');
      a.href = url;
      a.download = suggestedName;
      document.body.appendChild(a);
      a.click();
      a.remove();
    } finally {
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    }
  },

  /** GET /teaching-schedule/template — download Excel template blob. */
  async downloadTemplate(): Promise<void> {
    const res = await api.get('/teaching-schedule/template', {
      responseType: 'blob',
    });
    const url = URL.createObjectURL(res.data as Blob);
    try {
      const a = document.createElement('a');
      a.href = url;
      a.download = 'template-jadwal.xlsx';
      document.body.appendChild(a);
      a.click();
      a.remove();
    } finally {
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    }
  },

  /**
   * POST /teaching-schedule/import — upload Excel. The response is a
   * discriminated union — callers must switch on `status` to know
   * whether to render a confirm-dialog (MISSING_LESSON_HOURS,
   * MISSING_SUBJECTS_PER_TEACHER), a validation report
   * (VALIDATION_FAILED), or fire a success toast (SUCCESS). Missing
   * lesson hours + missing subjects are chained by the backend: pass
   * both flags on the retry and it will register hours + create-and-
   * assign subjects atomically before importing.
   */
  async importExcel(
    file: File,
    opts:
      | boolean
      | {
          createMissingHours?: boolean;
          createMissingSubjects?: boolean;
        } = false,
  ): Promise<ScheduleImportResponse> {
    // Back-compat: earlier callers passed a bare boolean for
    // createMissingHours. Preserve that call shape while accepting the
    // new options object.
    const {
      createMissingHours = false,
      createMissingSubjects = false,
    } = typeof opts === 'boolean' ? { createMissingHours: opts } : opts;
    try {
      const fd = new FormData();
      fd.append('file', file);
      if (createMissingHours) fd.append('create_missing_hours', '1');
      if (createMissingSubjects) fd.append('create_missing_subjects', '1');
      const res = await api.post('/teaching-schedule/import', fd, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      return res.data as ScheduleImportResponse;
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mengimpor jadwal.'));
    }
  },

  /**
   * POST /subject with `assign_to_teacher_id` — creates the mapel and
   * attaches it to the teacher atomically. Used by the schedule form's
   * inline Quick-Add panel so admins don't have to leave the drawer
   * when a picked teacher has no subjects yet. Backend contract:
   * MR !439 in edu_core.
   */
  async createSubjectAndAssign(args: {
    name: string;
    teacherId: string;
    code?: string | null;
    /** Grade to stamp on the new mapel (the class's grade_level). */
    grade?: string | number | null;
  }): Promise<Subject> {
    try {
      const payload: Record<string, unknown> = {
        name: args.name,
        assign_to_teacher_id: args.teacherId,
      };
      if (args.code) payload.code = args.code;
      if (args.grade !== undefined && args.grade !== null && args.grade !== '') {
        payload.grade = args.grade;
      }
      const res = await api.post('/subject', payload);
      const body = res.data as Record<string, unknown>;
      return subjectFromJson(
        (body.data ?? body) as Record<string, unknown>,
      );
    } catch (e) {
      throw new Error(humanError(e, 'Gagal membuat mapel.'));
    }
  },

  /**
   * Attach one or more EXISTING subject_school rows to a teacher without
   * touching their other assignments. Backend contract:
   * `POST /teacher/{id}/subjects` with `mode=attach` + `subject_ids: [...]`
   * (see TeacherController::syncSubjects — MR !439). Tenant-safe:
   * subject ids that don't belong to the caller's school are silently
   * filtered out server-side.
   *
   * Used by the Quick-Add "Pilih Existing" tab so admins can wire an
   * already-created school subject to a fresh guru instead of minting
   * a duplicate. syncWithoutDetaching semantics preserve any other
   * mapel the guru already owns.
   */
  async attachSubjectsToTeacher(args: {
    teacherId: string;
    subjectIds: string[];
  }): Promise<void> {
    if (!args.teacherId || args.subjectIds.length === 0) return;
    try {
      await api.post(`/teacher/${args.teacherId}/subjects`, {
        subject_ids: args.subjectIds,
        mode: 'attach',
      });
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menautkan mapel ke guru.'));
    }
  },

  /**
   * GET /schedule/prereq-check — asks the server whether teachers,
   * classes, lesson-hours and rooms are in place so the form can render
   * a "Setup-first" checklist instead of a form that would sit disabled.
   *
   * Fail-safe: on network error we return a `ready: true` payload so a
   * transient blip doesn't force a legitimate school through the setup
   * screen. The form will error out on save with a real reason if the
   * data actually isn't there.
   */
  async checkPrereq(): Promise<SchedulePrereqCheck> {
    try {
      const res = await api.get('/schedule/prereq-check');
      const body = (res.data?.data ?? res.data ?? {}) as Record<string, any>;
      const sec = (raw: any): PrereqCheckSection => ({
        count: asNum(raw?.count),
        has_any: Boolean(raw?.has_any),
      });
      const teachers = sec(body.teachers);
      const classes = sec(body.classes);
      const lesson_hours = sec(body.lesson_hours);
      const rooms = sec(body.rooms);
      // If the server didn't compute `ready` for us, derive it from the
      // three hard prerequisites (rooms is informational, not gating).
      const ready =
        typeof body.ready === 'boolean'
          ? body.ready
          : teachers.has_any && classes.has_any && lesson_hours.has_any;
      return { teachers, classes, lesson_hours, rooms, ready };
    } catch {
      // Don't block a legitimate school on a network hiccup — let the
      // form load and fail with a real error on save if it must.
      const empty: PrereqCheckSection = { count: 0, has_any: true };
      return {
        teachers: empty,
        classes: empty,
        lesson_hours: empty,
        rooms: empty,
        ready: true,
      };
    }
  },

  /**
   * POST /lesson-hours/seed — one-tap install of a standard hour grid
   * (SMP = 8 hours, SMA = 9 hours) across Senin–Sabtu. Backend is
   * idempotent: on a school that already has hours it returns
   * `status: 'SKIPPED'` with `existing`, so callers can distinguish
   * "just seeded 8 rows" from "already had 8 rows".
   */
  async seedLessonHours(
    payload: LessonHourSeedPayload,
  ): Promise<LessonHourSeedResponse> {
    try {
      const body = { preset: payload.preset, overwrite: payload.overwrite ?? false };
      const res = await api.post('/lesson-hours/seed', body);
      const data = (res.data?.data ?? res.data ?? {}) as Record<string, any>;
      const status = data.status === 'SKIPPED' ? 'SKIPPED' : 'SUCCESS';
      const created = asNum(data.created);
      const skipped = asNum(data.skipped);
      if (status === 'SKIPPED') {
        return {
          status,
          created,
          skipped,
          existing: data.existing !== undefined ? asNum(data.existing) : undefined,
        };
      }
      return { status, created, skipped };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal membuat jam pelajaran otomatis.'));
    }
  },

  /**
   * GET /teaching-schedules/available-teachers — slot-filtered teacher
   * roster for the Pola B Guru dropdown. Returns only teachers that are
   * free at (class × day × lesson_hour), sorted by the backend so wali
   * kelas of the picked class comes first.
   *
   * The reversed URL — `teaching-schedules` (plural) vs the singular
   * everywhere else — matches Sprint 2 MR A's controller mount. Don't
   * "normalise" it, that's the actual route.
   */
  /**
   * GET /teaching-schedules/matrix — per-class week grid for the Pola C
   * timetable entry mode (Sprint 3 MR C). class_id is REQUIRED; semester
   * + academic year default to the active tenant context server-side.
   *
   * Failure mode: throws with a translated message. The Pola C grid
   * catches it and renders its retry state — a partial matrix would be
   * worse than "load failed" since the empty cells lie about the class's
   * actual timetable.
   */
  async getTimetableMatrix(q: TimetableMatrixQuery): Promise<TimetableMatrix> {
    try {
      const params = sanitize({
        class_id: q.classId,
        semester_id: q.semesterId,
        academic_year_id: q.academicYearId,
      });
      const res = await api.get('/teaching-schedules/matrix', { params });
      const body = (res.data?.data ?? res.data ?? {}) as Record<string, any>;
      const days: TimetableDay[] = Array.isArray(body.days)
        ? body.days.map((d: any) => ({
            id: asStr(d.id),
            name: asStr(d.name),
            display_name: asStr(d.display_name ?? d.name),
            order_number: asNum(d.order_number),
          }))
        : [];
      const hours: TimetableHour[] = Array.isArray(body.hours)
        ? body.hours.map((h: any) => ({
            id: asStr(h.id),
            hour_number: asNum(h.hour_number),
            name: asStr(h.name),
            start_time: String(h.start_time ?? '').slice(0, 5),
            end_time: String(h.end_time ?? '').slice(0, 5),
            day_id: asStr(h.day_id),
          }))
        : [];
      const cells: Record<string, TimetableCell> = {};
      if (body.cells && typeof body.cells === 'object') {
        for (const [k, raw] of Object.entries(body.cells as Record<string, any>)) {
          if (!raw || typeof raw !== 'object') continue;
          const teacher = raw.teacher ?? {};
          const subject = raw.subject ?? {};
          cells[k] = {
            schedule_id: asStr(raw.schedule_id ?? raw.id),
            teacher: {
              id: asStr(teacher.id),
              name: asStr(teacher.name ?? teacher.nama),
            },
            subject: {
              id: asStr(subject.id),
              name: asStr(subject.name ?? subject.nama),
              code: subject.code ?? subject.kode ?? null,
            },
            room: raw.room ?? null,
            schedule_group_id: raw.schedule_group_id
              ? String(raw.schedule_group_id)
              : null,
            grouped_class_names: parseGroupedClassNames(
              raw.grouped_class_names,
            ),
          };
        }
      }
      const rawMeta = (body.meta ?? {}) as Record<string, any>;
      const meta: TimetableMeta = {
        class_id: asStr(rawMeta.class_id ?? q.classId),
        class_name: asStr(rawMeta.class_name),
        semester_id: asStr(rawMeta.semester_id ?? q.semesterId ?? ''),
        academic_year_id:
          rawMeta.academic_year_id ?? q.academicYearId ?? '',
        total_filled: asNum(rawMeta.total_filled ?? Object.keys(cells).length),
        total_slots: asNum(
          rawMeta.total_slots ?? days.length * hours.length,
        ),
      };
      return { days, hours, cells, meta };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat matrix jadwal.'));
    }
  },

  async getAvailableTeachers(
    q: AvailableTeachersQuery,
  ): Promise<AvailableTeacher[]> {
    try {
      const params = sanitize({
        class_id: q.classId,
        day_id: q.dayId,
        lesson_hour_id: q.lessonHourId,
        semester_id: q.semesterId,
        academic_year_id: q.academicYearId,
      });
      const res = await api.get('/teaching-schedules/available-teachers', {
        params,
      });
      const body = res.data;
      const list = Array.isArray(body?.data)
        ? body.data
        : Array.isArray(body)
          ? body
          : [];
      return list.map((raw: any): AvailableTeacher => ({
        id: asStr(raw.id),
        name: asStr(raw.name),
        subjects_count: asNum(raw.subjects_count),
        is_wali_kelas_of_this_class: Boolean(
          raw.is_wali_kelas_of_this_class,
        ),
      }));
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat guru yang tersedia.'));
    }
  },
};

// Re-export day key normaliser for legacy callers.
export { normalizeDayKey };

// Re-export this for shared row consumers (e.g. day grouping).
export const DAY_KEYS: DayKey[] = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
