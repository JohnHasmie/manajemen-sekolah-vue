/**
 * Grade book types - mirror Flutter's grade matrix data.
 *
 * The matrix has students as rows and assessments as columns. Each cell
 * is a Grade record keyed by (student_id, assessment_id).
 */

/**
 * Canonical English assessment types match the backend
 * `assessments.type` column:
 *   assignment | daily_test | midterm | final_exam | quiz
 *
 * `other` is a Vue-only display bucket for any value not in that set.
 */
export type AssessmentType =
  | 'assignment'
  | 'daily_test'
  | 'midterm'
  | 'final_exam'
  | 'quiz'
  | 'other';

/** Normalise legacy / mixed-case values to the canonical English keys. */
export function normalizeAssessmentType(raw: unknown): AssessmentType {
  const v = String(raw ?? '').toLowerCase().trim();
  if (!v) return 'other';
  if (v === 'assignment' || v === 'tugas' || v === 'tg' || v === 'pr') return 'assignment';
  if (v === 'daily_test' || v === 'uh' || v === 'ulangan harian') return 'daily_test';
  if (v === 'midterm' || v === 'uts' || v === 'pts') return 'midterm';
  if (v === 'final_exam' || v === 'uas' || v === 'pas') return 'final_exam';
  if (v === 'quiz' || v === 'kuis') return 'quiz';
  return 'other';
}

export interface Assessment {
  id: string;
  /** Display name. Synthesised from type when backend title is null. */
  name: string;
  /**
   * Backend's literal `title` column value (`null` when DB column is
   * NULL). MUST be sent verbatim on POST /grades — the unique index
   * `(teacher_id, subject_id, type, date, title)` treats NULL ≠ "UH",
   * so fabricating a name like "UH" causes the backend to spawn a
   * phantom duplicate assessment column.
   */
  raw_title?: string | null;
  type: AssessmentType;
  weight?: number;
  /** Date the assessment occurred / was due, ISO yyyy-mm-dd. */
  date?: string;
}

export interface GradeCell {
  id?: string;
  student_id: string;
  assessment_id: string;
  /** Numeric score 0..100; null if not yet entered. */
  score: number | null;
  /** Server-recorded notes / remed flag. */
  notes?: string | null;
  dirty?: boolean;
}

export interface GradeRow {
  student_id: string;
  /**
   * Per-academic-year enrolment id (`student_classes.id`). Required
   * by the backend POST/PUT /grades payload — sourced from
   * `/student/class/{id}` response on the matrix two-phase load.
   */
  student_class_id?: string | null;
  student_name: string;
  student_number: string;
  /** Optional alert mirrors AttendanceRow.alert pattern. */
  alert?: string | null;
  alert_tone?: 'warning' | 'danger' | null;
  /** Map of assessment_id -> GradeCell. */
  cells: Record<string, GradeCell>;
  /** Cached average across cells (or backend-computed). */
  average: number | null;
}

export interface GradeMatrix {
  assessments: Assessment[];
  rows: GradeRow[];
  /** Minimum passing threshold (KKM). */
  kkm: number;
}

export const ASSESSMENT_LABELS: Record<AssessmentType, string> = {
  assignment: 'Tugas',
  daily_test: 'UH',
  midterm: 'UTS',
  final_exam: 'UAS',
  quiz: 'Kuis',
  other: 'Lainnya',
};

// ── Teacher grade summary ──
//
// ── Admin school-wide overview (`/grades/admin-overview`) ─────────
//
// Returned by GradeController@adminOverview. Backs the Gradebook
// admin page — school-wide KPI stats + per-teacher cards with subject
// breakdown. Cached server-side for 5 minutes.

export interface AdminOverviewDistribution {
  high: number; // grades ≥ 80
  mid: number;  // 60 ≤ grades < 80
  low: number;  // grades < 60
}

export interface AdminOverviewSchoolStats {
  total_grades: number;
  total_assessments: number;
  total_teachers: number;
  total_students: number;
  avg_score: number;
  highest_score: number;
  lowest_score: number;
  passed: number;
  failed: number;
  /** 0..100 — share of grades that passed KKM 75. */
  pass_rate: number;
  distribution: AdminOverviewDistribution;
}

export interface AdminOverviewTeacherSubject {
  subject_id: string;
  subject_name: string;
  grade_counts: Record<string, number>;
  total_grades: number;
  avg_score: number | null;
}

export interface AdminOverviewTeacher {
  teacher_id: string;
  teacher_name: string;
  total_grades: number;
  total_assessments: number;
  subject_count: number;
  class_count: number;
  avg_score: number;
  highest_score: number;
  lowest_score: number;
  passed: number;
  failed: number;
  distribution: AdminOverviewDistribution;
  subjects: AdminOverviewTeacherSubject[];
}

export interface AdminGradeOverview {
  school_stats: AdminOverviewSchoolStats;
  teachers: AdminOverviewTeacher[];
}

function asNum(v: unknown, fallback = 0): number {
  if (typeof v === 'number') return Number.isFinite(v) ? v : fallback;
  if (typeof v === 'string') {
    const n = Number(v);
    return Number.isFinite(n) ? n : fallback;
  }
  return fallback;
}
function asNumOrNull(v: unknown): number | null {
  if (v === null || v === undefined) return null;
  if (typeof v === 'number') return Number.isFinite(v) ? v : null;
  if (typeof v === 'string' && v !== '') {
    const n = Number(v);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}
function asStr(v: unknown, fallback = ''): string {
  if (v === null || v === undefined) return fallback;
  return String(v);
}

export function adminGradeOverviewFromJson(
  raw: Record<string, unknown>,
): AdminGradeOverview {
  const ss = (raw.school_stats ?? {}) as Record<string, unknown>;
  const dist = (ss.distribution ?? {}) as Record<string, unknown>;
  const teachersRaw = Array.isArray(raw.teachers) ? raw.teachers : [];
  return {
    school_stats: {
      total_grades: asNum(ss.total_grades),
      total_assessments: asNum(ss.total_assessments),
      total_teachers: asNum(ss.total_teachers),
      total_students: asNum(ss.total_students),
      avg_score: asNum(ss.avg_score),
      highest_score: asNum(ss.highest_score),
      lowest_score: asNum(ss.lowest_score),
      passed: asNum(ss.passed),
      failed: asNum(ss.failed),
      pass_rate: asNum(ss.pass_rate),
      distribution: {
        high: asNum(dist.high),
        mid: asNum(dist.mid),
        low: asNum(dist.low),
      },
    },
    teachers: teachersRaw.map((t): AdminOverviewTeacher => {
      const tr = t as Record<string, unknown>;
      const td = (tr.distribution ?? {}) as Record<string, unknown>;
      const subjects = Array.isArray(tr.subjects) ? tr.subjects : [];
      return {
        teacher_id: asStr(tr.teacher_id),
        teacher_name: asStr(tr.teacher_name, 'Guru'),
        total_grades: asNum(tr.total_grades),
        total_assessments: asNum(tr.total_assessments),
        subject_count: asNum(tr.subject_count),
        class_count: asNum(tr.class_count),
        avg_score: asNum(tr.avg_score),
        highest_score: asNum(tr.highest_score),
        lowest_score: asNum(tr.lowest_score),
        passed: asNum(tr.passed),
        failed: asNum(tr.failed),
        distribution: {
          high: asNum(td.high),
          mid: asNum(td.mid),
          low: asNum(td.low),
        },
        subjects: subjects.map((s): AdminOverviewTeacherSubject => {
          const sr = s as Record<string, unknown>;
          const gc = (sr.grade_counts ?? {}) as Record<string, unknown>;
          const counts: Record<string, number> = {};
          for (const [k, v] of Object.entries(gc)) {
            counts[k] = asNum(v);
          }
          return {
            subject_id: asStr(sr.subject_id),
            subject_name: asStr(sr.subject_name, '-'),
            grade_counts: counts,
            total_grades: asNum(sr.total_grades),
            avg_score: asNumOrNull(sr.avg_score),
          };
        }),
      };
    }),
  };
}

// Returned by `/grades/teacher-summary` (Flutter
// `getTeacherGradeSummary`). One node per (class, subject) the teacher
// teaches, plus a per-assessment leaf so the dashboard card can render
// a tiny "type pill row" + progress strip without a second round-trip.

export interface TeacherGradeSummaryAssessment {
  id: string;
  /** Display label — e.g. "UH 1", "UTS". */
  label: string;
  /**
   * Backend's literal `title` column value (may be `null` when DB
   * column is NULL). Preserved so the matrix seed can echo the
   * exact title on save without triggering the duplicate-assessment
   * trap.
   */
  raw_title?: string | null;
  type: AssessmentType;
  /** Average across enrolled students; null until any cell is filled. */
  avg: number | null;
}

export interface TeacherGradeSummarySubject {
  id: string;
  name: string;
  code: string;
  /** Overall avg for (class, subject); null when nothing is filled. */
  avg_score: number | null;
  /** Count of grade cells already filled. */
  total_nilai: number;
  assessments: TeacherGradeSummaryAssessment[];
}

export interface TeacherGradeSummaryClass {
  class_id: string;
  class_name: string;
  /** "7" | "8" | "9" | "10" — used by the per-card kicker. */
  grade_level: string;
  student_count: number;
  subjects: TeacherGradeSummarySubject[];
}

/** Parse one raw `/grades/teacher-summary` row into the typed shape. */
export function teacherGradeSummaryFromJson(
  raw: Record<string, unknown>,
): TeacherGradeSummaryClass {
  const r = raw ?? {};
  const num = (v: unknown) =>
    typeof v === 'number' ? v : Number(v) || 0;
  const subjects = Array.isArray(r.subjects) ? (r.subjects as any[]) : [];
  return {
    class_id: String(r.class_id ?? r.id ?? ''),
    class_name: String(r.class_name ?? r.name ?? ''),
    grade_level: String(r.grade_level ?? r.level ?? ''),
    student_count: num(r.student_count),
    subjects: subjects.map((s) => {
      const assessments = Array.isArray(s.assessments)
        ? (s.assessments as any[])
        : [];
      const rawType = String(s.type ?? '').toLowerCase();
      void rawType;
      return {
        id: String(s.id ?? ''),
        name: String(s.name ?? s.nama ?? ''),
        code: String(s.code ?? s.kode ?? ''),
        avg_score:
          typeof s.avg_score === 'number'
            ? s.avg_score
            : s.avg_score === null || s.avg_score === undefined
              ? null
              : Number(s.avg_score) || null,
        total_nilai: num(s.total_nilai),
        assessments: assessments.map((a) => {
          const type: AssessmentType = normalizeAssessmentType(a.type);
          // Distinguish between the BACKEND's literal title field and
          // the safe display label. The summary endpoint typically
          // ships `title` (echoes DB column) AND a fallback `label`.
          // If title is explicitly present (even null), it's the
          // canonical write-side value; only the label is safe for
          // display.
          const titleProvided = 'title' in a;
          const rawTitle = titleProvided
            ? (a.title === null || a.title === undefined
                ? null
                : String(a.title))
            : undefined; // unknown — let caller fall back
          return {
            id: String(a.id ?? ''),
            label: String(a.label ?? a.name ?? a.id ?? ''),
            raw_title: rawTitle,
            type,
            avg:
              typeof a.avg === 'number'
                ? a.avg
                : a.avg === null || a.avg === undefined
                  ? null
                  : Number(a.avg) || null,
          };
        }),
      };
    }),
  };
}
