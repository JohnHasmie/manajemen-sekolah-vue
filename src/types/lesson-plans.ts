/**
 * Lesson plan (RPP) types — mirror Flutter's lesson_plan.dart freezed
 * model plus lesson_plan_format.dart enum + helpers.
 *
 * Backend ships mixed English + Indonesian keys; the parser at the
 * bottom of this file normalises them. The status enum has 5 states
 * (Draft / Pending / Approved / Rejected / SentBack); older Vue code
 * only saw 3 because the list endpoint scoped to those — the detail
 * endpoint exposes Draft + SentBack so we model both.
 */

import type { StatusBadgeTone } from './status-badge';

// ── Status ──

export type LessonPlanStatus =
  | 'Draft'
  | 'Pending'
  | 'Approved'
  | 'Rejected'
  | 'SentBack';

export const STATUS_LABELS: Record<LessonPlanStatus, string> = {
  Draft: 'Draf',
  Pending: 'Menunggu Review',
  Approved: 'Disetujui',
  Rejected: 'Ditolak',
  SentBack: 'Perlu Revisi',
};

/**
 * One-line, plain-language explanation of each status — surfaced via an
 * InfoHint next to the status pill, so a teacher new to the flow knows
 * what "Menunggu Review" or "Perlu Revisi" actually means for them.
 */
export const STATUS_HINTS: Record<LessonPlanStatus, string> = {
  Draft: 'Masih draf — tersimpan, belum diajukan. Ajukan untuk direview admin.',
  Pending: 'Sudah diajukan, menunggu review admin. Belum perlu tindakan dari Anda.',
  Approved: 'Sudah disetujui admin. Tidak ada tindakan lagi.',
  Rejected: 'Ditolak admin — lihat alasannya, perbaiki, lalu ajukan ulang.',
  SentBack: 'Dikembalikan untuk revisi — baca catatan, perbaiki, lalu ajukan ulang.',
};

export const STATUS_TONES: Record<
  LessonPlanStatus,
  { bg: string; text: string; border: string; dot: string; tone: StatusBadgeTone }
> = {
  Draft: {
    bg: 'bg-slate-50',
    text: 'text-slate-700',
    border: 'border-slate-200',
    dot: 'bg-slate-400',
    tone: 'neutral',
  },
  Pending: {
    bg: 'bg-amber-50',
    text: 'text-amber-800',
    border: 'border-amber-200',
    dot: 'bg-amber-500',
    tone: 'warning',
  },
  Approved: {
    bg: 'bg-emerald-50',
    text: 'text-emerald-800',
    border: 'border-emerald-200',
    dot: 'bg-emerald-500',
    tone: 'success',
  },
  Rejected: {
    bg: 'bg-red-50',
    text: 'text-red-800',
    border: 'border-red-200',
    dot: 'bg-red-500',
    tone: 'danger',
  },
  SentBack: {
    bg: 'bg-violet-50',
    text: 'text-violet-800',
    border: 'border-violet-200',
    dot: 'bg-violet-500',
    tone: 'info',
  },
};

/**
 * Backend ships several status spellings — normalise them. Idempotent:
 * already-canonical values pass through.
 */
export function normalizeStatus(raw: unknown): LessonPlanStatus {
  const v = String(raw ?? '').toLowerCase().trim();
  if (!v) return 'Draft';
  if (v === 'draft' || v === 'draf') return 'Draft';
  if (
    v === 'pending' ||
    v === 'pending_review' ||
    v === 'submitted' ||
    v === 'menunggu' ||
    v === 'menunggu_review'
  ) {
    // Backend's summary endpoint lumps 'submitted' with pending in the
    // "open" KPI — treat it the same here so the UI doesn't show a
    // mystery 5th status.
    return 'Pending';
  }
  if (v === 'approved' || v === 'disetujui') return 'Approved';
  if (v === 'rejected' || v === 'ditolak') return 'Rejected';
  if (v === 'sent_back' || v === 'sentback' || v === 'perlu_revisi') {
    return 'SentBack';
  }
  return 'Pending';
}

// ── Format ──

export type LessonPlanFormat =
  | 'k13'
  | 'rpp_1_halaman'
  | 'modul_ajar'
  | 'file';

export const FORMAT_LABELS: Record<LessonPlanFormat, string> = {
  k13: 'RPP K13',
  rpp_1_halaman: 'RPP 1 Halaman',
  modul_ajar: 'Modul Ajar',
  file: 'Upload File',
};

export const FORMAT_LONG_LABELS: Record<LessonPlanFormat, string> = {
  k13: 'Kurikulum 2013',
  rpp_1_halaman: 'RPP 1 Halaman',
  modul_ajar: 'Modul Ajar (Kurikulum Merdeka)',
  file: 'Upload File (PDF / DOCX)',
};

export const FORMAT_SHORT_LABELS: Record<LessonPlanFormat, string> = {
  k13: 'K13',
  rpp_1_halaman: '1 HAL',
  modul_ajar: 'MODUL AJAR',
  file: 'FILE',
};

export const FORMAT_COLORS: Record<LessonPlanFormat, string> = {
  k13: '#4338CA', // indigo-600
  rpp_1_halaman: '#047857', // emerald-600
  modul_ajar: '#7C3AED', // violet-600
  file: '#475569', // slate-600
};

export const FORMAT_ICONS: Record<LessonPlanFormat, string> = {
  k13: 'book',
  rpp_1_halaman: 'file-text',
  modul_ajar: 'sparkles',
  file: 'upload',
};

/**
 * Section keys per format — used by the detail renderer + regenerate
 * sheet so widget code never needs a match ladder.
 */
export const FORMAT_SECTION_KEYS: Record<LessonPlanFormat, string[]> = {
  k13: ['identitas', 'kd_indikator', 'tujuan', 'langkah_kegiatan', 'penilaian'],
  rpp_1_halaman: ['tujuan', 'kegiatan', 'asesmen'],
  modul_ajar: [
    'info_umum',
    'capaian',
    'tujuan',
    'pemahaman_pemantik',
    'kegiatan',
    'asesmen_refleksi',
  ],
  file: [],
};

/** Bahasa Indonesia label for a section key. */
export function sectionLabel(key: string): string {
  switch (key) {
    case 'identitas':
      return 'Identitas';
    case 'kd_indikator':
      return 'Kompetensi Dasar & Indikator';
    case 'langkah_kegiatan':
      return 'Langkah Kegiatan';
    case 'penilaian':
      return 'Penilaian';
    case 'tujuan':
      return 'Tujuan Pembelajaran';
    case 'kegiatan':
      return 'Kegiatan Pembelajaran';
    case 'asesmen':
      return 'Asesmen';
    case 'info_umum':
      return 'Informasi Umum';
    case 'capaian':
      return 'Capaian Pembelajaran';
    case 'pemahaman_pemantik':
      return 'Pemahaman Bermakna & Pertanyaan Pemantik';
    case 'asesmen_refleksi':
      return 'Asesmen & Refleksi';
    default:
      return key;
  }
}

export function normalizeFormat(raw: unknown): LessonPlanFormat {
  const v = String(raw ?? '').toLowerCase().trim();
  if (v === 'rpp_1_halaman' || v === '1_halaman' || v === '1halaman') {
    return 'rpp_1_halaman';
  }
  if (v === 'modul_ajar' || v === 'modulajar') return 'modul_ajar';
  if (v === 'file' || v === 'upload') return 'file';
  return 'k13';
}

/** Structured formats expose editable sections + AI generation. */
export function isStructuredFormat(f: LessonPlanFormat): boolean {
  return f !== 'file';
}

// ── Lesson plan row ──

/**
 * `format_data` — the structured section content for K13 / 1 Halaman /
 * Modul Ajar formats. Keys come from `FORMAT_SECTION_KEYS[format]`.
 * Backend may also expose legacy flat columns (`learning_objective`,
 * `basic_competence`, etc.) for K13; the parser reads either path.
 */
export type LessonPlanFormatData = Record<string, string>;

export interface LessonPlan {
  id: string;
  title: string;
  status: LessonPlanStatus;
  format: LessonPlanFormat;
  /** Raw backend format string — preserved for write payloads. */
  raw_format?: string | null;

  subject_id?: string | null;
  subject_name: string;
  class_id?: string | null;
  class_name: string;
  teacher_id: string;
  teacher_name: string;

  academic_year?: string | null;
  semester?: string | null;

  /** Teacher's notes / rationale. */
  notes?: string | null;
  /** Admin's revision note — populated when status=Rejected or SentBack. */
  admin_notes?: string | null;
  /** Sections flagged for revision (admin send-back). */
  revision_areas?: string[];

  ai_generated: boolean;
  /** Revision round — 1 = first submission. */
  revision: number;

  /** Structured section content (per format). */
  format_data?: LessonPlanFormatData;

  // File upload metadata (only populated when format='file')
  file_path?: string | null;
  file_name?: string | null;
  file_url?: string | null;
  file_size?: number | null;
  file_mime?: string | null;
  /** Derived: file size in MB rounded to 2 decimals. */
  file_size_mb?: number | null;

  created_at: string;
  submitted_at?: string | null;
  updated_at?: string | null;
}

export interface LessonPlanCounts {
  pending: number;
  approved: number;
  rejected: number;
  /** Optional — backend may include drafts + sent-back. */
  draft?: number;
  sent_back?: number;
  total?: number;
  weekly?: number;
  monthly?: number;
  ai_generated?: number;
}

// ── Review history row ──

export type ReviewAction =
  | 'created'
  | 'submitted'
  | 'approved'
  | 'rejected'
  | 'sent_back'
  | 'updated';

export interface LessonPlanReview {
  id: string;
  action: ReviewAction;
  /** Display label — "Diserahkan" / "Disetujui" / "Ditolak" / etc. */
  label: string;
  actor_id?: string | null;
  actor_name: string;
  actor_role?: string | null;
  from_status?: LessonPlanStatus | null;
  to_status?: LessonPlanStatus | null;
  note?: string | null;
  revision_areas?: string[];
  /** ISO timestamp. */
  created_at: string;
}

export const REVIEW_ACTION_LABELS: Record<ReviewAction, string> = {
  created: 'Dibuat',
  submitted: 'Diserahkan',
  approved: 'Disetujui',
  rejected: 'Ditolak',
  sent_back: 'Dikembalikan',
  updated: 'Diperbarui',
};

export const REVIEW_ACTION_TONES: Record<
  ReviewAction,
  { dot: string; text: string }
> = {
  created: { dot: 'bg-slate-400', text: 'text-slate-700' },
  submitted: { dot: 'bg-brand-cobalt', text: 'text-brand-cobalt' },
  approved: { dot: 'bg-emerald-500', text: 'text-emerald-700' },
  rejected: { dot: 'bg-red-500', text: 'text-red-700' },
  sent_back: { dot: 'bg-violet-500', text: 'text-violet-700' },
  updated: { dot: 'bg-amber-500', text: 'text-amber-700' },
};

function normalizeAction(raw: unknown): ReviewAction {
  const v = String(raw ?? '').toLowerCase().trim();
  if (v === 'created' || v === 'create' || v === 'dibuat') return 'created';
  if (v === 'submitted' || v === 'submit' || v === 'diserahkan') {
    return 'submitted';
  }
  if (v === 'approved' || v === 'approve' || v === 'disetujui') {
    return 'approved';
  }
  if (v === 'rejected' || v === 'reject' || v === 'ditolak') return 'rejected';
  if (v === 'sent_back' || v === 'sentback' || v === 'send_back') {
    return 'sent_back';
  }
  return 'updated';
}

// ── Admin queue (tier-grouped) ──

export interface AdminQueueTier {
  /** Tier key — "perlu_review" / "disetujui" / "ditolak". */
  key: 'perlu_review' | 'disetujui' | 'ditolak';
  label: string;
  /** Tone — drives the section header color. */
  tone: 'warn' | 'good' | 'bad';
  count: number;
  items: LessonPlan[];
}

export interface AdminQueueResponse {
  tiers: AdminQueueTier[];
  /** Top-level KPI block. */
  kpi: {
    total: number;
    perlu_review: number;
    disetujui: number;
    ditolak: number;
    /** Optional — backend may include "this week" / "today" counts. */
    this_week?: number;
    today?: number;
  };
}

// ── Parsers ──

type AnyRecord = Record<string, unknown>;

function num(v: unknown): number {
  if (typeof v === 'number') return v;
  if (v === null || v === undefined) return 0;
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

function strOrNull(v: unknown): string | null {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  return s === '' ? null : s;
}

/**
 * Read a section value from a lesson plan map.
 *
 * Tries `format_data[key]` first (the new path), then falls back to
 * legacy flat columns when the row's format is K13. Matches Flutter's
 * `readLessonPlanSection` helper for parity.
 */
export function readLessonPlanSection(
  plan: Pick<LessonPlan, 'format' | 'format_data'> & {
    [k: string]: unknown;
  },
  key: string,
): string {
  const fd = plan.format_data;
  if (fd && typeof fd[key] === 'string' && fd[key].trim().length > 0) {
    return fd[key];
  }
  // Legacy K13 column fallback
  if (plan.format === 'k13') {
    const legacy: Record<string, string> = {
      tujuan: 'learning_objective',
      kd_indikator: 'basic_competence',
      langkah_kegiatan: 'learning_activities',
      penilaian: 'assessment',
    };
    const col = legacy[key] ?? key;
    const v = (plan as Record<string, unknown>)[col];
    if (typeof v === 'string' && v.trim().length > 0) return v;
  }
  return '';
}

export function lessonPlanFromJson(raw: AnyRecord): LessonPlan {
  const r = raw;
  const fileSize = num(r.file_size);
  const teacherObj = (r.teacher as AnyRecord | undefined) ?? null;
  const teacherUserObj =
    (teacherObj?.user as AnyRecord | undefined) ?? null;
  const subjectObj = (r.subject as AnyRecord | undefined) ?? null;
  const classObj = (r.class as AnyRecord | undefined) ?? null;
  const fd =
    (r.format_data as AnyRecord | undefined) ??
    (r.formatData as AnyRecord | undefined) ??
    undefined;
  const formatData = fd
    ? (Object.fromEntries(
        Object.entries(fd).map(([k, v]) => [
          k,
          typeof v === 'string' ? v : v === null || v === undefined ? '' : String(v),
        ]),
      ) as LessonPlanFormatData)
    : undefined;

  // ── Subtitle-splitting fallback for the admin-queue light
  // projection. The backend ships e.g. "Matematika · VII A" in the
  // `subtitle` field instead of separate subject/class names, so
  // when neither nested object nor direct *_name fields are present
  // we lift them out of the subtitle.
  let subjectFromSubtitle = '';
  let classFromSubtitle = '';
  if (typeof r.subtitle === 'string' && r.subtitle.includes(' · ')) {
    const parts = r.subtitle.split(' · ').map((s: string) => s.trim());
    subjectFromSubtitle = parts[0] ?? '';
    classFromSubtitle = parts[1] ?? '';
  }

  return {
    // The backend ships `id` directly for both the index list and the
    // admin-queue light projection. Fallback chain only covers legacy
    // rpp_id / lesson_plan_id payloads.
    id: String(r.id ?? r.rpp_id ?? r.lesson_plan_id ?? ''),
    title: String(r.title ?? r.judul ?? ''),
    status: normalizeStatus(r.status),
    format: normalizeFormat(r.format),
    raw_format: strOrNull(r.format),
    subject_id: strOrNull(
      r.subject_id ?? subjectObj?.id ?? r.mata_pelajaran_id,
    ),
    subject_name: String(
      r.subject_name ??
        subjectObj?.name ??
        r.mata_pelajaran_nama ??
        r.mata_pelajaran ??
        subjectFromSubtitle ??
        '',
    ),
    class_id: strOrNull(r.class_id ?? classObj?.id ?? r.kelas_id),
    class_name: String(
      r.class_name ??
        classObj?.name ??
        r.kelas_nama ??
        r.kelas ??
        classFromSubtitle ??
        '',
    ),
    teacher_id: String(r.teacher_id ?? teacherObj?.id ?? ''),
    teacher_name: String(
      // Eager-loaded `teacher.user.name` is the canonical display
      // name on the backend (the teacher_profiles row only has the
      // foreign key + employee_number).
      r.teacher_name ??
        teacherUserObj?.name ??
        teacherObj?.name ??
        r.nama_guru ??
        r.guru_nama ??
        '',
    ),
    academic_year: strOrNull(r.academic_year ?? r.tahun_ajaran),
    semester: strOrNull(r.semester),
    notes: strOrNull(r.notes ?? r.catatan),
    admin_notes: strOrNull(
      // Canonical column post-rename is `lesson_plans.admin_note`.
      // Older endpoints may still ship `note_admin` / `admin_notes` /
      // `rejection_reason` / `revision_note`; accept all.
      r.admin_note ??
        r.admin_notes ??
        r.note_admin ??
        r.rejection_reason ??
        r.catatan_admin ??
        r.revision_note,
    ),
    revision_areas: Array.isArray(r.revision_areas)
      ? (r.revision_areas as unknown[]).map((x) => String(x))
      : undefined,
    ai_generated: Boolean(
      r.ai_generated ?? r.is_ai_generated ?? r.is_ai ?? false,
    ),
    revision: num(r.revision ?? r.revision_round) || 1,
    format_data: formatData,
    file_path: strOrNull(r.file_path),
    file_name: strOrNull(r.file_name),
    file_url: strOrNull(r.file_url),
    file_size: fileSize > 0 ? fileSize : null,
    file_mime: strOrNull(r.file_mime),
    file_size_mb:
      fileSize > 0
        ? Math.round((fileSize / 1024 / 1024) * 100) / 100
        : null,
    created_at: String(r.created_at ?? r.tanggal_buat ?? ''),
    submitted_at: strOrNull(r.submitted_at ?? r.tanggal_kirim),
    // Admin-queue light projection ships `updated_at_iso`; full payload
    // ships `updated_at`. Take whichever is present.
    updated_at: strOrNull(r.updated_at ?? r.updated_at_iso),
  };
}

export function reviewFromJson(raw: AnyRecord): LessonPlanReview {
  const action = normalizeAction(raw.action ?? raw.event);
  return {
    id: String(raw.id ?? `${action}_${raw.created_at ?? Date.now()}`),
    action,
    label: String(
      raw.label ?? raw.action_label ?? REVIEW_ACTION_LABELS[action],
    ),
    actor_id: strOrNull(raw.actor_id ?? raw.user_id),
    actor_name: String(
      raw.actor_name ?? raw.user_name ?? raw.nama ?? 'Pengguna',
    ),
    actor_role: strOrNull(raw.actor_role ?? raw.role),
    from_status:
      raw.from_status !== undefined && raw.from_status !== null
        ? normalizeStatus(raw.from_status)
        : null,
    to_status:
      raw.to_status !== undefined && raw.to_status !== null
        ? normalizeStatus(raw.to_status)
        : null,
    note: strOrNull(raw.note ?? raw.catatan),
    revision_areas: Array.isArray(raw.revision_areas)
      ? (raw.revision_areas as unknown[]).map((x) => String(x))
      : undefined,
    created_at: String(raw.created_at ?? raw.tanggal ?? ''),
  };
}

/**
 * Parse `/api/lesson-plans/admin-queue` response.
 *
 * Backend shape (single response, no per-tier indexing):
 *   {
 *     success: true,
 *     data: {
 *       tiers: [
 *         { key: 'pending'  | 'approved' | 'rejected',
 *           label, tone, total_count, delta_label, items: [{...}] }
 *       ]
 *     }
 *   }
 *
 * Each item is a light projection (id, title, subtitle, teacher_name,
 * status, format, rejection_reason, updated_at_iso) — not the full
 * lesson plan. We map it onto LessonPlan with the fields we have so
 * the admin queue card renders correctly.
 *
 * No top-level `kpi` block in the response — derive from `total_count`
 * on each tier so the KPI strip stays accurate.
 */
export function adminQueueFromJson(raw: AnyRecord): AdminQueueResponse {
  // Backend wraps tiers under `data.tiers`. Older payloads may have
  // had `tiers` at the top — fall through to both.
  const dataWrap = (raw.data as AnyRecord | undefined) ?? raw;
  const tierArr = Array.isArray(dataWrap.tiers)
    ? (dataWrap.tiers as AnyRecord[])
    : Array.isArray(raw.tiers)
      ? (raw.tiers as AnyRecord[])
      : [];

  // Backend tier keys → canonical Vue keys.
  const KEY_MAP: Record<string, AdminQueueTier['key']> = {
    pending: 'perlu_review',
    perlu_review: 'perlu_review',
    approved: 'disetujui',
    disetujui: 'disetujui',
    rejected: 'ditolak',
    ditolak: 'ditolak',
  };
  const TONE_MAP: Record<string, AdminQueueTier['tone']> = {
    warn: 'warn',
    good: 'good',
    bad: 'bad',
  };
  const DEFAULT_LABEL: Record<AdminQueueTier['key'], string> = {
    perlu_review: 'Perlu Review',
    disetujui: 'Disetujui',
    ditolak: 'Ditolak',
  };
  const DEFAULT_TONE: Record<AdminQueueTier['key'], AdminQueueTier['tone']> = {
    perlu_review: 'warn',
    disetujui: 'good',
    ditolak: 'bad',
  };

  const tiers: AdminQueueTier[] = [];
  // Build in canonical order so the UI always renders the same
  // sequence (Perlu Review → Disetujui → Ditolak), regardless of
  // backend order. Pull each tier from the response if present.
  const order: AdminQueueTier['key'][] = ['perlu_review', 'disetujui', 'ditolak'];
  for (const canonical of order) {
    const found = tierArr.find((t) => {
      const k = String(t.key ?? '').toLowerCase();
      return KEY_MAP[k] === canonical;
    });
    const items = Array.isArray(found?.items)
      ? (found!.items as AnyRecord[])
      : [];
    const total =
      found?.total_count !== undefined
        ? num(found.total_count)
        : items.length;
    tiers.push({
      key: canonical,
      label:
        (found?.label as string | undefined) ?? DEFAULT_LABEL[canonical],
      tone:
        TONE_MAP[String(found?.tone ?? '').toLowerCase()] ??
        DEFAULT_TONE[canonical],
      count: total,
      items: items.map(lessonPlanFromJson),
    });
  }

  const kpiRaw = (raw.kpi as AnyRecord | undefined) ?? {};
  return {
    tiers,
    kpi: {
      total: num(
        kpiRaw.total ?? tiers.reduce((s, t) => s + t.count, 0),
      ),
      perlu_review: num(
        kpiRaw.perlu_review ??
          kpiRaw.pending ??
          tiers.find((t) => t.key === 'perlu_review')?.count ??
          0,
      ),
      disetujui: num(
        kpiRaw.disetujui ??
          kpiRaw.approved ??
          tiers.find((t) => t.key === 'disetujui')?.count ??
          0,
      ),
      ditolak: num(
        kpiRaw.ditolak ??
          kpiRaw.rejected ??
          tiers.find((t) => t.key === 'ditolak')?.count ??
          0,
      ),
      this_week: kpiRaw.this_week !== undefined ? num(kpiRaw.this_week) : undefined,
      today: kpiRaw.today !== undefined ? num(kpiRaw.today) : undefined,
    },
  };
}
