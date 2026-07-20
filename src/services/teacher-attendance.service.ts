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
  TeacherAttendanceCheckoutPreview,
  TeacherAttendanceCheckoutPreviewResponse,
  TeacherAttendanceConfig,
  TeacherAttendanceEarlyLeavePolicy,
  TeacherAttendanceEmployeeDeepDive,
  TeacherAttendanceExportFilters,
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
  TeacherAttendanceTimeseries,
  TeacherAttendanceTimeseriesFilters,
} from '@/types/teacher-attendance';

const Endpoints = {
  config: '/teacher-attendance/config',
  checkIn: '/teacher-attendance/check-in',
  checkOut: '/teacher-attendance/check-out',
  // BE-2 !505: server-side preview of "would this check-out succeed
  // right now, and if so what status will it be stamped with?". Feeds
  // the eyebrow chip + pulang-cepat confirmation on the self-service
  // Presensi Saya screen. Fetched ONCE on mount — do NOT poll.
  checkoutPreview: '/teacher-attendance/checkout-preview',
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
  reportTimeseries: '/teacher-attendance/report/timeseries',
  reportEmployee: '/teacher-attendance/report/employee', // + /{personId}
  reportExport: '/teacher-attendance/report/export',
  geofences: '/teacher-attendance/geofences',
  // FU-2 pulang-parity telemetry (backend !513). Fire-and-forget POST
  // the confirm modal hits after the guru picks Batal / Ya-tetap-pulang.
  // Returns 204 — clients ignore the response.
  attendanceTelemetry: '/telemetry/attendance-events',
} as const;

/**
 * Allowlisted telemetry event types under [Endpoints.attendanceTelemetry].
 * Mirrors the backend's `RecordAttendanceTelemetryRequest::ALLOWED_TYPES`.
 * Kept as a union so a typo in a caller is a compile error, not a silent
 * 422 the modal swallows.
 */
export type AttendanceTelemetryEventType =
  | 'pulang_cepat_confirmed'
  | 'pulang_cepat_cancelled';

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
 * Allowed early-leave policy keys (Pulang parity BE-1, backend !504).
 * Anything else (including unknown strings or null) falls back to the
 * server-side default of `warn`.
 */
const ALLOWED_EARLY_LEAVE_POLICIES = ['none', 'warn', 'block'] as const;

/** Coerce a raw `early_leave_policy` field into the typed union. */
function earlyLeavePolicyFromJson(
  raw: unknown,
): import('@/types/teacher-attendance').TeacherAttendanceEarlyLeavePolicy {
  const k = String(raw ?? '').trim().toLowerCase();
  if ((ALLOWED_EARLY_LEAVE_POLICIES as readonly string[]).includes(k)) {
    return k as import('@/types/teacher-attendance').TeacherAttendanceEarlyLeavePolicy;
  }
  return 'warn';
}

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
    // Pulang parity BE-1/BE-2 (backend !504, !505). Grace defaults to
    // null (= inherit late_grace_minutes server-side); min_work defaults
    // to 0 (= disabled).
    early_leave_policy: earlyLeavePolicyFromJson(raw.early_leave_policy),
    early_leave_grace_minutes: asNumOrNull(raw.early_leave_grace_minutes),
    min_work_minutes: asInt(raw.min_work_minutes, 0),
    effective_geofence_lat: asNumOrNull(raw.effective_geofence_lat),
    effective_geofence_lng: asNumOrNull(raw.effective_geofence_lng),
    school_latitude: asNumOrNull(raw.school_latitude),
    school_longitude: asNumOrNull(raw.school_longitude),
    allowed_methods: methodsFromJson(raw.allowed_methods),
    gate_qr_rotation_minutes: asInt(raw.gate_qr_rotation_minutes, 15),
    geofence_required_for_qr: asBool(raw.geofence_required_for_qr, false),
    issue_student_cards: asBool(raw.issue_student_cards, false),
    workweek_days_bitmask:
      raw.workweek_days_bitmask !== undefined
        ? asInt(raw.workweek_days_bitmask, 62)
        : undefined,
    max_daily_shifts_per_person:
      raw.max_daily_shifts_per_person !== undefined
        ? asInt(raw.max_daily_shifts_per_person, 1)
        : undefined,
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
   * GET /teacher-attendance/checkout-preview — pulang parity BE-2 (!505).
   *
   * Answers "if the teacher taps Pulang Sekarang RIGHT NOW, what will
   * happen server-side?". Powers the eyebrow chip on the self-service
   * Presensi Saya screen:
   *   · policy=warn + early_leave → amber chip + confirmation modal
   *   · policy=block + early_leave → red chip, button disabled
   *   · min_work_ok=false        → red chip, button disabled (dominant)
   *   · anything else            → no chip, no hint
   *
   * IMPORTANT: fetched ONCE on mount. The server is authoritative — the
   * POST /check-out endpoint re-validates and returns the correct
   * outcome even if the FE hint is stale by the time the teacher taps.
   *
   * The response is nullable at both levels: the wrapper's `data` may be
   * `null` (e.g. before check-in, or when checkout is disabled for the
   * school and there's nothing to preview). Callers must handle both a
   * `null` block and a `success=false` response as "no chip".
   */
  async getCheckoutPreview(): Promise<TeacherAttendanceCheckoutPreviewResponse> {
    try {
      const res = await api.get(Endpoints.checkoutPreview);
      const body = (res.data ?? {}) as {
        success?: unknown;
        data?: unknown;
      };
      const raw = body.data as Record<string, unknown> | null | undefined;
      // Success flag defaults to true when the endpoint returns without
      // erroring — some intermediary wrappers omit `success` even on
      // 200s. `data` may be explicitly null on "nothing to say".
      const success = body.success === undefined ? true : asBool(body.success, true);
      if (!raw || typeof raw !== 'object') {
        return { success, data: null };
      }
      const policyRaw = String(raw.policy ?? 'none');
      const policy: TeacherAttendanceEarlyLeavePolicy =
        policyRaw === 'warn' || policyRaw === 'block' ? policyRaw : 'none';
      const data: TeacherAttendanceCheckoutPreview = {
        can_checkout: asBool(raw.can_checkout, false),
        checkout_enabled: asBool(raw.checkout_enabled, false),
        reason: raw.reason == null ? null : String(raw.reason),
        threshold_hh_mm: String(raw.threshold_hh_mm ?? ''),
        early_leave_boundary_hh_mm: String(raw.early_leave_boundary_hh_mm ?? ''),
        early_leave: asBool(raw.early_leave, false),
        would_be_status: String(raw.would_be_status ?? ''),
        min_work_ok: asBool(raw.min_work_ok, true),
        min_work_minutes: asInt(raw.min_work_minutes, 0),
        worked_minutes: asInt(raw.worked_minutes, 0),
        minutes_remaining: asInt(raw.minutes_remaining, 0),
        policy,
        grace_minutes_effective: asInt(raw.grace_minutes_effective, 0),
        grace_source: String(raw.grace_source ?? ''),
      };
      return { success, data };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat pratinjau presensi pulang.'));
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
        // Pulang parity BE-1/BE-2 (backend !504, !505). Null on
        // early_leave_grace_minutes is meaningful ("inherit late_grace")
        // — pass it through so a clear-and-save writes null rather than
        // being dropped by the `!== undefined` gate.
        'early_leave_policy',
        'early_leave_grace_minutes',
        'min_work_minutes',
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
      // Unified teacher+staff report: teacher | staff | all. Sent as-is
      // (including 'all', which the backend treats the same as omitted).
      if (filters.personnel_type) params.personnel_type = filters.personnel_type;
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
      // `all` = omit (backend also treats absent as all); teacher/staff
      // narrows the rekap in lock-step with the detail below.
      if (filters.personnel_type && filters.personnel_type !== 'all') {
        params.personnel_type = filters.personnel_type;
      }
      // Optional dominant-status narrowing (backend !492). Only present
      // rows whose `status` matches are counted — matches the detail
      // list filter so the two sections agree on the slice.
      if (filters.status) params.status = filters.status;
      const res = await api.get(Endpoints.reportSummary, { params });
      const body = (res.data ?? {}) as {
        meta?: Record<string, unknown>;
        data?: Record<string, unknown>[];
        totals?: Record<string, unknown>;
      };
      const statuses = statusKeysFromMeta(body.meta);
      const rawRows = Array.isArray(body.data) ? body.data : [];
      const data: TeacherAttendanceSummaryRow[] = rawRows.map((r) => {
        // Server ships `person_id` as the stable per-person key on the
        // unified teacher+staff rekap (staff rows have teacher_id=null).
        // Fall back to teacher_id when person_id isn't set — older
        // backends before the personnel unification used `teacher_id`
        // as the key.
        const rawPersonId = asStrOrNull(r.person_id) ?? asStrOrNull(r.teacher_id) ?? '';
        const rawTeacherId = asStrOrNull(r.teacher_id);
        const rawType = String(r.personnel_type ?? 'teacher');
        return {
          ...statusCountsFromJson(r, statuses),
          person_id: rawPersonId,
          personnel_type: (rawType === 'staff' ? 'staff' : 'teacher') as
            | 'teacher'
            | 'staff',
          teacher_id: rawTeacherId,
          teacher_name: String(r.teacher_name ?? '-'),
          employee_number: asStrOrNull(r.employee_number),
          total: asInt(r.total, 0),
          present_pct: asFloat(r.present_pct, 0),
        };
      });
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
   * GET /teacher-attendance/report/timeseries — per-day school-wide
   * totals over a date range (backend !492). Powers the tepat-waktu
   * harian bar chart in the redesigned admin dashboard.
   *
   * Response is dense — non-workdays return `is_workday=false` and
   * zero counts so the chart can render neutral bars for weekends /
   * holidays without gaps. Date bounds default server-side to the
   * trailing 7 workdays when omitted.
   */
  async adminTimeseries(
    filters: TeacherAttendanceTimeseriesFilters = {},
  ): Promise<TeacherAttendanceTimeseries> {
    try {
      const params: Record<string, unknown> = {};
      if (filters.start_date) params.start_date = filters.start_date;
      if (filters.end_date) params.end_date = filters.end_date;
      if (filters.personnel_type && filters.personnel_type !== 'all') {
        params.personnel_type = filters.personnel_type;
      }
      const res = await api.get(Endpoints.reportTimeseries, { params });
      const body = (res.data ?? {}) as {
        meta?: Record<string, unknown>;
        data?: Record<string, unknown>[];
      };
      const rawDays = Array.isArray(body.data) ? body.data : [];
      const meta = (body.meta ?? {}) as Record<string, unknown>;
      const personnel = String(meta.personnel_type ?? 'all');
      return {
        meta: {
          start_date: String(meta.start_date ?? ''),
          end_date: String(meta.end_date ?? ''),
          day_count: asInt(meta.day_count, rawDays.length),
          personnel_type: (personnel === 'teacher' || personnel === 'staff'
            ? personnel
            : 'all') as TeacherAttendanceTimeseries['meta']['personnel_type'],
        },
        data: rawDays.map((d) => ({
          date: String(d.date ?? ''),
          is_workday: asBool(d.is_workday, true),
          present_count: asInt(d.present_count, 0),
          late_count: asInt(d.late_count, 0),
          absent_count: asInt(d.absent_count, 0),
          ontime_pct: asFloat(d.ontime_pct, 0),
          overtime_minutes: asInt(d.overtime_minutes, 0),
        })),
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat grafik harian presensi.'));
    }
  },

  /**
   * GET /teacher-attendance/report/employee/{personId} — per-person
   * 30-day deep-dive (backend !492). Feeds the drill-down drawer opened
   * from a rekap row: profile hero, KPI stat blocks, calendar heatmap,
   * and the last N raw rows for the "Aktivitas terbaru" list.
   *
   * `personId` accepts a Teacher ID OR a User ID; the server resolves
   * school-scoped, same as the detail-list `teacher_id` filter.
   */
  async adminEmployeeDeepDive(args: {
    personId: string;
    start_date?: string;
    end_date?: string;
  }): Promise<TeacherAttendanceEmployeeDeepDive> {
    try {
      const params: Record<string, unknown> = {};
      if (args.start_date) params.start_date = args.start_date;
      if (args.end_date) params.end_date = args.end_date;
      const res = await api.get(
        `${Endpoints.reportEmployee}/${encodeURIComponent(args.personId)}`,
        { params },
      );
      const body = (res.data?.data ?? res.data ?? {}) as Record<string, unknown>;
      const rawPerson = (body.person ?? {}) as Record<string, unknown>;
      const rawPeriod = (body.period ?? {}) as Record<string, unknown>;
      const rawKpi = (body.kpi ?? {}) as Record<string, unknown>;
      const rawHeat = Array.isArray(body.heatmap) ? body.heatmap : [];
      const rawRows = Array.isArray(body.recent_rows) ? body.recent_rows : [];
      const personType = String(rawPerson.personnel_type ?? 'teacher');
      return {
        person: {
          id: String(rawPerson.id ?? ''),
          name: String(rawPerson.name ?? '-'),
          personnel_type: (personType === 'staff'
            ? 'staff'
            : 'teacher') as TeacherAttendanceEmployeeDeepDive['person']['personnel_type'],
          employee_number: asStrOrNull(rawPerson.employee_number),
          role_label: asStrOrNull(rawPerson.role_label),
        },
        period: {
          start_date: String(rawPeriod.start_date ?? ''),
          end_date: String(rawPeriod.end_date ?? ''),
          day_count: asInt(rawPeriod.day_count, rawHeat.length),
        },
        kpi: {
          streak_days: asInt(rawKpi.streak_days, 0),
          ontime_pct: asFloat(rawKpi.ontime_pct, 0),
          present_days: asInt(rawKpi.present_days, 0),
          late_days: asInt(rawKpi.late_days, 0),
          absent_days: asInt(rawKpi.absent_days, 0),
          overtime_minutes: asInt(rawKpi.overtime_minutes, 0),
        },
        heatmap: rawHeat.map((raw) => {
          const c = raw as Record<string, unknown>;
          const s = String(c.status ?? 'off');
          const status = (
            s === 'present' || s === 'late' || s === 'absent' || s === 'off'
              ? s
              : 'off'
          ) as TeacherAttendanceEmployeeDeepDive['heatmap'][number]['status'];
          return {
            date: String(c.date ?? ''),
            is_workday: asBool(c.is_workday, true),
            status,
            check_in_at: (c.check_in_at as string | null) ?? null,
            check_out_at: (c.check_out_at as string | null) ?? null,
          };
        }),
        recent_rows: rawRows as TeacherAttendanceRecord[],
      };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat detail kehadiran pegawai.'));
    }
  },

  /**
   * POST /teacher-attendance/report/export — server-generated XLSX
   * download (backend !492). Two scopes:
   *   · `summary` — aggregate per-person totals (mirrors adminSummary).
   *   · `detail`  — one row per (person × day) with masuk/pulang times.
   *
   * Returns a Blob so the caller can prompt a save-as. Filename can be
   * derived from the `Content-Disposition` header when the server sets
   * one; otherwise the caller falls back to a canonical template.
   */
  async adminExport(
    filters: TeacherAttendanceExportFilters,
  ): Promise<{ blob: Blob; filename: string | null }> {
    try {
      const body: Record<string, unknown> = { scope: filters.scope };
      if (filters.start_date) body.start_date = filters.start_date;
      if (filters.end_date) body.end_date = filters.end_date;
      if (filters.personnel_type && filters.personnel_type !== 'all') {
        body.personnel_type = filters.personnel_type;
      }
      if (filters.teacher_id) body.teacher_id = filters.teacher_id;
      if (filters.status) body.status = filters.status;
      const res = await api.post(Endpoints.reportExport, body, {
        responseType: 'blob',
      });
      const disposition = String(
        (res.headers?.['content-disposition'] as string | undefined) ??
          (res.headers?.['Content-Disposition'] as string | undefined) ??
          '',
      );
      // RFC 6266: filename="..." OR filename*=UTF-8''...
      let filename: string | null = null;
      const starMatch = disposition.match(/filename\*=UTF-8''([^;]+)/i);
      const plainMatch = disposition.match(/filename="?([^";]+)"?/i);
      if (starMatch?.[1]) {
        try {
          filename = decodeURIComponent(starMatch[1].trim());
        } catch {
          filename = starMatch[1].trim();
        }
      } else if (plainMatch?.[1]) {
        filename = plainMatch[1].trim();
      }
      const blob = new Blob([res.data as BlobPart], {
        type:
          (res.data as Blob)?.type ||
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      });
      return { blob, filename };
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mengekspor laporan presensi.'));
    }
  },

  /**
   * POST /telemetry/attendance-events — FU-2 pulang parity telemetry
   * (backend !513). Records the guru's outcome on the "policy=warn +
   * early_leave" confirm modal so analytics can compute conversion
   * (warn shown -> actually confirmed vs cancelled).
   *
   * FIRE-AND-FORGET: this MUST NEVER block or fail the check-out flow.
   * The confirm-modal handler awaits this only for ordering guarantees;
   * network / server errors are swallowed to `console.warn` so a broken
   * telemetry endpoint can never surface a toast to a guru who's just
   * trying to check out.
   *
   * Backend gate is `auth + module:attendance_staff` — same as
   * /teacher-attendance/check-out itself. The X-School-ID header rides
   * the axios interceptor.
   */
  async recordAttendanceEvent(
    type: AttendanceTelemetryEventType,
    context: Record<string, unknown> = {},
  ): Promise<void> {
    try {
      await api.post(Endpoints.attendanceTelemetry, {
        type,
        occurred_at: new Date().toISOString(),
        context,
      });
    } catch (e) {
      // Never rethrow — a telemetry failure must not surface to the user.
      // Warn so it's visible in devtools during development / on a
      // stitched Datadog RUM session for post-mortem, but the modal
      // caller keeps moving.
      // eslint-disable-next-line no-console
      console.warn('[telemetry] attendance event failed', type, e);
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
