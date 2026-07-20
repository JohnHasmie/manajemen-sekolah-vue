/**
 * AttendanceService - /attendance/* endpoint wrapper.
 * Mirrors `lib/features/attendance/data/helpers/attendance_*_helper.dart`.
 *
 * Wire format (POST /attendance/bulk):
 *   {
 *     teacher_id, subject_id, class_id, date (YYYY-MM-DD),
 *     lesson_hour_id?, attendances: [{ student_id, status, notes? }]
 *   }
 */
import { api } from '@/lib/http';
import { StudentService } from '@/services/students.service';
import {
  denormalizeAttendanceStatus,
  normalizeAttendanceStatus,
  type AdminAttendanceSummary,
  type AttendanceDashboard,
  type AttendanceHistoryEntry,
  type AttendanceKpiSummary,
  type AttendanceRange,
  type AttendanceRow,
  type AttendanceStatus,
  type HeatmapCellState,
  type SessionReport,
  type StudentAttendanceTimeseries,
  type StudentAttendanceTimeseriesDay,
  type StudentHeatmapResponse,
  type TingkatTrend,
} from '@/types/attendance';

/** Coerce a wire value to a rounded integer, falling back on parse errors. */
function toIntLoose(v: unknown, fallback: number): number {
  if (typeof v === 'number' && Number.isFinite(v)) return Math.round(v);
  if (typeof v === 'string') {
    const n = Number.parseFloat(v);
    return Number.isFinite(n) ? Math.round(n) : fallback;
  }
  return fallback;
}

/** Coerce a wire value to a float (1dp), falling back on parse errors. */
function toFloatLoose(v: unknown, fallback: number): number {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (typeof v === 'string') {
    const n = Number.parseFloat(v);
    return Number.isFinite(n) ? n : fallback;
  }
  return fallback;
}

interface RosterParams {
  class_id: string;
  subject_id: string;
  date: string;
  lesson_hour_id?: string;
}

interface BulkParams {
  teacher_id: string;
  subject_id: string;
  class_id: string;
  date: string;
  lesson_hour_id?: string;
  attendances: { student_id: string; status: NonNullable<AttendanceStatus>; notes?: string }[];
}

/**
 * Pull the status + optional alert/notes off an `/attendance` row.
 *
 * `/attendance` only carries the student id + per-session status
 * fields — the display name + NIS come from the separate
 * `/student/class/{id}` fetch and are merged client-side
 * (matches Flutter's pattern in
 * `teacher_attendance_controller.dart`).
 */
function attendanceFactsFromJson(raw: Record<string, any>): {
  studentId: string;
  status: AttendanceStatus;
  alert: string | null;
  alertTone: 'warning' | 'danger' | null;
  notes: string;
} {
  const rawStatus = raw.status ?? raw.attendance_status ?? null;
  return {
    studentId: String(
      raw.student_id ?? raw.id ?? raw.student?.id ?? '',
    ),
    // Normalise via the shared helper so backend English values
    // (`present`/`sick`/`excused`/`absent`) get mapped onto the FE
    // Indonesian short-form canonical the components branch on.
    status: typeof rawStatus === 'string'
      ? normalizeAttendanceStatus(rawStatus)
      : null,
    alert: (raw.alert as string | undefined) ?? null,
    alertTone:
      (raw.alert_tone as 'warning' | 'danger' | undefined) ?? null,
    notes: raw.notes ?? raw.catatan ?? '',
  };
}

export const AttendanceService = {
  /**
   * Build the per-session roster for the attendance detail / input
   * screens.
   *
   * Mirrors Flutter's two-phase load
   * (`AttendanceController._loadAttendanceData`):
   *   1. `/student/class/{class_id}` — full student list with names + NIS
   *   2. `/attendance?class_id&subject_id&date` — saved status rows
   *
   * The two responses are merged client-side. Students with no
   * matching attendance record render with `status = null` so the
   * UI can render "Belum ditandai".
   *
   * Returns `[]` only when the student list also fails to load —
   * an empty attendance response is normal (session not yet recorded).
   */
  async getRoster(params: RosterParams): Promise<AttendanceRow[]> {
    if (!params.class_id) return [];
    const studentsPromise = StudentService.byClass(params.class_id);
    const attendancePromise = api
      .get('/attendance', {
        params: {
          class_id: params.class_id,
          subject_id: params.subject_id,
          date: params.date,
          ...(params.lesson_hour_id
            ? { lesson_hour_id: params.lesson_hour_id }
            : {}),
          per_page: 500,
        },
      })
      .then((res) => {
        const body = res.data;
        const list = Array.isArray(body?.data)
          ? body.data
          : Array.isArray(body)
            ? body
            : [];
        return list as Record<string, any>[];
      })
      .catch(() => [] as Record<string, any>[]);

    const [students, attendanceRows] = await Promise.all([
      studentsPromise,
      attendancePromise,
    ]);
    if (students.length === 0) return [];

    // Index attendance by student_id for O(1) lookup during the merge.
    const byId = new Map<
      string,
      ReturnType<typeof attendanceFactsFromJson>
    >();
    for (const raw of attendanceRows) {
      const facts = attendanceFactsFromJson(raw);
      if (facts.studentId) byId.set(facts.studentId, facts);
    }

    return students.map<AttendanceRow>((s) => {
      const facts = byId.get(s.id);
      return {
        student_id: s.id,
        student_name: s.name,
        student_number: s.student_number,
        gender:
          s.gender === 'L' || s.gender === 'P'
            ? (s.gender as 'L' | 'P')
            : null,
        alert: facts?.alert ?? null,
        alert_tone: facts?.alertTone ?? null,
        status: facts?.status ?? null,
        notes: facts?.notes ?? '',
      };
    });
  },

  /** POST /attendance/bulk — saves all rows in one round-trip.
   *
   * Translates FE Indonesian short-form (`hadir`/`sakit`/`izin`/`alpa`)
   * to the backend's canonical English values
   * (`present`/`sick`/`excused`/`absent`) before posting.
   */
  async saveBulk(params: BulkParams): Promise<void> {
    const body: BulkParams = {
      ...params,
      attendances: params.attendances.map((a) => ({
        ...a,
        status: denormalizeAttendanceStatus(a.status) as unknown as NonNullable<AttendanceStatus>,
      })),
    };
    await api.post('/attendance/bulk', body);
  },

  /**
   * Per-session attendance reports for the Presensi list page.
   *
   * Hits `/attendance/teacher-summary` (Flutter:
   * `AttendanceQueryHelper.getTeacherAttendanceSummary`). The backend
   * returns `{ data: [...], pagination, kpi, teacher_classes }`. We
   * extract `data` rows and normalize them into the `SessionReport`
   * shape — the response can come back as either:
   *
   *   • per-session rows (single date + jam ke-), or
   *   • per-group rows (class+subject with `latest_records: [...]`)
   *
   * For the per-group shape we expand each `latest_records[]` entry
   * into one `SessionReport` so the list page always renders one row
   * per session. Empty / failed responses degrade to `[]`.
   *
   * When `args.classId` is provided we also pass `view='homeroom'`
   * so the backend includes the recording teacher's name (used by the
   * Parent-Kelas chip in the UI).
   */
  async listReports(args: {
    teacher_id: string;
    date_start?: string;
    date_end?: string;
    class_id?: string;
    subject_id?: string;
    academic_year_id?: string;
    search?: string;
    page?: number;
    per_page?: number;
    /** 'homeroom' surfaces teacher_name; 'session' forces per-row mode. */
    view?: 'session' | 'homeroom';
  }): Promise<{ items: SessionReport[]; kpi: AttendanceKpiSummary }> {
    try {
      const params: Record<string, unknown> = {
        page: args.page ?? 1,
        per_page: args.per_page ?? 50,
      };
      if (args.teacher_id) params.teacher_id = args.teacher_id;
      if (args.class_id) params.class_id = args.class_id;
      if (args.subject_id) params.subject_id = args.subject_id;
      if (args.search) params.search = args.search;
      if (args.academic_year_id)
        params.academic_year_id = args.academic_year_id;
      // `date_filter` is a server-side enum (`today` | `this_week` | `last_7_days` …).
      // For ad-hoc ranges we drop both ends in — Flutter does the same.
      if (args.date_start) params.date_start = args.date_start;
      if (args.date_end) params.date_end = args.date_end;
      if (args.view) params.view = args.view;
      params.include_classes = '0';

      const res = await api.get('/attendance/teacher-summary', { params });
      const body = res.data;
      const list: any[] = Array.isArray(body?.data)
        ? body.data
        : Array.isArray(body)
          ? body
          : [];
      const items: SessionReport[] = [];
      for (const raw of list) {
        // Per-group shape — explode latest_records into one row each.
        if (Array.isArray(raw?.latest_records) && raw.latest_records.length > 0) {
          for (const rec of raw.latest_records) {
            items.push(reportFromGroup(raw, rec));
          }
        } else {
          items.push(reportFromJson(raw));
        }
      }
      const kpi = body?.kpi ?? body?.summary ?? {};
      return {
        items,
        kpi: {
          sessions_today: Number(kpi.sessions_today ?? 0),
          sessions_completed: Number(kpi.sessions_completed ?? 0),
          sessions_pending: Number(kpi.sessions_pending ?? 0),
          avg_present_pct:
            kpi.avg_present_pct !== undefined
              ? Number(kpi.avg_present_pct)
              : undefined,
        },
      };
    } catch {
      return {
        items: [],
        kpi: { sessions_today: 0, sessions_completed: 0, sessions_pending: 0 },
      };
    }
  },

  // ═════════════════════════════════════════════════════════════════
  // Admin Kehadiran
  // ═════════════════════════════════════════════════════════════════

  /**
   * GET /attendance/dashboard-summary
   * Drives the admin Kehadiran dashboard (Mockup #11).
   * Returns ring totals + KPI strip + per-tingkat sparkline panel.
   */
  async getDashboardSummary(args: {
    range?: AttendanceRange;
    academic_year_id?: string;
  } = {}): Promise<AttendanceDashboard> {
    try {
      const params: Record<string, unknown> = {};
      if (args.range) params.range = args.range;
      if (args.academic_year_id) params.academic_year_id = args.academic_year_id;
      const res = await api.get('/attendance/dashboard-summary', { params });
      const body = res.data?.data ?? res.data ?? {};
      const totals = body.totals ?? {};
      const kpi = body.kpi ?? {};
      const tingkats: TingkatTrend[] = Array.isArray(body.tingkats)
        ? body.tingkats.map((t: any) => ({
            tingkat: Number(t.tingkat ?? 0),
            current_pct: Number(t.current_pct ?? 0),
            delta_pct: Number(t.delta_pct ?? 0),
            series: Array.isArray(t.series) ? t.series.map((v: any) => Number(v)) : [],
            alert_copy: t.alert_copy ?? null,
          }))
        : [];
      return {
        range: body.range ?? args.range ?? 'today',
        range_label: body.range_label ?? '',
        totals: {
          present: Number(totals.present ?? 0),
          excused: Number(totals.excused ?? 0),
          sick: Number(totals.sick ?? 0),
          alpha: Number(totals.alpha ?? 0),
          present_pct: Number(totals.present_pct ?? 0),
        },
        kpi: {
          avg_pct: Number(kpi.avg_pct ?? 0),
          absent_count: Number(kpi.absent_count ?? 0),
          absent_delta: Number(kpi.absent_delta ?? 0),
          sparkline: Array.isArray(kpi.sparkline)
            ? kpi.sparkline.map((v: any) => Number(v))
            : [],
        },
        tingkats,
        trend_window: body.trend_window
          ? {
              start: String(body.trend_window.start ?? ''),
              end: String(body.trend_window.end ?? ''),
              is_historical: body.trend_window.is_historical === true,
            }
          : undefined,
        computed_at: body.computed_at,
      };
    } catch {
      return {
        range: args.range ?? 'today',
        range_label: '',
        totals: { present: 0, excused: 0, sick: 0, alpha: 0, present_pct: 0 },
        kpi: { avg_pct: 0, absent_count: 0, absent_delta: 0, sparkline: [] },
        tingkats: [],
      };
    }
  },

  /**
   * GET /attendance/student-heatmap
   * Per-student × N-day heatmap for the admin tingkat drill-in.
   *
   * Scope params:
   *   - tingkat (1-12) scopes to all classes in that tingkat
   *   - class_id  scopes to a single class (overrides tingkat)
   */
  async getStudentHeatmap(args: {
    tingkat?: number;
    class_id?: string;
    days?: 30 | 60 | 90;
    end_date?: string;
    academic_year_id?: string;
  }): Promise<StudentHeatmapResponse> {
    try {
      const params: Record<string, unknown> = {};
      if (args.tingkat !== undefined) params.tingkat = args.tingkat;
      if (args.class_id) params.class_id = args.class_id;
      if (args.days) params.days = args.days;
      if (args.end_date) params.end_date = args.end_date;
      if (args.academic_year_id) params.academic_year_id = args.academic_year_id;
      const res = await api.get('/attendance/student-heatmap', { params });
      const body = res.data?.data ?? res.data ?? {};
      const students = Array.isArray(body.students)
        ? body.students.map((s: any) => ({
            id: String(s.id ?? ''),
            name: String(s.name ?? ''),
            student_number: s.student_number ?? null,
            cells: Array.isArray(s.cells)
              ? s.cells.map((c: any) => String(c) as HeatmapCellState)
              : [],
            monthly_pct: Number(s.monthly_pct ?? 0),
            present_days: Number(s.present_days ?? 0),
            total_days: Number(s.total_days ?? 0),
            alert_copy: s.alert_copy ?? null,
            alert: Boolean(s.alert),
          }))
        : [];
      return {
        days: Number(body.days ?? args.days ?? 30),
        start_date: String(body.start_date ?? ''),
        end_date: String(body.end_date ?? ''),
        students,
        computed_at: body.computed_at,
      };
    } catch {
      return {
        days: args.days ?? 30,
        start_date: '',
        end_date: '',
        students: [],
      };
    }
  },

  /**
   * GET /attendance/summary — paginated per-session aggregate list for
   * the admin Laporan screen. Always passes `with[]=subject,class,
   * lessonHour` so the backend joins (no N+1).
   */
  async getAdminSummary(args: {
    page?: number;
    per_page?: number;
    teacher_id?: string;
    class_id?: string;
    subject_id?: string;
    date_start?: string;
    date_end?: string;
    lesson_hour_id?: string;
    academic_year_id?: string;
    search?: string;
  } = {}): Promise<{
    items: AdminAttendanceSummary[];
    total: number;
    current_page: number;
    last_page: number;
  }> {
    try {
      const params: Record<string, unknown> = {
        page: args.page ?? 1,
        per_page: args.per_page ?? 25,
      };
      if (args.teacher_id) params.teacher_id = args.teacher_id;
      if (args.class_id) params.class_id = args.class_id;
      if (args.subject_id) params.subject_id = args.subject_id;
      if (args.date_start) params.date_start = args.date_start;
      if (args.date_end) params.date_end = args.date_end;
      if (args.lesson_hour_id) params.lesson_hour_id = args.lesson_hour_id;
      if (args.academic_year_id) params.academic_year_id = args.academic_year_id;
      if (args.search) params.search = args.search;
      const res = await api.get('/attendance/summary', { params });
      const body = res.data ?? {};
      const list: any[] = Array.isArray(body?.data)
        ? body.data
        : Array.isArray(body)
          ? body
          : [];
      const items = list.map<AdminAttendanceSummary>((r) => {
        const total = Number(r.total_students ?? r.total ?? 0);
        const present = Number(r.present ?? r.hadir ?? 0);
        const absent = Number(r.absent ?? Math.max(0, total - present));
        const lh = r.lesson_hour ?? r.lessonHour ?? null;
        return {
          id: String(r.id ?? `${r.class_id}__${r.subject_id}__${r.date}`),
          subject_id: String(r.subject_id ?? r.subject?.id ?? ''),
          subject_name: String(r.subject_name ?? r.subject?.name ?? ''),
          class_id: String(r.class_id ?? r.class?.id ?? ''),
          class_name: String(r.class_name ?? r.class?.name ?? ''),
          date: String(r.date ?? ''),
          lesson_hour_id: r.lesson_hour_id ?? lh?.id ?? null,
          lesson_hour_name: r.lesson_hour_name ?? lh?.name ?? null,
          hour_number: r.hour_number ?? r.jam_ke ?? lh?.hour_number ?? null,
          // Deprecated alias kept for views not yet migrated.
          jam_ke: r.hour_number ?? r.jam_ke ?? lh?.hour_number ?? null,
          total_students: total,
          present,
          absent,
          percentage: total > 0 ? Math.round((present / total) * 100) : 0,
          teacher_id: r.teacher_id ?? r.teacher?.id ?? null,
          teacher_name: r.teacher_name ?? r.teacher?.name ?? null,
        };
      });
      return {
        items,
        total: Number(body.total ?? items.length),
        current_page: Number(body.current_page ?? 1),
        last_page: Number(body.last_page ?? 1),
      };
    } catch {
      return { items: [], total: 0, current_page: 1, last_page: 1 };
    }
  },

  /**
   * GET /attendance/student-timeseries
   *
   * Per-day school-wide student attendance totals across a date window.
   * Feeds the "Minggu ini" bar chart on the admin dashboard's
   * Kehadiran card. Backend respects the per-school WorkdayCalendar
   * (workweek bitmask + attendance_holidays), so non-workdays come back
   * as `{is_workday:false, present_count:0, absent_count:0, total:0,
   * present_pct:0}` — the client draws them as neutral placeholder
   * bars with a "libur" pill (never "0%").
   *
   * Fails soft: on network error / 403 / 404 (endpoint not yet
   * deployed) we return an empty `data[]` so the chart shows the
   * "belum ada data efektif" empty state instead of blowing up the
   * whole dashboard.
   */
  async getStudentTimeseries(args: {
    start_date: string;
    end_date: string;
    academic_year_id?: string;
  }): Promise<StudentAttendanceTimeseries> {
    try {
      const params: Record<string, unknown> = {
        start_date: args.start_date,
        end_date: args.end_date,
      };
      if (args.academic_year_id) params.academic_year_id = args.academic_year_id;
      const res = await api.get('/attendance/student-timeseries', { params });
      const body = (res.data ?? {}) as {
        meta?: Record<string, unknown>;
        data?: Record<string, unknown>[];
      };
      const rawDays = Array.isArray(body.data) ? body.data : [];
      const meta = (body.meta ?? {}) as Record<string, unknown>;
      const data: StudentAttendanceTimeseriesDay[] = rawDays.map((d) => {
        const present = toIntLoose(d.present_count, 0);
        const absent = toIntLoose(d.absent_count, 0);
        const total = toIntLoose(d.total, present + absent);
        const pct = toFloatLoose(
          d.present_pct,
          total > 0 ? (present / total) * 100 : 0,
        );
        return {
          date: String(d.date ?? ''),
          is_workday: d.is_workday !== false,
          present_count: present,
          absent_count: absent,
          total,
          present_pct: pct,
          holiday_name:
            typeof d.holiday_name === 'string' && d.holiday_name.length > 0
              ? d.holiday_name
              : null,
        };
      });
      return {
        meta: {
          start_date: String(meta.start_date ?? args.start_date),
          end_date: String(meta.end_date ?? args.end_date),
          day_count: toIntLoose(meta.day_count, data.length),
        },
        data,
      };
    } catch {
      return {
        meta: {
          start_date: args.start_date,
          end_date: args.end_date,
          day_count: 0,
        },
        data: [],
      };
    }
  },

  /** DELETE /attendance/{id} — single row delete. */
  async deleteOne(id: string): Promise<void> {
    await api.delete(`/attendance/${id}`);
  },

  /**
   * Delete a whole attendance session (one POST /bulk-delete with
   * the standard scope keys). Backend accepts class_id + subject_id +
   * date + lesson_hour_id and soft-deletes all matching rows.
   */
  async deleteSession(args: {
    class_id: string;
    subject_id: string;
    date: string;
    lesson_hour_id?: string;
  }): Promise<{ deleted: number }> {
    const res = await api.delete('/attendance/bulk', {
      data: args,
    });
    return { deleted: Number(res.data?.deleted ?? 0) };
  },

  /**
   * POST /attendance/export — request an XLSX blob.
   *
   * Body shape mirrors the Flutter export service: a `presenceData[]`
   * payload + class/subject identity. Returns a downloadable Blob so
   * the caller can wrap it in `URL.createObjectURL` + an anchor.
   */
  async exportXlsx(payload: {
    presenceData: Array<{
      student_id: string;
      student_name: string;
      student_number?: string | null;
      status: NonNullable<AttendanceStatus>;
      notes?: string | null;
    }>;
    class_id: string;
    class_name: string;
    subject_id: string;
    subject_name: string;
    date: string;
    teacher_id?: string;
    teacher_name?: string;
    lesson_hour_id?: string;
    hour_number?: number | null;
    /** @deprecated Use `hour_number`. */
    jam_ke?: number | null;
  }): Promise<Blob> {
    const res = await api.post('/attendance/export', payload, {
      responseType: 'blob',
    });
    return res.data as Blob;
  },

  /** Convenience helper: download the XLSX blob via an anchor click. */
  async downloadXlsx(
    payload: Parameters<typeof AttendanceService.exportXlsx>[0],
    suggestedName = 'presensi.xlsx',
  ): Promise<void> {
    const blob = await this.exportXlsx(payload);
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

  /**
   * POST /attendance/export with flat presence rows.
   *
   * Mirrors Flutter's `ExcelPresenceService.exportPresenceToExcel`. The
   * backend (AttendanceController@export) pivots the rows into a
   * student × (date × subject) matrix, derives className/academicYear/
   * monthName from the first row, and returns a binary XLSX.
   *
   * Each row MUST contain: nis, student_name, class_name, academic_year,
   * date (YYYY-MM-DD), subject_name, status (hadir|terlambat|izin|sakit|alpha).
   */
  async exportPresenceRows(
    presenceData: Array<{
      nis: string;
      student_name: string;
      class_name: string;
      academic_year: string;
      date: string;
      subject_name: string;
      status: string;
    }>,
    filters: Record<string, unknown> = {},
  ): Promise<Blob> {
    const res = await api.post(
      '/attendance/export',
      { presenceData, filters },
      { responseType: 'blob' },
    );
    return res.data as Blob;
  },

  /**
   * Build a flat list of presence rows for one month of a class —
   * mirrors Flutter's `AttendanceExportHelper.buildExportRows`.
   *
   * Walks the class roster once, then fetches every attendance record
   * in the month (per_page=2000, single round-trip) and joins by
   * student_id. Returns [] when there is no attendance recorded for
   * the month — caller should skip those months silently.
   */
  async buildExportRowsForMonth(args: {
    class_id: string;
    class_name: string;
    academic_year_name: string;
    academic_year_id?: string;
    year: number;
    month: number; // 1-12
  }): Promise<
    Array<{
      nis: string;
      student_name: string;
      class_name: string;
      academic_year: string;
      date: string;
      subject_name: string;
      status: string;
    }>
  > {
    const pad = (n: number) => n.toString().padStart(2, '0');
    const startOfMonth = `${args.year}-${pad(args.month)}-01`;
    const lastDay = new Date(args.year, args.month, 0).getDate();
    const endOfMonth = `${args.year}-${pad(args.month)}-${pad(lastDay)}`;

    const { StudentService } = await import('./students.service');

    const [students, recordsRes] = await Promise.all([
      StudentService.byClass(args.class_id, {
        academic_year_id: args.academic_year_id,
      }),
      api.get('/attendance', {
        params: {
          class_id: args.class_id,
          date_start: startOfMonth,
          date_end: endOfMonth,
          page: 1,
          per_page: 2000,
          ...(args.academic_year_id
            ? { academic_year_id: args.academic_year_id }
            : {}),
        },
      }),
    ]);

    const recordsBody = recordsRes.data ?? {};
    const records: any[] = Array.isArray(recordsBody?.data)
      ? recordsBody.data
      : Array.isArray(recordsBody)
        ? recordsBody
        : [];
    if (records.length === 0) return [];

    // Lookup by student id.
    const studentMap = new Map<
      string,
      { name: string; nis: string }
    >();
    for (const s of students) {
      studentMap.set(String(s.id), {
        name: s.name ?? 'Unknown',
        nis: s.student_number ?? '',
      });
    }

    const rows: Array<{
      nis: string;
      student_name: string;
      class_name: string;
      academic_year: string;
      date: string;
      subject_name: string;
      status: string;
    }> = [];

    for (const r of records) {
      const sid = String(r.student_id ?? r.student?.id ?? '');
      const s = studentMap.get(sid);
      if (!s) continue;

      const subjectName = String(
        r.subject_name ?? r.subject?.name ?? 'Unknown',
      );
      const status = String(r.status ?? '').toLowerCase();
      if (!status) continue;

      rows.push({
        nis: s.nis,
        student_name: s.name,
        class_name: args.class_name,
        academic_year: args.academic_year_name,
        date: String(r.date ?? ''),
        subject_name: subjectName,
        status,
      });
    }

    return rows;
  },

  /**
   * Convenience: export a single month and trigger a browser download.
   * Returns true on success, false when the month had no data.
   */
  async downloadMonthlyReport(args: {
    class_id: string;
    class_name: string;
    academic_year_name: string;
    academic_year_id?: string;
    year: number;
    month: number;
  }): Promise<boolean> {
    const rows = await this.buildExportRowsForMonth(args);
    if (rows.length === 0) return false;

    const blob = await this.exportPresenceRows(rows);
    const url = URL.createObjectURL(blob);
    try {
      const monthNames = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
      ];
      const monthName = monthNames[args.month - 1] ?? `${args.month}`;
      const fileName = `Data_Absensi_${args.class_name}_${monthName}_${args.year}.xlsx`
        .replace(/\s+/g, '_');

      const a = document.createElement('a');
      a.href = url;
      a.download = fileName;
      document.body.appendChild(a);
      a.click();
      a.remove();
    } finally {
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    }
    return true;
  },

  /**
   * Per-student attendance history. Hits the same `/attendance` endpoint
   * with `student_id` set + a wide `per_page` so we get the full slice
   * for the requested date range in one round-trip. Matches Flutter's
   * `AttendanceQueryHelper.getAttendance(studentId: ...)`.
   */
  async getStudentHistory(args: {
    student_id: string;
    date_start?: string;
    date_end?: string;
    subject_id?: string;
    class_id?: string;
    academic_year_id?: string;
    per_page?: number;
  }): Promise<AttendanceHistoryEntry[]> {
    try {
      // Flutter's `AttendanceQueryHelper` uses `date_start`/`date_end`
      // (not the `tanggalStart`/`tanggalEnd` aliases — those are RPP-only).
      const res = await api.get('/attendance', {
        params: {
          student_id: args.student_id,
          ...(args.date_start ? { date_start: args.date_start } : {}),
          ...(args.date_end ? { date_end: args.date_end } : {}),
          ...(args.subject_id ? { subject_id: args.subject_id } : {}),
          ...(args.class_id ? { class_id: args.class_id } : {}),
          ...(args.academic_year_id
            ? { academic_year_id: args.academic_year_id }
            : {}),
          limit: args.per_page ?? 200,
        },
      });
      const body = res.data;
      const list: any[] = Array.isArray(body?.data)
        ? body.data
        : Array.isArray(body)
          ? body
          : [];
      return list
        .map((raw: any) => historyFromJson(raw))
        .sort((a, b) =>
          String(b.date ?? '').localeCompare(String(a.date ?? '')),
        );
    } catch {
      return [];
    }
  },
};

/**
 * Normalize a flat per-session row from `/attendance/teacher-summary`.
 * Handles both server-confirmed sessions (filled=true) and skeleton
 * rows for not-yet-recorded scheduled sessions.
 */
function reportFromJson(raw: any): SessionReport {
  const hadir = Number(raw.hadir ?? raw.present ?? 0);
  const sakit = Number(raw.sakit ?? raw.sick ?? 0);
  const izin = Number(raw.izin ?? raw.permit ?? 0);
  const alpa = Number(
    raw.alpa ?? raw.absent ?? raw.alpha ?? 0,
  );
  const total = Number(
    raw.total ?? raw.total_students ?? hadir + sakit + izin + alpa,
  );
  const filled = Boolean(
    raw.filled ?? raw.is_filled ?? (raw.recorded_at != null) ?? hadir + sakit + izin + alpa > 0,
  );
  const percentage = total > 0 ? Math.round((hadir / total) * 100) : 0;
  const classId = String(
    raw.class_id ?? raw.class?.id ?? raw.kelas_id ?? '',
  );
  const subjectId = String(
    raw.subject_id ?? raw.subject?.id ?? raw.mata_pelajaran_id ?? '',
  );
  const date = String(raw.date ?? raw.tanggal ?? '');
  // Backend now emits `hour_number` as the canonical key, with `jam_ke`
  // kept as a deprecated alias. Prefer English first; fall back to
  // Indonesian + nested `lesson_hour.hour_number` for older payloads.
  const jamKe = raw.hour_number ?? raw.jam_ke ?? raw.lesson_hour?.hour_number ?? null;
  const lessonHourId = raw.lesson_hour_id ?? raw.lesson_hour?.id ?? null;
  const id = String(
    raw.id ?? `${classId}__${subjectId}__${date}__${jamKe ?? lessonHourId ?? '0'}`,
  );
  return {
    id,
    class_id: classId,
    class_name: String(
      raw.class_name ?? raw.class?.name ?? raw.kelas_nama ?? '',
    ),
    subject_id: subjectId,
    subject_name: String(
      raw.subject_name ??
        raw.subject?.name ??
        raw.mata_pelajaran_nama ??
        raw.mapel ??
        '',
    ),
    date,
    start_time: raw.start_time ?? raw.lesson_hour?.start_time ?? null,
    end_time: raw.end_time ?? raw.lesson_hour?.end_time ?? null,
    hour_number: typeof jamKe === 'number' ? jamKe : jamKe ? Number(jamKe) : null,
    // Deprecated alias kept in sync for views not yet migrated.
    jam_ke: typeof jamKe === 'number' ? jamKe : jamKe ? Number(jamKe) : null,
    lesson_hour_id: lessonHourId ? String(lessonHourId) : null,
    total,
    hadir,
    sakit,
    izin,
    alpa,
    filled,
    percentage,
    teacher_id: raw.teacher_id ?? raw.teacher?.id ?? null,
    teacher_name: raw.teacher_name ?? raw.teacher?.name ?? null,
  };
}

/**
 * When the backend returns per-class+subject groups with `latest_records`,
 * each record is a flat per-session aggregate (date, present, total). We
 * graft the parent's class/subject identity onto it so the resulting
 * row stands alone on the list page.
 */
function reportFromGroup(parent: any, rec: any): SessionReport {
  const present = Number(rec.present ?? rec.hadir ?? 0);
  const total = Number(rec.total ?? parent.total ?? 0);
  const percentage = total > 0 ? Math.round((present / total) * 100) : 0;
  return {
    id: String(
      rec.id ??
        `${parent.class_id ?? ''}__${parent.subject_id ?? ''}__${rec.date ?? ''}`,
    ),
    class_id: String(parent.class_id ?? parent.class?.id ?? ''),
    class_name: String(parent.class_name ?? parent.class?.name ?? ''),
    subject_id: String(parent.subject_id ?? parent.subject?.id ?? ''),
    subject_name: String(parent.subject_name ?? parent.subject?.name ?? ''),
    date: String(rec.date ?? ''),
    start_time: rec.start_time ?? null,
    end_time: rec.end_time ?? null,
    hour_number: rec.hour_number ?? rec.jam_ke ?? null,
    // Deprecated alias.
    jam_ke: rec.hour_number ?? rec.jam_ke ?? null,
    lesson_hour_id: rec.lesson_hour_id ?? null,
    total,
    hadir: present,
    // Backend now surfaces the H/S/I/A breakdown per session
    // (present/sick/izin/alpa), so read it directly — izin was previously
    // folded into alpha by `alpa = total - present`. Fall back to a
    // status-aware remainder for older payloads that only carried present/total.
    sakit: Number(rec.sakit ?? rec.sick ?? 0),
    izin: Number(rec.izin ?? rec.permit ?? 0),
    alpa: Number(
      rec.alpa ??
        rec.absent ??
        Math.max(
          0,
          total - present - Number(rec.sakit ?? rec.sick ?? 0) - Number(rec.izin ?? rec.permit ?? 0),
        ),
    ),
    filled: present > 0 || total > 0,
    percentage,
    teacher_id: parent.teacher_id ?? null,
    teacher_name: parent.teacher_name ?? null,
  };
}

function historyFromJson(raw: any): AttendanceHistoryEntry {
  const rawStatus =
    String(raw.status ?? raw.attendance_status ?? 'hadir').toLowerCase();
  // Map backend canonical English + legacy spellings to the FE
  // Indonesian short-form canonical (which components hard-code).
  const status = ((): NonNullable<AttendanceStatus> => {
    if (rawStatus === 'hadir' || rawStatus === 'present') return 'hadir';
    if (rawStatus === 'sakit' || rawStatus === 'sick') return 'sakit';
    if (rawStatus === 'izin' || rawStatus === 'excused' || rawStatus === 'permission')
      return 'izin';
    if (
      rawStatus === 'alpa' ||
      rawStatus === 'alfa' ||
      rawStatus === 'alpha' ||
      rawStatus === 'absent'
    )
      return 'alpa';
    return 'hadir';
  })();
  const subjectName =
    raw.subject_name ?? raw.subject?.name ?? raw.mata_pelajaran ?? null;
  const hourNumber = raw.hour_number ?? raw.jam_ke;
  const sessionLabel =
    raw.lesson_hour_name ??
    raw.session_label ??
    raw.lesson_hour?.name ??
    (hourNumber ? `Jam ke-${hourNumber}` : subjectName ?? null);
  return {
    id: String(raw.id ?? `${raw.date}-${raw.subject_id ?? ''}`),
    date: String(raw.date ?? raw.tanggal ?? ''),
    session_label: sessionLabel,
    subject_id: raw.subject_id ?? raw.subject?.id ?? null,
    subject_name: subjectName,
    class_id: raw.class_id ?? raw.class?.id ?? null,
    class_name: raw.class_name ?? raw.class?.name ?? raw.kelas_nama ?? null,
    teacher_name: raw.teacher_name ?? raw.teacher?.name ?? raw.guru_nama ?? null,
    status,
    notes: raw.notes ?? raw.catatan ?? null,
    recorded_at: raw.created_at ?? raw.recorded_at ?? null,
  };
}
