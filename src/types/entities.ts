// Entity models -- mirror the Flutter domain models in
// lib/features/<feature>/domain/models/.
//
// The Laravel backend returns fields in mixed English/Indonesian shapes.
// Each *FromJson() helper normalizes the variants the Flutter models
// handle so the Vue UI sees one canonical shape.

// ---- Student ----
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
export interface Classroom {
  id: string;
  name: string;
  homeroom_teacher_name?: string | null;
  homeroom_teacher_id?: string | null;
  student_count: number;
  grade_level?: string | null;
  academic_year_id?: string | null;
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
  };
}

// ---- Subject ----
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
  return {
    id: String(r.id ?? ''),
    name: (r.name as string) ?? (r.nama as string) ?? '',
    code: (r.code as string) ?? (r.kode as string) ?? null,
    kkm: (r.kkm as number) ?? (r.minimum_score as number) ?? null,
    description: (r.description as string) ?? (r.deskripsi as string) ?? null,
    is_active: isActive,
    master_subject_id:
      (r.master_subject_id as string) ?? (ms?.id as string) ?? null,
    master_subject_name:
      (ms?.name as string) ?? (r.master_subject_name as string) ?? null,
    grade_level:
      (r.grade_level as string) ?? (r.tingkat as string) ?? null,
    class_count:
      (r.class_count as number) ?? (r.classes_count as number) ?? undefined,
  };
}
