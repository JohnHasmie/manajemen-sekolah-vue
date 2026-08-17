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
