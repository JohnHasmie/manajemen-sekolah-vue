// Types + JSON parsers for the class-first "Kelas" hub. Mirror the mobile
// domain models (ClassCard / ClassFeedItem) and the backend response shapes
// from GET /classes/mine and GET /classes/{id}/feed.

export type ClassRoleInClass = 'wali_kelas' | 'guru_mapel' | 'parent' | null;

export type ClassScope = 'general' | 'subject';

export interface ClassCard {
  id: string;
  name: string;
  gradeLevel: number | null;
  studentCount: number;
  isHomeroom: boolean;
  isTeaching: boolean;
  roleInClass: ClassRoleInClass;
  homeroomTeacherName: string | null;
  activeTugas: number;
  needsGrading: number;
  /** Admin oversight only — no class activity in the last 7 days ("sepi"). */
  isSilent: boolean;
  /** Subject this card is scoped to; null on a general (all-subjects) card. */
  subjectId: string | null;
  subjectName: string | null;
  /** The subject's teacher (parent's per-subject cards show who teaches it). */
  teacherName: string | null;
  /** `general` (all subjects, oversight) | `subject` (scoped to subjectId). */
  scope: ClassScope;
}

export type ClassFeedType =
  | 'tugas'
  | 'ujian'
  | 'materi'
  | 'pengumuman'
  | 'nilai'
  | 'presensi'
  | 'unknown';

export interface ClassFeedItem {
  type: ClassFeedType;
  id: string;
  title: string;
  subtitle: string | null;
  occurredAt: string | null;
  meta: Record<string, unknown>;
  isRead: boolean;
}

function toInt(v: unknown): number {
  if (typeof v === 'number') return Math.trunc(v);
  if (typeof v === 'string') {
    const n = parseInt(v, 10);
    return Number.isNaN(n) ? 0 : n;
  }
  return 0;
}

export function classCardFromJson(json: Record<string, unknown>): ClassCard {
  const homeroom = json.homeroom_teacher as
    | Record<string, unknown>
    | null
    | undefined;
  return {
    id: String(json.id ?? ''),
    name: String(json.name ?? ''),
    gradeLevel: json.grade_level == null ? null : toInt(json.grade_level),
    studentCount: toInt(json.student_count),
    isHomeroom: json.is_homeroom === true,
    isTeaching: json.is_teaching === true,
    roleInClass: (json.role_in_class as ClassRoleInClass) ?? null,
    homeroomTeacherName: homeroom ? String(homeroom.name ?? '') || null : null,
    activeTugas: toInt(json.active_tugas),
    needsGrading: toInt(json.needs_grading),
    isSilent: json.is_silent === true,
    subjectId: json.subject_id == null ? null : String(json.subject_id),
    subjectName: json.subject_name == null ? null : String(json.subject_name),
    teacherName: json.teacher_name == null ? null : String(json.teacher_name),
    // Fall back to deriving the scope from subject_id so this stays correct
    // against an older backend that doesn't send `scope` yet.
    scope:
      typeof json.scope === 'string' && json.scope
        ? (json.scope as ClassScope)
        : json.subject_id != null
          ? 'subject'
          : 'general',
  };
}

export function isWaliKelas(c: ClassCard): boolean {
  return c.roleInClass === 'wali_kelas' || c.isHomeroom;
}

export function isSubjectScoped(c: ClassCard): boolean {
  return c.scope === 'subject' && c.subjectId != null;
}

export function isGeneralCard(c: ClassCard): boolean {
  return c.scope === 'general';
}

/** Stable per-card key — a class yields a general card + one per subject. */
export function classCardKey(c: ClassCard): string {
  return `${c.id}::${c.subjectId ?? 'general'}`;
}

const FEED_TYPES: ClassFeedType[] = [
  'tugas',
  'ujian',
  'materi',
  'pengumuman',
  'nilai',
  'presensi',
];

export function classFeedItemFromJson(
  json: Record<string, unknown>,
): ClassFeedItem {
  const rawType = String(json.type ?? '');
  const type = (FEED_TYPES as string[]).includes(rawType)
    ? (rawType as ClassFeedType)
    : 'unknown';
  return {
    type,
    id: String(json.id ?? ''),
    title: String(json.title ?? ''),
    subtitle: json.subtitle == null ? null : String(json.subtitle),
    occurredAt: json.occurred_at == null ? null : String(json.occurred_at),
    meta:
      json.meta && typeof json.meta === 'object'
        ? (json.meta as Record<string, unknown>)
        : {},
    isRead: json.is_read === true,
  };
}

// --- Anggota tab (GET /classes/{id}/members) ---------------------------------

export interface ClassMemberStudent {
  id: string;
  name: string;
  nis: string | null;
}

export interface ClassMembers {
  homeroomTeacherName: string | null;
  studentCount: number;
  students: ClassMemberStudent[];
}

export function classMembersFromJson(
  json: Record<string, unknown>,
): ClassMembers {
  const homeroom = json.homeroom_teacher as
    | Record<string, unknown>
    | null
    | undefined;
  const rawStudents = Array.isArray(json.students)
    ? (json.students as Record<string, unknown>[])
    : [];
  return {
    homeroomTeacherName: homeroom ? String(homeroom.name ?? '') || null : null,
    studentCount: toInt(json.student_count),
    students: rawStudents.map((s) => ({
      id: String(s.id ?? ''),
      name: String(s.name ?? ''),
      nis: s.nis == null ? null : String(s.nis),
    })),
  };
}
