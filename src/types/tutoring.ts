/**
 * Tutoring (bimbel) types — mirror the backend JsonResource shapes
 * (app/Modules/Tutoring/Http/Resources) and the Flutter
 * `tutoring_models.dart` / `tutoring_management_models.dart`.
 *
 * Snake_case fields match the wire format; the services map them into
 * these interfaces with light coercion where needed.
 */

// ── Parent-facing (read) ──────────────────────────────────────────

/** Session feedback row (per session × student). */
export interface TutoringSessionFeedback {
  id: string;
  student_id: string;
  rating: number; // 1..5
  comment?: string | null;
  updated_at?: string | null;
}

/** Aggregate from /sessions/{id}/feedback/summary. */
export interface TutoringSessionFeedbackSummary {
  count: number;
  avg: number | null;
}

/** Group announcement (tutor → kelompok broadcast). */
export interface TutoringGroupAnnouncement {
  id: string;
  tutoring_group_id: string;
  group_name?: string | null;
  created_by: string;
  author_name?: string | null;
  title: string;
  body: string;
  created_at?: string | null;
}

/** One row from /groups/{id}/leaderboard. */
export interface TutoringLeaderboardRow {
  rank: number;
  student_id: string;
  name: string;
  attendance_rate: number | null;
  avg_score: number | null;
  composite: number;
}

/** One row from /leaderboard/by-group — per-group avg composite, used
 *  by the admin leaderboard antar-kelompok strip. */
export interface TutoringLeaderboardGroupRow {
  group_id: string;
  group_name: string;
  program_name: string | null;
  student_count: number;
  avg_composite: number;
}

/** Calon siswa (lead). Status drives the funnel column on the admin
 *  list. converted_enrollment_id is set when the lead is converted. */
export interface TutoringLead {
  id: string;
  name: string;
  email?: string | null;
  phone?: string | null;
  program_id?: string | null;
  program_name?: string | null;
  source?: string | null;
  status: 'TRIAL' | 'CONVERTED' | 'DROPPED';
  notes?: string | null;
  converted_enrollment_id?: string | null;
  converted_at?: string | null;
  dropped_at?: string | null;
  created_at?: string | null;
}

/** Voucher / promo code. */
export interface TutoringVoucher {
  id: string;
  code: string;
  type: 'PERCENTAGE' | 'AMOUNT';
  value: number;
  max_uses?: number | null;
  used_count: number;
  valid_from?: string | null;
  valid_until?: string | null;
  is_active: boolean;
  notes?: string | null;
  created_at?: string | null;
}

/** Validate-voucher response — preview without recording a redemption. */
export interface TutoringVoucherPreview {
  voucher_id: string;
  code: string;
  type: 'PERCENTAGE' | 'AMOUNT';
  value: number;
  original_amount: number;
  discount_amount: number;
  final_amount: number;
}

/** Material (PDF / link / catatan) shipped to a group OR program. */
export interface TutoringMaterial {
  id: string;
  tutoring_group_id?: string | null;
  tutoring_program_id?: string | null;
  group?: { id: string; name?: string } | null;
  program?: { id: string; name?: string } | null;
  subject?: { id: string; name?: string } | null;
  title: string;
  description?: string | null;
  file_url?: string | null;
  published_at?: string | null;
  created_at?: string | null;
}

export interface TutoringSession {
  id: string;
  group_id: string;
  scheduled_at: string | null;
  duration_minutes: number;
  room: string | null;
  meeting_url?: string | null;
  status: 'SCHEDULED' | 'DONE' | 'CANCELLED';
  status_label?: string | null;
  topic?: string | null;
  group?: { name?: string; program?: { name?: string } } | null;
  tutor?: { name?: string } | null;
}

export interface TutoringAttendanceSummary {
  total_recorded: number;
  attended: number;
  attendance_rate: number | null;
  breakdown: Record<string, number>;
}

export interface TutoringBill {
  id: string;
  amount: number | null;
  status: string;
  due_date: string | null;
  month?: string | null;
  source_type?: string | null;
  source_label?: string | null;
  student_name?: string | null;
}

/** Headline KPIs for the admin bimbel dashboard. */
export interface TutoringAdminStats {
  active_programs: number;
  groups: number;
  students: number;
  active_enrollments: number;
  upcoming_sessions: number;
  sessions_this_week: number;
  sessions_today: number;
  unpaid_bills: number;
  unpaid_total: number;
  bills_due_today: number;
  month_revenue: number;
  new_enrollments_today: number;
  hot_leads: number;
  attendance_rate: number | null;
  program_id?: string | null;
}

/** Compact next-session payload embedded in tutor stats — drives the
 *  pinned "Next Session" card on the tutor home dashboard. */
export interface TutoringNextSession {
  id: string;
  scheduled_at: string | null;
  duration_minutes: number;
  group_id?: string | null;
  group_name?: string | null;
  program_name?: string | null;
  room?: string | null;
  meeting_url?: string | null;
  topic?: string | null;
}

/** KPI strip for the tutor's own "Sesi Saya" dashboard.
 *  Mirrors GetTutoringTutorStatsAction. `attendance_rate` is null when
 *  the tutor hasn't recorded any attendance in the last 30 days. */
export interface TutoringTutorStats {
  sessions_this_week: number;
  sessions_today: number;
  hours_this_week: number;
  minutes_this_week: number;
  upcoming_sessions: number;
  groups: number;
  students: number;
  attendance_rate: number | null;
  pending_submissions: number;
  month_earnings: number;
  month_sessions_done: number;
  next_session: TutoringNextSession | null;
  rating_avg: number | null;
  rating_count: number;
}

/** One row in the admin or wali activity feed.
 *  wali  → note | score | announcement | bill | attendance
 *  admin → enrollment_new | lead_new | lead_converted | session_done | bill_paid
 */
export interface TutoringFeedEvent {
  type: string;
  occurred_at: string | null;
  title: string;
  subtitle?: string | null;
  meta?: Record<string, unknown>;
}

export interface TutoringProgressEntry {
  assessment_id: string;
  title: string;
  type?: string | null;
  type_label?: string | null;
  subject?: string | null;
  held_at?: string | null;
  score?: number | null;
  max_score?: number | null;
  percentage?: number | null;
}

export interface TutoringProgress {
  timeline: TutoringProgressEntry[];
  trend: Record<string, number[]>;
  summary: {
    overall: {
      count: number;
      latest: number | null;
      best: number | null;
      average: number | null;
    };
  };
}

/** Combined snapshot for the parent overview page. */
export interface TutoringChildOverview {
  upcomingSessions: TutoringSession[];
  attendance: TutoringAttendanceSummary;
  bills: TutoringBill[];
  progress: TutoringProgress;
}

// ── Admin / tutor (manage) ────────────────────────────────────────

export interface TutoringProgram {
  id: string;
  name: string;
  description?: string | null;
  target_education_level?: string | null;
  is_active: boolean;
  packages_count?: number;
  groups_count?: number;
}

export interface TutoringPackage {
  id: string;
  program_id: string;
  name: string;
  total_sessions?: number | null;
  price?: number | null;
  billing_modes_allowed: string[];
  is_active: boolean;
}

export interface TutoringGroup {
  id: string;
  program_id: string;
  name: string;
  tutor_user_id?: string | null;
  tutor?: { name?: string } | null;
  capacity: number;
  status: string;
  enrollments_count?: number;
}

export interface TenantBillingSettings {
  allow_prepaid: boolean;
  allow_monthly: boolean;
  allow_per_session: boolean;
  default_mode?: string | null;
  // Payment account — where wali transfers TO. All nullable so
  // admin can configure incrementally (bank now, QRIS later).
  bank_name?: string | null;
  bank_account_number?: string | null;
  bank_account_holder?: string | null;
  qris_image_url?: string | null;
  payment_instructions?: string | null;
  payment_gateway_enabled?: boolean;
  payment_gateway_provider?: string | null;
  /** True when credentials are stored; admin sees a status indicator. */
  payment_gateway_configured?: boolean;
}

/** Payment-account slice — same shape on bill detail + standalone GET. */
export interface TutoringPaymentAccount {
  bank_name?: string | null;
  bank_account_number?: string | null;
  bank_account_holder?: string | null;
  qris_image_url?: string | null;
  payment_instructions?: string | null;
  payment_gateway_enabled?: boolean;
  payment_gateway_provider?: string | null;
}

/** One row in the bill's payment history. */
export interface TutoringBillPayment {
  id: string;
  amount: number;
  payment_method?: string | null;
  payment_date?: string | null;
  status?: string | null;
  admin_notes?: string | null;
  verified_at?: string | null;
  proof_url?: string | null;
  proof_proxy_url?: string | null;
  created_at?: string | null;
}

/** Response shape of GET /tutoring/bills/{id}. */
export interface TutoringBillDetail {
  bill: TutoringBill;
  student: { id: string; name: string } | null;
  payments: TutoringBillPayment[];
  paid_total: number;
  outstanding: number;
  payment_account: TutoringPaymentAccount | null;
}

export interface TutoringEnrollee {
  /** enrollment id */
  id: string;
  student_id: string;
  student?: { name?: string } | null;
}

export interface TutoringSessionAttendanceRow {
  student_id: string;
  status: string;
  status_label?: string | null;
  student?: { name?: string } | null;
}

export type AttendanceStatusKey =
  | 'PRESENT'
  | 'LATE'
  | 'SICK'
  | 'EXCUSED'
  | 'ALPHA';

export const ATTENDANCE_STATUS_LABELS: Record<AttendanceStatusKey, string> = {
  PRESENT: 'Hadir',
  LATE: 'Terlambat',
  SICK: 'Sakit',
  EXCUSED: 'Izin',
  ALPHA: 'Alpa',
};

export const BILLING_MODE_LABELS: Record<string, string> = {
  PREPAID: 'Paket Prabayar',
  MONTHLY: 'SPP Bulanan',
  PER_SESSION: 'Per Sesi',
};

// ── AI-generated questions (try-out / exercise) ──────────────────

export interface TutoringAiOption {
  label: string;
  text: string;
  is_correct: boolean;
}

export interface TutoringAiQuestion {
  number?: number;
  question: string;
  type?: string;
  options?: TutoringAiOption[];
  correct_answer?: string;
  explanation?: string;
  difficulty?: string;
  topic?: string;
}

/** Assessment header + persisted AI question set. */
export interface TutoringAssessment {
  id: string;
  title: string;
  type?: string;
  type_label?: string;
  held_at?: string | null;
  questions_count?: number;
  scores_count?: number;
  questions?: TutoringAiQuestion[] | null;
}

/** Admin: row from GET /tutoring/students. */
export interface TutoringStudentRow {
  student_id: string;
  student_name: string;
  enrollment_id: string;
  program_id?: string | null;
  program_name?: string | null;
  package_name?: string | null;
  group_name?: string | null;
  billing_mode: string;
  attendance_recorded: number;
  attendance_present: number;
  attendance_rate: number | null;
  unpaid_count: number;
  unpaid_total: number;
}

/** Admin: row from GET /tutoring/tutors. */
export interface TutoringTutorRow {
  user_id: string;
  name: string;
  email: string;
  /** 'ACTIVE' (has groups) | 'PENDING' (no groups yet). */
  status: 'ACTIVE' | 'PENDING';
  group_count: number;
  groups: { id: string; name: string; program?: string | null }[];
  sessions_30d: number;
  attendance_rate: number | null;
  joined_at?: string | null;
}

/** Result of POST /tutoring/tutors/invite. */
export interface TutoringInviteResult {
  user_id: string;
  name: string;
  email: string;
  /** 'created' (new account) | 'attached' | 'already_tutor'. */
  status: 'created' | 'attached' | 'already_tutor';
  /** Only set when status === 'created'. */
  temp_password?: string | null;
}

/** One activity (homework / exam / quiz / project) shipped to a
 *  bimbel group. Mirrors TutoringActivityResource. */
export interface TutoringActivity {
  id: string;
  tutoring_group_id: string;
  group?: { id: string; name?: string; program?: { id: string; name?: string } | null } | null;
  subject?: { id: string; name?: string } | null;
  type: 'HOMEWORK' | 'EXAM' | 'QUIZ' | 'PROJECT' | string;
  type_label?: string | null;
  title: string;
  description?: string | null;
  due_at?: string | null;
  submissions_count?: number | null;
  created_at?: string | null;
}

/** One tutor's honorarium rate. */
export interface TutorPayoutRate {
  id?: string;
  user_id: string;
  name?: string | null;
  email?: string | null;
  basis: 'PER_SESSION' | 'PER_HOUR';
  amount: number;
  currency?: string;
  note?: string | null;
  bank_name?: string | null;
  bank_account_number?: string | null;
  bank_account_holder?: string | null;
  updated_at?: string | null;
}

/** Computed monthly payout summary for one tutor. */
export interface TutorPayoutSummary {
  user_id: string;
  period: { from: string; to: string; label: string };
  rate: {
    basis: 'PER_SESSION' | 'PER_HOUR';
    amount: number;
    currency: string;
    note?: string | null;
    configured: boolean;
  };
  sessions_count: number;
  minutes: number;
  hours: number;
  earnings: number;
}

export interface TutoringActivitySubmission {
  id: string;
  activity_id?: string;
  tutoring_activity_id?: string;
  student_id: string;
  student?: { id: string; name?: string } | null;
  student_name?: string | null;
  status: 'ASSIGNED' | 'SUBMITTED' | 'LATE' | 'GRADED' | 'MISSED' | string;
  status_label?: string | null;
  score?: number | null;
  max_score?: number | null;
  note?: string | null;
  submitted_at?: string | null;
}

/** Rich per-class meta for the wali Kelas list page.
 *  Mirrors GetWaliClassMetaAction (one row per kelompok the student
 *  is enrolled in). */
export interface TutoringWaliClassMeta {
  group_id: string;
  group_name: string;
  program_id?: string | null;
  program_name?: string | null;
  tutor_user_id?: string | null;
  tutor_name?: string | null;
  status: string;
  next_session?: {
    id: string;
    scheduled_at: string | null;
    room?: string | null;
    topic?: string | null;
    duration_minutes: number;
  } | null;
  attendance: {
    rate: number | null;
    total_recorded: number;
    attended: number;
  };
  latest_score?: {
    title?: string;
    score?: number | null;
    max_score?: number | null;
    held_at?: string | null;
  } | null;
  new_announcements_count_7d: number;
}

/** Admin activity report — per-group activity creation + submission +
 *  graded counts. Backs AdminActivityReportView. */
export interface AdminActivityReport {
  kpi: {
    total_activities: number;
    submitted_pct: number | null;
    graded_pct: number | null;
    avg_score: number | null;
  };
  rows: Array<{
    group_id: string;
    group_name: string;
    program_name?: string | null;
    tutor_name?: string | null;
    type: string;
    created: number;
    submitted: number;
    avg_score: number | null;
    status: string;
  }>;
}

/** Admin attendance report — 4-pill breakdown + per-group rates +
 *  watch-list of low-attendance students. */
export interface AdminAttendanceReport {
  pills: { hadir: number; izin: number; sakit: number; alpha: number };
  rows: Array<{
    group_id: string;
    group_name: string;
    students: number;
    sessions: number;
    hadir_pct: number | null;
    tutor_name?: string | null;
  }>;
  watch: Array<{
    student_id: string;
    student_name: string;
    group_name: string;
    sessions_done: number;
    hadir: number;
    hadir_pct: number | null;
  }>;
}

/** Tutor's own rating summary — drives the Rating page.
 *  Mirrors GetTutorRatingsSummaryAction. */
export interface TutorRatingsSummary {
  overall: {
    avg: number | null;
    count: number;
    delta: number | null;
    window_label: string;
  };
  week: { avg: number | null; count: number };
  response: { rate: number | null; rated_sessions: number; done_sessions: number };
  distribution: Record<string, number>;
  groups: Array<{
    group_id: string;
    group_name: string;
    avg: number | null;
    count: number;
  }>;
  recent: Array<{
    id: string;
    student_name?: string | null;
    group_name?: string | null;
    rating: number;
    comment?: string | null;
    scheduled_at?: string | null;
    created_at?: string | null;
  }>;
  filters: {
    group_id: string | null;
    stars: number[] | null;
    has_comment: boolean | null;
  };
}
