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
  term_id?: string | null;
  tutor_id?: string | null;
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
  program_id: string;
  learning_group_id?: string | null;
  package_id?: string | null;
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
  tutor_id?: string | null;
  series_key?: string | null;
  starts_at: string;
  ends_at: string;
  room?: string | null;
  status: 'scheduled' | 'in_progress' | 'done' | 'cancelled';
  status_label?: string;
  materials_note?: string | null;
  tutor_note?: string | null;
  attendances_count?: number;
}

// ─── Assessments + Scores (BE-5) ───────────────────────────────────

export interface BimbelAssessment {
  id: string;
  program_id: string;
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
  async listScores(assessmentId: string) {
    const r = await api.get<ListEnvelope<TutoringScoreRow>>(`/tutoring-v2/assessments/${assessmentId}/scores`);
    return { items: r.data.data, pagination: r.data.meta };
  },
  async upsertScores(assessmentId: string, rows: Array<{ enrollment_id: string; score: number | null; notes?: string | null }>) {
    const r = await api.post<ListEnvelope<TutoringScoreRow>>(`/tutoring-v2/assessments/${assessmentId}/scores`, { rows });
    return r.data.data;
  },
};

// Type re-exports for downstream views.
export type { TutoringAttendanceRow, TutoringScoreRow, TutoringMaterial };
