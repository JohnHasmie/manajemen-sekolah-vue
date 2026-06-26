/**
 * Shared parent-side types (children, announcements, report cards).
 */

export interface Child {
  student_id: string;
  name: string;
  class_name: string;
  /** Optional avatar URL. */
  avatar?: string | null;
}

export interface Announcement {
  id: string;
  title: string;
  body: string;
  /** Source label: "Sekolah", "Homeroom Teacher", "Bu Ratna". */
  source: string;
  /** Closed enum: penting / announcement / acara / libur. */
  category?: string;
  read_at?: string | null;
  created_at: string;
}

export interface ReportCard {
  id: string;
  semester: string;
  academic_year: string;
  /** Class at time of issuance. */
  class_name: string;
  /** Computed GPA across subjects. */
  avg_grade: number | null;
  /** Number of subjects below KKM. */
  remed_count: number;
  published_at?: string | null;
  /** Download URL for the rendered PDF. */
  pdf_url?: string | null;
}

export interface ReportCardEntry {
  subject_id: string;
  subject_name: string;
  score: number;
  kkm: number;
  predicate: 'A' | 'B' | 'C' | 'D' | string;
  notes?: string | null;
}

export interface ReportCardDetail extends ReportCard {
  entries: ReportCardEntry[];
  /** Attendance summary for the semester. */
  attendance_summary?: {
    hadir: number;
    sakit: number;
    izin: number;
    alpa: number;
  };
  /** Homeroom teacher notes. */
  homeroom_notes?: string | null;
}

/**
 * Canonical parent attendance status. Mirrors Flutter's 5-status
 * enum (hadir/terlambat/izin/sakit/alpha). Backend may return either
 * `alpa` or `alpha` — `parseParentAttendanceStatus` below normalises
 * to `alpha` so display + count logic only has one spelling to deal
 * with.
 */
export type ParentAttendanceStatus =
  | 'hadir'
  | 'terlambat'
  | 'izin'
  | 'sakit'
  | 'alpha';

export interface ParentAttendanceEntry {
  id: string;
  date: string;
  /** Lesson hour label e.g. "JP 1-2" — Flutter renders this on the secondary line. */
  lesson_hour_name?: string | null;
  lesson_hour_id?: string | null;
  subject_id?: string | null;
  subject_name: string;
  /** Optional session label fallback used by older callers. */
  session?: string | null;
  status: ParentAttendanceStatus;
  notes?: string | null;
  /** Per-row mark-as-read flag from /attendance. */
  is_read?: boolean;
}

/**
 * Normalise raw backend status string to the canonical
 * ParentAttendanceStatus. Backend stores legacy spellings (`alpa`,
 * uppercase, English) — collapse them here so consumers branch on
 * exactly one set of values.
 */
export function parseParentAttendanceStatus(raw: unknown): ParentAttendanceStatus {
  const s = String(raw ?? '').toLowerCase().trim();
  if (s === 'terlambat' || s === 'late') return 'terlambat';
  if (s === 'izin' || s === 'excused' || s === 'permit') return 'izin';
  if (s === 'sakit' || s === 'sick') return 'sakit';
  if (s === 'alpha' || s === 'alpa' || s === 'absent') return 'alpha';
  return 'hadir'; // present | hadir | unknown → hadir
}

export const PARENT_ATTENDANCE_LABELS: Record<ParentAttendanceStatus, string> = {
  hadir: 'Hadir',
  terlambat: 'Terlambat',
  izin: 'Izin',
  sakit: 'Sakit',
  alpha: 'Alpa',
};

export interface ParentGradeRow {
  subject_id: string;
  subject_name: string;
  kkm: number;
  scores: { assessment: string; score: number | null }[];
  average: number | null;
}

/**
 * Flat one-row-per-assessment shape used by the parent Grade screen.
 * Mirrors the Flutter mobile `Map<String, dynamic>` payload that the
 * parent's `/grades` endpoint returns — each row is one graded
 * assessment for the student.
 */
export type ParentGradeType =
  | 'Tugas'
  | 'UH'
  | 'PTS'
  | 'PAS'
  | 'Praktek'
  | 'Portofolio'
  | 'Proyek';

export interface ParentGradeEntry {
  id: string;
  subject_id: string;
  subject_name: string;
  /** Raw assessment type label (Tugas/UH/PTS/PAS/Praktek/Portofolio/Proyek). */
  type: string;
  /** Assessment title (e.g. "UH BAB 3"). Empty string when unset. */
  title: string;
  /** ISO yyyy-MM-dd. May be empty if backend didn't include one. */
  date: string;
  /** null when the teacher hasn't entered a score yet. */
  score: number | null;
  kkm: number;
  is_read: boolean;
}

export const PARENT_GRADE_TYPE_OPTIONS: { value: string; label: string }[] = [
  { value: 'Tugas', label: 'Tugas' },
  { value: 'UH', label: 'Ulangan Harian' },
  { value: 'PTS', label: 'PTS' },
  { value: 'PAS', label: 'PAS' },
  { value: 'Praktek', label: 'Praktek' },
  { value: 'Portofolio', label: 'Portofolio' },
  { value: 'Proyek', label: 'Proyek' },
];
