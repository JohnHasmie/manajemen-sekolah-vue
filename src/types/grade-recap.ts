/**
 * Grade Recap (Rekap Nilai) types — mirror Flutter's grade_recap
 * domain. Distinct from `grades.ts` (assessment-level grades): a
 * recap is one *aggregated* row per (student × subject × academic
 * year) holding chapter (Bab) scores, UTS, UAS, final, skill,
 * predikat, and a narrative deskripsi.
 *
 * Backend lives in `GradeRecapController` + `GradeController::admin
 * RecapOverview`. The teacher input flow stores one row per student
 * via `POST /grade-recaps/batch` after the matrix is edited.
 */

// ── Detail / matrix row (`GET /grade-recaps`) ──
//
// One row per student in the (class, subject) matrix. Students
// without a recap yet are still returned with `has_recap=false` so
// the matrix can render empty editable rows.

export interface GradeRecapRow {
  /** student_classes pivot id — required for POST/batch payloads. */
  student_class_id: string;
  student_id: string;
  student_name: string;
  /** NISN (national student number). */
  nis: string | null;
  /** True when the backend already has a row for this (student, subject). */
  has_recap: boolean;
  /** Predicate label (A / B / C / D or very_good/good/fair/poor). */
  predicate: string | null;
  /** Narrative description shown on the raport. */
  description: string | null;
  /**
   * Per-chapter scores. The array index aligns with `chapter_names`
   * and with the chapter columns in the matrix. `null` slots =
   * unfilled.
   */
  chapter_scores: (number | null)[] | null;
  /** Display names for each chapter column. */
  chapter_names: string[] | null;
  midterm_score: number | null;
  final_exam_score: number | null;
  /** Auto-computed or teacher-overridden final. */
  final_score: number | null;
  /** Keterampilan / skill score (optional in many schools). */
  skill_score: number | null;
}

// ── Save payload (`POST /grade-recaps` / `POST /grade-recaps/batch`) ──

export interface GradeRecapSavePayload {
  student_class_id: string;
  /** subject_schools.id (NOT the master subjects.id — backend maps it). */
  subject_id: string;
  academic_year_id: number;
  predicate?: string | null;
  description?: string | null;
  final_score?: number | null;
  skill_score?: number | null;
  chapter_scores?: (number | null)[] | null;
  chapter_names?: string[] | null;
  midterm_score?: number | null;
  final_exam_score?: number | null;
}

export interface GradeRecapBatchResponse {
  success: boolean;
  message?: string;
  saved?: number;
  skipped?: number;
  error?: string;
}

// ── Teacher Summary (`GET /grade-recaps/teacher-summary`) ──
//
// Returns one node per (class, subject) the teacher teaches, with
// completion stats so the overview card can render progress + avg
// without a second round-trip.

export interface TeacherGradeRecapSubject {
  id: string;
  name: string;
  code: string | null;
  /** Wali-kelas view only: subject teacher's name. */
  teacher_id?: string | null;
  teacher_name?: string | null;
  /** Students with at least one recap entry recorded. */
  recap_count: number;
  total_students: number;
  /** 0–100. */
  completion_pct: number;
  /** Avg final score across recapped students; null when 0 recaps. */
  avg_final_score: number | null;
  /** Number of chapter columns the matrix would render. */
  chapter_count: number;
  /** Total numeric grade entries across all chapter_scores arrays. */
  entries_count?: number;
}

export interface TeacherGradeRecapClass {
  class_id: string;
  class_name: string;
  student_count: number;
  subjects: TeacherGradeRecapSubject[];
}

export interface TeacherGradeRecapSummary {
  total_classes: number;
  total_students: number;
  /** Sum over (class, subject) of student_count — denominator at 100% fill. */
  total_expected_recaps: number;
  /** Sum over (class, subject) of recap_count. */
  total_filled_recaps: number;
  /** 0–100. */
  overall_completion_pct: number;
  /** recap_count-weighted average; null when nothing's filled. */
  overall_avg_score: number | null;
}

export interface TeacherGradeRecapResponse {
  data: TeacherGradeRecapClass[];
  summary: TeacherGradeRecapSummary;
}

// ── Admin Overview (`GET /grades/admin-recap-overview`) ──

export interface AdminRecapOverviewRow {
  class_id: string;
  class_name: string;
  /**
   * Master subject id (bigint, e.g. "3"). Stored on
   * `grade_recaps.subject_id` for legacy reasons; NOT a UUID. Do not
   * pass this to the matrix drill endpoint (`/grade-recaps`) — it
   * validates `subject_id` as a UUID. Use `subject_school_id` below.
   */
  subject_id: string;
  /**
   * Per-school subject UUID (`subject_schools.id`). The backend
   * resolves it from `subject_id × school_id` so admin clients can
   * drill straight into the matrix. May be null when the school
   * has no `subject_schools` row for the master subject.
   */
  subject_school_id: string | null;
  subject_name: string;
  teacher_id: string | null;
  teacher_name: string | null;
  students_total: number;
  students_with_recap: number;
  /** 0–100 cells-filled / cells-expected (Bab + UTS + UAS). */
  progress_pct: number;
  avg_final_score: number | null;
  /** % of students whose final_score ≥ 75. */
  pass_rate: number;
  chapter_total: number;
  chapter_filled: number;
  midterm_done: number;
  final_exam_done: number;
  /** True when every student has every chapter + midterm + final_exam filled. */
  is_complete: boolean;
}

export interface AdminRecapOverviewSummary {
  total_slice: number;
  completed_slice: number;
  /** 0–100. */
  avg_progress: number;
}

export interface AdminRecapOverviewResponse {
  summary: AdminRecapOverviewSummary;
  rows: AdminRecapOverviewRow[];
}

// ── Parsers (defensive, mirror the *FromJson helpers elsewhere) ──

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
  const s = String(v);
  return s === '' ? null : s;
}

export function gradeRecapRowFromJson(raw: AnyRecord): GradeRecapRow {
  const chapterScoresRaw = raw.chapter_scores ?? raw.bab_scores;
  const chapterNamesRaw = raw.chapter_names ?? raw.bab_names;
  return {
    student_class_id: String(raw.student_class_id ?? ''),
    student_id: String(raw.student_id ?? ''),
    student_name: String(raw.student_name ?? '-'),
    nis: strOrNull(raw.nis),
    has_recap: Boolean(raw.has_recap),
    predicate: strOrNull(raw.predicate ?? raw.predikat),
    description: strOrNull(raw.description ?? raw.deskripsi),
    chapter_scores: Array.isArray(chapterScoresRaw)
      ? chapterScoresRaw.map((v) => numOrNull(v))
      : null,
    chapter_names: Array.isArray(chapterNamesRaw)
      ? chapterNamesRaw.map((v) => String(v))
      : null,
    midterm_score: numOrNull(raw.midterm_score ?? raw.uts_score),
    final_exam_score: numOrNull(raw.final_exam_score ?? raw.uas_score),
    final_score: numOrNull(raw.final_score),
    skill_score: numOrNull(raw.skill_score),
  };
}

export function teacherGradeRecapResponseFromJson(
  raw: AnyRecord,
): TeacherGradeRecapResponse {
  const data = Array.isArray(raw.data) ? (raw.data as AnyRecord[]) : [];
  const summaryRaw = (raw.summary as AnyRecord | undefined) ?? {};
  return {
    data: data.map((cls) => ({
      class_id: String(cls.class_id ?? ''),
      class_name: String(cls.class_name ?? '-'),
      student_count: num(cls.student_count),
      subjects: Array.isArray(cls.subjects)
        ? (cls.subjects as AnyRecord[]).map((s) => ({
            id: String(s.id ?? ''),
            name: String(s.name ?? '-'),
            code: strOrNull(s.code),
            teacher_id: strOrNull(s.teacher_id),
            teacher_name: strOrNull(s.teacher_name),
            recap_count: num(s.recap_count),
            total_students: num(s.total_students),
            completion_pct: num(s.completion_pct),
            avg_final_score: numOrNull(s.avg_final_score),
            chapter_count: num(s.chapter_count ?? s.bab_count),
            entries_count: num(s.entries_count),
          }))
        : [],
    })),
    summary: {
      total_classes: num(summaryRaw.total_classes),
      total_students: num(summaryRaw.total_students),
      total_expected_recaps: num(summaryRaw.total_expected_recaps),
      total_filled_recaps: num(summaryRaw.total_filled_recaps),
      overall_completion_pct: num(summaryRaw.overall_completion_pct),
      overall_avg_score: numOrNull(summaryRaw.overall_avg_score),
    },
  };
}

export function adminRecapOverviewFromJson(
  raw: AnyRecord,
): AdminRecapOverviewResponse {
  const rows = Array.isArray(raw.rows) ? (raw.rows as AnyRecord[]) : [];
  const summaryRaw = (raw.summary as AnyRecord | undefined) ?? {};
  return {
    summary: {
      total_slice: num(summaryRaw.total_slice),
      completed_slice: num(summaryRaw.completed_slice),
      avg_progress: num(summaryRaw.avg_progress),
    },
    rows: rows.map((r) => ({
      class_id: String(r.class_id ?? ''),
      class_name: String(r.class_name ?? '-'),
      subject_id: String(r.subject_id ?? ''),
      subject_school_id: strOrNull(r.subject_school_id),
      subject_name: String(r.subject_name ?? '-'),
      teacher_id: strOrNull(r.teacher_id),
      teacher_name: strOrNull(r.teacher_name),
      students_total: num(r.students_total),
      students_with_recap: num(r.students_with_recap),
      progress_pct: num(r.progress_pct),
      avg_final_score: numOrNull(r.avg_final_score),
      pass_rate: num(r.pass_rate),
      chapter_total: num(r.chapter_total ?? r.bab_total),
      chapter_filled: num(r.chapter_filled ?? r.bab_filled),
      midterm_done: num(r.midterm_done ?? r.uts_done),
      final_exam_done: num(r.final_exam_done ?? r.uas_done),
      is_complete: Boolean(r.is_complete),
    })),
  };
}
