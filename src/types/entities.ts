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
  };
}

// ---- Teacher ----
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
  user_id?: string | null;
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
      (r.phone_number as string) ?? (r.no_hp as string) ?? null,
    address: (r.address as string) ?? (r.alamat as string) ?? null,
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
    user_id: (r.user_id as string) ?? (user?.id as string) ?? null,
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
