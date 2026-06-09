/**
 * Tutoring (bimbel) types — mirror the backend JsonResource shapes
 * (app/Modules/Tutoring/Http/Resources) and the Flutter
 * `tutoring_models.dart` / `tutoring_management_models.dart`.
 *
 * Snake_case fields match the wire format; the services map them into
 * these interfaces with light coercion where needed.
 */

// ── Parent-facing (read) ──────────────────────────────────────────

export interface TutoringSession {
  id: string;
  group_id: string;
  scheduled_at: string | null;
  duration_minutes: number;
  room: string | null;
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
  unpaid_bills: number;
  unpaid_total: number;
  attendance_rate: number | null;
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
