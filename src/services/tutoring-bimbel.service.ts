/**
 * TutoringBimbelService — thin wrapper over the greenfield backend
 * (`/api/tutoring-v2/*`, delivered by BE-2..7). Coexists with the
 * legacy `TutoringService` under `/api/tutoring/*` (which we're
 * tearing down in CLEAN-1..3). Named `-bimbel` on purpose so the two
 * imports never accidentally alias.
 *
 * Every method carries the `X-Tenant-ID` implicitly via the shared
 * http layer — no explicit school_id juggling here.
 */
import { api } from '@/lib/http';
import type { Pagination } from '@/types/api';
import type {
  TutoringAttendanceRow,
  TutoringMaterial,
  TutoringScoreRow,
} from '@/types/tutoring-bimbel';

// ─── Programs (BE-2) ────────────────────────────────────────────────

export interface BimbelProgram {
  id: string;
  name: string;
  grade_level?: string | null;
  description?: string | null;
  status: 'draft' | 'active' | 'archived';
  status_label?: string;
  packages_count?: number;
  min_price?: number | null;
  created_at?: string;
  updated_at?: string;
}

export interface ProgramListParams {
  page?: number;
  per_page?: number;
  status?: string;
  grade_level?: string;
  search?: string;
}

// ─── Packages (BE-2) ────────────────────────────────────────────────

export interface BimbelPackage {
  id: string;
  program_id: string;
  name: string;
  price: number;
  total_sessions?: number | null;
  duration_days?: number | null;
  allowed_billing_modes: Array<'prepaid' | 'monthly' | 'per_session'>;
  status: 'draft' | 'active' | 'archived';
  status_label?: string;
  created_at?: string;
  updated_at?: string;
}

// ─── Learning groups (BE-3) ─────────────────────────────────────────

export interface BimbelLearningGroup {
  id: string;
  program_id: string;
  program_name?: string | null;
  term_id?: string | null;
  term_name?: string | null;
  tutor_id?: string | null;
  tutor_name?: string | null;
  name: string;
  kind: 'group' | 'private';
  kind_label?: string;
  capacity: number;
  room?: string | null;
  status: 'draft' | 'active' | 'closed';
  status_label?: string;
  /**
   * Students currently seated in this group.
   *
   * OPTIONAL ON PURPOSE, and the `?` is load-bearing: only
   * `LearningGroupController::show()` sets the attribute, and
   * `LearningGroupResource` emits it through `when()`, which OMITS the
   * key entirely rather than sending null. Every row from
   * `listGroups()` therefore arrives WITHOUT it.
   *
   * `seated_count ?? 0` is a bug, not a default — it renders "not sent"
   * as "nobody seated". Use `countOrDash` / `isCounted` from
   * `@/lib/absent-vs-zero`, which keep a real 0 rendering as 0.
   */
  seated_count?: number;
}

// ─── Enrollments (BE-3) ─────────────────────────────────────────────

export interface BimbelEnrollment {
  id: string;
  student_id: string;
  student_name?: string | null;
  student_number?: string | null;
  program_id: string;
  program_name?: string | null;
  learning_group_id?: string | null;
  learning_group_name?: string | null;
  package_id?: string | null;
  package_name?: string | null;
  billing_mode: 'prepaid' | 'monthly' | 'per_session';
  billing_mode_label?: string;
  status: 'trial' | 'active' | 'paused' | 'graduated' | 'withdrawn';
  status_label?: string;
  start_date?: string | null;
  end_date?: string | null;
  total_sessions_snapshot?: number | null;
  remaining_sessions?: number | null;
  price_at_enrollment?: number | null;
  billing_day_of_month?: number | null;
  notes?: string | null;
}

// ─── Sessions (BE-4) ────────────────────────────────────────────────

export interface BimbelSession {
  id: string;
  learning_group_id: string;
  learning_group_name?: string | null;
  tutor_id?: string | null;
  tutor_name?: string | null;
  series_key?: string | null;
  starts_at: string;
  ends_at: string;
  room?: string | null;
  status: 'scheduled' | 'in_progress' | 'done' | 'cancelled';
  status_label?: string;
  materials_note?: string | null;
  tutor_note?: string | null;
  /**
   * Attendance rows recorded for this session. Present only when the
   * caller counted them — absent means "not counted", NOT "nobody
   * attended". `index` did not count at all until BE !786, so every
   * list row omitted it.
   */
  attendances_count?: number;
  /**
   * How many of those were `hadir`. Same absent-vs-zero rule: a
   * missing value read as 0 would report a 0% rate for a fully
   * attended session.
   */
  attendances_present_count?: number;
}

/** One session lifecycle state. Alias of the canonical union above. */
export type BimbelSessionStatus = BimbelSession['status'];

/**
 * The fields `PUT /tutoring-v2/sessions/{id}` may carry FROM THIS APP.
 *
 * `UpdateSessionRequest::rules()` also accepts `tutor_id`. It is
 * excluded on purpose and the exclusion is enforced twice — see
 * `TutoringBimbelService.updateSession` for the full reasoning.
 *
 * Every field is optional and an ABSENT key is not the same as `null`:
 * the controller writes a column only when the key is present, so
 * omitting `room` leaves the room untouched while sending
 * `room: null` clears it. Callers must therefore build this object
 * from what actually changed, not from the whole form.
 */
export interface BimbelSessionUpdatePayload {
  room?: string | null;
  materials_note?: string | null;
  tutor_note?: string | null;
  /**
   * Reassigning the tutor is not part of any edit surface in this app.
   * `never` makes `{ tutor_id: '…' }` a compile error at every call
   * site; `BIMBEL_SESSION_UPDATE_FIELDS` stops it on the wire even when
   * the type is cast away.
   */
  tutor_id?: never;
}

/**
 * The same allowlist at RUNTIME — the half that survives an `as any`.
 *
 * Typed as `readonly (keyof BimbelSessionUpdatePayload)[]` so a field
 * added to the payload interface but forgotten here is a type error at
 * the point of use rather than a value that silently never ships.
 */
export const BIMBEL_SESSION_UPDATE_FIELDS = [
  'room',
  'materials_note',
  'tutor_note',
] as const satisfies readonly (keyof BimbelSessionUpdatePayload)[];

/**
 * The same lifecycle, enumerable at RUNTIME.
 *
 * `BimbelSession['status']` is the canonical union — it mirrors the
 * backend `App\Modules\Tutoring\Enums\SessionStatus` case for case —
 * but a TypeScript union is erased at build time, and a filter picker
 * needs a real array to render rows from. This is that union made
 * iterable, NOT a second copy of it: the `Record<BimbelSessionStatus,
 * true>` below is exhaustive in BOTH directions, so the build fails if a
 * status is ever added to the union and forgotten here, and equally if a
 * value here stops being a valid status.
 *
 * Same role as `PAYOUT_REQUEST_STATUSES` in `@/types/tutoring2/payout`.
 */
const SESSION_STATUS_SET: Record<BimbelSessionStatus, true> = {
  scheduled: true,
  in_progress: true,
  done: true,
  cancelled: true,
};

export const BIMBEL_SESSION_STATUSES = Object.keys(
  SESSION_STATUS_SET,
) as BimbelSessionStatus[];

// ─── Assessments + Scores (BE-5) ───────────────────────────────────

export interface BimbelAssessment {
  id: string;
  program_id: string;
  /** AssessmentResource exposes this whenever `program` is loaded, and
   *  `index` + `show` both eager-load `program:id,name`. The list screen
   *  printed `program_id` for months while this sat on the same row. */
  program_name?: string | null;
  learning_group_id?: string | null;
  term_id?: string | null;
  created_by_teacher_id?: string | null;
  title: string;
  kind: 'tryout' | 'latihan' | 'kuis';
  kind_label?: string;
  assessment_date?: string | null;
  max_score: number;
  kkm?: number | null;
  description?: string | null;
  published_at?: string | null;
  /**
   * Scores recorded for this assessment. Absent from `listAssessments()`
   * rows — `AssessmentController::index` runs no `withCount('scores')`,
   * and the resource's `when()` drops the key. Read it with
   * `@/lib/absent-vs-zero`, never with `?? 0`.
   */
  scores_count?: number;
}

// ─── Bills (BE-8) ───────────────────────────────────────────────────

/** Wire shape for `/api/tutoring-v2/bills`. Fields optional where the
 * BE resource omits them (whenLoaded / non-tutoring rows). */
export interface BimbelBill {
  id: string;
  school_id: string;
  student_id: string;
  student_name?: string | null;
  student_number?: string | null;
  bimbel_enrollment_id?: string | null;
  bimbel_session_id?: string | null;
  enrollment?: {
    id: string;
    program_id: string;
    billing_mode?: string | null;
  } | null;
  payment_type_id: string;
  payment_type_name?: string | null;
  amount: number;
  status: 'unpaid' | 'pending' | 'partial' | 'paid' | string;
  source_type: 'TUTORING_PREPAID' | 'TUTORING_MONTHLY' | 'TUTORING_SESSION' | string;
  source_label?: string;
  due_date?: string | null;
  month?: string | null;
  reminder_count?: number;
  last_reminded_at?: string | null;
  created_at?: string;
  updated_at?: string;
}

/**
 * One row of `/api/tutoring-v2/payment-types` — the picker feed for the
 * Tambah Tagihan sheet.
 *
 * This is NOT the school-side `/payment-types` shape. That endpoint is
 * unreachable from a bimbel tenant twice over (it sits inside
 * `module:finance`, and it authorizes `finance.bill_type.manage`, whose
 * `finance.` prefix the entitlement filter strips from every tenant on
 * the bimbel bundle), which is why a bimbel-owned read exists at all.
 * It is gated on `tutoring.payment_type.view`.
 *
 * The BE deliberately does NOT filter to active rows: issuing a one-off
 * bill against a paused type is a real thing to want, and a picker that
 * silently omits rows is the harder failure to diagnose. So `status` is
 * on every row and the picker must SHOW it rather than assume it.
 */
export interface BimbelPaymentTypeOption {
  id: string;
  name: string;
  description?: string | null;
  /** Default nominal, already coerced to a number — see `listPaymentTypes`. */
  amount: number;
  /** `PaymentPeriod` backed value. Kept wide so an unseen period still renders. */
  period: 'monthly' | 'yearly' | 'once' | string;
  status: 'active' | 'inactive' | string;
  /**
   * The tenant's SYSTEM type (`schools.tenant_config.bimbel_payment_type_id`)
   * — the row the enrollment and per-session billing hooks anchor their
   * automatic bills to. Server-computed; zero or one row per tenant.
   */
  is_default: boolean;
}

export interface BimbelBillsSummary {
  tertagih: number;
  terbayar: number;
  menunggak: number;
  overdue_count: number;
}

// ─── Envelopes ─────────────────────────────────────────────────────

interface ListEnvelope<T> {
  data: T[];
  meta?: Pagination;
}

interface OneEnvelope<T> {
  data: T;
}

export const TutoringBimbelService = {
  // Programs
  async listPrograms(params: ProgramListParams = {}) {
    const r = await api.get<ListEnvelope<BimbelProgram>>('/tutoring-v2/programs', { params });
    return { items: r.data.data, pagination: r.data.meta };
  },
  async getProgram(id: string) {
    const r = await api.get<OneEnvelope<BimbelProgram>>(`/tutoring-v2/programs/${id}`);
    return r.data.data;
  },
  async createProgram(payload: Partial<BimbelProgram>) {
    const r = await api.post<OneEnvelope<BimbelProgram>>('/tutoring-v2/programs', payload);
    return r.data.data;
  },
  async updateProgram(id: string, payload: Partial<BimbelProgram>) {
    const r = await api.put<OneEnvelope<BimbelProgram>>(`/tutoring-v2/programs/${id}`, payload);
    return r.data.data;
  },
  async archiveProgram(id: string) {
    const r = await api.post<OneEnvelope<BimbelProgram>>(`/tutoring-v2/programs/${id}/archive`, {});
    return r.data.data;
  },
  async deleteProgram(id: string) {
    await api.delete(`/tutoring-v2/programs/${id}`);
  },

  // Packages
  async listPackages(programId: string, params: { page?: number; per_page?: number; status?: string } = {}) {
    const r = await api.get<ListEnvelope<BimbelPackage>>(`/tutoring-v2/programs/${programId}/packages`, { params });
    return { items: r.data.data, pagination: r.data.meta };
  },
  async createPackage(programId: string, payload: Partial<BimbelPackage>) {
    const r = await api.post<OneEnvelope<BimbelPackage>>(`/tutoring-v2/programs/${programId}/packages`, payload);
    return r.data.data;
  },
  async updatePackage(programId: string, id: string, payload: Partial<BimbelPackage>) {
    const r = await api.put<OneEnvelope<BimbelPackage>>(`/tutoring-v2/programs/${programId}/packages/${id}`, payload);
    return r.data.data;
  },
  async deletePackage(programId: string, id: string) {
    await api.delete(`/tutoring-v2/programs/${programId}/packages/${id}`);
  },

  // Learning groups
  async listGroups(params: { page?: number; per_page?: number; program_id?: string; term_id?: string; status?: string; tutor_id?: string } = {}) {
    const r = await api.get<ListEnvelope<BimbelLearningGroup>>('/tutoring-v2/learning-groups', { params });
    return { items: r.data.data, pagination: r.data.meta };
  },
  async getGroup(id: string) {
    const r = await api.get<OneEnvelope<BimbelLearningGroup>>(`/tutoring-v2/learning-groups/${id}`);
    return r.data.data;
  },
  async createGroup(payload: Partial<BimbelLearningGroup>) {
    const r = await api.post<OneEnvelope<BimbelLearningGroup>>('/tutoring-v2/learning-groups', payload);
    return r.data.data;
  },
  async updateGroup(id: string, payload: Partial<BimbelLearningGroup>) {
    const r = await api.put<OneEnvelope<BimbelLearningGroup>>(`/tutoring-v2/learning-groups/${id}`, payload);
    return r.data.data;
  },
  async getGroupRoster(id: string) {
    const r = await api.get<ListEnvelope<BimbelEnrollment>>(`/tutoring-v2/learning-groups/${id}/roster`);
    return { items: r.data.data, pagination: r.data.meta };
  },

  // Enrollments
  async listEnrollments(params: { page?: number; per_page?: number; student_id?: string; program_id?: string; learning_group_id?: string; status?: string; billing_mode?: string } = {}) {
    const r = await api.get<ListEnvelope<BimbelEnrollment>>('/tutoring-v2/enrollments', { params });
    return { items: r.data.data, pagination: r.data.meta };
  },
  async createEnrollment(payload: Partial<BimbelEnrollment>) {
    const r = await api.post<OneEnvelope<BimbelEnrollment>>('/tutoring-v2/enrollments', payload);
    return r.data.data;
  },
  async convertEnrollment(id: string) {
    const r = await api.post<OneEnvelope<BimbelEnrollment>>(`/tutoring-v2/enrollments/${id}/convert`, {});
    return r.data.data;
  },
  async withdrawEnrollment(id: string, reason?: string) {
    const r = await api.post<OneEnvelope<BimbelEnrollment>>(`/tutoring-v2/enrollments/${id}/withdraw`, { reason });
    return r.data.data;
  },
  async moveEnrollmentGroup(id: string, learning_group_id: string | null) {
    const r = await api.post<OneEnvelope<BimbelEnrollment>>(`/tutoring-v2/enrollments/${id}/move-group`, { learning_group_id });
    return r.data.data;
  },

  // Sessions + attendance (BE-4)
  async listSessions(params: { page?: number; per_page?: number; learning_group_id?: string; tutor_id?: string; status?: string; from?: string; to?: string } = {}) {
    const r = await api.get<ListEnvelope<BimbelSession>>('/tutoring-v2/sessions', { params });
    return { items: r.data.data, pagination: r.data.meta };
  },
  async createSession(payload: Partial<BimbelSession>) {
    const r = await api.post<OneEnvelope<BimbelSession>>('/tutoring-v2/sessions', payload);
    return r.data.data;
  },
  /**
   * One session by id.
   *
   * `GET /tutoring-v2/sessions/{id}` shipped with BE-4 and had no
   * caller: every screen that wanted a single session paged
   * `listSessions({ per_page: 100 })` and filtered client-side, which
   * is wrong the moment a centre has more than 100 sessions — the
   * detail page for session 101 renders "not found" for a row the list
   * above it just displayed.
   *
   * `show` does NOT return more fields than a list row: `index` and
   * `show` run an identical `withCount(['attendances', 'attendances as
   * attendances_present_count'])` — `index` has since 2026-08-17 — and
   * both render the same `SessionResource`. An earlier version of this
   * note claimed `index` lacked those counts; it never did.
   *
   * What `show` does add is scope enforcement on a single id: it applies
   * the SAME `narrowToCaller` scope as the list BEFORE `findOrFail`, so
   * an out-of-scope id 404s rather than leaking the room, the tutor and
   * the private `tutor_note`.
   */
  async getSession(id: string) {
    const r = await api.get<OneEnvelope<BimbelSession>>(`/tutoring-v2/sessions/${id}`);
    return r.data.data;
  },
  /**
   * Field edits on a session — NOT its schedule.
   *
   * ── Why this is a separate call from `rescheduleSession` ──
   *
   * The two halves of "edit a session" genuinely live on two endpoints,
   * and neither accepts the other's fields:
   *
   *   PUT  /sessions/{id}             room, materials_note, tutor_note
   *                                   (+ tutor_id — see below)
   *   POST /sessions/{id}/reschedule  starts_at, ends_at (+ room)
   *
   * `SessionController::update` copies a key ONLY when
   * `$request->has($k)`, so an omitted key is genuinely left alone in
   * the database. That is what makes a partial payload safe here and
   * why callers should send only what the user actually changed —
   * sending the whole form back would re-stamp fields nobody touched.
   *
   * ── `room` deliberately belongs to THIS call, never to reschedule ──
   *
   * `room` is the one field both endpoints accept. Routing it through
   * whichever call happens to be firing would give one field two
   * possible writers depending on unrelated state, and when both calls
   * fire the second would silently overwrite the first. It is pinned
   * here instead: one field, one writer, always. `RescheduleSessionAction`
   * only assigns room when it is non-null (`if ($room !== null)`), so
   * omitting it there is a genuine no-op rather than a blanking.
   *
   * ── `tutor_id` is accepted by the endpoint and refused here ──
   *
   * The FormRequest allows `tutor_id`, but reassigning a session's tutor
   * is out of scope for the edit surfaces that call this (product
   * decision: schedule / room / notes only, because moving the tutor or
   * the group disturbs attendance already recorded against the session).
   * `tutor_id?: never` blocks it at compile time, and the runtime
   * allowlist below blocks it even for a caller that cast the type away.
   * Both halves are deliberate: the type alone would not survive an
   * `as any`, and the allowlist alone would fail silently.
   */
  async updateSession(id: string, payload: BimbelSessionUpdatePayload) {
    const body: Record<string, unknown> = {};
    for (const k of BIMBEL_SESSION_UPDATE_FIELDS) {
      // `in`, not a truthiness test: `null` clears a note and is a
      // meaningful value, while an ABSENT key means "leave it alone".
      if (k in payload) body[k] = payload[k];
    }
    const r = await api.put<OneEnvelope<BimbelSession>>(`/tutoring-v2/sessions/${id}`, body);
    return r.data.data;
  },
  async createRecurringSessions(payload: Record<string, unknown>) {
    const r = await api.post<ListEnvelope<BimbelSession>>('/tutoring-v2/sessions/recurring', payload);
    return r.data.data;
  },
  /**
   * Move a session to a new slot.
   *
   * `POST /tutoring-v2/sessions/{id}/reschedule` shipped with BE-4 and
   * had no caller — the tutor's Reschedule button was a
   * `toast.info('Belum tersedia')` for the whole time it existed.
   *
   * The backend validates `ends_at` is after `starts_at` and refuses a
   * cancelled session, so both failures come back as a 422 message the
   * caller can surface verbatim rather than re-implementing the rules
   * here and letting the two drift.
   */
  async rescheduleSession(
    id: string,
    payload: { starts_at: string; ends_at: string; room?: string | null },
  ) {
    const r = await api.post<OneEnvelope<BimbelSession>>(
      `/tutoring-v2/sessions/${id}/reschedule`,
      payload,
    );
    return r.data.data;
  },
  async cancelSession(id: string, reason?: string) {
    const r = await api.post<OneEnvelope<BimbelSession>>(`/tutoring-v2/sessions/${id}/cancel`, { reason });
    return r.data.data;
  },
  async completeSession(id: string, tutor_note?: string) {
    const r = await api.post<OneEnvelope<BimbelSession>>(`/tutoring-v2/sessions/${id}/complete`, { tutor_note });
    return r.data.data;
  },
  async listSessionAttendance(sessionId: string) {
    const r = await api.get<ListEnvelope<TutoringAttendanceRow>>(`/tutoring-v2/sessions/${sessionId}/attendance`);
    return { items: r.data.data, pagination: r.data.meta };
  },
  async markSessionAttendance(sessionId: string, rows: Array<{ enrollment_id: string; status: string; notes?: string }>) {
    const r = await api.post<ListEnvelope<TutoringAttendanceRow>>(`/tutoring-v2/sessions/${sessionId}/attendance`, { rows });
    return r.data.data;
  },

  // Assessments + scores (BE-5)
  async listAssessments(params: { page?: number; per_page?: number; program_id?: string; learning_group_id?: string; kind?: string; published?: boolean } = {}) {
    const r = await api.get<ListEnvelope<BimbelAssessment>>('/tutoring-v2/assessments', { params });
    return { items: r.data.data, pagination: r.data.meta };
  },
  async createAssessment(payload: Partial<BimbelAssessment>) {
    const r = await api.post<OneEnvelope<BimbelAssessment>>('/tutoring-v2/assessments', payload);
    return r.data.data;
  },
  async publishAssessment(id: string) {
    const r = await api.post<OneEnvelope<BimbelAssessment>>(`/tutoring-v2/assessments/${id}/publish`, {});
    return r.data.data;
  },
  async unpublishAssessment(id: string) {
    const r = await api.post<OneEnvelope<BimbelAssessment>>(`/tutoring-v2/assessments/${id}/unpublish`, {});
    return r.data.data;
  },
  /** One assessment by id — the only place `max_score` and `kkm` are on
   * the wire. `listScores` returns a flat collection with no envelope,
   * so a view that renders "45 / max" or colours rows against a pass
   * mark has to read them from here. */
  async getAssessment(id: string) {
    const r = await api.get<OneEnvelope<BimbelAssessment>>(`/tutoring-v2/assessments/${id}`);
    return r.data.data;
  },
  async listScores(assessmentId: string) {
    const r = await api.get<ListEnvelope<TutoringScoreRow>>(`/tutoring-v2/assessments/${assessmentId}/scores`);
    return { items: r.data.data, pagination: r.data.meta };
  },
  async upsertScores(assessmentId: string, rows: Array<{ enrollment_id: string; score: number | null; notes?: string | null }>) {
    const r = await api.post<ListEnvelope<TutoringScoreRow>>(`/tutoring-v2/assessments/${assessmentId}/scores`, { rows });
    return r.data.data;
  },

  // ─── Bills (BE-8) ─────────────────────────────────────────────────
  async listBills(params: { page?: number; per_page?: number; student_id?: string; status?: string; source_type?: string; month?: string } = {}) {
    const r = await api.get<ListEnvelope<BimbelBill>>('/tutoring-v2/bills', { params });
    return { items: r.data.data, pagination: r.data.meta };
  },
  async getBill(id: string) {
    const r = await api.get<OneEnvelope<BimbelBill>>(`/tutoring-v2/bills/${id}`);
    return r.data.data;
  },
  async getBillsSummary(params: { source_type?: string; month?: string } = {}) {
    const r = await api.get<OneEnvelope<BimbelBillsSummary>>('/tutoring-v2/bills/summary', { params });
    return r.data.data;
  },
  /**
   * Picker feed for Tambah Tagihan. `search` is forwarded to the SERVER,
   * which runs the same case-insensitive name/description filter the
   * school catalogue uses, so typing reaches rows this page never held.
   *
   * `amount` is coerced HERE, once. `payment_types.amount` is
   * `decimal(15,2)` and `PaymentTypeOptionResource` passes it through
   * with no `(float)` cast, so postgres hands it over as the string
   * `"150000.00"`. `<MoneyInput>` takes `number | null` and nothing
   * else — an uncoerced string reaches it as a non-number and the
   * Nominal prefill silently does nothing.
   */
  async listPaymentTypes(
    params: { search?: string; status?: string; period?: string } = {},
  ) {
    const r = await api.get<ListEnvelope<BimbelPaymentTypeOption>>(
      '/tutoring-v2/payment-types',
      { params },
    );
    return r.data.data.map((row) => ({
      ...row,
      amount: Number(row.amount) || 0,
      is_default: Boolean(row.is_default),
    }));
  },
  async createBill(payload: {
    student_id: string;
    bimbel_enrollment_id?: string | null;
    bimbel_session_id?: string | null;
    payment_type_id: string;
    amount: number;
    due_date: string;
    source_type: string;
    month?: string | null;
    status?: string;
  }) {
    const r = await api.post<OneEnvelope<BimbelBill>>('/tutoring-v2/bills', payload);
    return r.data.data;
  },
  async markBillPaid(id: string, payload: { amount?: number; payment_method?: string; payment_date?: string; admin_notes?: string } = {}) {
    const r = await api.post<OneEnvelope<BimbelBill>>(`/tutoring-v2/bills/${id}/mark-paid`, payload);
    return r.data.data;
  },
  async resendBill(id: string) {
    const r = await api.post<OneEnvelope<BimbelBill>>(`/tutoring-v2/bills/${id}/resend`, {});
    return r.data.data;
  },
};

// Type re-exports for downstream views.
export type { TutoringAttendanceRow, TutoringScoreRow, TutoringMaterial };
