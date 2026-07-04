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
  TutoringBillDetail,
  TutoringPaymentAccount,
  TutoringChildOverview,
  TutoringEnrollee,
  TutoringFeedEvent,
  TutoringGroup,
  TutoringInviteResult,
  TutoringPackage,
  TutoringProgram,
  TutoringProgress,
  TutoringSession,
  TutoringSessionAttendanceRow,
  TutoringActivity,
  TutoringActivitySubmission,
  TutoringGroupAnnouncement,
  TutoringLead,
  TutoringLeaderboardRow,
  TutoringMaterial,
  TutoringSessionFeedback,
  TutoringSessionFeedbackSummary,
  TutoringStudentRow,
  TutoringTutorRow,
  TutoringTutorStats,
  TutoringVoucher,
  TutoringVoucherPreview,
  TutorPayoutRate,
  TutorPayoutRequest,
  TutorPayoutRequestStatus,
  TutorPayoutSettings,
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

  /** Bill detail — header + payment history + tenant payment account. */
  async getBillDetail(id: string): Promise<TutoringBillDetail> {
    const res = await api.get<ApiResponse<TutoringBillDetail>>(
      `/tutoring/bills/${id}`,
    );
    return extractData(res);
  },

  /**
   * Download the invoice PDF for a paid bill. Triggers a browser
   * download via an in-memory blob URL — matches the pattern used by
   * BillingService.downloadReceipt. Backend wraps the binary in an
   * `application/pdf` response; the `disposition=attachment` query
   * keeps it consistent with the existing kuitansi/receipt UX.
   *
   * The filename uses the first 8 chars of the bill id so admins can
   * cross-reference downloads with the bill list without exposing the
   * full UUID.
   */
  async downloadInvoicePdf(billId: string): Promise<void> {
    const res = await api.get(`/tutoring/bills/${billId}/invoice`, {
      responseType: 'blob',
      params: { disposition: 'attachment' },
    });
    const blob = res.data as Blob;
    const url = window.URL.createObjectURL(blob);
    try {
      const a = document.createElement('a');
      a.href = url;
      a.download = `invoice-${billId.slice(0, 8)}.pdf`;
      document.body.appendChild(a);
      a.click();
      a.remove();
    } finally {
      // Defer revoke so the click can settle on some browsers.
      setTimeout(() => window.URL.revokeObjectURL(url), 1000);
    }
  },

  /**
   * Resend the invoice for an already-paid bill via the configured
   * channels (email + WhatsApp). Backend returns 422 if the bill is
   * not paid yet — caller surfaces that as a toast error.
   */
  async resendInvoice(billId: string): Promise<void> {
    await api.post(`/tutoring/bills/${billId}/resend-invoice`);
  },

  /** Admin manual mark-paid — creates a verified Payment row and
   *  flips bill.status → paid in one transaction. */
  async markBillPaid(
    id: string,
    payload: {
      amount?: number;
      payment_method?: string;
      payment_date?: string;
      admin_notes?: string;
    } = {},
  ): Promise<void> {
    await api.post(`/tutoring/bills/${id}/mark-paid`, payload);
  },

  /** Tenant payment-account block (parent reads to know where to transfer). */
  async getPaymentAccount(): Promise<TutoringPaymentAccount | null> {
    const res = await api.get<ApiResponse<TutoringPaymentAccount | null>>(
      '/tutoring/payment-account',
    );
    return extractData(res);
  },

  /** Admin: upload QRIS image. Returns `{ path, url }`. */
  async uploadQrisImage(file: File): Promise<{ path: string; url: string }> {
    const form = new FormData();
    form.append('image', file);
    const res = await api.post<ApiResponse<{ path: string; url: string }>>(
      '/tutoring/billing-settings/qris',
      form,
      { headers: { 'Content-Type': 'multipart/form-data' } },
    );
    return extractData(res);
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

  /** Rich per-class list for the parent Kelas page. Backed by
   *  GetWaliClassMetaAction — one row per group with attendance,
   *  next session, latest score, and unread-7d announcement count. */
  async getWaliClassMeta(
    studentId: string,
  ): Promise<import('@/types/tutoring').TutoringParentClassMeta[]> {
    const res = await api.get<ApiResponse<{
      classes: import('@/types/tutoring').TutoringParentClassMeta[];
    }>>(`/tutoring/students/${studentId}/parent-class-meta`);
    return (extractData(res)?.classes ?? []) as import('@/types/tutoring').TutoringParentClassMeta[];
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
      '/tutoring/classes',
      { params: { program_id: programId } },
    );
    return extractData(res) ?? [];
  },

  /** All tenant groups (no program filter). */
  async getAllGroups(): Promise<TutoringGroup[]> {
    const res = await api.get<ApiResponse<TutoringGroup[]>>('/tutoring/classes');
    return extractData(res) ?? [];
  },

  async createGroup(payload: {
    program_id: string;
    name: string;
    capacity?: number;
    tutor_user_id?: string;
  }): Promise<TutoringGroup> {
    const res = await api.post<ApiResponse<TutoringGroup>>(
      '/tutoring/classes',
      payload,
    );
    return extractData(res);
  },

  async updateGroup(
    groupId: string,
    payload: { name?: string; capacity?: number },
  ): Promise<void> {
    await api.put(`/tutoring/classes/${groupId}`, payload);
  },

  async deleteGroup(groupId: string): Promise<void> {
    await api.delete(`/tutoring/classes/${groupId}`);
  },

  async assignGroupTutor(groupId: string, tutorUserId: string | null): Promise<void> {
    await api.post(`/tutoring/classes/${groupId}/assign-tutor`, {
      tutor_user_id: tutorUserId,
    });
  },

  async updateTutor(userId: string, payload: { name: string }): Promise<void> {
    await api.put(`/tutoring/tutors/${userId}`, payload);
  },

  async deactivateTutor(userId: string): Promise<{ groups_unassigned: number }> {
    const res = await api.post<ApiResponse<{ groups_unassigned: number }>>(
      `/tutoring/tutors/${userId}/deactivate`,
    );
    return extractData(res) ?? { groups_unassigned: 0 };
  },

  async cancelEnrollment(enrollmentId: string): Promise<void> {
    await api.post(`/tutoring/enrollments/${enrollmentId}/cancel`);
  },

  /** Update a student's school-level fields (name, parent contact).
   *  Goes via the shared `/students/:id` endpoint that the school
   *  admin uses — bimbel admin reuses it through the tenant scope. */
  async updateStudent(
    studentId: string,
    payload: {
      name?: string;
      guardian_name?: string | null;
      guardian_phone?: string | null;
    },
  ): Promise<void> {
    await api.put(`/students/${studentId}`, payload);
  },

  /** Create a brand-new student record in the tenant. Only `name` is
   *  required by the backend (CreateStudentRequest); everything else
   *  is optional. Returns the new student's id so the caller can
   *  immediately enroll them into a program. */
  async createStudent(payload: {
    name: string;
    guardian_name?: string | null;
    guardian_phone?: string | null;
    guardian_email?: string | null;
  }): Promise<string> {
    const res = await api.post<{ data?: { id?: string } }>(
      '/students',
      payload,
    );
    const id = res.data?.data?.id;
    return id ? String(id) : '';
  },

  // ── Admin: enrollment ───────────────────────────────────────────

  /** Tenant students for the enroll picker.
   *
   *  Previously this hit /students (school endpoint) which kept coming
   *  back empty in this tenant because of subtle response-envelope
   *  differences between paginated and non-paginated branches.
   *  Switch to the same /tutoring/students endpoint that the Student
   *  list page uses (getAdminStudents) — that one is confirmed
   *  working. It returns currently-enrolled students; freshly-created
   *  students without enrollments yet won't appear here, but the
   *  Student list also covers them once they're enrolled.
   *
   *  Dedup by student_id since one student with two enrollments comes
   *  back as two rows. */
  async getTenantStudents(): Promise<{ id: string; name: string }[]> {
    const rows = await TutoringService.getAdminStudents();
    const seen = new Set<string>();
    const out: { id: string; name: string }[] = [];
    for (const r of rows) {
      const id = String(r.student_id);
      if (!id || seen.has(id)) continue;
      seen.add(id);
      out.push({ id, name: String(r.student_name ?? '—') });
    }
    return out;
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

  // ── Session reminder offsets (admin-configurable list) ────────
  async getSessionReminderOffsets(): Promise<{
    offsets_minutes: number[];
    is_default: boolean;
    max_offset_minutes: number;
  }> {
    const res = await api.get<ApiResponse<{
      offsets_minutes: number[];
      is_default: boolean;
      max_offset_minutes: number;
    }>>('/tutoring/settings/session-reminders');
    return extractData(res);
  },

  async updateSessionReminderOffsets(
    offsetsMinutes: number[],
  ): Promise<{
    offsets_minutes: number[];
    is_default: boolean;
    max_offset_minutes: number;
  }> {
    const res = await api.put<ApiResponse<{
      offsets_minutes: number[];
      is_default: boolean;
      max_offset_minutes: number;
    }>>('/tutoring/settings/session-reminders', {
      offsets_minutes: offsetsMinutes,
    });
    return extractData(res);
  },

  // ── Bill reminder offsets (days before due_date) ──────────────
  async getBillReminderOffsets(): Promise<{
    offsets_days: number[];
    is_default: boolean;
    max_offset_days: number;
  }> {
    const res = await api.get<ApiResponse<{
      offsets_days: number[];
      is_default: boolean;
      max_offset_days: number;
    }>>('/tutoring/settings/bill-reminders');
    return extractData(res);
  },

  async updateBillReminderOffsets(
    offsetsDays: number[],
  ): Promise<{
    offsets_days: number[];
    is_default: boolean;
    max_offset_days: number;
  }> {
    const res = await api.put<ApiResponse<{
      offsets_days: number[];
      is_default: boolean;
      max_offset_days: number;
    }>>('/tutoring/settings/bill-reminders', {
      offsets_days: offsetsDays,
    });
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
    // Matches backend ActivityType enum (ASSIGNMENT / EXAM / MATERIAL).
    // The earlier union (HOMEWORK / QUIZ / PROJECT) never matched any
    // rows because those values don't exist in the database.
    type?: 'ASSIGNMENT' | 'EXAM' | 'MATERIAL';
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
    type: 'ASSIGNMENT' | 'EXAM' | 'MATERIAL';
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
      bank_name?: string | null;
      bank_account_number?: string | null;
      bank_account_holder?: string | null;
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

  // ── Honor-withdrawal requests (self-service) ────────────────────
  // Backend endpoints:
  //   POST   /tutoring/payouts/requests             tutor (own)
  //   GET    /tutoring/payouts/requests             tutor own / admin all
  //   GET    /tutoring/payouts/requests/{id}        scoped detail
  //   PATCH  /tutoring/payouts/requests/{id}/approve         admin
  //   PATCH  /tutoring/payouts/requests/{id}/reject          admin
  //   PATCH  /tutoring/payouts/requests/{id}/mark-paid       admin (FormData)
  //   PATCH  /tutoring/payouts/requests/{id}/rollback        admin
  //   GET/PUT /tutoring/payouts/settings                      admin

  /** Tutor: file a new withdrawal request for a period. Backend
   *  computes the eligible amount internally; the tutor's
   *  `amount_requested` may be less than that (when
   *  allow_partial_withdrawal is on) but never more. */
  async createPayoutRequest(payload: {
    period_from: string; // YYYY-MM-DD
    period_to: string;
    amount_requested: number;
    bank_name?: string | null;
    bank_account_number?: string | null;
    bank_account_holder?: string | null;
    notes?: string | null;
  }): Promise<TutorPayoutRequest> {
    const res = await api.post<ApiResponse<TutorPayoutRequest>>(
      '/tutoring/payouts/requests',
      payload,
    );
    return extractData(res);
  },

  /**
   * Tutor list: backend scopes to the caller automatically when
   * `isAdmin === false`. The same endpoint serves both — but admins
   * see all rows; non-admins see only their own. This wrapper is the
   * "tutor-shaped" caller (no user_id filter).
   */
  async listMyPayoutRequests(opts: {
    status?: TutorPayoutRequestStatus;
    period_from?: string;
    period_to?: string;
    page?: number;
    per_page?: number;
  } = {}): Promise<{
    items: TutorPayoutRequest[];
    pagination: { page: number; per_page: number; total: number; last_page: number };
  }> {
    const res = await api.get<ApiResponse<{
      items: TutorPayoutRequest[];
      pagination: { page: number; per_page: number; total: number; last_page: number };
    }>>('/tutoring/payouts/requests', {
      params: {
        ...(opts.status ? { status: opts.status } : {}),
        ...(opts.period_from ? { period_from: opts.period_from } : {}),
        ...(opts.period_to ? { period_to: opts.period_to } : {}),
        ...(opts.page ? { page: opts.page } : {}),
        ...(opts.per_page ? { per_page: opts.per_page } : {}),
      },
    });
    return (
      extractData(res) ?? {
        items: [],
        pagination: { page: 1, per_page: 20, total: 0, last_page: 1 },
      }
    );
  },

  /** Admin variant — same endpoint, but exposes the extra `user_id`
   *  filter so the queue page can scope to one tutor. */
  async listAllPayoutRequests(opts: {
    status?: TutorPayoutRequestStatus;
    period_from?: string;
    period_to?: string;
    user_id?: string;
    page?: number;
    per_page?: number;
  } = {}): Promise<{
    items: TutorPayoutRequest[];
    pagination: { page: number; per_page: number; total: number; last_page: number };
  }> {
    const res = await api.get<ApiResponse<{
      items: TutorPayoutRequest[];
      pagination: { page: number; per_page: number; total: number; last_page: number };
    }>>('/tutoring/payouts/requests', {
      params: {
        ...(opts.status ? { status: opts.status } : {}),
        ...(opts.period_from ? { period_from: opts.period_from } : {}),
        ...(opts.period_to ? { period_to: opts.period_to } : {}),
        ...(opts.user_id ? { user_id: opts.user_id } : {}),
        ...(opts.page ? { page: opts.page } : {}),
        ...(opts.per_page ? { per_page: opts.per_page } : {}),
      },
    });
    return (
      extractData(res) ?? {
        items: [],
        pagination: { page: 1, per_page: 20, total: 0, last_page: 1 },
      }
    );
  },

  async getPayoutRequest(id: string): Promise<TutorPayoutRequest> {
    const res = await api.get<ApiResponse<TutorPayoutRequest>>(
      `/tutoring/payouts/requests/${id}`,
    );
    return extractData(res);
  },

  async approvePayoutRequest(id: string): Promise<TutorPayoutRequest> {
    const res = await api.patch<ApiResponse<TutorPayoutRequest>>(
      `/tutoring/payouts/requests/${id}/approve`,
    );
    return extractData(res);
  },

  async rejectPayoutRequest(
    id: string,
    payload: { reject_reason: string },
  ): Promise<TutorPayoutRequest> {
    const res = await api.patch<ApiResponse<TutorPayoutRequest>>(
      `/tutoring/payouts/requests/${id}/reject`,
      payload,
    );
    return extractData(res);
  },

  /**
   * Multipart mark-paid — proof_file (max 2MB) is optional. Sent as
   * FormData because of the file slot; the other fields ride along.
   *
   * Laravel doesn't natively accept files on PATCH (PHP's input parser
   * strips files when method !== POST), so we POST and rely on the
   * `_method` field to upgrade the route to PATCH server-side. Mirrors
   * the same trick used by `markBillPaid`-style endpoints elsewhere.
   */
  async markPayoutRequestPaid(
    id: string,
    payload: {
      paid_at?: string | null;
      payment_notes?: string | null;
      proof_file?: File | Blob | null;
    } = {},
  ): Promise<TutorPayoutRequest> {
    const form = new FormData();
    form.append('_method', 'PATCH');
    if (payload.paid_at) form.append('paid_at', payload.paid_at);
    if (payload.payment_notes) form.append('payment_notes', payload.payment_notes);
    if (payload.proof_file) form.append('proof_file', payload.proof_file);
    const res = await api.post<ApiResponse<TutorPayoutRequest>>(
      `/tutoring/payouts/requests/${id}/mark-paid`,
      form,
      { headers: { 'Content-Type': 'multipart/form-data' } },
    );
    return extractData(res);
  },

  /** Admin: roll one step back (APPROVED→PENDING / PAID→APPROVED). */
  async rollbackPayoutRequest(id: string): Promise<TutorPayoutRequest> {
    const res = await api.patch<ApiResponse<TutorPayoutRequest>>(
      `/tutoring/payouts/requests/${id}/rollback`,
    );
    return extractData(res);
  },

  async getPayoutSettings(): Promise<TutorPayoutSettings> {
    const res = await api.get<ApiResponse<TutorPayoutSettings>>(
      '/tutoring/payouts/settings',
    );
    return (
      extractData(res) ?? {
        allow_partial_withdrawal: false,
        min_withdrawal_amount: 0,
        auto_approve_full_amount: false,
        is_default: true,
      }
    );
  },

  async updatePayoutSettings(payload: {
    allow_partial_withdrawal?: boolean;
    min_withdrawal_amount?: number;
    auto_approve_full_amount?: boolean;
  }): Promise<TutorPayoutSettings> {
    const res = await api.put<ApiResponse<TutorPayoutSettings>>(
      '/tutoring/payouts/settings',
      payload,
    );
    return extractData(res);
  },

  // ── Leads (calon student) ─────────────────────────────────────────

  async getLeads(opts: { status?: 'TRIAL' | 'CONVERTED' | 'DROPPED' } = {}):
    Promise<TutoringLead[]> {
    const res = await api.get<ApiResponse<TutoringLead[]>>('/tutoring/leads', {
      params: opts.status ? { status: opts.status } : {},
    });
    return extractData(res) ?? [];
  },

  async createLead(payload: {
    name: string;
    email?: string;
    phone?: string;
    program_id?: string;
    source?: string;
    notes?: string;
  }): Promise<{ id: string }> {
    const res = await api.post<ApiResponse<{ id: string }>>(
      '/tutoring/leads',
      payload,
    );
    return extractData(res);
  },

  async convertLead(id: string, enrollmentId: string): Promise<void> {
    await api.post(`/tutoring/leads/${id}/convert`, {
      enrollment_id: enrollmentId,
    });
  },

  async dropLead(id: string, notes?: string): Promise<void> {
    await api.post(`/tutoring/leads/${id}/drop`, { notes });
  },

  async deleteLead(id: string): Promise<void> {
    await api.delete(`/tutoring/leads/${id}`);
  },

  // ── Vouchers (promo codes) ──────────────────────────────────────

  async getVouchers(): Promise<TutoringVoucher[]> {
    const res = await api.get<ApiResponse<TutoringVoucher[]>>(
      '/tutoring/vouchers',
    );
    return extractData(res) ?? [];
  },

  async createVoucher(payload: {
    code: string;
    type: 'PERCENTAGE' | 'AMOUNT';
    value: number;
    max_uses?: number | null;
    valid_from?: string | null;
    valid_until?: string | null;
    is_active?: boolean;
    notes?: string;
  }): Promise<{ id: string }> {
    const res = await api.post<ApiResponse<{ id: string }>>(
      '/tutoring/vouchers',
      payload,
    );
    return extractData(res);
  },

  async updateVoucher(
    id: string,
    payload: Partial<{
      value: number;
      max_uses: number | null;
      valid_from: string | null;
      valid_until: string | null;
      is_active: boolean;
      notes: string;
    }>,
  ): Promise<void> {
    await api.put(`/tutoring/vouchers/${id}`, payload);
  },

  async deleteVoucher(id: string): Promise<void> {
    await api.delete(`/tutoring/vouchers/${id}`);
  },

  /** Preview discount on [amount] without recording a redemption. */
  async validateVoucher(
    code: string,
    amount: number,
  ): Promise<TutoringVoucherPreview> {
    const res = await api.post<ApiResponse<TutoringVoucherPreview>>(
      '/tutoring/vouchers/validate',
      { code, amount },
    );
    return extractData(res);
  },

  /** Record a redemption; called during enroll submit. */
  async redeemVoucher(payload: {
    code: string;
    amount: number;
    enrollment_id?: string;
  }): Promise<{ voucher_id: string; discount_amount: number; final_amount: number }> {
    const res = await api.post<
      ApiResponse<{ voucher_id: string; discount_amount: number; final_amount: number }>
    >('/tutoring/vouchers/redeem', payload);
    return extractData(res);
  },

  // ── Session feedback (parent rate) ──────────────────────────────

  async getSessionFeedback(sessionId: string): Promise<TutoringSessionFeedback[]> {
    const res = await api.get<ApiResponse<TutoringSessionFeedback[]>>(
      `/tutoring/sessions/${sessionId}/feedback`,
    );
    return extractData(res) ?? [];
  },

  async getSessionFeedbackSummary(
    sessionId: string,
  ): Promise<TutoringSessionFeedbackSummary> {
    const res = await api.get<ApiResponse<TutoringSessionFeedbackSummary>>(
      `/tutoring/sessions/${sessionId}/feedback/summary`,
    );
    return extractData(res);
  },

  async upsertSessionFeedback(
    sessionId: string,
    payload: { student_id: string; rating: number; comment?: string },
  ): Promise<void> {
    await api.put(`/tutoring/sessions/${sessionId}/feedback`, payload);
  },

  // ── Group announcements (tutor → group) ──────────────────────

  async getGroupAnnouncements(opts: {
    group_id?: string;
    student_id?: string;
  } = {}): Promise<TutoringGroupAnnouncement[]> {
    const res = await api.get<ApiResponse<TutoringGroupAnnouncement[]>>(
      '/tutoring/class-announcements',
      {
        params: {
          ...(opts.group_id ? { group_id: opts.group_id } : {}),
          ...(opts.student_id ? { student_id: opts.student_id } : {}),
        },
      },
    );
    return extractData(res) ?? [];
  },

  async createGroupAnnouncement(payload: {
    tutoring_group_id: string;
    title: string;
    body: string;
  }): Promise<{ id: string }> {
    const res = await api.post<ApiResponse<{ id: string }>>(
      '/tutoring/class-announcements',
      payload,
    );
    return extractData(res);
  },

  async deleteGroupAnnouncement(id: string): Promise<void> {
    await api.delete(`/tutoring/class-announcements/${id}`);
  },

  // ── Leaderboard ─────────────────────────────────────────────────

  async getGroupLeaderboard(
    groupId: string,
    opts: { limit?: number } = {},
  ): Promise<TutoringLeaderboardRow[]> {
    const res = await api.get<ApiResponse<TutoringLeaderboardRow[]>>(
      `/tutoring/classes/${groupId}/leaderboard`,
      { params: opts.limit ? { limit: opts.limit } : {} },
    );
    return extractData(res) ?? [];
  },

  async getLeaderboardByGroup(): Promise<TutoringLeaderboardGroupRow[]> {
    const res = await api.get<ApiResponse<TutoringLeaderboardGroupRow[]>>(
      '/tutoring/leaderboard/by-group',
    );
    return extractData(res) ?? [];
  },

  // ── Activity feeds (dashboard "What's New" widget) ──────────────

  /** Parent feed: notes / scores / announcements / bills / attendance. */
  async getStudentFeed(
    studentId: string,
    opts: { limit?: number; sinceDays?: number } = {},
  ): Promise<TutoringFeedEvent[]> {
    const res = await api.get<ApiResponse<TutoringFeedEvent[]>>(
      `/tutoring/students/${studentId}/feed`,
      {
        params: {
          ...(opts.limit ? { limit: opts.limit } : {}),
          ...(opts.sinceDays ? { since_days: opts.sinceDays } : {}),
        },
      },
    );
    return extractData(res) ?? [];
  },

  /** Admin feed: enrollments / leads / sessions / paid bills. */
  async getAdminActivity(
    opts: { limit?: number; sinceDays?: number } = {},
  ): Promise<TutoringFeedEvent[]> {
    const res = await api.get<ApiResponse<TutoringFeedEvent[]>>(
      '/tutoring/admin-activity',
      {
        params: {
          ...(opts.limit ? { limit: opts.limit } : {}),
          ...(opts.sinceDays ? { since_days: opts.sinceDays } : {}),
        },
      },
    );
    return extractData(res) ?? [];
  },

  /** Admin: activity/tasks report — per-group counts + KPIs. */
  async getAdminActivityReport(
    opts: { type?: string } = {},
  ): Promise<import('@/types/tutoring').AdminActivityReport> {
    const res = await api.get<ApiResponse<import('@/types/tutoring').AdminActivityReport>>(
      '/tutoring/admin/reports/activity',
      { params: { ...(opts.type ? { type: opts.type } : {}) } },
    );
    return extractData(res);
  },

  /** Admin: attendance report — 4-pill + per-group + low-attendance watch. */
  async getAdminAttendanceReport(
    opts: { from?: string; to?: string } = {},
  ): Promise<import('@/types/tutoring').AdminAttendanceReport> {
    const res = await api.get<ApiResponse<import('@/types/tutoring').AdminAttendanceReport>>(
      '/tutoring/admin/reports/attendance',
      { params: opts },
    );
    return extractData(res);
  },

  /** Tutor's own rating summary — overall avg + per-group + recent
   *  comments. Backed by GetTutorRatingsSummaryAction. */
  async getTutorRatingsSummary(
    opts: { group_id?: string; stars?: number[]; has_comment?: boolean } = {},
  ): Promise<import('@/types/tutoring').TutorRatingsSummary> {
    const res = await api.get<ApiResponse<import('@/types/tutoring').TutorRatingsSummary>>(
      '/tutoring/tutor/ratings/summary',
      {
        params: {
          ...(opts.group_id ? { group_id: opts.group_id } : {}),
          ...(opts.stars ? { stars: opts.stars.join(',') } : {}),
          ...(opts.has_comment != null ? { has_comment: opts.has_comment ? 1 : 0 } : {}),
        },
      },
    );
    return extractData(res);
  },

  /** Tutor feed: submissions / ratings / enrollments / announcements / sessions done. */
  async getTutorActivity(
    opts: { limit?: number; sinceDays?: number } = {},
  ): Promise<TutoringFeedEvent[]> {
    const res = await api.get<ApiResponse<TutoringFeedEvent[]>>(
      '/tutoring/tutor-activity',
      {
        params: {
          ...(opts.limit ? { limit: opts.limit } : {}),
          ...(opts.sinceDays ? { since_days: opts.sinceDays } : {}),
        },
      },
    );
    return extractData(res) ?? [];
  },

  /** Partial update on a session — catatan session, topic, status. Used
   *  by the attendance flow to attach a tutor note after class. */
  async updateSession(
    sessionId: string,
    payload: { notes?: string; topic?: string; status?: string },
  ): Promise<void> {
    await api.put(`/tutoring/sessions/${sessionId}`, payload);
  },
};
