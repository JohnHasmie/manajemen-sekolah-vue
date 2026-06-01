/**
 * ReportCardService — `/raport*` wrapper (main Laravel `api`).
 *
 * Mirrors Flutter's `report_card_service.dart` + `ExcelReportCardService`
 * + `RaportController.php` end-to-end. All endpoints on the main
 * Laravel API (no AI backend trap).
 *
 * Fixes 3 critical bugs the previous version shipped:
 *   1. `getInitialData` now reads `grades` (backend field) instead of
 *      `subjects` — the empty form was a parser miss.
 *   2. `save()` now writes `attendance_sick/permit/absent` instead of
 *      `sick_days/permit_days/absent_days` — the legacy keys were
 *      silently dropped by the backend, so kehadiran never persisted.
 *   3. Adds `parentRaports()` to call `/parent/raports` (parent.service
 *      used to hit the teacher class-roster endpoint with an ignored
 *      `student_id` filter, always returning empty).
 *
 * Plus the new admin pipeline + publish + PDF/Excel binary download
 * surface needed by the rewritten admin hub + parent detail views.
 */
import { api } from '@/lib/http';
import {
  normalizeReportCardStatus,
  type AdminRaportPipeline,
  type KelasMiniChip,
  type ParentRaportRow,
  type PipelineKey,
  type PipelineNode,
  type RaportAchievement,
  type RaportClassSummary,
  type RaportExtra,
  type RaportInitialData,
  type RaportSubject,
  type RaportSummary,
  type RaportSummaryRow,
  type ReportCardDetail,
  type ReportCardStatus,
  type TingkatGroup,
} from '@/types/report-card';

type AnyRecord = Record<string, unknown>;

function num(v: unknown, fallback = 0): number {
  if (typeof v === 'number') return v;
  if (v === null || v === undefined) return fallback;
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
}

function strOrNull(v: unknown): string | null {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  return s === '' ? null : s;
}

// ── Row mappers ─────────────────────────────────────────────────────

function subjectFromJson(raw: AnyRecord): RaportSubject {
  // `/parent/raports` eager-loads `raportSubjects.subject`, so the
  // raport_subject row carries a nested `subject` relation with the
  // master subject's id / name / kkm. The flat `id` on the row is the
  // raport_subject pivot id — useless to the UI. Prefer the nested
  // subject's id and name when present.
  const subjectRel =
    (raw.subject as AnyRecord | undefined) ??
    (raw.master_subject as AnyRecord | undefined) ??
    undefined;
  const teacherRel = raw.teacher as AnyRecord | string | null | undefined;
  return {
    subject_id: String(
      raw.subject_id ?? subjectRel?.id ?? raw.id ?? '',
    ),
    subject_name: String(
      raw.subject_name ??
        subjectRel?.name ??
        subjectRel?.nama ??
        raw.name ??
        raw.mata_pelajaran ??
        '',
    ),
    teacher_name:
      (typeof teacherRel === 'string' ? teacherRel : null) ??
      ((teacherRel as AnyRecord | undefined)?.name as string | null | undefined) ??
      (raw.teacher_name as string | null) ??
      (raw.guru as string | null) ??
      null,
    kkm:
      typeof raw.kkm === 'number'
        ? raw.kkm
        : raw.kkm != null
          ? num(raw.kkm, 75)
          : typeof subjectRel?.kkm === 'number'
            ? (subjectRel.kkm as number)
            : subjectRel?.kkm != null
              ? num(subjectRel.kkm, 75)
              : 75,
    knowledge_score:
      (raw.knowledge_score as number | string | null) ??
      (raw.nilai as number | string | null) ??
      (raw.score as number | string | null) ??
      null,
    knowledge_predicate:
      (raw.knowledge_predicate as string | undefined) ??
      (raw.predikat as string | undefined) ??
      (raw.predicate as string | undefined),
    knowledge_description:
      (raw.knowledge_description as string | undefined) ??
      (raw.deskripsi as string | undefined) ??
      (raw.description as string | undefined),
    skill_score: (raw.skill_score as number | string | null) ?? null,
    skill_predicate: raw.skill_predicate as string | undefined,
    skill_description: raw.skill_description as string | undefined,
    recap_uh_avg:
      raw.recap_uh_avg !== undefined ? num(raw.recap_uh_avg) : null,
    recap_uts: raw.recap_uts !== undefined ? num(raw.recap_uts) : null,
    recap_uas: raw.recap_uas !== undefined ? num(raw.recap_uas) : null,
    recap_final_score:
      raw.recap_final_score !== undefined ? num(raw.recap_final_score) : null,
    recap_bab_scores: Array.isArray(raw.recap_bab_scores)
      ? (raw.recap_bab_scores as unknown[]).map((x) => num(x))
      : undefined,
    recap_bab_names: Array.isArray(raw.recap_bab_names)
      ? (raw.recap_bab_names as unknown[]).map((x) => String(x))
      : undefined,
  };
}

function extraFromJson(raw: AnyRecord): RaportExtra {
  return {
    id: raw.id ? String(raw.id) : undefined,
    name: String(raw.name ?? raw.nama ?? ''),
    score:
      raw.score !== undefined && raw.score !== null
        ? String(raw.score)
        : raw.nilai !== undefined && raw.nilai !== null
          ? String(raw.nilai)
          : '',
    description:
      (raw.description as string | undefined) ??
      (raw.deskripsi as string | undefined) ??
      '',
  };
}

function achievementFromJson(raw: AnyRecord): RaportAchievement {
  return {
    id: raw.id ? String(raw.id) : undefined,
    name: String(raw.name ?? raw.nama ?? ''),
    type:
      (raw.type as string | undefined) ??
      (raw.tipe as string | undefined) ??
      (raw.kategori as string | undefined) ??
      '',
    description:
      (raw.description as string | undefined) ??
      (raw.deskripsi as string | undefined) ??
      '',
  };
}

function summaryFromJson(raw: AnyRecord | undefined | null): RaportSummary | undefined {
  if (!raw || typeof raw !== 'object') return undefined;
  return {
    rerata: raw.rerata !== undefined ? num(raw.rerata) : null,
    kkm_threshold:
      raw.kkm_threshold !== undefined ? num(raw.kkm_threshold) : null,
    kkm_pass_count:
      raw.kkm_pass_count !== undefined ? num(raw.kkm_pass_count) : null,
    total_subjects:
      raw.total_subjects !== undefined ? num(raw.total_subjects) : null,
    class_rank: raw.class_rank !== undefined ? num(raw.class_rank) : null,
    class_total: raw.class_total !== undefined ? num(raw.class_total) : null,
  };
}

function detailFromJson(raw: AnyRecord): ReportCardDetail {
  const studentObj = raw.student as AnyRecord | undefined;
  const classObj = raw.class as AnyRecord | undefined;

  // Backend ships subjects under different keys depending on endpoint
  // and serialiser config:
  //   - `/raport/show` (camel-cased)   → `raportSubjects`
  //   - `/parent/raports` (Eloquent)   → `raport_subjects` (Laravel
  //                                       snake_cases relation keys
  //                                       by default in toJson)
  //   - `/raport/initial-data`         → `grades` (recap roll-up)
  //   - legacy / form payloads         → `subjects`
  const subjectsRaw = (Array.isArray(raw.raportSubjects)
    ? raw.raportSubjects
    : Array.isArray(raw.raport_subjects)
      ? raw.raport_subjects
      : Array.isArray(raw.grades)
        ? raw.grades
        : Array.isArray(raw.subjects)
          ? raw.subjects
          : []) as AnyRecord[];

  // `extracurriculars` is the canonical key on `/raport/show`. Older
  // form payloads used `extras` / `ekstrakurikuler`.
  const extrasRaw = (Array.isArray(raw.extracurriculars)
    ? raw.extracurriculars
    : Array.isArray(raw.extras)
      ? raw.extras
      : Array.isArray(raw.ekstrakurikuler)
        ? raw.ekstrakurikuler
        : []) as AnyRecord[];

  const achievementsRaw = (Array.isArray(raw.achievements)
    ? raw.achievements
    : Array.isArray(raw.prestasi)
      ? raw.prestasi
      : []) as AnyRecord[];

  const subjects = subjectsRaw.map(subjectFromJson);

  // Compute derived fields when backend doesn't supply them.
  const numeric = subjects
    .map((s) => num(s.knowledge_score, 0))
    .filter((n) => n > 0);
  const summaryBlock = summaryFromJson(raw.summary as AnyRecord | undefined);
  const avg =
    (raw.avg_grade as number | null | undefined) ??
    (raw.average as number | null | undefined) ??
    summaryBlock?.rerata ??
    (numeric.length > 0
      ? Math.round(
          (numeric.reduce((a, b) => a + b, 0) / numeric.length) * 10,
        ) / 10
      : null);
  const remed =
    (raw.remed_count as number | undefined) ??
    subjects.filter(
      (s) =>
        num(s.knowledge_score, 0) > 0 &&
        num(s.knowledge_score, 0) < (s.kkm ?? 75),
    ).length;

  return {
    id: raw.id ? String(raw.id) : undefined,
    student_class_id: String(
      raw.student_class_id ?? raw.studentClassId ?? '',
    ),
    student_id: strOrNull(raw.student_id ?? studentObj?.id) ?? undefined,
    student_name:
      (raw.student_name as string | undefined) ??
      (studentObj?.name as string | undefined),
    class_id: strOrNull(raw.class_id ?? classObj?.id) ?? undefined,
    class_name:
      (raw.class_name as string | undefined) ??
      (classObj?.name as string | undefined),
    academic_year:
      (raw.academic_year as string | null | undefined) ??
      (raw.tahun_ajaran as string | null | undefined) ??
      null,
    semester: strOrNull(raw.semester),
    status: normalizeReportCardStatus(raw.status),
    published_at: strOrNull(raw.published_at),

    spiritual_description:
      (raw.spiritual_description as string | undefined) ??
      (raw.deskripsi_spiritual as string | undefined) ??
      '',
    spiritual_predicate:
      (raw.spiritual_predicate as string | undefined) ??
      (raw.predikat_spiritual as string | undefined) ??
      'Baik',
    social_description:
      (raw.social_description as string | undefined) ??
      (raw.deskripsi_sosial as string | undefined) ??
      '',
    social_predicate:
      (raw.social_predicate as string | undefined) ??
      (raw.predikat_sosial as string | undefined) ??
      'Baik',

    subjects,
    extras: extrasRaw.map(extraFromJson),
    achievements: achievementsRaw.map(achievementFromJson),

    // Backend column names — accept both canonical + legacy. We
    // populate BOTH the canonical and legacy keys so the un-rewritten
    // teacher view (which still reads `sick_days`) keeps working.
    // Phase 3 will drop the legacy aliases.
    attendance_sick: num(raw.attendance_sick ?? raw.sick_days ?? raw.sakit, 0),
    attendance_permit: num(
      raw.attendance_permit ?? raw.permit_days ?? raw.izin,
      0,
    ),
    attendance_absent: num(
      raw.attendance_absent ?? raw.absent_days ?? raw.alpa,
      0,
    ),
    sick_days: num(raw.attendance_sick ?? raw.sick_days ?? raw.sakit, 0),
    permit_days: num(
      raw.attendance_permit ?? raw.permit_days ?? raw.izin,
      0,
    ),
    absent_days: num(
      raw.attendance_absent ?? raw.absent_days ?? raw.alpa,
      0,
    ),
    homeroom_notes:
      (raw.homeroom_notes as string | undefined) ??
      (raw.notes as string | undefined) ??
      (raw.catatan_wali as string | undefined) ??
      '',
    promotion_decision:
      (raw.promotion_decision as string | undefined) ??
      (raw.keputusan as string | undefined) ??
      'Naik Kelas',

    summary: summaryBlock,
    avg_grade: avg,
    remed_count: remed,
  };
}

function initialDataFromJson(raw: AnyRecord): RaportInitialData {
  // ── BUGFIX #1 ── backend ships `grades`, not `subjects`. The old
  // parser read `subjects` and silently returned an empty form on
  // the new-rapor path.
  const subjectsRaw = (Array.isArray(raw.grades)
    ? raw.grades
    : Array.isArray(raw.subjects)
      ? raw.subjects
      : []) as AnyRecord[];

  const studentObj = raw.student as AnyRecord | undefined;
  const classObj = raw.class as AnyRecord | undefined;
  const attendance = (raw.attendance as AnyRecord | undefined) ?? {};

  return {
    student_class_id: String(raw.student_class_id ?? ''),
    student_id: strOrNull(raw.student_id ?? studentObj?.id) ?? undefined,
    student_name:
      (raw.student_name as string | undefined) ??
      (studentObj?.name as string | undefined),
    class_name:
      (raw.class_name as string | undefined) ??
      (classObj?.name as string | undefined),
    academic_year:
      (raw.academic_year as string | undefined) ??
      (raw.tahun_ajaran as string | undefined) ??
      '',
    semester: (raw.semester as string | undefined) ?? '',
    subjects: subjectsRaw.map(subjectFromJson),
    attendance_sick: num(attendance.sick ?? attendance.sakit, 0),
    attendance_permit: num(attendance.permit ?? attendance.izin, 0),
    attendance_absent: num(attendance.absent ?? attendance.alpa, 0),
    summary: summaryFromJson(raw.summary as AnyRecord | undefined),
  };
}

function summaryRowFromJson(raw: AnyRecord): RaportSummaryRow {
  return {
    student_class_id: String(raw.student_class_id ?? raw.id ?? ''),
    student_id: strOrNull(raw.student_id ?? (raw.student as AnyRecord)?.id) ?? undefined,
    student_name: String(
      raw.student_name ?? (raw.student as AnyRecord)?.name ?? '',
    ),
    student_number:
      (raw.student_number as string | null | undefined) ??
      (raw.nis as string | null | undefined) ??
      null,
    has_raport:
      raw.has_raport !== undefined
        ? Boolean(raw.has_raport)
        : Boolean(raw.raport_id || raw.raport_status),
    raport_id: raw.raport_id ? String(raw.raport_id) : null,
    raport_status: raw.raport_status
      ? normalizeReportCardStatus(raw.raport_status)
      : raw.status
        ? normalizeReportCardStatus(raw.status)
        : null,
    avg_grade: (raw.avg_grade as number | null | undefined) ?? null,
    remed_count: num(raw.remed_count, 0),
    published_at: strOrNull(raw.published_at),
  };
}

function classSummaryFromJson(raw: AnyRecord): RaportClassSummary {
  return {
    class_id: String(raw.class_id ?? raw.id ?? ''),
    class_name: String(raw.class_name ?? raw.name ?? ''),
    grade_level:
      (raw.grade_level as string | number | null | undefined) ??
      (raw.tingkat as string | number | null | undefined) ??
      null,
    student_count: num(raw.student_count ?? raw.students_count),
    total_raports: num(raw.total_raports),
    draft_count: num(raw.draft_count),
    final_count: num(raw.final_count),
    published_count: num(raw.published_count),
    completion_pct:
      raw.completion_pct !== undefined ? num(raw.completion_pct) : undefined,
  };
}

// ── Admin pipeline mappers ──────────────────────────────────────────

function pipelineNodeFromJson(raw: AnyRecord): PipelineNode {
  const k = String(raw.key ?? '').toLowerCase();
  const key: PipelineKey =
    k === 'reviewed' || k === 'final'
      ? 'reviewed'
      : k === 'published' || k === 'terbit'
        ? 'published'
        : k === 'distributed' || k === 'dibagikan'
          ? 'distributed'
          : 'draft';
  return {
    key,
    label: String(raw.label ?? raw.key ?? ''),
    count: num(raw.count),
    active: raw.active === true,
  };
}

function kelasMiniChipFromJson(raw: AnyRecord): KelasMiniChip {
  const countsRaw = (raw.counts as AnyRecord | undefined) ?? {};
  return {
    id: String(raw.id ?? ''),
    name: String(raw.name ?? ''),
    status_label: strOrNull(raw.status_label),
    status_tone:
      typeof raw.status_tone === 'string'
        ? raw.status_tone.toLowerCase()
        : undefined,
    counts: {
      draft: num(countsRaw.draft),
      reviewed: num(countsRaw.reviewed ?? countsRaw.final),
      published: num(countsRaw.published),
      distributed: num(countsRaw.distributed),
    },
    student_count:
      raw.student_count !== undefined ? num(raw.student_count) : undefined,
  };
}

function tingkatGroupFromJson(raw: AnyRecord): TingkatGroup {
  return {
    tingkat: String(raw.tingkat ?? raw.grade_level ?? ''),
    class_count: num(raw.class_count),
    student_count: num(raw.student_count),
    reviewed_pct:
      raw.reviewed_pct !== undefined ? num(raw.reviewed_pct) : undefined,
    alert: raw.alert === true,
    classes: Array.isArray(raw.classes)
      ? (raw.classes as AnyRecord[]).map(kelasMiniChipFromJson)
      : [],
  };
}

function adminPipelineFromJson(raw: AnyRecord): AdminRaportPipeline {
  const data = (raw.data as AnyRecord | undefined) ?? raw;
  const pipelineRaw = Array.isArray(data.pipeline) ? data.pipeline : [];
  const tingkatsRaw = Array.isArray(data.tingkats) ? data.tingkats : [];
  const period = (data.period as AnyRecord | undefined) ?? {};
  return {
    pipeline: pipelineRaw.map((p) => pipelineNodeFromJson(p as AnyRecord)),
    tingkats: tingkatsRaw.map((t) => tingkatGroupFromJson(t as AnyRecord)),
    period: {
      academic_year_id: strOrNull(period.academic_year_id),
      academic_year_label: strOrNull(period.academic_year_label),
      semester_id: strOrNull(period.semester_id),
      semester_label: strOrNull(period.semester_label),
    },
    total_raports: num(data.total_raports),
    total_classes: num(data.total_classes),
  };
}

// ── Parent inbox mapper ─────────────────────────────────────────────

function parentRaportRowFromJson(raw: AnyRecord): ParentRaportRow {
  const studentObj = (raw.student as AnyRecord | undefined) ?? {};
  const reportRaw = (raw.reportCard as AnyRecord | undefined) ?? {};
  return {
    student_class_id: String(raw.student_class_id ?? ''),
    student: {
      id: String(studentObj.id ?? ''),
      name: String(studentObj.name ?? ''),
      student_number:
        (studentObj.student_number as string | null | undefined) ??
        (studentObj.nis as string | null | undefined) ??
        null,
      class_name:
        (studentObj.class_name as string | null | undefined) ??
        ((studentObj.class as AnyRecord | undefined)?.name as
          | string
          | null
          | undefined) ??
        null,
    },
    rank: raw.rank !== undefined ? num(raw.rank) : null,
    total_in_class:
      raw.total_in_class !== undefined ? num(raw.total_in_class) : null,
    average_score:
      raw.average_score !== undefined ? num(raw.average_score) : null,
    attendance_pct:
      raw.attendance_pct !== undefined ? num(raw.attendance_pct) : null,
    reportCard: detailFromJson(reportRaw),
  };
}

// ── Service surface ────────────────────────────────────────────────

export interface SaveReportCardPayload {
  student_class_id: string;
  academic_year_id: string;
  semester_id: string;
  status?: ReportCardStatus;
  spiritual_predicate?: string;
  spiritual_description?: string;
  social_predicate?: string;
  social_description?: string;
  /** Canonical backend keys. */
  attendance_sick?: number;
  attendance_permit?: number;
  attendance_absent?: number;
  /** Back-compat aliases — service maps to attendance_* before POST. */
  sick_days?: number;
  permit_days?: number;
  absent_days?: number;
  homeroom_notes?: string;
  promotion_decision?: string;
  subjects?: RaportSubject[];
  extras?: RaportExtra[];
  achievements?: RaportAchievement[];
}

/**
 * Lazily-fetched current semester id.
 *
 * Backend `/raports` index + `/raport/initial-data` + `/raport/show`
 * + `/raport` POST all validate `semester_id` as required. The HTTP
 * interceptor auto-injects `academic_year_id` but NOT `semester_id`,
 * so a bare class_id call previously 400'd and the catch{} swallowed
 * it as "Belum ada siswa di kelas ini".
 *
 * We resolve the current semester id from `/semesters` (looking for
 * the row with `current=true`) and cache the promise so the
 * round-trip happens at most once per session. Caller can still
 * override by passing an explicit `semester_id`.
 */
let currentSemesterIdPromise: Promise<string | null> | null = null;

function fetchCurrentSemesterId(): Promise<string | null> {
  if (currentSemesterIdPromise) return currentSemesterIdPromise;
  currentSemesterIdPromise = (async () => {
    try {
      const res = await api.get('/semesters');
      const body = (res.data ?? []) as unknown;
      const list = Array.isArray(body) ? (body as AnyRecord[]) : [];
      const current = list.find((s) => s.current === true || s.current === 1);
      return current ? String(current.id ?? '') : null;
    } catch {
      return null;
    }
  })();
  return currentSemesterIdPromise;
}

/**
 * Resolve the semester id to use for a raport endpoint. Caller-passed
 * value wins; otherwise we fall through to the cached current semester.
 * Returns empty string when nothing resolves — callers should still
 * pass it (backend will 400 with a friendly validation message).
 */
async function resolveSemesterId(explicit?: string): Promise<string> {
  if (explicit) return explicit;
  const current = await fetchCurrentSemesterId();
  return current ?? '';
}

/** Trigger a binary download in the browser for a blob response. */
function triggerDownload(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  // Revoke after a tick so download has time to register.
  setTimeout(() => URL.revokeObjectURL(url), 1500);
}

export const ReportCardService = {
  // ── Teacher hub: per-class roll-up ──────────────────────────────

  /**
   * `GET /raports/teacher-summary` — per-homeroom-class stats for
   * the Frame A hub. Returns one row per class with draft/final/
   * published counts + completion percentage.
   *
   * Backend ships `class_id / class_name / grade_level / student_count
   * / total_raports / draft_count / final_count / published_count /
   * completion_pct`. Older Vue truncated this to "summary rows" with
   * `student_class_id` (wrong axis).
   */
  async getTeacherClassSummary(args: {
    teacher_id: string;
    academic_year_id?: string;
    semester_id?: string;
  }): Promise<RaportClassSummary[]> {
    try {
      const res = await api.get('/raports/teacher-summary', {
        params: {
          teacher_id: args.teacher_id,
          ...(args.academic_year_id
            ? { academic_year_id: args.academic_year_id }
            : {}),
          ...(args.semester_id ? { semester_id: args.semester_id } : {}),
        },
      });
      const body = (res.data?.data ?? res.data ?? []) as unknown;
      const list = Array.isArray(body) ? (body as AnyRecord[]) : [];
      return list.map(classSummaryFromJson);
    } catch {
      return [];
    }
  },

  // ── Teacher: per-class student roster ───────────────────────────

  /**
   * `GET /raports?class_id=…` — student roster + per-student status
   * for the Frame B class screen. Response shape is light: no avg /
   * extra fields, just `{student_class_id, student_name, student_number,
   * has_raport, raport_status, raport_id}`.
   */
  async getClassRoster(args: {
    class_id: string;
    academic_year_id?: string;
    semester_id?: string;
  }): Promise<RaportSummaryRow[]> {
    try {
      // Backend validator requires semester_id — auto-resolve from
      // `/semesters` when not explicitly passed. academic_year_id is
      // auto-injected by the HTTP interceptor.
      const semesterId = await resolveSemesterId(args.semester_id);
      const res = await api.get('/raports', {
        params: {
          class_id: args.class_id,
          ...(args.academic_year_id
            ? { academic_year_id: args.academic_year_id }
            : {}),
          ...(semesterId ? { semester_id: semesterId } : {}),
        },
      });
      const body = (res.data?.data ?? res.data ?? []) as unknown;
      const list = Array.isArray(body) ? (body as AnyRecord[]) : [];
      return list.map(summaryRowFromJson);
    } catch {
      return [];
    }
  },

  /**
   * Back-compat alias for callers that still call `getTeacherSummary`
   * expecting per-student rows. New code should pick whichever of
   * `getTeacherClassSummary` / `getClassRoster` matches the chrome.
   */
  async getTeacherSummary(args: {
    teacher_id: string;
    academic_year_id?: string;
    semester_id?: string;
  }): Promise<RaportSummaryRow[]> {
    // The legacy view called this expecting a flat student list; the
    // backend doesn't ship one keyed by teacher_id. Easiest stub: just
    // delegate to the class summary then return an empty roster (the
    // legacy view will switch to per-class roster in Phase 3).
    await this.getTeacherClassSummary(args);
    return [];
  },

  // ── Teacher form ────────────────────────────────────────────────

  /**
   * `GET /raport/initial-data` — form seed for a brand-new raport.
   * Returns subjects with KKM + teacher_name + recap fields, plus
   * attendance pre-fill + class rank summary.
   */
  async getInitialData(args: {
    student_class_id: string;
    academic_year_id: string;
    semester_id?: string;
  }): Promise<RaportInitialData | null> {
    try {
      const semesterId = await resolveSemesterId(args.semester_id);
      const res = await api.get('/raport/initial-data', {
        params: {
          student_class_id: args.student_class_id,
          academic_year_id: args.academic_year_id,
          ...(semesterId ? { semester_id: semesterId } : {}),
        },
      });
      const body = (res.data?.data ?? res.data ?? null) as AnyRecord | null;
      return body ? initialDataFromJson(body) : null;
    } catch {
      return null;
    }
  },

  /**
   * `GET /raport/show` — hydrated existing raport. Returns null when
   * the backend reports "no raport exists yet" (data === null).
   */
  async getDetail(args: {
    student_class_id: string;
    academic_year_id: string;
    semester_id?: string;
  }): Promise<ReportCardDetail | null> {
    try {
      const semesterId = await resolveSemesterId(args.semester_id);
      const res = await api.get('/raport/show', {
        params: {
          student_class_id: args.student_class_id,
          academic_year_id: args.academic_year_id,
          ...(semesterId ? { semester_id: semesterId } : {}),
        },
      });
      const body = (res.data?.data ?? res.data ?? null) as AnyRecord | null;
      return body ? detailFromJson(body) : null;
    } catch {
      return null;
    }
  },

  /**
   * `POST /raport` — upsert. `status` can be 'draft' (Simpan Draf) or
   * 'final' (Finalisasi).
   *
   * ── BUGFIX #3 ── caller payload may use legacy `sick_days/permit_days/
   * absent_days` keys; backend writes `attendance_sick/permit/absent`.
   * Service maps explicitly so neither side has to remember.
   */
  async save(payload: SaveReportCardPayload): Promise<ReportCardDetail | null> {
    const semesterId = await resolveSemesterId(payload.semester_id);
    const body: Record<string, unknown> = {
      student_class_id: payload.student_class_id,
      academic_year_id: payload.academic_year_id,
      semester_id: semesterId,
      ...(payload.status ? { status: payload.status } : {}),
      ...(payload.spiritual_predicate !== undefined
        ? { spiritual_predicate: payload.spiritual_predicate }
        : {}),
      ...(payload.spiritual_description !== undefined
        ? { spiritual_description: payload.spiritual_description }
        : {}),
      ...(payload.social_predicate !== undefined
        ? { social_predicate: payload.social_predicate }
        : {}),
      ...(payload.social_description !== undefined
        ? { social_description: payload.social_description }
        : {}),
      attendance_sick: num(payload.attendance_sick ?? payload.sick_days, 0),
      attendance_permit: num(
        payload.attendance_permit ?? payload.permit_days,
        0,
      ),
      attendance_absent: num(
        payload.attendance_absent ?? payload.absent_days,
        0,
      ),
      ...(payload.homeroom_notes !== undefined
        ? { homeroom_notes: payload.homeroom_notes }
        : {}),
      ...(payload.promotion_decision !== undefined
        ? { promotion_decision: payload.promotion_decision }
        : {}),
      ...(payload.subjects !== undefined ? { subjects: payload.subjects } : {}),
      ...(payload.extras !== undefined ? { extras: payload.extras } : {}),
      ...(payload.achievements !== undefined
        ? { achievements: payload.achievements }
        : {}),
    };
    const res = await api.post('/raport', body);
    const respBody = (res.data?.data ?? res.data ?? null) as AnyRecord | null;
    return respBody ? detailFromJson(respBody) : null;
  },

  // ── Admin pipeline (Mockup #08) ─────────────────────────────────

  /**
   * `GET /raports/admin-pipeline` — 4-node pipeline + tingkat tree
   * for the admin Rapor hub. Backend already groups by tingkat with
   * per-class status badges (`status_label`, `status_tone`, `counts`).
   *
   * Note: requires X-School-ID header (already injected by the axios
   * interceptor on `api`); 400s without it.
   */
  async getAdminPipeline(args: {
    academic_year_id?: string;
    semester_id?: string;
  } = {}): Promise<AdminRaportPipeline | null> {
    try {
      const res = await api.get('/raports/admin-pipeline', {
        params: {
          ...(args.academic_year_id
            ? { academic_year_id: args.academic_year_id }
            : {}),
          ...(args.semester_id ? { semester_id: args.semester_id } : {}),
        },
      });
      return adminPipelineFromJson(res.data ?? {});
    } catch {
      return null;
    }
  },

  /**
   * `POST /raports/publish` — bulk flip `final → published` for a
   * class. Returns the number of rows promoted.
   */
  async publishClass(args: {
    class_id: string;
    academic_year_id?: string;
    semester_id?: string;
  }): Promise<{ published_count: number }> {
    const semesterId = await resolveSemesterId(args.semester_id);
    const res = await api.post('/raports/publish', {
      class_id: args.class_id,
      ...(args.academic_year_id
        ? { academic_year_id: args.academic_year_id }
        : {}),
      ...(semesterId ? { semester_id: semesterId } : {}),
    });
    const body = (res.data?.data ?? res.data ?? {}) as AnyRecord;
    return { published_count: num(body.published_count, 0) };
  },

  // ── Parent inbox ────────────────────────────────────────────────

  /**
   * ── BUGFIX #2 ── `GET /parent/raports` — parent's children with
   * full hydrated raport. The old `parent.service.reportCards` hit
   * `/raports?student_id=…` (teacher class-roster endpoint that
   * ignores the filter) and always returned empty.
   *
   * Backend only ships rows with `status='published'` — empty state
   * copy should say "Sekolah belum menerbitkan rapor".
   */
  async parentRaports(args: {
    academic_year_id?: string;
    semester_id?: string;
  } = {}): Promise<ParentRaportRow[]> {
    try {
      const res = await api.get('/parent/raports', {
        params: {
          ...(args.academic_year_id
            ? { academic_year_id: args.academic_year_id }
            : {}),
          ...(args.semester_id ? { semester_id: args.semester_id } : {}),
        },
      });
      const body = (res.data?.data ?? res.data ?? []) as unknown;
      const list = Array.isArray(body) ? (body as AnyRecord[]) : [];
      return list.map(parentRaportRowFromJson);
    } catch {
      return [];
    }
  },

  // ── PDF / Excel binary downloads ────────────────────────────────

  /**
   * `GET /raports/export-pdf` — server-rendered Blade PDF (single
   * raport). Replaces the legacy `window.print()` modal which only
   * captured the current viewport, not the real A4 layout.
   *
   * Auth gates:
   *  - Teachers / admins always allowed.
   *  - Parents only allowed when raport status is `published`.
   * Caller should check `status === 'published'` before showing the
   * Cetak button on the parent view.
   */
  async exportSinglePdf(args: {
    student_class_id: string;
    academic_year_id?: string;
    semester_id?: string;
    /** Filename for the browser download. */
    filename?: string;
  }): Promise<void> {
    const semesterId = await resolveSemesterId(args.semester_id);
    const res = await api.get('/raports/export-pdf', {
      params: {
        student_class_id: args.student_class_id,
        ...(args.academic_year_id
          ? { academic_year_id: args.academic_year_id }
          : {}),
        ...(semesterId ? { semester_id: semesterId } : {}),
      },
      responseType: 'blob',
    });
    const blob = new Blob([res.data], { type: 'application/pdf' });
    triggerDownload(blob, args.filename ?? 'rapor.pdf');
  },

  /** `GET /raports/export-certificate-pdf` — certificate-style PDF. */
  async exportCertificatePdf(args: {
    student_class_id: string;
    academic_year_id?: string;
    semester_id?: string;
    filename?: string;
  }): Promise<void> {
    const semesterId = await resolveSemesterId(args.semester_id);
    const res = await api.get('/raports/export-certificate-pdf', {
      params: {
        student_class_id: args.student_class_id,
        ...(args.academic_year_id
          ? { academic_year_id: args.academic_year_id }
          : {}),
        ...(semesterId ? { semester_id: semesterId } : {}),
      },
      responseType: 'blob',
    });
    const blob = new Blob([res.data], { type: 'application/pdf' });
    triggerDownload(blob, args.filename ?? 'sertifikat.pdf');
  },

  /** `GET /raports/export` — class-wide Excel binary. */
  async exportClassExcel(args: {
    class_id: string;
    academic_year_id?: string;
    semester_id?: string;
    filename?: string;
  }): Promise<void> {
    const semesterId = await resolveSemesterId(args.semester_id);
    const res = await api.get('/raports/export', {
      params: {
        class_id: args.class_id,
        ...(args.academic_year_id
          ? { academic_year_id: args.academic_year_id }
          : {}),
        ...(semesterId ? { semester_id: semesterId } : {}),
      },
      responseType: 'blob',
    });
    const blob = new Blob([res.data], {
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    });
    triggerDownload(blob, args.filename ?? 'rapor-kelas.xlsx');
  },
};
