/**
 * Rapor (report card) types — Flutter parity end-to-end.
 *
 * Mirrors `Raport` model + `RaportController` response shapes:
 *  - Teacher form (`ReportCardDetailScreen`) — `subjects` /
 *    `extras` / `achievements` / sikap / kehadiran / catatan
 *  - Parent detail — full hydrated with `raportSubjects` /
 *    `extracurriculars` / `achievements` / rank / attendance_pct
 *  - Admin pipeline — 4-node Draft → Diperiksa → Terbit → Dibagikan
 *    + tingkat tree with per-class status badges
 *
 * Status vocab:
 *  - `draft`       — teacher is still editing
 *  - `final`       — teacher has finalised (= "Diperiksa" / siap
 *                    di-publish admin)
 *  - `published`   — admin has published; parent can download PDF
 *  - `distributed` — published + delivered notification to parent
 *
 * Vue used to truncate to `draft|final` only — `published` and
 * `distributed` were mis-labelled across the chrome. Always reach
 * for `STATUS_LABELS` / `STATUS_TONES` instead of literal strings.
 */

// ── Status enum + display ───────────────────────────────────────────

export type ReportCardStatus = 'draft' | 'final' | 'published' | 'distributed';

export const STATUS_LABELS: Record<ReportCardStatus, string> = {
  draft: 'Draf',
  final: 'Diperiksa',
  published: 'Terbit',
  distributed: 'Dibagikan',
};

export const STATUS_TONES: Record<
  ReportCardStatus,
  { bg: string; text: string; border: string; dot: string }
> = {
  draft: {
    bg: 'bg-slate-50',
    text: 'text-slate-700',
    border: 'border-slate-200',
    dot: 'bg-slate-400',
  },
  final: {
    bg: 'bg-amber-50',
    text: 'text-amber-800',
    border: 'border-amber-200',
    dot: 'bg-amber-500',
  },
  published: {
    bg: 'bg-emerald-50',
    text: 'text-emerald-800',
    border: 'border-emerald-200',
    dot: 'bg-emerald-500',
  },
  distributed: {
    bg: 'bg-brand-cobalt/10',
    text: 'text-brand-cobalt',
    border: 'border-brand-cobalt/30',
    dot: 'bg-brand-cobalt',
  },
};

/** Backend normaliser — accept legacy casings + lowercased strings. */
export function normalizeReportCardStatus(raw: unknown): ReportCardStatus {
  const v = String(raw ?? '').toLowerCase().trim();
  if (v === 'final' || v === 'reviewed' || v === 'diperiksa') return 'final';
  if (v === 'published' || v === 'terbit') return 'published';
  if (v === 'distributed' || v === 'dibagikan') return 'distributed';
  return 'draft';
}

// ── Sikap / Kehadiran / Decision options ────────────────────────────

export type PredicateKey =
  | 'very_good'
  | 'good'
  | 'fair'
  | 'poor'
  | string;

export type PromotionDecision = 'promoted' | 'not_promoted' | 'graduated' | 'not_graduated' | string;

export const PREDICATE_OPTIONS: PredicateKey[] = [
  'very_good',
  'good',
  'fair',
  'poor',
];

export const DECISION_OPTIONS: PromotionDecision[] = [
  'promoted',
  'not_promoted',
];

/** Map old Indonesian predicate values to canonical English keys. */
export function normalizePredicate(raw: unknown): PredicateKey {
  const v = String(raw ?? '').toLowerCase().trim();
  if (v === 'sangat baik' || v === 'baik sekali' || v === 'very_good' || v === 'a') return 'very_good';
  if (v === 'baik' || v === 'good' || v === 'b') return 'good';
  if (v === 'cukup' || v === 'fair' || v === 'c') return 'fair';
  if (v === 'kurang' || v === 'poor' || v === 'd') return 'poor';
  return String(raw ?? 'good');
}

/** Map old Indonesian promotion decision values to canonical English keys. */
export function normalizePromotionDecision(raw: unknown): PromotionDecision {
  const v = String(raw ?? '').toLowerCase().trim();
  if (v === 'naik kelas' || v === 'promoted') return 'promoted';
  if (v === 'tinggal di kelas' || v === 'tidak naik' || v === 'not_promoted') return 'not_promoted';
  if (v === 'lulus' || v === 'graduated') return 'graduated';
  if (v === 'tidak lulus' || v === 'not_graduated') return 'not_graduated';
  return String(raw ?? 'promoted');
}

// ── Form / detail row types ─────────────────────────────────────────

export interface ReportCardSubject {
  subject_id: string;
  subject_name: string;
  teacher_name?: string | null;
  kkm?: number;
  /** Knowledge / pengetahuan score (0-100). */
  knowledge_score?: number | string | null;
  knowledge_predicate?: string;
  knowledge_description?: string;
  /** Optional skill (keterampilan) score, when provided by the backend. */
  skill_score?: number | string | null;
  skill_predicate?: string;
  skill_description?: string;
  /**
   * Backend `/report-card/initial-data` ships these recap fields per
   * subject (Flutter consumes them for the Grade tab preview). They
   * mirror the daily-test average + midterm + final-exam columns so
   * the teacher doesn't have to cross-check the grade book.
   */
  recap_uh_avg?: number | null;
  recap_uts?: number | null;
  recap_uas?: number | null;
  recap_final_score?: number | null;
  recap_chapter_scores?: number[];
  recap_chapter_names?: string[];
}

export interface ReportCardExtra {
  id?: string;
  /** Name of the ekstrakurikuler. */
  name: string;
  /** Numeric score or descriptive label ("A", "very_good"). */
  score?: string;
  description?: string;
}

export interface ReportCardAchievement {
  id?: string;
  name: string;
  /** "Academic" / "Non-academic" / "Tingkat sekolah" / etc. */
  type?: string;
  description?: string;
}

/** Summary block injected on `/report-card/show`. */
export interface ReportCardSummary {
  rerata?: number | null;
  kkm_threshold?: number | null;
  kkm_pass_count?: number | null;
  total_subjects?: number | null;
  class_rank?: number | null;
  class_total?: number | null;
}

// ── Backward-compat aliases (will be removed once all callers move) ─
export type RaportSubject = ReportCardSubject;
export type RaportExtra = ReportCardExtra;
export type RaportAchievement = ReportCardAchievement;
export type RaportSummary = ReportCardSummary;

export interface ReportCardDetail {
  id?: string;
  student_class_id: string;
  student_id?: string;
  student_name?: string;
  class_id?: string;
  class_name?: string;
  academic_year?: string | null;
  semester?: string | null;
  status: ReportCardStatus;
  published_at?: string | null;

  // ── Sikap (Tab 1) ──
  spiritual_description?: string;
  spiritual_predicate?: PredicateKey;
  social_description?: string;
  social_predicate?: PredicateKey;

  // ── Grade (Tab 2) ──
  subjects: ReportCardSubject[];

  // ── Tambahan (Tab 3) ──
  extras: ReportCardExtra[];
  achievements: ReportCardAchievement[];

  // ── Info (Tab 4) ──
  /**
   * Backend column names. Vue previously used `sick_days/permit_days/
   * absent_days` and silently dropped them on save (mismatch).
   * Always reach for the `attendance_*` shape — the save service maps
   * legacy callers as a back-compat helper.
   */
  attendance_sick?: number;
  attendance_permit?: number;
  attendance_absent?: number;
  /**
   * Legacy aliases kept for the un-rewritten teacher view (Phase 3
   * will drop these). Parser populates both shapes so the old
   * template can keep reading `sick_days` etc. while the new save
   * payload sends canonical `attendance_*`.
   */
  sick_days?: number;
  permit_days?: number;
  absent_days?: number;
  homeroom_notes?: string;
  promotion_decision?: PromotionDecision;

  /** Aggregate computed by the backend (rerata, rank, KKM pass count). */
  summary?: ReportCardSummary;

  // ── Derived / display ──
  avg_grade?: number | null;
  remed_count?: number;
}

export interface ReportCardInitialData {
  student_class_id: string;
  student_id?: string;
  student_name?: string;
  class_name?: string;
  academic_year?: string;
  semester?: string;
  subjects: ReportCardSubject[];
  attendance_sick?: number;
  attendance_permit?: number;
  attendance_absent?: number;
  summary?: ReportCardSummary;
}

export type RaportInitialData = ReportCardInitialData;

// ── Teacher hub summary ─────────────────────────────────────────────

/**
 * Per-class row returned by `/report-cards/teacher-summary`. Drives
 * the Frame A class-hub cards (4-cell stats + progress ring + drill).
 */
export interface ReportCardClassSummary {
  class_id: string;
  class_name: string;
  grade_level?: string | number | null;
  student_count: number;
  total_report_cards: number;
  draft_count: number;
  final_count: number;
  published_count: number;
  /** Optional — backend computes when all students are accounted for. */
  completion_pct?: number;
}

export type RaportClassSummary = ReportCardClassSummary;

/** Per-student row on the per-class roster (Frame B). */
export interface ReportCardSummaryRow {
  student_class_id: string;
  student_id?: string;
  student_name: string;
  student_number?: string | null;
  has_report_card?: boolean;
  report_card_id?: string | null;
  report_card_status?: ReportCardStatus | null;
  avg_grade?: number | null;
  remed_count?: number;
  published_at?: string | null;
}

export type RaportSummaryRow = ReportCardSummaryRow;

// ── Admin pipeline (Mockup #08) ─────────────────────────────────────

export type PipelineKey = 'draft' | 'reviewed' | 'published' | 'distributed';

export interface PipelineNode {
  /** One of: 'draft' | 'reviewed' | 'published' | 'distributed'. */
  key: PipelineKey;
  label: string;
  count: number;
  active?: boolean;
}

export interface ClassMiniChip {
  id: string;
  name: string;
  /** Backend computes status label per kelas ("Selesai", "Perlu", etc). */
  status_label?: string | null;
  /** Tone hint: 'good' | 'warn' | 'bad' | 'slate'. */
  status_tone?: 'good' | 'warn' | 'bad' | 'slate' | string;
  counts?: {
    draft?: number;
    reviewed?: number;
    published?: number;
    distributed?: number;
  };
  student_count?: number;
}

export interface TingkatGroup {
  /** "VII" / "VIII" / "IX" etc. */
  tingkat: string;
  class_count: number;
  student_count: number;
  reviewed_pct?: number;
  /** True when at least one class in this tingkat needs admin attention. */
  alert?: boolean;
  classes: ClassMiniChip[];
}

export interface AdminReportCardPeriod {
  academic_year_id?: string | null;
  academic_year_label?: string | null;
  semester_id?: string | null;
  semester_label?: string | null;
}

export type AdminRaportPeriod = AdminReportCardPeriod;

export interface AdminReportCardPipeline {
  pipeline: PipelineNode[];
  tingkats: TingkatGroup[];
  period: AdminReportCardPeriod;
  total_report_cards: number;
  total_classes: number;
}

export type AdminRaportPipeline = AdminReportCardPipeline;

// ── Parent inbox ────────────────────────────────────────────────────

/**
 * Row returned by `GET /parent/report-cards` (one per child with a
 * published report card for the active TP+semester).
 */
export interface ParentReportCardRow {
  student_class_id: string;
  /** Backend ships student + reportCard as nested objects. */
  student: {
    id: string;
    name: string;
    student_number?: string | null;
    class_name?: string | null;
  };
  rank?: number | null;
  total_in_class?: number | null;
  average_score?: number | null;
  attendance_pct?: number | null;
  /** Full hydrated rapor — same shape as `ReportCardDetail`. */
  reportCard: ReportCardDetail;
}

export type ParentRaportRow = ParentReportCardRow;
