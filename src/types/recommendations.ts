/**
 * AI Recommendation types — mirrors the Flutter
 * `recommendation_service.dart` contract end-to-end.
 *
 * The Flutter app treats each recommendation as a per-student action
 * item with rich metadata (priority, type, ai_reasoning, materials,
 * due date, teacher notes, share-to-parent state, etc.). All
 * endpoints live on the **kamiledu-ai** backend (separate from the
 * main Laravel API); the Vue HTTP layer points `aiApi` at
 * `VITE_AI_API_URL` accordingly.
 *
 * The "insight" wrapper (`Recommendation`, `RecommendationStudent`)
 * is the older shape still used by the parent inbox + the teacher
 * dashboard's quick-action card. New code should reach for
 * `LearningRecommendation` directly.
 */

import type { StatusBadgeTone } from './status-badge';

export type RecommendationScope = 'class' | 'student';

/** Operational status of an individual rec (Flutter parity). */
export type RecStatus = 'pending' | 'in_progress' | 'completed' | 'dismissed';

/**
 * AI job polling status.
 *
 * Flutter accepts both `done` and `completed` as terminal-success;
 * `failed` and `error` are both terminal-failure. We surface all
 * four in the union so the polling loop's match ladder is
 * exhaustive without runtime guesswork.
 */
export type RecommendationJobStatus =
  | 'pending'
  | 'running'
  | 'processing'
  | 'done'
  | 'completed'
  | 'error'
  | 'failed';

/** Legacy alias kept for back-compat with the older insight surface. */
export type RecommendationStatus = RecommendationJobStatus;

export type RecPriority = 'high' | 'medium' | 'low';

/** Free-form rec type — backend returns strings; UI shows uppercase pill. */
export type RecType =
  | 'remediation'
  | 'enrichment'
  | 'behavior'
  | 'attendance'
  | 'other'
  | string;

// ── Generate sheet (Frame D) types ──────────────────────────────────

/**
 * Scope axis for the AI generate sheet.
 *
 * - `at_risk`     — backend's default. Only students flagged at-risk
 *                   on the latest assessment / attendance window.
 * - `all`         — every active enrolment in the class.
 * - `per_student` — explicit subset; client fans out one call per
 *                   selected student.
 */
export type GenerateScope = 'at_risk' | 'all' | 'per_student';

/** Tone hint passed to the AI / share copy. */
export type RecTone = 'warm' | 'formal' | 'concise' | 'detailed';

/**
 * Config payload for the AI generate sheet.
 *
 * `subject_ids` is fanned out client-side (one POST per subject) so a
 * teacher can ask "Matematika + IPA at once" and only have to wait
 * once. Per-student scope adds a second fan-out axis (one POST per
 * `subject × student`).
 *
 * `trigger_source` is logged on the backend for usage analytics
 * (mockup says "ai_button_class_hub" / "ai_button_per_student" etc.).
 */
export interface GenerateConfig {
  scope: GenerateScope;
  subject_ids: string[];
  /** Required when scope === 'per_student'. */
  student_ids?: string[];
  /** "today" | "week" | "month" | "semester" — backend hint. */
  period?: string;
  /** When true, overrides backend cache + regenerates fresh. */
  force_regenerate?: boolean;
  /**
   * When false (default), the AI only surfaces students it judges
   * at-risk. When true, includes students already on-track for
   * "enrichment" recs.
   */
  include_on_track?: boolean;
  /** Free-form analytics label. */
  trigger_source?: string;
}

// ── Materials ───────────────────────────────────────────────────────

/** Material attachment for a per-student rec. */
export interface RecMaterial {
  id?: string;
  title: string;
  description?: string | null;
  url?: string | null;
  kind?: string | null;
  source?: 'manual' | 'ai' | 'curriculum' | string;
}

// ── Share recipient (Riwayat Pengiriman) ────────────────────────────

/** Per-recipient share row (used by the share-history sheet). */
export interface RecShareRecipient {
  id: string;
  parent_user_id?: string | null;
  parent_name: string;
  parent_relation?: string | null;
  /** Channels selected when the share was sent — for the timeline icons. */
  channels?: { push?: boolean; whatsapp?: boolean };
  /** Per-channel delivery state (backend ships these as ISO strings). */
  sent_at?: string | null;
  delivered_at?: string | null;
  read_at?: string | null;
  replied_at?: string | null;
  reply_text?: string | null;
  /** Set when the teacher "Tarik Pesan"-ed this recipient. */
  revoked_at?: string | null;
  /** Set when the parent clicked "Sudah saya terapkan" on their side. */
  parent_completed_at?: string | null;
  parent_completed_note?: string | null;
  /** How many times "Ingatkan Ulang" has been used. */
  resend_count?: number;
  /** Last message + tone snapshot (drives Edit & Kirim Ulang). */
  last_message?: string | null;
  last_tone?: RecTone | string | null;
}

/**
 * Rolled-up share summary on the rec row itself (saves a roundtrip
 * for the card's "n DIBACA WALI" pill). Backend ships these as
 * counters alongside the rec.
 */
export interface RecShareSummary {
  recipient_count: number;
  read_count: number;
  replied_count: number;
  revoked_count: number;
  /** Most recent send timestamp across recipients. */
  latest_sent_at?: string | null;
}

// ── Bulk share-to-parent (Kirim semua ke parent) ────────────────────────

/** Per-rec outcome row of the bulk `POST /recommendations/share-all`. */
export interface ShareAllResultRow {
  recommendation_id: string;
  student_name: string;
  /** 'sent' on success, 'failed' on a per-rec exception, 'skipped' when no contactable parent. */
  status: 'sent' | 'failed' | 'skipped';
  /** Present only on 'failed' / 'skipped' rows. */
  error?: string | null;
}

/**
 * Response envelope for the bulk share endpoint. The backend resolves
 * each rec's parent itself (no `parents[]` sent) and reports a tally plus
 * a per-rec breakdown so the UI can show "X terkirim, Y gagal, Z
 * dilewati".
 */
export interface ShareAllResult {
  success: boolean;
  /** Shareable, not-yet-shared recs found (optionally scoped to one class). */
  total: number;
  /** Shared successfully. */
  sent: number;
  /** A per-rec share threw (batch continues). */
  failed: number;
  /** Student had no contactable parent. */
  skipped_no_wali: number;
  results: ShareAllResultRow[];
}

// ── Full recommendation row ─────────────────────────────────────────

/**
 * Full per-student recommendation. Maps directly to the AI backend's
 * `/recommendations/{id}` shape. Many fields are optional because the
 * backend doesn't always populate them (e.g. the share-state columns
 * are only set after the homeroom teacher fans the rec out).
 */
export interface LearningRecommendation {
  id: string;
  /** Always 'recommendation' on the backend — kept for symmetry. */
  scope?: RecommendationScope;
  status: RecStatus;
  priority: RecPriority;
  type: RecType;

  /** Display title from the AI ("Latih ulang SPLDV bab 4"). */
  title: string;
  /** HTML-flavored description. Rendered with `v-html` after sanitisation. */
  description?: string | null;
  /** AI's "why this matters" paragraph. */
  ai_reasoning?: string | null;
  /** Teacher-added notes ("Catatan Homeroom Teacher"). */
  teacher_notes?: string | null;

  /** Materials attached to the rec. */
  materials?: RecMaterial[];

  /** Student context. */
  student_id?: string;
  student_name?: string;
  /**
   * Parent denorm (eager-loaded on the homeroom-scope detail). Drives
   * the share sheet's recipient picker without an extra roundtrip.
   */
  student_parents?: Array<{
    parent_user_id?: string | null;
    parent_name: string;
    parent_relation?: string | null;
    parent_phone?: string | null;
  }>;

  /** Class context. */
  class_id?: string;
  class_name?: string;

  /** Subject context. */
  subject_id?: string | null;
  subject_name?: string | null;

  /** Authoring teacher (parent-kelas scope only). */
  teacher_id?: string;
  teacher_name?: string | null;

  /** Due date / completion timestamps. */
  due_date?: string | null;
  completed_at?: string | null;
  created_at?: string;
  updated_at?: string | null;

  /** Parent-share state — rolled-up counters from `share_recipients`. */
  shared_with_parent_at?: string | null;
  share_summary?: RecShareSummary;
  /** Light counters for back-compat with cards that read these directly. */
  share_recipient_count?: number;
  share_read_count?: number;

  /** Detached recipient list (only present on the hydrated detail). */
  share_recipients?: RecShareRecipient[];
}

// ── Status / priority / tone display helpers ────────────────────────

export const STATUS_LABELS: Record<RecStatus, string> = {
  pending: 'Menunggu',
  in_progress: 'Sedang Dikerjakan',
  completed: 'Diterapkan',
  dismissed: 'Diabaikan',
};

export const STATUS_TONES: Record<
  RecStatus,
  { bg: string; text: string; border: string; dot: string; tone: StatusBadgeTone }
> = {
  pending: {
    bg: 'bg-amber-50',
    text: 'text-amber-800',
    border: 'border-amber-200',
    dot: 'bg-amber-500',
    tone: 'warning',
  },
  in_progress: {
    bg: 'bg-blue-50',
    text: 'text-blue-800',
    border: 'border-blue-200',
    dot: 'bg-blue-500',
    tone: 'info',
  },
  completed: {
    bg: 'bg-emerald-50',
    text: 'text-emerald-800',
    border: 'border-emerald-200',
    dot: 'bg-emerald-500',
    tone: 'success',
  },
  dismissed: {
    bg: 'bg-slate-50',
    text: 'text-slate-600',
    border: 'border-slate-200',
    dot: 'bg-slate-400',
    tone: 'neutral',
  },
};

export const PRIORITY_LABELS: Record<RecPriority, string> = {
  high: 'Tinggi',
  medium: 'Sedang',
  low: 'Rendah',
};

export const PRIORITY_TONES: Record<
  RecPriority,
  { accent: string; pill: string }
> = {
  high: { accent: '#DC2626', pill: 'bg-red-100 text-red-700' },
  medium: { accent: '#D97706', pill: 'bg-amber-100 text-amber-700' },
  low: { accent: '#4F46E5', pill: 'bg-indigo-100 text-indigo-700' },
};

export const TONE_LABELS: Record<RecTone, string> = {
  warm: 'Hangat',
  formal: 'Formal',
  concise: 'Singkat',
  detailed: 'Detail',
};

/** Normalise backend status strings → canonical RecStatus. */
export function normalizeRecStatus(raw: unknown): RecStatus {
  const v = String(raw ?? '')
    .toLowerCase()
    .trim();
  if (v === 'completed' || v === 'done' || v === 'diterapkan')
    return 'completed';
  if (v === 'in_progress' || v === 'inprogress' || v === 'progress') {
    return 'in_progress';
  }
  if (v === 'dismissed' || v === 'rejected' || v === 'diabaikan') {
    return 'dismissed';
  }
  return 'pending';
}

export function normalizeRecPriority(raw: unknown): RecPriority {
  const v = String(raw ?? '')
    .toLowerCase()
    .trim();
  if (v === 'high' || v === 'tinggi' || v === 'urgent') return 'high';
  if (v === 'low' || v === 'rendah') return 'low';
  return 'medium';
}

// ── Legacy insight wrapper (parent inbox + dashboard cards) ─────────

/**
 * Legacy "insight" wrapper still used by the parent inbox and the
 * teacher view's "featured insight" card. New code should prefer
 * `LearningRecommendation` directly.
 */
export interface RecommendationStudent {
  student_id: string;
  student_name: string;
  metric_label?: string | null;
  metric_value?: string | number | null;
  acted: boolean;
}

export interface Recommendation {
  id: string;
  scope: RecommendationScope;
  context_label: string;
  subject_name?: string | null;
  status: RecommendationStatus;
  insight?: string | null;
  students: RecommendationStudent[];
  meta?: Record<string, unknown> | null;
  created_at: string;
}

export interface RecommendationJob {
  id: string;
  scope: RecommendationScope;
  context_label: string;
  status: RecommendationStatus;
  progress: number;
}

// ── Parent inbox (parent) ─────────────────────────────────────────────
//
// Each row is `{ recipient_id, recommendation, sent_at, read_at,
// replied_at, reply_text, parent_completed_at, parent_completion_note }`
// returned by `GET /recommendations/parent-inbox` on the AI backend.
// The nested `recommendation` is the same shape `LearningRecommendation`
// already models — we keep it loose (`AnyRecord`) here so the view
// layer can read the rich nested relations the backend returns
// (`teacher`, `subject_school`, `class_`, `student`, `chapter`,
// `subChapter`, `materials`, etc.) without a brittle schema.

type AnyRecord = Record<string, unknown>;

export interface ParentInboxRow {
  recipient_id: string;
  recommendation: AnyRecord;
  sent_at: string | null;
  read_at: string | null;
  replied_at?: string | null;
  reply_text?: string | null;
  parent_completed_at?: string | null;
  parent_completion_note?: string | null;
}

/** Per-child summary row (Frame A multi-child hub card). */
export interface ParentSummaryChild {
  student_id: string;
  student_name: string;
  class_name: string;
  total_count: number;
  unread_count: number;
  completed_count: number;
  high_priority_count: number;
}

export interface ParentSummaryResponse {
  children: ParentSummaryChild[];
  totals?: Record<string, number>;
}

/** Filter sheet snapshot (Frame F). */
export type ParentRecStatus = 'all' | 'unread' | 'active' | 'completed';
export type ParentRecPriority = 'all' | 'high' | 'medium' | 'low';
export type ParentRecPeriod = 'last7' | 'last30' | 'all';

export interface ParentRecFilter {
  status: ParentRecStatus;
  priority: ParentRecPriority;
  /** Case-insensitive list of subject_school names. Empty = no filter. */
  subjects: string[];
  period: ParentRecPeriod;
}

export const DEFAULT_PARENT_REC_FILTER: ParentRecFilter = {
  status: 'all',
  priority: 'all',
  subjects: [],
  period: 'all',
};

export function parentRecFilterActiveCount(f: ParentRecFilter): number {
  let n = 0;
  if (f.status !== 'all') n++;
  if (f.priority !== 'all') n++;
  if (f.subjects.length > 0) n++;
  if (f.period !== 'all') n++;
  return n;
}

export function parseParentInboxRow(raw: AnyRecord): ParentInboxRow {
  const recRaw = raw.recommendation;
  const rec: AnyRecord =
    recRaw && typeof recRaw === 'object' ? (recRaw as AnyRecord) : {};
  return {
    recipient_id: String(raw.recipient_id ?? raw.id ?? ''),
    recommendation: rec,
    sent_at: raw.sent_at != null ? String(raw.sent_at) : null,
    read_at: raw.read_at != null ? String(raw.read_at) : null,
    replied_at: raw.replied_at != null ? String(raw.replied_at) : null,
    reply_text: raw.reply_text != null ? String(raw.reply_text) : null,
    parent_completed_at:
      raw.parent_completed_at != null ? String(raw.parent_completed_at) : null,
    parent_completion_note:
      raw.parent_completion_note != null
        ? String(raw.parent_completion_note)
        : null,
  };
}

export function parseParentSummaryChild(raw: AnyRecord): ParentSummaryChild {
  return {
    student_id: String(raw.student_id ?? ''),
    student_name: String(raw.student_name ?? 'Siswa'),
    class_name: String(raw.class_name ?? '-'),
    total_count: Number(raw.total_count ?? 0),
    unread_count: Number(raw.unread_count ?? 0),
    completed_count: Number(raw.completed_count ?? 0),
    high_priority_count: Number(raw.high_priority_count ?? 0),
  };
}

// ── Class summary (Frame A drill-down KPIs) ─────────────────────────

/**
 * Aggregated class-level summary returned by
 * `GET /recommendations/class/{id}/summary`.
 *
 * `at_risk_count` is optional because older backend versions don't
 * compute it. The Flutter app falls back to "count of high-priority"
 * then to "30% of enrolment" — replicate the same chain in the Vue
 * generate sheet.
 */
export interface RecommendationClassSummary {
  total_recommendations: number;
  by_status: Record<RecStatus, number>;
  by_priority: Record<RecPriority, number>;
  by_category: Record<string, number>;
  at_risk_count?: number;
}

// ── Student status counts (Frame B per-student rollup) ──────────────

/**
 * Per-student rollup driving the student list view's REC pills.
 * Keyed by `student_id`.
 *
 * Service helper paginates through `GET /recommendations` 50/page and
 * tallies — backend doesn't ship this as a dedicated endpoint yet
 * (mirrors Flutter `getStudentStatusCounts`).
 */
export type StudentStatusCounts = Record<
  string,
  { total: number; pending: number; completed: number }
>;
