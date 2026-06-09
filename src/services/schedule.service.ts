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

/** Light parser — teacher / parent / wali read view. */
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
  // precedence so the Kegiatan form can persist the exact slot UUID.
  const lessonHourId =
    lessonHour?.id ?? raw.lesson_hour_id ?? raw.jam_pelajaran_id ?? null;

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
  };
}

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
// Service
// ───────────────────────────────────────────────────────────────────

export const ScheduleService = {
  // ═════════════════════════════════════════════════════════════════
  // Teacher / parent / wali read methods (existing)
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

  /** Wali-kelas view — full week for one class. */
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

  /** POST /teaching-schedule — create (with optional multi-day fan-out). */
  async create(payload: SchedulePayload): Promise<ScheduleRow[]> {
    try {
      const body = sanitize(payload as Record<string, unknown>);
      const res = await api.post('/teaching-schedule', body);
      const data = res.data?.data ?? res.data;
      // Server may return single row or array (multi-day).
      if (Array.isArray(data)) return data.map(rowFromJson);
      if (data && typeof data === 'object') return [rowFromJson(data)];
      return [];
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menyimpan jadwal.'));
    }
  },

  /** PUT /teaching-schedule/{id} — update single row. */
  async update(
    id: string,
    payload: Partial<SchedulePayload>,
  ): Promise<ScheduleRow> {
    try {
      const body = sanitize(payload as Record<string, unknown>);
      const res = await api.put(`/teaching-schedule/${id}`, body);
      const data = res.data?.data ?? res.data;
      return rowFromJson(data);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memperbarui jadwal.'));
    }
  },

  /** DELETE /teaching-schedule/{id}. */
  async destroy(id: string): Promise<void> {
    try {
      await api.delete(`/teaching-schedule/${id}`);
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

  /** POST /teaching-schedule/import — upload Excel. */
  async importExcel(file: File): Promise<{ created: number; skipped: number }> {
    try {
      const fd = new FormData();
      fd.append('file', file);
      const res = await api.post('/teaching-schedule/import', fd, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      const body = res.data ?? {};
      return {
        created: asNum(body.created ?? body.imported),
        skipped: asNum(body.skipped),
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mengimpor jadwal.'));
    }
  },
};

// Re-export day key normaliser for legacy callers.
export { normalizeDayKey };

// Re-export this for shared row consumers (e.g. day grouping).
export const DAY_KEYS: DayKey[] = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
