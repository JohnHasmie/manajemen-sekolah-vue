/**
 * TutoringService — /tutoring/* endpoint wrapper.
 *
 * Mirrors the Flutter `tutoring_service.dart`. Every call is tenant-
 * scoped server-side via the X-Tenant-ID header the axios interceptor
 * stamps, so none of these pass a school_id. Reads unwrap the
 * `{ success, data, meta }` envelope via `extractData`; the one case
 * that needs `meta` (attendance summary) reads the raw response.
 */
import { aiApi, api, extractData } from '@/lib/http';
import type { ApiResponse } from '@/types/api';
import type {
  TenantBillingSettings,
  TutoringAiQuestion,
  TutoringAttendanceSummary,
  TutoringBill,
  TutoringChildOverview,
  TutoringEnrollee,
  TutoringGroup,
  TutoringPackage,
  TutoringProgram,
  TutoringProgress,
  TutoringSession,
  TutoringSessionAttendanceRow,
} from '@/types/tutoring';

function toIso(d: Date): string {
  return d.toISOString();
}

export const TutoringService = {
  // ── Parent reads ────────────────────────────────────────────────

  async getSchedule(
    studentId: string,
    from: Date,
    to: Date,
  ): Promise<TutoringSession[]> {
    const res = await api.get<ApiResponse<TutoringSession[]>>(
      '/tutoring/schedule',
      { params: { student_id: studentId, from: toIso(from), to: toIso(to) } },
    );
    return extractData(res) ?? [];
  },

  /** Attendance summary lives in `meta.summary`, not `data`. */
  async getAttendanceSummary(
    studentId: string,
  ): Promise<TutoringAttendanceSummary> {
    const res = await api.get('/tutoring/attendance', {
      params: { student_id: studentId },
    });
    const summary = res.data?.meta?.summary;
    return (
      summary ?? {
        total_recorded: 0,
        attended: 0,
        attendance_rate: null,
        breakdown: {},
      }
    );
  },

  async getBills(studentId: string): Promise<TutoringBill[]> {
    const res = await api.get<ApiResponse<TutoringBill[]>>('/tutoring/bills', {
      params: { student_id: studentId },
    });
    return extractData(res) ?? [];
  },

  async getProgress(studentId: string): Promise<TutoringProgress> {
    const res = await api.get<ApiResponse<TutoringProgress>>(
      `/tutoring/students/${studentId}/progress`,
    );
    return extractData(res);
  },

  /** One combined fetch for the parent overview page (Promise.all). */
  async getChildOverview(studentId: string): Promise<TutoringChildOverview> {
    const now = new Date();
    const from = new Date(now.getTime() - 7 * 24 * 3600 * 1000);
    const to = new Date(now.getTime() + 14 * 24 * 3600 * 1000);

    const [sessions, attendance, bills, progress] = await Promise.all([
      this.getSchedule(studentId, from, to),
      this.getAttendanceSummary(studentId),
      this.getBills(studentId),
      this.getProgress(studentId),
    ]);

    const upcoming = sessions
      .filter(
        (s) =>
          s.status === 'SCHEDULED' &&
          s.scheduled_at != null &&
          new Date(s.scheduled_at).getTime() > now.getTime(),
      )
      .sort(
        (a, b) =>
          new Date(a.scheduled_at as string).getTime() -
          new Date(b.scheduled_at as string).getTime(),
      );

    return { upcomingSessions: upcoming, attendance, bills, progress };
  },

  // ── Admin: programs + billing ───────────────────────────────────

  async getPrograms(): Promise<TutoringProgram[]> {
    const res = await api.get<ApiResponse<TutoringProgram[]>>(
      '/tutoring/programs',
    );
    return extractData(res) ?? [];
  },

  async createProgram(payload: {
    name: string;
    description?: string;
    target_education_level?: string;
  }): Promise<TutoringProgram> {
    const res = await api.post<ApiResponse<TutoringProgram>>(
      '/tutoring/programs',
      payload,
    );
    return extractData(res);
  },

  async deleteProgram(id: string): Promise<void> {
    await api.delete(`/tutoring/programs/${id}`);
  },

  async getPackages(programId: string): Promise<TutoringPackage[]> {
    const res = await api.get<ApiResponse<TutoringPackage[]>>(
      '/tutoring/packages',
      { params: { program_id: programId } },
    );
    return extractData(res) ?? [];
  },

  async createPackage(payload: {
    program_id: string;
    name: string;
    billing_modes_allowed: string[];
    total_sessions?: number;
    price?: number;
  }): Promise<TutoringPackage> {
    const res = await api.post<ApiResponse<TutoringPackage>>(
      '/tutoring/packages',
      payload,
    );
    return extractData(res);
  },

  async getGroups(programId: string): Promise<TutoringGroup[]> {
    const res = await api.get<ApiResponse<TutoringGroup[]>>(
      '/tutoring/groups',
      { params: { program_id: programId } },
    );
    return extractData(res) ?? [];
  },

  /** All tenant groups (no program filter). */
  async getAllGroups(): Promise<TutoringGroup[]> {
    const res = await api.get<ApiResponse<TutoringGroup[]>>('/tutoring/groups');
    return extractData(res) ?? [];
  },

  async createGroup(payload: {
    program_id: string;
    name: string;
    capacity?: number;
    tutor_user_id?: string;
  }): Promise<TutoringGroup> {
    const res = await api.post<ApiResponse<TutoringGroup>>(
      '/tutoring/groups',
      payload,
    );
    return extractData(res);
  },

  // ── Admin: enrollment ───────────────────────────────────────────

  /** Tenant students (for the enroll picker) via the core /student. */
  async getTenantStudents(): Promise<{ id: string; name: string }[]> {
    const res = await api.get('/student');
    const body = res.data;
    const list = Array.isArray(body?.data)
      ? body.data
      : Array.isArray(body)
        ? body
        : [];
    return (list as Record<string, unknown>[]).map((m) => ({
      id: String(m.id),
      name: String(m.name ?? m.nama ?? '—'),
    }));
  },

  async createEnrollment(payload: {
    student_id: string;
    package_id: string;
    billing_mode: string;
    group_id?: string;
  }): Promise<string> {
    const res = await api.post<ApiResponse<{ id: string }>>(
      '/tutoring/enrollments',
      payload,
    );
    return extractData(res)?.id ?? '';
  },

  async createBillingPlan(
    enrollmentId: string,
    mode: string,
    config: Record<string, number>,
  ): Promise<void> {
    await api.post(`/tutoring/enrollments/${enrollmentId}/billing-plan`, {
      mode,
      config,
    });
  },

  async getBillingSettings(): Promise<TenantBillingSettings> {
    const res = await api.get<ApiResponse<TenantBillingSettings>>(
      '/tutoring/billing-settings',
    );
    return extractData(res);
  },

  async updateBillingSettings(
    payload: TenantBillingSettings,
  ): Promise<TenantBillingSettings> {
    const res = await api.put<ApiResponse<TenantBillingSettings>>(
      '/tutoring/billing-settings',
      payload,
    );
    return extractData(res);
  },

  // ── Tutor: sessions + attendance ────────────────────────────────

  async getTutorSessions(
    tutorUserId: string,
    from: Date,
    to: Date,
  ): Promise<TutoringSession[]> {
    const res = await api.get<ApiResponse<TutoringSession[]>>(
      '/tutoring/schedule',
      {
        params: {
          tutor_user_id: tutorUserId,
          from: toIso(from),
          to: toIso(to),
        },
      },
    );
    return extractData(res) ?? [];
  },

  async getSessionRoster(
    sessionId: string,
  ): Promise<TutoringSessionAttendanceRow[]> {
    const res = await api.get<ApiResponse<TutoringSessionAttendanceRow[]>>(
      `/tutoring/sessions/${sessionId}/attendance`,
    );
    return extractData(res) ?? [];
  },

  async getGroupEnrollees(groupId: string): Promise<TutoringEnrollee[]> {
    const res = await api.get<ApiResponse<TutoringEnrollee[]>>(
      '/tutoring/enrollments',
      { params: { group_id: groupId, status: 'ACTIVE' } },
    );
    return extractData(res) ?? [];
  },

  async recordAttendance(
    sessionId: string,
    items: { student_id: string; status: string }[],
  ): Promise<void> {
    await api.post(`/tutoring/sessions/${sessionId}/attendance`, { items });
  },

  /**
   * Create a single session. tutor_user_id is omitted — the backend
   * inherits the group's default tutor.
   */
  async createSession(payload: {
    group_id: string;
    scheduled_at: string;
    duration_minutes?: number;
    room?: string;
    topic?: string;
  }): Promise<void> {
    await api.post('/tutoring/sessions', payload);
  },

  // ── AI: try-out / exercise generation ───────────────────────────

  /**
   * Generate try-out / exercise questions via the AI microservice
   * (aiApi base URL, not the core API). Synchronous — returns the
   * `{ questions, meta }` data block directly.
   */
  async generateTryout(payload: {
    subject: string;
    target_education_level?: string;
    topic?: string;
    question_count?: number;
    difficulty?: string;
    mode?: 'tryout' | 'exercise';
  }): Promise<{ questions: TutoringAiQuestion[]; meta: Record<string, unknown> }> {
    const path =
      payload.mode === 'exercise'
        ? '/tutoring-ai/exercise/generate'
        : '/tutoring-ai/tryout/generate';
    const res = await aiApi.post<
      ApiResponse<{ questions: TutoringAiQuestion[]; meta: Record<string, unknown> }>
    >(path, payload);
    return extractData(res) ?? { questions: [], meta: {} };
  },
};
