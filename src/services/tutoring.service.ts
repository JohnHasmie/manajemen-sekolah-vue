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
  TutoringAdminStats,
  TutoringAiQuestion,
  TutoringAssessment,
  TutoringAttendanceSummary,
  TutoringBill,
  TutoringChildOverview,
  TutoringEnrollee,
  TutoringGroup,
  TutoringInviteResult,
  TutoringPackage,
  TutoringProgram,
  TutoringProgress,
  TutoringSession,
  TutoringSessionAttendanceRow,
  TutoringActivity,
  TutoringActivitySubmission,
  TutoringMaterial,
  TutoringStudentRow,
  TutoringTutorRow,
  TutoringTutorStats,
  TutorPayoutRate,
  TutorPayoutSummary,
} from '@/types/tutoring';

function toIso(d: Date): string {
  return d.toISOString();
}

export const TutoringService = {
  // ── Admin reads ─────────────────────────────────────────────────

  /** Headline KPIs for the admin bimbel dashboard. Optionally scoped
   *  to a single program (the dashboard slice filter). */
  async getAdminStats(programId?: string | null): Promise<TutoringAdminStats> {
    const res = await api.get<ApiResponse<TutoringAdminStats>>(
      '/tutoring/admin-stats',
      { params: programId ? { program_id: programId } : {} },
    );
    return (
      extractData(res) ?? {
        active_programs: 0,
        groups: 0,
        students: 0,
        active_enrollments: 0,
        upcoming_sessions: 0,
        sessions_this_week: 0,
        unpaid_bills: 0,
        unpaid_total: 0,
        attendance_rate: null,
      }
    );
  },

  /** Admin: list of enrolled bimbel students. */
  async getAdminStudents(opts: {
    program_id?: string | null;
    search?: string;
  } = {}): Promise<TutoringStudentRow[]> {
    const res = await api.get<ApiResponse<TutoringStudentRow[]>>(
      '/tutoring/students',
      {
        params: {
          ...(opts.program_id ? { program_id: opts.program_id } : {}),
          ...(opts.search ? { search: opts.search } : {}),
        },
      },
    );
    return extractData(res) ?? [];
  },

  /** Admin: tutors carrying TEACHER role on this tenant. */
  async getAdminTutors(opts: {
    status?: 'active' | 'pending';
    search?: string;
  } = {}): Promise<TutoringTutorRow[]> {
    const res = await api.get<ApiResponse<TutoringTutorRow[]>>(
      '/tutoring/tutors',
      {
        params: {
          ...(opts.status ? { status: opts.status } : {}),
          ...(opts.search ? { search: opts.search } : {}),
        },
      },
    );
    return extractData(res) ?? [];
  },

  /** Admin: invite a tutor by email (idempotent). */
  async inviteTutor(payload: {
    email: string;
    name?: string | null;
  }): Promise<TutoringInviteResult> {
    const res = await api.post<ApiResponse<TutoringInviteResult>>(
      '/tutoring/tutors/invite',
      {
        email: payload.email,
        ...(payload.name ? { name: payload.name } : {}),
      },
    );
    return extractData(res)!;
  },

  /** All sessions for the tenant within [from]..[to] (admin view). */
  async getAllSessions(from: Date, to: Date): Promise<TutoringSession[]> {
    const res = await api.get<ApiResponse<TutoringSession[]>>(
      '/tutoring/schedule',
      { params: { from: toIso(from), to: toIso(to) } },
    );
    return extractData(res) ?? [];
  },

  /** All tutoring bills for the tenant (admin view). */
  async getAllBills(status?: string): Promise<TutoringBill[]> {
    const res = await api.get<ApiResponse<TutoringBill[]>>('/tutoring/bills', {
      params: { per_page: 100, ...(status ? { status } : {}) },
    });
    return extractData(res) ?? [];
  },

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

  /** KPI strip for the tutor's own dashboard — sessions/hours this
   *  week, attendance rate, groups, students. Defaults to the calling
   *  user; pass [tutorUserId] only when an admin previews a specific
   *  tutor's KPIs. */
  async getTutorStats(tutorUserId?: string): Promise<TutoringTutorStats> {
    const res = await api.get<ApiResponse<TutoringTutorStats>>(
      '/tutoring/tutor-stats',
      { params: tutorUserId ? { tutor_user_id: tutorUserId } : {} },
    );
    return (
      extractData(res) ?? {
        sessions_this_week: 0,
        sessions_today: 0,
        hours_this_week: 0,
        minutes_this_week: 0,
        upcoming_sessions: 0,
        groups: 0,
        students: 0,
        attendance_rate: null,
      }
    );
  },

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
   * Create a tutoring assessment header (try-out / post-test). Used by
   * the AI generator's "Simpan sebagai Try-out".
   */
  async createAssessment(payload: {
    type: string;
    title: string;
    held_at: string;
    tutoring_group_id?: string;
    tutoring_program_id?: string;
    max_score?: number;
    questions?: TutoringAiQuestion[];
  }): Promise<void> {
    await api.post('/tutoring/assessments', payload);
  },

  /** Assessments for a program (header list — admin viewer). */
  async getAssessments(programId: string): Promise<TutoringAssessment[]> {
    const res = await api.get<ApiResponse<TutoringAssessment[]>>(
      '/tutoring/assessments',
      { params: { program_id: programId } },
    );
    return extractData(res) ?? [];
  },

  /** One assessment incl. its persisted question set. */
  async getAssessment(id: string): Promise<TutoringAssessment> {
    const res = await api.get<ApiResponse<TutoringAssessment>>(
      `/tutoring/assessments/${id}`,
    );
    return extractData(res);
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
    meeting_url?: string;
    topic?: string;
  }): Promise<void> {
    await api.post('/tutoring/sessions', payload);
  },

  /** Bulk-create sessions on a weekday template. */
  async generateRecurringSessions(payload: {
    group_id: string;
    weekdays: number[]; // ISO ints 1..7
    start_date: string; // YYYY-MM-DD
    end_date: string;
    time: string; // HH:mm
    duration_minutes?: number;
    room?: string;
    meeting_url?: string;
    topic?: string;
  }): Promise<{ created: number; skipped: number; sessions: string[] }> {
    const res = await api.post<
      ApiResponse<{ created: number; skipped: number; sessions: string[] }>
    >('/tutoring/sessions/generate-recurring', payload);
    return extractData(res);
  },

  // ── Materials (bahan ajar) ──────────────────────────────────────

  async getMaterials(opts: {
    group_id?: string;
    program_id?: string;
    only_published?: boolean;
  } = {}): Promise<TutoringMaterial[]> {
    const res = await api.get<ApiResponse<TutoringMaterial[]>>(
      '/tutoring/materials',
      {
        params: {
          ...(opts.group_id ? { group_id: opts.group_id } : {}),
          ...(opts.program_id ? { program_id: opts.program_id } : {}),
          ...(opts.only_published ? { only_published: 1 } : {}),
          per_page: 100,
        },
      },
    );
    return extractData(res) ?? [];
  },

  async createMaterial(payload: {
    tutoring_group_id?: string;
    tutoring_program_id?: string;
    title: string;
    description?: string;
    file_url?: string;
    published_at?: string | null;
  }): Promise<TutoringMaterial> {
    const res = await api.post<ApiResponse<TutoringMaterial>>(
      '/tutoring/materials',
      payload,
    );
    return extractData(res);
  },

  async deleteMaterial(materialId: string): Promise<void> {
    await api.delete(`/tutoring/materials/${materialId}`);
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

  // ── Activities (Phase 5 — tugas / quiz / ujian / proyek) ────────

  /** List activities. Tutor + parent reads; optional group/type filter. */
  async getActivities(opts: {
    group_id?: string;
    type?: 'HOMEWORK' | 'EXAM' | 'QUIZ' | 'PROJECT';
  } = {}): Promise<TutoringActivity[]> {
    const res = await api.get<ApiResponse<TutoringActivity[]>>(
      '/tutoring/activities',
      {
        params: {
          ...(opts.group_id ? { group_id: opts.group_id } : {}),
          ...(opts.type ? { type: opts.type } : {}),
          per_page: 100,
        },
      },
    );
    return extractData(res) ?? [];
  },

  async createActivity(payload: {
    tutoring_group_id: string;
    type: 'HOMEWORK' | 'EXAM' | 'QUIZ' | 'PROJECT';
    title: string;
    description?: string;
    due_at?: string | null;
    subject_id?: string | null;
  }): Promise<TutoringActivity> {
    const res = await api.post<ApiResponse<TutoringActivity>>(
      '/tutoring/activities',
      payload,
    );
    return extractData(res);
  },

  async getActivitySubmissions(
    activityId: string,
  ): Promise<TutoringActivitySubmission[]> {
    const res = await api.get<ApiResponse<TutoringActivitySubmission[]>>(
      `/tutoring/activities/${activityId}/submissions`,
    );
    return extractData(res) ?? [];
  },

  async recordActivitySubmissions(
    activityId: string,
    items: Array<{
      student_id: string;
      status: string;
      score?: number | null;
      note?: string | null;
    }>,
  ): Promise<void> {
    await api.post(
      `/tutoring/activities/${activityId}/submissions`,
      { items },
    );
  },

  async getStudentActivitySubmissions(
    studentId: string,
  ): Promise<TutoringActivitySubmission[]> {
    const res = await api.get<ApiResponse<TutoringActivitySubmission[]>>(
      '/tutoring/activity-submissions',
      { params: { student_id: studentId } },
    );
    return extractData(res) ?? [];
  },

  // ── Payouts (honorarium per tutor) ──────────────────────────────

  /** Admin: list rates for every tutor on this tenant. */
  async getPayoutRates(): Promise<TutorPayoutRate[]> {
    const res = await api.get<ApiResponse<TutorPayoutRate[]>>(
      '/tutoring/payouts/rates',
    );
    return extractData(res) ?? [];
  },

  /** Admin: upsert one tutor's rate. */
  async upsertPayoutRate(
    userId: string,
    payload: {
      basis: 'PER_SESSION' | 'PER_HOUR';
      amount: number;
      currency?: string;
      note?: string | null;
    },
  ): Promise<TutorPayoutRate> {
    const res = await api.put<ApiResponse<TutorPayoutRate>>(
      `/tutoring/payouts/rates/${userId}`,
      payload,
    );
    return extractData(res);
  },

  /**
   * Tutor own summary (or admin override via [userId]).
   * Period defaults to current calendar month; pass [month] as YYYY-MM
   * to override.
   */
  async getPayoutSummary(opts: {
    userId?: string;
    month?: string;
  } = {}): Promise<TutorPayoutSummary> {
    const res = await api.get<ApiResponse<TutorPayoutSummary>>(
      '/tutoring/payouts/summary',
      {
        params: {
          ...(opts.userId ? { user_id: opts.userId } : {}),
          ...(opts.month ? { month: opts.month } : {}),
        },
      },
    );
    return extractData(res);
  },
};
