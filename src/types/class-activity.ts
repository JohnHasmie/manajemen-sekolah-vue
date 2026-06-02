/**
 * Class activity (Kegiatan Kelas) types — mirror Flutter's
 * `lib/features/class_activity/domain/models/` exactly.
 *
 * Canonical Flutter enum is 4 values: tugas / pr / ulangan / lainnya.
 * Earlier Vue revisions had a wider set (material, general, etc.) —
 * those are now collapsed onto `lainnya` via `normalizeActivityType`
 * so legacy backend rows keep mapping cleanly without throwing.
 *
 * Three roles consume these types:
 *   - Teacher: list + create/edit + submission tracker
 *   - Admin:   read-only hub with KPI strip + submission progress
 *   - Parent:  read-only feed with auto-mark-as-read
 */

// ── Type enum ──
//
// Canonical English values match the backend `class_activities.type`
// column: assignment | test | quiz | activity | exam | material.
// Vue keeps a compact 4-value bucket: assignment / homework / test /
// other — anything not in the first three maps to 'other'.

export type ActivityType = 'assignment' | 'homework' | 'test' | 'other';

export const ACTIVITY_TYPE_LABELS: Record<ActivityType, string> = {
  assignment: 'Tugas',
  homework: 'PR',
  test: 'Ulangan',
  other: 'Lainnya',
};

/** Per-type accent hex — drives card left bar + type pill. */
export const ACTIVITY_TYPE_COLORS: Record<ActivityType, string> = {
  assignment: '#B45309', // amber-700
  homework: '#7C3AED', // violet-600
  test: '#DC2626', // red-600
  other: '#475569', // slate-600
};

/**
 * Accept any of the legacy raw values the backend / older clients
 * may emit and collapse them onto the canonical 4 types. Mirrors
 * `AdminActivityType.fromRaw` in the Flutter model.
 */
export function normalizeActivityType(raw: unknown): ActivityType {
  const v = String(raw ?? '').toLowerCase().trim();
  if (!v) return 'other';
  if (v === 'assignment' || v === 'tugas') return 'assignment';
  if (v === 'homework' || v === 'pr') return 'homework';
  if (
    v === 'test' ||
    v === 'ulangan' ||
    v === 'exam' ||
    v === 'ujian' ||
    v === 'quiz' ||
    v === 'kuis'
  ) {
    return 'test';
  }
  return 'other';
}

// ── Period enum (admin hub filter chip) ──

export type ActivityPeriod = 'today' | '7d' | '30d' | 'semester' | 'year';

export const ACTIVITY_PERIOD_LABELS: Record<ActivityPeriod, string> = {
  today: 'Hari Ini',
  '7d': '7 Hari',
  '30d': '30 Hari',
  semester: 'Semester',
  year: 'Tahun Ajaran',
};

// ── Submission status (teacher's Catat Submit picker) ──

export type SubmissionStatus = 'pending' | 'submitted' | 'late' | 'excused';

export const SUBMISSION_STATUS_LABELS: Record<SubmissionStatus, string> = {
  pending: 'Belum',
  submitted: 'Sudah',
  late: 'Telat',
  excused: 'Izin',
};

export const SUBMISSION_STATUS_TONES: Record<
  SubmissionStatus,
  { bg: string; text: string; border: string }
> = {
  pending: {
    bg: 'bg-slate-100',
    text: 'text-slate-600',
    border: 'border-slate-200',
  },
  submitted: {
    bg: 'bg-emerald-50',
    text: 'text-emerald-700',
    border: 'border-emerald-200',
  },
  late: {
    bg: 'bg-amber-50',
    text: 'text-amber-700',
    border: 'border-amber-200',
  },
  excused: {
    bg: 'bg-violet-50',
    text: 'text-violet-700',
    border: 'border-violet-200',
  },
};

// ── Submission summary (admin card footer) ──

export interface ActivitySubmissionSummary {
  total_students: number;
  submitted: number;
  pending: number;
  late: number;
  excused: number;
  avg_score: number | null;
}

/** 0..1 ratio for progress bar — clamps to 0 when no enrolled students. */
export function submissionProgress(s: ActivitySubmissionSummary): number {
  if (s.total_students <= 0) return 0;
  return Math.min(1, Math.max(0, (s.submitted + s.late) / s.total_students));
}

export function submissionHasTracking(s: ActivitySubmissionSummary): boolean {
  return (
    s.total_students > 0 ||
    s.submitted > 0 ||
    s.pending > 0 ||
    s.late > 0 ||
    s.excused > 0
  );
}

// ── Per-student submission row (teacher's submission picker) ──

export interface ActivitySubmissionRow {
  /** student_classes.id — required by the upsert payload. */
  student_class_id: string;
  student_id: string;
  student_name: string;
  status: SubmissionStatus;
  /** 0..100 — only filled for scored types (tugas/ulangan). */
  score?: number | null;
  notes?: string | null;
}

// ── Main activity row ──
//
// Single shape used across overview list (teacher / admin / parent)
// and the detail modal. Fields the list endpoint doesn't include
// (description, attachments, full submission roster) are lazy-loaded
// by `GET /class-activity/{id}` and merged into the same shape.

export interface ClassActivity {
  id: string;
  title: string;
  /** ISO yyyy-mm-dd. */
  date: string;
  /** Optional 'HH:MM' time. */
  time?: string | null;
  /** Optional session label (e.g. 'Sesi 1'). */
  session?: string | null;
  type: ActivityType;
  /** Raw type string from backend — preserved for write payloads. */
  raw_type?: string | null;
  class_id: string;
  class_name: string;
  subject_id: string;
  subject_name: string;
  /** Chapter/sub-chapter reference label. */
  chapter_label?: string | null;
  /** Body text — "Deskripsi" section. */
  description?: string | null;
  /** Linked teaching material title (display). */
  material?: string | null;
  /** Linked material id (foreign key). */
  material_id?: string | null;
  /** Teacher's reflection notes (teacher feature, optional). */
  reflection?: string | null;
  attachment_count: number;
  has_reflection: boolean;
  teacher_id?: string | null;
  teacher_name?: string | null;
  /** True when activity targets a subset of students (renders "Khusus" pill). */
  is_specific_target: boolean;
  /** Parent-only: true when the parent's child is in the targeted subset
   *  (renders the "Untuk anak ini" star chip on top of the Khusus pill). */
  for_this_student?: boolean;
  /** Optional deadline for assignments. ISO yyyy-mm-dd. */
  deadline?: string | null;
  /** Optional bab/sub-bab titles split out. The combined `chapter_label`
   *  stays in place for back-compat; these two power the mobile detail
   *  sheet's separate "Bab" + "Sub-Bab" rendering. */
  chapter_title?: string | null;
  sub_chapter_title?: string | null;
  /** Optional list of additional materi sub-chapters referenced by the
   *  activity. Each entry renders as a "Sub-Bab tambahan" detail row. */
  additional_material?: { sub_chapter_title: string }[];
  /** Parent-only: true when the parent's child has read this activity. */
  is_read?: boolean;
  /** Submission stats block — auto-zero for non-trackable types. */
  submissions: ActivitySubmissionSummary;
}

// ── Admin KPI strip ──

export interface AdminActivityKpi {
  total: number;
  this_week: number;
  pending_submissions: number;
}

export interface AdminActivitySummaryPage {
  items: ClassActivity[];
  kpi: AdminActivityKpi;
  pagination?: {
    current_page: number;
    total_pages: number;
    total_items: number;
    has_next_page: boolean;
  };
}

// ── Teacher summary (teacher-summary endpoint) ──
//
// Lighter envelope — same items[] shape + a small KPI for the
// teacher hub header.

export interface TeacherActivityKpi {
  total: number;
  this_week: number;
  /** Activities the teacher created but haven't tracked submissions for. */
  pending_action: number;
}

export interface TeacherActivitySummaryPage {
  items: ClassActivity[];
  kpi: TeacherActivityKpi;
  pagination?: {
    current_page: number;
    total_pages: number;
    total_items: number;
    has_next_page: boolean;
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

function numOrNull(v: unknown): number | null {
  if (v === null || v === undefined || v === '') return null;
  if (typeof v === 'number') return Number.isFinite(v) ? v : null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function strOrNull(v: unknown): string | null {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  return s === '' ? null : s;
}

export function submissionSummaryFromJson(
  raw: AnyRecord | null | undefined,
): ActivitySubmissionSummary {
  const r = (raw ?? {}) as AnyRecord;
  return {
    total_students: num(r.total_students),
    submitted: num(r.submitted),
    pending: num(r.pending),
    late: num(r.late),
    excused: num(r.excused),
    avg_score: numOrNull(r.avg_score),
  };
}

export function classActivityFromJson(raw: AnyRecord): ClassActivity {
  const submissions = submissionSummaryFromJson(
    (raw.submissions_summary as AnyRecord | undefined) ??
      (raw.submissions as AnyRecord | undefined),
  );
  // Fallback when backend doesn't ship a submissions_summary block:
  // derive counts from flat fields. Accepts both singular
  // (`student_count` / `submission_count` from teacher-summary's
  // nested `latest_activities`) and plural (`students_count` /
  // `submitted_count` from legacy index list) shapes.
  if (
    !submissions.total_students &&
    (raw.students_count !== undefined ||
      raw.student_count !== undefined ||
      raw.total_students !== undefined)
  ) {
    submissions.total_students = num(
      raw.students_count ?? raw.student_count ?? raw.total_students,
    );
  }
  if (
    !submissions.submitted &&
    (raw.submitted_count !== undefined ||
      raw.submission_count !== undefined ||
      raw.submissions_count !== undefined)
  ) {
    submissions.submitted = num(
      raw.submitted_count ?? raw.submission_count ?? raw.submissions_count,
    );
  }
  if (!submissions.pending && submissions.total_students > 0) {
    submissions.pending = Math.max(
      0,
      submissions.total_students - submissions.submitted - submissions.late,
    );
  }

  const rawType = raw.type ?? raw.jenis;
  return {
    id: String(raw.id ?? ''),
    title: String(
      raw.title ?? raw.judul ?? raw.topic ?? raw.topik ?? 'Kegiatan kelas',
    ),
    date: String(raw.date ?? raw.tanggal ?? ''),
    time: strOrNull(raw.time ?? raw.waktu),
    session: strOrNull(raw.session ?? raw.sesi),
    type: normalizeActivityType(rawType),
    raw_type: strOrNull(rawType),
    class_id: String(raw.class_id ?? raw.kelas_id ?? ''),
    class_name: String(
      raw.class_name ?? raw.kelas_name ?? raw.kelas ?? '',
    ),
    subject_id: String(raw.subject_id ?? raw.mata_pelajaran_id ?? ''),
    subject_name: String(
      raw.subject_name ?? raw.mata_pelajaran ?? '',
    ),
    chapter_label: strOrNull(raw.chapter_label ?? raw.bab),
    description: strOrNull(
      raw.description ?? raw.deskripsi ?? raw.uraian ?? raw.body,
    ),
    material: strOrNull(
      raw.material ?? raw.materi ?? raw.materi_terkait ?? raw.material_title,
    ),
    material_id: strOrNull(raw.material_id),
    reflection: strOrNull(raw.reflection ?? raw.refleksi),
    attachment_count: num(raw.attachment_count),
    has_reflection: Boolean(
      raw.has_reflection ?? raw.reflection ?? raw.refleksi,
    ),
    teacher_id: strOrNull(raw.teacher_id ?? raw.guru_id),
    teacher_name: strOrNull(raw.teacher_name ?? raw.guru_name),
    is_specific_target: Boolean(
      raw.is_specific_target ??
        raw.target_specific ??
        (raw.target_role === 'specific') ??
        (raw.target === 'specific') ??
        (raw.target === 'khusus') ??
        false,
    ),
    for_this_student: 'untuk_siswa_ini' in raw
      ? Boolean(raw.untuk_siswa_ini)
      : 'for_this_student' in raw
        ? Boolean(raw.for_this_student)
        : undefined,
    deadline: strOrNull(raw.deadline ?? raw.batas_waktu),
    chapter_title: strOrNull(
      raw.chapter_title ??
        raw.judul_bab ??
        ((raw.chapter as AnyRecord | undefined)?.title as unknown),
    ),
    sub_chapter_title: strOrNull(
      raw.sub_chapter_title ??
        raw.judul_sub_bab ??
        ((raw.subChapter as AnyRecord | undefined)?.title as unknown),
    ),
    additional_material: Array.isArray(raw.additional_material)
      ? (raw.additional_material as AnyRecord[])
          .map((item) => ({
            sub_chapter_title: String(item.sub_chapter_title ?? ''),
          }))
          .filter((m) => m.sub_chapter_title.length > 0)
      : undefined,
    is_read:
      'is_read' in raw
        ? Boolean(raw.is_read)
        : raw.read_at
          ? true
          : undefined,
    submissions,
  };
}

export function activitySubmissionRowFromJson(
  raw: AnyRecord,
): ActivitySubmissionRow {
  const rawStatus = String(raw.status ?? 'pending').toLowerCase();
  const status: SubmissionStatus =
    rawStatus === 'submitted' ||
    rawStatus === 'late' ||
    rawStatus === 'excused' ||
    rawStatus === 'pending'
      ? (rawStatus as SubmissionStatus)
      : 'pending';
  return {
    student_class_id: String(raw.student_class_id ?? ''),
    student_id: String(raw.student_id ?? ''),
    student_name: String(raw.student_name ?? raw.nama ?? '-'),
    status,
    score: numOrNull(raw.score),
    notes: strOrNull(raw.notes ?? raw.note),
  };
}

export function adminActivitySummaryPageFromJson(
  raw: AnyRecord,
): AdminActivitySummaryPage {
  const data = Array.isArray(raw.data) ? (raw.data as AnyRecord[]) : [];
  const kpiRaw = (raw.kpi as AnyRecord | undefined) ?? {};
  const pag = (raw.pagination as AnyRecord | undefined) ?? {};
  return {
    items: data.map(classActivityFromJson),
    kpi: {
      total: num(kpiRaw.total),
      this_week: num(kpiRaw.this_week),
      pending_submissions: num(kpiRaw.pending_submissions),
    },
    pagination: raw.pagination
      ? {
          current_page: num(pag.current_page) || 1,
          total_pages: num(pag.total_pages) || 1,
          total_items: num(pag.total_items),
          has_next_page: Boolean(pag.has_next_page),
        }
      : undefined,
  };
}

export function teacherActivitySummaryPageFromJson(
  raw: AnyRecord,
): TeacherActivitySummaryPage {
  const data = Array.isArray(raw.data) ? (raw.data as AnyRecord[]) : [];
  const kpiRaw = (raw.kpi as AnyRecord | undefined) ?? {};
  const pag = (raw.pagination as AnyRecord | undefined) ?? {};

  // Backend's teacher-summary returns groups per (class, subject)
  // with nested `latest_activities[]` — flatten into a single
  // chronological list while inheriting class/subject ids from
  // the parent group. Falls back to treating each row as a flat
  // activity when the nested shape isn't present (admin-style or
  // legacy responses).
  const items: ClassActivity[] = [];
  for (const row of data) {
    const nested = Array.isArray(row.latest_activities)
      ? (row.latest_activities as AnyRecord[])
      : null;
    if (nested && nested.length > 0) {
      for (const n of nested) {
        items.push(
          classActivityFromJson({
            // Inherit class/subject from the parent group when the
            // nested record doesn't carry them.
            class_id: row.class_id,
            class_name: row.class_name,
            subject_id: row.subject_id,
            subject_name: row.subject_name,
            ...n,
          }),
        );
      }
    } else {
      items.push(classActivityFromJson(row));
    }
  }

  // KPI shape varies by backend revision — `total` / `this_week` /
  // `pending_action` (new) or `monthly_count` / `weekly_count` /
  // `assignment_count` (Flutter legacy). Accept both so the strip
  // stays populated regardless.
  return {
    items,
    kpi: {
      total: num(kpiRaw.total ?? kpiRaw.monthly_count ?? items.length),
      this_week: num(kpiRaw.this_week ?? kpiRaw.weekly_count),
      pending_action: num(
        kpiRaw.pending_action ?? kpiRaw.assignment_count,
      ),
    },
    pagination: raw.pagination
      ? {
          current_page: num(pag.current_page) || 1,
          total_pages: num(pag.total_pages) || 1,
          total_items: num(pag.total_items),
          has_next_page: Boolean(pag.has_next_page),
        }
      : undefined,
  };
}
