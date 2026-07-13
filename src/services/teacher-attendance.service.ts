/**
 * TeacherAttendanceService — PRESENSI GURU (teacher daily attendance).
 *
 * Wraps the App\Modules\Attendance TeacherAttendance endpoints
 * (backend MR !108). All routes sit under `auth:sanctum` + the
 * `X-School-ID` school context, both injected by the axios interceptor
 * in `@/lib/http`.
 *
 * Teacher-facing:
 *   GET  /teacher-attendance/config    → config()
 *   POST /teacher-attendance/check-in  → checkIn()  (multipart)
 *   POST /teacher-attendance/check-out → checkOut() (multipart)
 *   GET  /teacher-attendance/history   → history()
 *
 * Admin-facing:
 *   GET  /teacher-attendance/settings  → getSettings()
 *   PUT  /teacher-attendance/settings  → updateSettings() (partial)
 *   GET  /teacher-attendance/report     → adminReport()
 *   GET  /teacher-attendance/report/summary → adminSummary()
 *
 * The check-in/out payload is `multipart/form-data` because it carries
 * a live camera photo. We build a FormData and let the browser set the
 * boundary — DON'T set Content-Type manually. The server stamps the
 * timestamps; the client clock is never trusted.
 */
import { api } from '@/lib/http';
import type {
  TeacherAttendanceAdminFilters,
  TeacherAttendanceAdminSummary,
  TeacherAttendanceAdminSummaryFilters,
  TeacherAttendanceConfig,
  TeacherAttendanceGeofence,
  TeacherAttendanceGeofenceDraft,
  TeacherAttendanceHistoryFilters,
  TeacherAttendanceListResult,
  TeacherAttendanceOwnSummary,
  TeacherAttendanceOwnSummaryTotals,
  TeacherAttendancePageMeta,
  TeacherAttendanceRecord,
  TeacherAttendanceReminderScope,
  TeacherAttendanceReminderSettings,
  TeacherAttendanceSettings,
  TeacherAttendanceSubmission,
  TeacherAttendanceSummaryFilters,
  TeacherAttendanceSummaryRow,
  TeacherAttendanceSummaryTotals,
} from '@/types/teacher-attendance';

const Endpoints = {
  config: '/teacher-attendance/config',
  checkIn: '/teacher-attendance/check-in',
  checkOut: '/teacher-attendance/check-out',
  // Caller-aware GATE-QR self check-in (backend QrCheckInController@store).
  // The SAME route the mobile app posts to — resolves teacher/staff/student
  // server-side, gated by `attendance.self.checkin` + `module:attendance_gate`.
  // Sits on the shared `api` instance whose baseURL already ends in `/api`,
  // exactly like every other endpoint here.
  checkInQr: '/attendance/check-in/qr',
  history: '/teacher-attendance/history',
  historySummary: '/teacher-attendance/history/summary',
  settings: '/teacher-attendance/settings',
  reminderSettings: '/teacher-attendance/reminder-settings',
  rules: '/teacher-attendance/rules',
  report: '/teacher-attendance/report',
  reportSummary: '/teacher-attendance/report/summary',
  geofences: '/teacher-attendance/geofences',
} as const;

/**
 * Pull a human Indonesian message out of a Laravel error. The backend
 * uses the keys `photo` / `latitude` / `location` / `check_in` /
 * `check_out` for validation errors and `message` for action errors
 * (geofence reject, double check-in, etc.).
 */
function humanError(e: unknown, fallback: string): string {
  const ax = e as {
    response?: {
      data?: {
        message?: string;
        error?: string;
        errors?: Record<string, string[]>;
      };
    };
  };
  const d = ax?.response?.data;
  if (d) {
    if (d.message) return String(d.message);
    if (d.error) return String(d.error);
    if (d.errors && typeof d.errors === 'object') {
      const first = Object.values(d.errors)[0];
      if (Array.isArray(first) && first.length > 0) return String(first[0]);
    }
  }
  if (e instanceof Error) return e.message;
  return fallback;
}

/** Coerce any backend boolean-ish value to a real boolean. */
function asBool(v: unknown, fallback = false): boolean {
  if (typeof v === 'boolean') return v;
  if (v === 1 || v === '1' || v === 'true') return true;
  if (v === 0 || v === '0' || v === 'false') return false;
  return fallback;
}

/** Coerce to a finite number or null. */
function asNumOrNull(v: unknown): number | null {
  if (v === null || v === undefined || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

/** Coerce to an integer with a fallback. */
function asInt(v: unknown, fallback: number): number {
  const n = Number(v);
  return Number.isFinite(n) ? Math.round(n) : fallback;
}

/** Coerce to a finite float with a fallback (for percentages). */
function asFloat(v: unknown, fallback: number): number {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
}

/** Coerce to a non-empty string or null (employee_number may be null). */
function asStrOrNull(v: unknown): string | null {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  return s === '' ? null : s;
}

/**
 * Read the authoritative ordered status-column list from a summary
 * `meta.statuses`. Defaults to the two always-present columns when the
 * server omits or mangles it, so the UI never renders a column-less
 * rekap.
 */
function statusKeysFromMeta(meta: unknown): string[] {
  const raw = (meta as { statuses?: unknown })?.statuses;
  if (Array.isArray(raw)) {
    const keys = raw.map((s) => String(s)).filter((s) => s !== '');
    if (keys.length > 0) return keys;
  }
  return ['present', 'late'];
}

/**
 * Pull the per-status int counts out of a raw row/totals object using
 * the authoritative `statuses` list. Any column the server omitted for
 * a given row reads as 0 (a teacher with no `late` records still gets a
 * `late: 0` cell).
 */
function statusCountsFromJson(
  raw: Record<string, unknown>,
  statuses: string[],
): Record<string, number> {
  const out: Record<string, number> = {};
  for (const key of statuses) out[key] = asInt(raw[key], 0);
  return out;
}

/** Allowed QR check-in method keys (MR !226). Anything else is dropped. */
const ALLOWED_METHOD_KEYS = ['SELFIE', 'QR_GATE', 'QR_CARD'] as const;

/**
 * Coerce a raw `allowed_methods` field into a typed list. Accepts the
 * server's JSON array, a comma-separated string (in case the legacy
 * settings page serialised it that way), or null (treat as the default
 * SELFIE-only). Unknown entries are silently dropped so a stray value
 * doesn't break the typed select.
 */
function methodsFromJson(
  raw: unknown,
): import('@/types/attendance-qr').CheckInMethod[] {
  let list: unknown[] = [];
  if (Array.isArray(raw)) list = raw;
  else if (typeof raw === 'string' && raw !== '') list = raw.split(',');
  const out: import('@/types/attendance-qr').CheckInMethod[] = [];
  for (const m of list) {
    const k = String(m).trim().toUpperCase();
    if ((ALLOWED_METHOD_KEYS as readonly string[]).includes(k)) {
      out.push(k as import('@/types/attendance-qr').CheckInMethod);
    }
  }
  // Guarantee at least one method — mirrors the backend's ≥1 constraint
  // so a misconfigured row never renders an unselectable form.
  return out.length > 0 ? out : ['SELFIE'];
}

/** Normalize a raw settings object (handles 0/1 + missing keys). */
function settingsFromJson(
  raw: Record<string, unknown>,
): TeacherAttendanceSettings {
  return {
    camera_required: asBool(raw.camera_required, true),
    location_required: asBool(raw.location_required, true),
    checkout_enabled: asBool(raw.checkout_enabled, false),
    geofence_lat: asNumOrNull(raw.geofence_lat),
    geofence_lng: asNumOrNull(raw.geofence_lng),
    geofence_radius_m: asInt(raw.geofence_radius_m, 150),
    reject_outside_geofence: asBool(raw.reject_outside_geofence, true),
    late_grace_minutes: asInt(raw.late_grace_minutes, 0),
    effective_geofence_lat: asNumOrNull(raw.effective_geofence_lat),
    effective_geofence_lng: asNumOrNull(raw.effective_geofence_lng),
    school_latitude: asNumOrNull(raw.school_latitude),
    school_longitude: asNumOrNull(raw.school_longitude),
    allowed_methods: methodsFromJson(raw.allowed_methods),
    gate_qr_rotation_minutes: asInt(raw.gate_qr_rotation_minutes, 15),
    geofence_required_for_qr: asBool(raw.geofence_required_for_qr, false),
    issue_student_cards: asBool(raw.issue_student_cards, false),
  };
}

/** Allowed reminder-scope keys. Anything else falls back to all_workdays. */
const ALLOWED_REMINDER_SCOPES: readonly TeacherAttendanceReminderScope[] = [
  'all_workdays',
  'teaching_days_only',
];

/**
 * Coerce a raw offsets field into a clean minute list: finite, integer,
 * non-negative, de-duplicated, sorted descending (soonest reminder last).
 * Accepts the server's JSON array or a comma-separated string. Empty in →
 * empty out; the caller / backend enforce the ≥1 constraint so a bad row
 * never silently gains a phantom offset here.
 */
function offsetsFromJson(raw: unknown): number[] {
  let list: unknown[] = [];
  if (Array.isArray(raw)) list = raw;
  else if (typeof raw === 'string' && raw !== '') list = raw.split(',');
  const seen = new Set<number>();
  for (const v of list) {
    const n = Number(v);
    if (Number.isFinite(n)) {
      const i = Math.round(n);
      if (i >= 0) seen.add(i);
    }
  }
  return [...seen].sort((a, b) => b - a);
}

/**
 * Normalize a raw reminder-settings object (handles 0/1, missing keys,
 * and an out-of-range scope). Mirrors settingsFromJson so the view can
 * trust every field is present and typed.
 */
function reminderSettingsFromJson(
  raw: Record<string, unknown>,
): TeacherAttendanceReminderSettings {
  const scopeRaw = String(raw.scope ?? 'all_workdays');
  const scope = (
    ALLOWED_REMINDER_SCOPES as readonly string[]
  ).includes(scopeRaw)
    ? (scopeRaw as TeacherAttendanceReminderScope)
    : 'all_workdays';
  return {
    enabled: asBool(raw.enabled, false),
    scope,
    checkin_offsets_minutes: offsetsFromJson(raw.checkin_offsets_minutes),
    checkout_offsets_minutes: offsetsFromJson(raw.checkout_offsets_minutes),
  };
}

/** Pull `{ data, meta }` out of a Laravel paginated resource collection. */
function listFromJson(body: unknown): TeacherAttendanceListResult {
  const b = (body ?? {}) as {
    data?: TeacherAttendanceRecord[];
    meta?: Partial<TeacherAttendancePageMeta>;
  };
  const items = Array.isArray(b.data) ? b.data : [];
  const meta = b.meta ?? {};
  return {
    items,
    meta: {
      current_page: asInt(meta.current_page, 1),
      last_page: asInt(meta.last_page, 1),
      per_page: asInt(meta.per_page, items.length || 20),
      total: asInt(meta.total, items.length),
    },
  };
}

/**
 * Build the multipart body for check-in / check-out. Only appends keys
 * that are actually present so the backend's conditional-required rules
 * (camera_required / location_required) see "missing" rather than empty
 * strings.
 */
function buildSubmission(payload: TeacherAttendanceSubmission): FormData {
  const fd = new FormData();
  if (payload.photo) {
    // Stable filename — the server derives the extension from the mime.
    fd.append('photo', payload.photo, 'selfie.jpg');
  }
  if (payload.latitude !== undefined && payload.latitude !== null) {
    fd.append('latitude', String(payload.latitude));
  }
  if (payload.longitude !== undefined && payload.longitude !== null) {
    fd.append('longitude', String(payload.longitude));
  }
  if (
    payload.notes !== undefined &&
    payload.notes !== null &&
    payload.notes !== ''
  ) {
    fd.append('notes', payload.notes);
  }
  if (payload.shift_id !== undefined && payload.shift_id !== null) {
    fd.append('shift_id', payload.shift_id);
  }
  return fd;
}

export const TeacherAttendanceService = {
  /**
   * GET /teacher-attendance/config — teacher bootstrap: settings +
   * today's teaching schedule + today's check-in/out state. 403 when
   * the user isn't a teacher; 400 when school context is missing.
   */
  async config(): Promise<TeacherAttendanceConfig> {
    try {
      const res = await api.get(Endpoints.config);
      const data = (res.data?.data ?? res.data ?? {}) as Record<
        string,
        unknown
      >;
      return {
        teacher: (data.teacher ?? {}) as TeacherAttendanceConfig['teacher'],
        date: String(data.date ?? ''),
        server_time: String(data.server_time ?? ''),
        settings: settingsFromJson(
          (data.settings ?? {}) as Record<string, unknown>,
        ),
        today_schedule: Array.isArray(data.today_schedule)
          ? (data.today_schedule as TeacherAttendanceConfig['today_schedule'])
          : [],
        first_teaching_start:
          (data.first_teaching_start as string | null) ?? null,
        late_after: (data.late_after as string | null) ?? null,
        state: (data.state ?? {
          has_checked_in: false,
          has_checked_out: false,
          can_check_out: false,
          record: null,
        }) as TeacherAttendanceConfig['state'],
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat data presensi.'));
    }
  },

  /**
   * POST /teacher-attendance/check-in — multipart. Returns the created
   * record. Throws an Indonesian error on geofence reject / double
   * check-in / missing-required-field (422).
   */
  async checkIn(
    payload: TeacherAttendanceSubmission,
  ): Promise<TeacherAttendanceRecord> {
    try {
      const res = await api.post(Endpoints.checkIn, buildSubmission(payload), {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      return (res.data?.data ?? res.data) as TeacherAttendanceRecord;
    } catch (e) {
      throw new Error(humanError(e, 'Gagal melakukan presensi masuk.'));
    }
  },

  /**
   * POST /teacher-attendance/check-out — multipart. Requires an
   * existing same-day check-in and checkout_enabled. Returns the
   * updated record.
   */
  async checkOut(
    payload: TeacherAttendanceSubmission,
  ): Promise<TeacherAttendanceRecord> {
    try {
      const res = await api.post(Endpoints.checkOut, buildSubmission(payload), {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      return (res.data?.data ?? res.data) as TeacherAttendanceRecord;
    } catch (e) {
      throw new Error(humanError(e, 'Gagal melakukan presensi pulang.'));
    }
  },

  /**
   * POST /attendance/check-in/qr — self check-in via the school's rotating
   * GATE QR. Body is a SHORT JSON `{ token, latitude?, longitude? }` (NOT
   * multipart — there's no photo). The route is caller-aware: the server
   * resolves the authenticated user as teacher OR staff and writes the
   * correct personnel row, returning the SAME TeacherAttendanceRecord shape
   * the selfie check-in returns — so we reuse the identical `data` unwrap +
   * humanError mapping. present/late + geofence are computed server-side.
   *
   * GPS is only attached when the caller passes it (the view supplies it
   * when the school sets `geofence_required_for_qr`); the server enforces
   * the geofence rule regardless.
   */
  async checkInWithQr(payload: {
    token: string;
    latitude?: number | null;
    longitude?: number | null;
  }): Promise<TeacherAttendanceRecord> {
    try {
      const body: Record<string, unknown> = { token: payload.token };
      if (payload.latitude !== undefined && payload.latitude !== null) {
        body.latitude = payload.latitude;
      }
      if (payload.longitude !== undefined && payload.longitude !== null) {
        body.longitude = payload.longitude;
      }
      const res = await api.post(Endpoints.checkInQr, body);
      return (res.data?.data ?? res.data) as TeacherAttendanceRecord;
    } catch (e) {
      throw new Error(humanError(e, 'Gagal melakukan presensi via QR.'));
    }
  },

  /**
   * GET /teacher-attendance/history — the authenticated teacher's own
   * paginated records.
   */
  async history(
    filters: TeacherAttendanceHistoryFilters = {},
  ): Promise<TeacherAttendanceListResult> {
    try {
      const params: Record<string, unknown> = {};
      if (filters.start_date) params.start_date = filters.start_date;
      if (filters.end_date) params.end_date = filters.end_date;
      if (filters.per_page) params.per_page = filters.per_page;
      if (filters.page) params.page = filters.page;
      const res = await api.get(Endpoints.history, { params });
      return listFromJson(res.data);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat riwayat presensi.'));
    }
  },

  /**
   * GET /teacher-attendance/settings — per-school admin config. Includes
   * the school pin (school_latitude / school_longitude) as the geofence
   * fallback.
   */
  async getSettings(): Promise<TeacherAttendanceSettings> {
    try {
      const res = await api.get(Endpoints.settings);
      const data = (res.data?.data ?? res.data ?? {}) as Record<
        string,
        unknown
      >;
      return settingsFromJson(data);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat pengaturan presensi guru.'));
    }
  },

  /**
   * PUT /teacher-attendance/settings — partial update. Only the keys
   * present in `patch` are sent; the backend patches just those (the
   * rules are all `sometimes`).
   */
  async updateSettings(
    patch: Partial<TeacherAttendanceSettings>,
  ): Promise<TeacherAttendanceSettings> {
    try {
      const body: Record<string, unknown> = {};
      const keys: (keyof TeacherAttendanceSettings)[] = [
        'camera_required',
        'location_required',
        'checkout_enabled',
        'geofence_lat',
        'geofence_lng',
        'geofence_radius_m',
        'reject_outside_geofence',
        'late_grace_minutes',
        // Gate QR + personnel card fields (MR !226).
        'allowed_methods',
        'gate_qr_rotation_minutes',
        'geofence_required_for_qr',
        'issue_student_cards',
        'workweek_days_bitmask',
        'max_daily_shifts_per_person',
      ];
      for (const k of keys) {
        if (patch[k] !== undefined) body[k] = patch[k];
      }
      const res = await api.put(Endpoints.settings, body);
      const data = (res.data?.data ?? res.data ?? body) as Record<
        string,
        unknown
      >;
      return settingsFromJson(data);
    } catch (e) {
      throw new Error(
        humanError(e, 'Gagal menyimpan pengaturan presensi guru.'),
      );
    }
  },

  /**
   * GET /teacher-attendance/reminder-settings — per-school attendance
   * reminder config (backend MR1 !413, Slack 1783935842). The endpoint
   * always returns a body — the school's saved row or the API defaults —
   * so the settings card never has to invent offsets locally.
   *
   * School context rides the `X-School-ID` header from the axios
   * interceptor, exactly like getSettings() above (no schoolId arg).
   */
  async getReminderSettings(): Promise<TeacherAttendanceReminderSettings> {
    try {
      const res = await api.get(Endpoints.reminderSettings);
      const data = (res.data?.data ?? res.data ?? {}) as Record<
        string,
        unknown
      >;
      return reminderSettingsFromJson(data);
    } catch (e) {
      throw new Error(
        humanError(e, 'Gagal memuat pengaturan pengingat presensi guru.'),
      );
    }
  },

  /**
   * PUT /teacher-attendance/reminder-settings — full replace of the
   * reminder config. Sends only the keys present in `patch`; the backend
   * validates offsets (integer minutes) and rejects an enabled config
   * with zero offsets, so the view guards that before calling.
   */
  async updateReminderSettings(
    patch: Partial<TeacherAttendanceReminderSettings>,
  ): Promise<TeacherAttendanceReminderSettings> {
    try {
      const body: Record<string, unknown> = {};
      const keys: (keyof TeacherAttendanceReminderSettings)[] = [
        'enabled',
        'scope',
        'checkin_offsets_minutes',
        'checkout_offsets_minutes',
      ];
      for (const k of keys) {
        if (patch[k] !== undefined) body[k] = patch[k];
      }
      const res = await api.put(Endpoints.reminderSettings, body);
      const data = (res.data?.data ?? res.data ?? body) as Record<
        string,
        unknown
      >;
      return reminderSettingsFromJson(data);
    } catch (e) {
      throw new Error(
        humanError(e, 'Gagal menyimpan pengaturan pengingat presensi guru.'),
      );
    }
  },

  /**
   * GET /teacher-attendance/geofences — list all multi-location
   * geofences for the current school (Slack 1783559232, backend
   * MR !375). Sorted primary-first then alphabetical by name.
   */
  async listGeofences(): Promise<TeacherAttendanceGeofence[]> {
    try {
      const res = await api.get(Endpoints.geofences);
      return (res.data?.data ?? []) as TeacherAttendanceGeofence[];
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat daftar lokasi geofence.'));
    }
  },

  /**
   * POST /teacher-attendance/geofences — create a new multi-loc row.
   * Set `is_primary=true` and the server demotes the previous
   * primary inside a DB transaction.
   */
  async createGeofence(
    draft: TeacherAttendanceGeofenceDraft,
  ): Promise<TeacherAttendanceGeofence> {
    try {
      const res = await api.post(Endpoints.geofences, draft);
      return (res.data?.data ?? draft) as TeacherAttendanceGeofence;
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menyimpan lokasi geofence.'));
    }
  },

  /**
   * PATCH /teacher-attendance/geofences/{id} — partial update.
   */
  async updateGeofence(
    id: string,
    draft: Partial<TeacherAttendanceGeofenceDraft>,
  ): Promise<TeacherAttendanceGeofence> {
    try {
      const res = await api.patch(`${Endpoints.geofences}/${id}`, draft);
      return (res.data?.data ?? draft) as TeacherAttendanceGeofence;
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memperbarui lokasi geofence.'));
    }
  },

  async deleteGeofence(id: string): Promise<void> {
    try {
      await api.delete(`${Endpoints.geofences}/${id}`);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menghapus lokasi geofence.'));
    }
  },

  async getRules(): Promise<{ rules: any[]; teachers: any[]; grade_levels: string[] }> {
    try {
      const res = await api.get(Endpoints.rules);
      return res.data?.data ?? { rules: [], teachers: [], grade_levels: [] };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat aturan presensi guru.'));
    }
  },

  async saveRule(payload: any): Promise<any> {
    try {
      const res = await api.post(Endpoints.rules, payload);
      return res.data?.data;
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menyimpan aturan presensi guru.'));
    }
  },

  async deleteRule(id: string): Promise<void> {
    try {
      await api.delete(`${Endpoints.rules}/${id}`);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal menghapus aturan presensi guru.'));
    }
  },

  /**
   * GET /teacher-attendance/report — school-scoped report list. The
   * `teacher_id` filter accepts a Teacher ID OR a User ID; the server
   * resolves it within the active school.
   */
  async adminReport(
    filters: TeacherAttendanceAdminFilters = {},
  ): Promise<TeacherAttendanceListResult> {
    try {
      const params: Record<string, unknown> = {};
      if (filters.date) params.date = filters.date;
      if (filters.start_date) params.start_date = filters.start_date;
      if (filters.end_date) params.end_date = filters.end_date;
      if (filters.teacher_id) params.teacher_id = filters.teacher_id;
      if (filters.status) params.status = filters.status;
      if (filters.per_page) params.per_page = filters.per_page;
      if (filters.page) params.page = filters.page;
      const res = await api.get(Endpoints.report, { params });
      return listFromJson(res.data);
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat laporan presensi guru.'));
    }
  },

  /**
   * GET /teacher-attendance/report/summary — per-TEACHER rekap over a
   * date range. Status columns are dynamic: read `meta.statuses` for
   * the ordered column list, then index each row by status key.
   * `teacher_id` accepts a Teacher ID OR a User ID; the server resolves
   * it within the active school. Date bounds default to start-of-month
   * → today server-side when omitted.
   */
  async adminSummary(
    filters: TeacherAttendanceAdminSummaryFilters = {},
  ): Promise<TeacherAttendanceAdminSummary> {
    try {
      const params: Record<string, unknown> = {};
      if (filters.start_date) params.start_date = filters.start_date;
      if (filters.end_date) params.end_date = filters.end_date;
      if (filters.teacher_id) params.teacher_id = filters.teacher_id;
      const res = await api.get(Endpoints.reportSummary, { params });
      const body = (res.data ?? {}) as {
        meta?: Record<string, unknown>;
        data?: Record<string, unknown>[];
        totals?: Record<string, unknown>;
      };
      const statuses = statusKeysFromMeta(body.meta);
      const rawRows = Array.isArray(body.data) ? body.data : [];
      const data: TeacherAttendanceSummaryRow[] = rawRows.map((r) => ({
        ...statusCountsFromJson(r, statuses),
        teacher_id: String(r.teacher_id ?? ''),
        teacher_name: String(r.teacher_name ?? '-'),
        employee_number: asStrOrNull(r.employee_number),
        total: asInt(r.total, 0),
        present_pct: asFloat(r.present_pct, 0),
      }));
      const rawTotals = (body.totals ?? {}) as Record<string, unknown>;
      const totals: TeacherAttendanceSummaryTotals = {
        ...statusCountsFromJson(rawTotals, statuses),
        total: asInt(rawTotals.total, 0),
        present_pct: asFloat(rawTotals.present_pct, 0),
        teacher_count: asInt(rawTotals.teacher_count, data.length),
      };
      return {
        meta: {
          start_date: String(body.meta?.start_date ?? ''),
          end_date: String(body.meta?.end_date ?? ''),
          statuses,
        },
        data,
        totals,
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat rekap presensi guru.'));
    }
  },

  /**
   * GET /teacher-attendance/history/summary — the AUTHENTICATED
   * teacher's OWN totals over a date range (Hadir · Telat · % Kehadiran
   * for the period header). Status columns are dynamic — read
   * `meta.statuses`. Same date defaults as the admin summary.
   */
  async historySummary(
    filters: TeacherAttendanceSummaryFilters = {},
  ): Promise<TeacherAttendanceOwnSummary> {
    try {
      const params: Record<string, unknown> = {};
      if (filters.start_date) params.start_date = filters.start_date;
      if (filters.end_date) params.end_date = filters.end_date;
      const res = await api.get(Endpoints.historySummary, { params });
      const body = (res.data ?? {}) as {
        meta?: Record<string, unknown>;
        summary?: Record<string, unknown>;
      };
      const statuses = statusKeysFromMeta(body.meta);
      const rawSummary = (body.summary ?? {}) as Record<string, unknown>;
      const summary: TeacherAttendanceOwnSummaryTotals = {
        ...statusCountsFromJson(rawSummary, statuses),
        total: asInt(rawSummary.total, 0),
        present_pct: asFloat(rawSummary.present_pct, 0),
      };
      return {
        meta: {
          teacher_id: String(body.meta?.teacher_id ?? ''),
          teacher_name: String(body.meta?.teacher_name ?? '-'),
          start_date: String(body.meta?.start_date ?? ''),
          end_date: String(body.meta?.end_date ?? ''),
          statuses,
        },
        summary,
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat ringkasan presensi.'));
    }
  },
};
