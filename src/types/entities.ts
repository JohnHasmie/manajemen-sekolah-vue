// Entity models -- mirror the Flutter domain models in
// lib/features/<feature>/domain/models/.
//
// The Laravel backend returns fields in mixed English/Indonesian shapes.
// Each *FromJson() helper normalizes the variants the Flutter models
// handle so the Vue UI sees one canonical shape.

// ---- Student ----
/**
 * Compact class reference emitted by the enriched `/student` list
 * response. Same shape as TeacherClassRef but kept separate so the two
 * feature areas can evolve independently.
 */
export interface StudentClassRef {
  id: string;
  name: string;
}

/**
 * Compact academic-year reference — carries a human display name
 * ("2025/2026") and, when the backend surfaces it, the current
 * semester ("S1" / "S2"). Used by the two-column student card to
 * render the "Tahun ajaran" facet.
 */
export interface StudentAcademicYearRef {
  id?: string;
  name: string;
  semester?: string | null;
}

/**
 * Structured wali (guardian) contact block. The pre-redesign shape
 * dumped `guardian_name` + `phone_number` at the top level; the
 * enriched response bundles them so the two-column card can render
 * a labelled Wali/Ortu column alongside a Kontak wali column.
 */
export interface StudentGuardianContact {
  name?: string | null;
  phone?: string | null;
  relationship?: string | null;
}

export interface Student {
  id: string;
  name: string;
  class_name: string;
  student_number: string;
  address: string;
  guardian_name: string;
  phone_number: string;
  class_id?: string | null;
  student_class_id?: string | null;
  gender?: string | null;
  date_of_birth?: string | null;
  guardian_email?: string | null;
  /**
   * Account lifecycle status — server side is one of
   * `active` | `inactive` | `unverified`. Optional because the API
   * historically omitted it on older list responses; downstream code
   * treats missing as `active` (matches the filter default).
   */
  status?: 'active' | 'inactive' | 'unverified' | null;
  /**
   * Structured wali (guardian) contact — { name, phone, relationship }.
   * Undefined against a legacy backend; consumers should fall back to
   * `guardian_name` + `phone_number` scalars at the top level.
   */
  wali_contact?: StudentGuardianContact | null;
  /**
   * Truncated address string suitable for the two-column card
   * (typically "kecamatan, kabupaten"). Falls back to the full
   * `address` scalar when the backend has not shipped this field.
   */
  address_short?: string | null;
  /**
   * Structured class reference — id + display name. Newer name for
   * the historical `class_name`/`class_id` scalar pair. Consumers
   * prefer this when present and fall back to `class_name` otherwise.
   */
  class_ref?: StudentClassRef | null;
  /**
   * Active academic year the student is currently enrolled in.
   * Backend ships this alongside the class ref so the card can render
   * "2025/2026 · S1" without another lookup.
   */
  academic_year?: StudentAcademicYearRef | null;
}

type AnyRecord = Record<string, unknown>;

/**
 * Normalise gender values to canonical English (`male` / `female`).
 * Accepts legacy short-codes (`L`/`P`) and Indonesian
 * (`laki-laki`/`perempuan`) so old payloads + cached data still
 * resolve.
 */
export function normalizeGender(raw: unknown): 'male' | 'female' | null {
  if (raw == null) return null;
  const v = String(raw).toLowerCase().trim();
  if (!v) return null;
  if (v === 'male' || v === 'l' || v === 'laki-laki' || v === 'laki' || v === 'm')
    return 'male';
  if (v === 'female' || v === 'p' || v === 'perempuan' || v === 'f')
    return 'female';
  return null;
}

function pickClassName(json: AnyRecord): string {
  if (typeof json.class_name === 'string') return json.class_name;
  if (typeof json.kelas_nama === 'string') return json.kelas_nama;
  const cls = json.class ?? json.kelas;
  if (cls && typeof cls === 'object') {
    const c = cls as AnyRecord;
    if (typeof c.name === 'string') return c.name;
    if (typeof c.nama === 'string') return c.nama;
  }
  const enrolls = (json.student_classes ?? json.siswa_kelas) as
    | AnyRecord[]
    | undefined;
  if (Array.isArray(enrolls) && enrolls[0]) {
    const first = enrolls[0];
    if (typeof first.class_name === 'string') return first.class_name;
    const nested = (first.class ?? first.kelas) as AnyRecord | undefined;
    if (nested?.name && typeof nested.name === 'string') return nested.name;
    if (nested?.nama && typeof nested.nama === 'string') return nested.nama;
  }
  return '';
}

/**
 * Resolve `student_class_id` defensively. The backend serialises it
 * either as a flat field or as the id of the first row inside
 * `student_classes` (the pivot table). Without this, POST /grades
 * 422s on `student_class_id` is required.
 */
function pickStudentClassId(json: AnyRecord): string | null {
  const flat =
    (json.student_class_id as string | undefined) ??
    (json.siswa_kelas_id as string | undefined) ??
    null;
  if (flat) return String(flat);
  const list =
    (json.student_classes as AnyRecord[] | undefined) ??
    (json.siswa_kelas as AnyRecord[] | undefined);
  if (Array.isArray(list) && list.length > 0) {
    const first = list[0];
    const id = first?.id ?? first?.student_class_id;
    if (id) return String(id);
  }
  return null;
}

export function studentFromJson(raw: AnyRecord): Student {
  const r = raw;

  // ── Enriched structured refs — prefer these over the flat scalars
  //   when the backend has shipped them, but tolerate their absence so
  //   the pre-deploy list response still parses cleanly. ────────────

  const walContactRaw =
    (r.wali_contact as AnyRecord | null | undefined) ??
    (r.guardian_contact as AnyRecord | null | undefined);
  let walContact: StudentGuardianContact | null | undefined;
  if (walContactRaw && typeof walContactRaw === 'object') {
    const name =
      (walContactRaw.name as string) ??
      (walContactRaw.nama as string) ??
      null;
    const phone =
      (walContactRaw.phone as string) ??
      (walContactRaw.phone_number as string) ??
      (walContactRaw.no_hp as string) ??
      null;
    const relationship =
      (walContactRaw.relationship as string) ??
      (walContactRaw.hubungan as string) ??
      null;
    walContact =
      name || phone ? { name, phone, relationship } : null;
  } else if (walContactRaw === null) {
    walContact = null;
  }

  const classRefRaw =
    (r.class_ref as AnyRecord | null | undefined) ??
    (r.current_class as AnyRecord | null | undefined);
  let classRef: StudentClassRef | null | undefined;
  if (classRefRaw && typeof classRefRaw === 'object') {
    const id = String(classRefRaw.id ?? '');
    const name = String(
      classRefRaw.name ?? classRefRaw.nama ?? '',
    );
    classRef = id && name ? { id, name } : null;
  } else if (classRefRaw === null) {
    classRef = null;
  }

  const academicYearRaw =
    (r.academic_year as AnyRecord | null | undefined) ??
    (r.tahun_ajaran as AnyRecord | null | undefined);
  let academicYear: StudentAcademicYearRef | null | undefined;
  if (academicYearRaw && typeof academicYearRaw === 'object') {
    const name = String(
      academicYearRaw.name ??
        academicYearRaw.label ??
        academicYearRaw.year ??
        '',
    );
    const idRaw = academicYearRaw.id;
    const semesterRaw =
      (academicYearRaw.semester as string | number | undefined) ??
      (academicYearRaw.semester_label as string | undefined) ??
      null;
    academicYear = name
      ? {
          id: idRaw ? String(idRaw) : undefined,
          name,
          semester:
            semesterRaw == null || semesterRaw === ''
              ? null
              : String(semesterRaw),
        }
      : null;
  } else if (academicYearRaw === null) {
    academicYear = null;
  }

  const addressShort =
    (r.address_short as string) ??
    (r.alamat_singkat as string) ??
    undefined;

  return {
    id: String(r.id ?? ''),
    name: (r.name as string) ?? (r.nama as string) ?? '',
    class_name: pickClassName(r),
    student_number:
      (r.student_number as string) ??
      (r.nomor_induk as string) ??
      (r.nis as string) ??
      (r.nisn as string) ??
      '',
    address: (r.address as string) ?? (r.alamat as string) ?? '',
    guardian_name:
      (r.guardian_name as string) ?? (r.nama_wali as string) ?? '',
    phone_number:
      (r.phone_number as string) ??
      (r.no_hp as string) ??
      (r.telepon as string) ??
      '',
    class_id: (r.class_id as string) ?? (r.kelas_id as string) ?? null,
    student_class_id: pickStudentClassId(r),
    gender: (r.gender as string) ?? (r.jenis_kelamin as string) ?? null,
    date_of_birth:
      (r.date_of_birth as string) ?? (r.tanggal_lahir as string) ?? null,
    guardian_email:
      (r.guardian_email as string) ?? (r.email_wali as string) ?? null,
    status: normaliseStudentStatus(r.status ?? r.is_active),
    wali_contact: walContact,
    address_short: addressShort ?? null,
    class_ref: classRef,
    academic_year: academicYear,
  };
}

/**
 * Map the raw student status onto the canonical enum. Accepts the
 * three modern string values (`active`/`inactive`/`unverified`), the
 * legacy boolean `is_active`, and the Indonesian strings
 * (`aktif`/`nonaktif`) some older seed data still ships with. Returns
 * `null` when the field is absent so callers know to treat as unknown.
 */
function normaliseStudentStatus(
  raw: unknown,
): 'active' | 'inactive' | 'unverified' | null {
  if (raw == null) return null;
  if (typeof raw === 'boolean') return raw ? 'active' : 'inactive';
  const v = String(raw).toLowerCase().trim();
  if (!v) return null;
  if (v === 'active' || v === 'aktif' || v === '1') return 'active';
  if (v === 'inactive' || v === 'nonaktif' || v === '0') return 'inactive';
  if (v === 'unverified' || v === 'belum verifikasi') return 'unverified';
  return null;
}

// ---- Teacher ----
/**
 * Compact subject reference emitted by the enriched `/teacher` list
 * response. Includes `code` so cards can render chips as
 * `[CODE · Name]` (e.g. "MTK · Matematika"). Deduped by the backend
 * so the "Bahasa Inggris, Bahasa Inggris, Bahasa Inggris" repetition
 * bug on the old admin cards is fixed at the source.
 */
export interface TeacherSubjectRef {
  id: string;
  name: string;
  code?: string | null;
}

/** Compact class reference (id + display name). */
export interface TeacherClassRef {
  id: string;
  name: string;
}

export interface Teacher {
  id: string;
  name: string;
  email: string;
  role: string;
  employee_number?: string | null;
  phone_number?: string | null;
  address?: string | null;
  gender?: string | null;
  employment_status?: string | null;
  homeroom_class_id?: string | null;
  homeroom_class_name?: string | null;
  homeroom_class_names?: string[];
  subject_ids?: string[];
  subject_names?: string[];
  /**
   * Structured, deduped subjects (id + name + optional code). Populated
   * from the enriched backend response; the flat `subject_names` field
   * is retained for compatibility with older list callers.
   */
  subjects?: TeacherSubjectRef[];
  /**
   * Classes this teacher actively teaches — the "KELAS YANG DIPEGANG"
   * facet on the two-column card. Distinct from `homeroom_of` (below).
   * Undefined when the backend has not shipped this field yet;
   * consumers should render an empty state ("Belum diberi kelas").
   */
  teaching_classes?: TeacherClassRef[];
  /**
   * Homeroom class the teacher is currently wali of, if any. Newer
   * name for the historical `homeroom_class_name`/`homeroom_class_id`
   * scalar pair — consumers should prefer this when present and fall
   * back to those two scalars otherwise.
   */
  homeroom_of?: TeacherClassRef | null;
  /**
   * Coarse status label computed by the backend so admin cards don't
   * have to re-derive it inconsistently. Undefined against a legacy
   * backend — cards should fall back to `is_active_this_year` +
   * homeroom heuristics in that case.
   */
  teaching_status?: 'active' | 'no_class' | 'no_subject' | 'not_assigned' | null;
  user_id?: string | null;
  is_active_this_year?: boolean;
}

export function teacherFromJson(raw: AnyRecord): Teacher {
  const r = raw;
  const user = r.user as AnyRecord | undefined;
  const homeroom = r.homeroom_class as AnyRecord | undefined;
  const subjects = (r.subjects ?? r.mata_pelajaran) as AnyRecord[] | undefined;

  const subjectIds = Array.isArray(subjects)
    ? subjects.map((s) => String(s.id))
    : undefined;
  const subjectNames = Array.isArray(subjects)
    ? subjects.map((s) => {
        const n = (s.name as string) ?? (s.nama as string);
        return n ?? '';
      })
    : undefined;

  // Structured subject refs (deduped by id) with optional `code` for
  // the "[CODE · Name]" chip on the two-column card. Legacy backends
  // ship `subjects: [{id, name}]` without `code`; the chip helper
  // falls back to just the name when `code` is absent.
  let structuredSubjects: TeacherSubjectRef[] | undefined;
  if (Array.isArray(subjects)) {
    const seen = new Set<string>();
    structuredSubjects = [];
    for (const s of subjects) {
      const id = String(s.id ?? '');
      if (!id || seen.has(id)) continue;
      seen.add(id);
      const name = (s.name as string) ?? (s.nama as string) ?? '';
      const code = (s.code as string) ?? (s.kode as string) ?? null;
      structuredSubjects.push({ id, name, code });
    }
  }

  // Teaching classes — the classes this teacher actively teaches.
  // Read `teaching_classes` from the enriched response; fall back to
  // `classes`/`kelas_diampu` when older backend variants use those keys.
  const teachingClassesRaw =
    (r.teaching_classes as AnyRecord[] | undefined) ??
    (r.classes as AnyRecord[] | undefined) ??
    (r.kelas_diampu as AnyRecord[] | undefined);
  const teachingClasses: TeacherClassRef[] | undefined = Array.isArray(
    teachingClassesRaw,
  )
    ? teachingClassesRaw
        .map((c) => ({
          id: String(c?.id ?? c?.class_id ?? c?.kelas_id ?? ''),
          name: String(c?.name ?? c?.nama ?? c?.class_name ?? ''),
        }))
        .filter((c) => c.id && c.name)
    : undefined;

  // Homeroom — prefer the structured `homeroom_of` object emitted by
  // the enriched response; fall back to the flat scalar pair from the
  // legacy shape so pre-deploy callers still see a wali chip.
  let homeroomOf: TeacherClassRef | null | undefined;
  const homeroomOfRaw = r.homeroom_of as AnyRecord | null | undefined;
  if (homeroomOfRaw && typeof homeroomOfRaw === 'object') {
    const id = String(homeroomOfRaw.id ?? '');
    const name = String(homeroomOfRaw.name ?? homeroomOfRaw.nama ?? '');
    homeroomOf = id && name ? { id, name } : null;
  } else if (homeroomOfRaw === null) {
    homeroomOf = null;
  }
  // If the enriched field wasn't in the payload at all, `homeroomOf`
  // stays undefined and consumers fall through to homeroom_class_name.

  const teachingStatusRaw = r.teaching_status as string | undefined;
  const teachingStatus: Teacher['teaching_status'] =
    teachingStatusRaw === 'active' ||
    teachingStatusRaw === 'no_class' ||
    teachingStatusRaw === 'no_subject' ||
    teachingStatusRaw === 'not_assigned'
      ? teachingStatusRaw
      : undefined;

  return {
    id: String(r.id ?? ''),
    name:
      (r.name as string) ??
      (user?.name as string) ??
      (r.nama as string) ??
      '',
    email: (r.email as string) ?? (user?.email as string) ?? '',
    role: (r.role as string) ?? 'guru',
    employee_number:
      (r.employee_number as string) ??
      (r.nip as string) ??
      (r.no_pegawai as string) ??
      null,
    phone_number:
      (r.phone_number as string) ?? (user?.phone_number as string) ?? (r.no_hp as string) ?? null,
    address: (r.address as string) ?? (user?.address as string) ?? (r.alamat as string) ?? null,
    homeroom_class_id:
      (r.homeroom_class_id as string) ?? (homeroom?.id as string) ?? null,
    homeroom_class_name:
      (r.homeroom_class_name as string) ??
      (r.wali_kelas_nama as string) ??
      (homeroom?.name as string) ??
      (homeroom?.nama as string) ??
      null,
    subject_ids: (r.subject_ids as string[]) ?? subjectIds,
    subject_names: (r.subject_names as string[]) ?? subjectNames,
    gender: (r.gender as string) ?? (r.jenis_kelamin as string) ?? null,
    employment_status:
      (r.employment_status as string) ??
      (r.status_kepegawaian as string) ??
      null,
    homeroom_class_names: Array.isArray(r.homeroom_classes)
      ? (r.homeroom_classes as AnyRecord[])
          .map((h) => String(h.name ?? h.nama ?? ''))
          .filter(Boolean)
      : undefined,
    subjects: structuredSubjects,
    teaching_classes: teachingClasses,
    homeroom_of: homeroomOf,
    teaching_status: teachingStatus,
    user_id: (r.user_id as string) ?? (user?.id as string) ?? null,
    is_active_this_year: r.is_active_this_year === true,
  };
}

// ---- Classroom ----
/**
 * Rich per-class preview payload emitted by GET /api/class as of the
 * roster-preview-card series (Entitas 3 Opsi B). All fields are
 * optional — the admin view falls back gracefully when a
 * pre-deploy backend still returns the flat shape.
 */
export interface ClassroomStudentPreview {
  id: string;
  name: string;
  gender: 'male' | 'female' | null;
  avatar_initials: string;
}

export interface ClassroomCapacity {
  current: number;
  max: number;
}

export interface ClassroomSubjectPreview {
  id: string;
  code: string | null;
  name: string;
}

export interface ClassroomWaliTeacher {
  id: string;
  name: string;
  avatar_initials: string;
}

export interface ClassroomLocation {
  floor: string | null;
  room: string | null;
}

export interface Classroom {
  id: string;
  name: string;
  homeroom_teacher_name?: string | null;
  homeroom_teacher_id?: string | null;
  student_count: number;
  grade_level?: string | null;
  academic_year_id?: string | null;
  /** ≤5 student preview rows, sorted by name asc. */
  students_preview?: ClassroomStudentPreview[];
  /** {current, max}; max defaults to 36 when unknown. */
  capacity?: ClassroomCapacity | null;
  /** Up to 3 most-scheduled subjects for chips. */
  subjects_top3?: ClassroomSubjectPreview[];
  /** Total distinct subjects taught in this class. */
  subjects_count?: number;
  /** Enriched wali object; falls back to legacy flat scalars. */
  wali_teacher?: ClassroomWaliTeacher | null;
  /** {floor, room}; either side may be null. */
  location?: ClassroomLocation | null;
}

function initialsFromName(name: string): string {
  const trimmed = (name ?? '').trim();
  if (!trimmed) return '?';
  const parts = trimmed.split(/\s+/);
  const first = parts[0]?.[0] ?? '';
  const second = parts[1]?.[0] ?? '';
  return (first + second).toUpperCase();
}

export function classroomFromJson(raw: AnyRecord): Classroom {
  const r = raw;
  const homeroom = r.homeroom_teacher as AnyRecord | AnyRecord[] | undefined;
  let homeroomName: string | null = null;
  let homeroomId: string | null = null;
  if (Array.isArray(homeroom) && homeroom[0]) {
    homeroomName =
      (homeroom[0].name as string) ?? (homeroom[0].nama as string) ?? null;
    homeroomId = (homeroom[0].id as string) ?? null;
  } else if (homeroom && typeof homeroom === 'object') {
    const h = homeroom as AnyRecord;
    homeroomName = (h.name as string) ?? (h.nama as string) ?? null;
    homeroomId = (h.id as string) ?? null;
  }

  // ── Optional roster preview payload (new BE MR) ────────────────
  const rawPreview = r.students_preview as AnyRecord[] | undefined;
  const studentsPreview = Array.isArray(rawPreview)
    ? rawPreview.map((s) => {
        const sr = s as AnyRecord;
        const name = (sr.name as string) ?? (sr.nama as string) ?? '';
        const genderRaw = (sr.gender as string) ?? null;
        const gender: 'male' | 'female' | null =
          genderRaw === 'male' || genderRaw === 'female' ? genderRaw : null;
        return {
          id: String(sr.id ?? ''),
          name,
          gender,
          avatar_initials:
            (sr.avatar_initials as string) ?? initialsFromName(name),
        };
      })
    : undefined;

  const rawCapacity = r.capacity as AnyRecord | undefined;
  const capacity: ClassroomCapacity | null = rawCapacity
    ? {
        current: Number(rawCapacity.current ?? 0),
        max: Number(rawCapacity.max ?? 36) || 36,
      }
    : null;

  const rawSubjects = r.subjects_top3 as AnyRecord[] | undefined;
  const subjectsTop3 = Array.isArray(rawSubjects)
    ? rawSubjects.map((s) => {
        const sr = s as AnyRecord;
        return {
          id: String(sr.id ?? ''),
          code: (sr.code as string) ?? (sr.kode as string) ?? null,
          name: (sr.name as string) ?? (sr.nama as string) ?? '',
        };
      })
    : undefined;

  const rawWali = r.wali_teacher as AnyRecord | undefined;
  let waliTeacher: ClassroomWaliTeacher | null = null;
  if (rawWali && typeof rawWali === 'object') {
    const wname = (rawWali.name as string) ?? (rawWali.nama as string) ?? '';
    waliTeacher = {
      id: String(rawWali.id ?? ''),
      name: wname,
      avatar_initials:
        (rawWali.avatar_initials as string) ?? initialsFromName(wname),
    };
  } else if (homeroomName) {
    // Legacy fallback — synthesise from flat homeroom scalars so the
    // card still shows the wali avatar+name before the BE MR ships.
    waliTeacher = {
      id: homeroomId ?? '',
      name: homeroomName,
      avatar_initials: initialsFromName(homeroomName),
    };
  }

  const rawLocation = r.location as AnyRecord | undefined;
  const location: ClassroomLocation | null = rawLocation
    ? {
        floor: (rawLocation.floor as string) ?? null,
        room: (rawLocation.room as string) ?? null,
      }
    : null;

  return {
    id: String(r.id ?? ''),
    name: (r.name as string) ?? (r.nama as string) ?? '',
    homeroom_teacher_name:
      homeroomName ??
      (r.homeroom_teacher_name as string) ??
      (r.wali_kelas_nama as string) ??
      null,
    homeroom_teacher_id:
      homeroomId ?? (r.homeroom_teacher_id as string) ?? null,
    student_count:
      (r.student_count as number) ??
      (r.jumlah_siswa as number) ??
      (r.students_count as number) ??
      0,
    grade_level: (r.grade_level as string) ?? (r.tingkat as string) ?? null,
    academic_year_id: (r.academic_year_id as string) ?? null,
    students_preview: studentsPreview,
    capacity,
    subjects_top3: subjectsTop3,
    subjects_count:
      typeof r.subjects_count === 'number'
        ? (r.subjects_count as number)
        : subjectsTop3?.length,
    wali_teacher: waliTeacher,
    location,
  };
}

// ---- Subject ----

/** Compact teacher chip used on the "Data Mapel" curriculum-forward card. */
export interface SubjectTeacherPreview {
  id: string;
  name: string;
  avatar_initials: string;
}

/** Compact class reference on the "Diajarkan di …" strip of the card. */
export interface SubjectClassRef {
  id: string;
  name: string;
}

/**
 * Curriculum aggregate — only populated for LINKED subjects (i.e.
 * `master_subject_id != null` on the backend). Drives the violet
 * "Kurikulum · Semester 1" body of the SubjectCurriculumCard.
 * `null` on the ORPHAN branch and on older backends that haven't
 * shipped the aggregate yet — the card falls back to the amber
 * "Rekap belum aktif" copy in either case.
 */
export interface SubjectCurriculumAggregate {
  total_chapters: number;
  chapters_completed: number;
  assessment_count: number;
  kkm_value: number;
  /** Achievement rate in the [0, 1] range (backend rounds to 2 dp). */
  kkm_achievement_rate: number;
}

export interface Subject {
  id: string;
  name: string;
  code?: string | null;
  kkm?: number | null;
  description?: string | null;
  is_active?: boolean;
  master_subject_id?: string | null;
  master_subject_name?: string | null;
  grade_level?: string | null;
  class_count?: number;
  /**
   * Enriched fields shipped by `feat/subject-list-curriculum-forward`
   * (backend MR). All optional so older backend deploys still typecheck
   * and the new admin card degrades to the "no teachers / no classes /
   * ORPHAN" state gracefully.
   */
  teachers_preview?: SubjectTeacherPreview[];
  teachers_count?: number;
  classes_taught?: SubjectClassRef[];
  is_linked?: boolean;
  master_name?: string | null;
  curriculum?: SubjectCurriculumAggregate | null;
}

export function subjectFromJson(raw: AnyRecord): Subject {
  const r = raw;
  const ms = r.master_subject as AnyRecord | undefined;
  const statusRaw = (r.status as string) ?? (r.is_active as unknown) ?? null;
  let isActive: boolean | undefined;
  if (typeof statusRaw === 'boolean') isActive = statusRaw;
  else if (statusRaw === 'active' || statusRaw === 'aktif') isActive = true;
  else if (statusRaw === 'inactive' || statusRaw === 'nonaktif') isActive = false;
  else if (statusRaw === 0 || statusRaw === '0') isActive = false;
  else if (statusRaw === 1 || statusRaw === '1') isActive = true;

  const masterId =
    (r.master_subject_id as string) ?? (ms?.id as string) ?? null;
  const masterName =
    (ms?.name as string) ??
    (r.master_subject_name as string) ??
    (r.master_name as string) ??
    null;

  // Enriched teachers_preview — trust the backend order (per-mapel
  // pengampu ordered by created_at). Cap defensively to 3 on the client
  // to protect the card layout in case a legacy payload ships the full
  // list.
  const rawTeachers = r.teachers_preview as AnyRecord[] | undefined;
  const teachersPreview: SubjectTeacherPreview[] | undefined = Array.isArray(
    rawTeachers,
  )
    ? rawTeachers
        .slice(0, 3)
        .map((t) => ({
          id: String(t?.id ?? ''),
          name: String(t?.name ?? t?.nama ?? ''),
          avatar_initials: String(
            t?.avatar_initials ?? t?.initials ?? '',
          ),
        }))
        .filter((t) => t.id && t.name)
    : undefined;

  const rawTeachersCount = r.teachers_count as unknown;
  const teachersCount =
    typeof rawTeachersCount === 'number'
      ? rawTeachersCount
      : typeof rawTeachersCount === 'string' && rawTeachersCount !== ''
        ? Number(rawTeachersCount)
        : undefined;

  const rawClasses = r.classes_taught as AnyRecord[] | undefined;
  const classesTaught: SubjectClassRef[] | undefined = Array.isArray(rawClasses)
    ? rawClasses
        .map((c) => ({
          id: String(c?.id ?? ''),
          name: String(c?.name ?? c?.nama ?? c?.class_name ?? ''),
        }))
        .filter((c) => c.id && c.name)
    : undefined;

  // is_linked — trust the enriched flag if present, otherwise derive it
  // from `master_subject_id` so older backends still route to the
  // right violet/amber body.
  const rawIsLinked = r.is_linked as unknown;
  const isLinked =
    typeof rawIsLinked === 'boolean'
      ? rawIsLinked
      : masterId != null && masterId !== ''
        ? true
        : undefined;

  const rawCurriculum = r.curriculum as AnyRecord | null | undefined;
  let curriculum: SubjectCurriculumAggregate | null | undefined;
  if (rawCurriculum === null) {
    curriculum = null;
  } else if (rawCurriculum && typeof rawCurriculum === 'object') {
    const rawRate = rawCurriculum.kkm_achievement_rate;
    const rate =
      typeof rawRate === 'number' && Number.isFinite(rawRate) ? rawRate : 0;
    curriculum = {
      total_chapters: Number(rawCurriculum.total_chapters ?? 0) || 0,
      chapters_completed:
        Number(rawCurriculum.chapters_completed ?? 0) || 0,
      assessment_count: Number(rawCurriculum.assessment_count ?? 0) || 0,
      kkm_value: Number(rawCurriculum.kkm_value ?? 0) || 0,
      kkm_achievement_rate: Math.max(0, Math.min(1, rate)),
    };
  }

  return {
    id: String(r.id ?? ''),
    name: (r.name as string) ?? (r.nama as string) ?? '',
    code: (r.code as string) ?? (r.kode as string) ?? null,
    kkm: (r.kkm as number) ?? (r.minimum_score as number) ?? null,
    description: (r.description as string) ?? (r.deskripsi as string) ?? null,
    is_active: isActive,
    master_subject_id: masterId,
    master_subject_name: masterName,
    grade_level:
      (r.grade_level as string) ?? (r.tingkat as string) ?? null,
    class_count:
      (r.class_count as number) ?? (r.classes_count as number) ?? undefined,
    teachers_preview: teachersPreview,
    teachers_count:
      teachersCount ?? (teachersPreview ? teachersPreview.length : undefined),
    classes_taught: classesTaught,
    is_linked: isLinked,
    master_name: masterName,
    curriculum,
  };
}
