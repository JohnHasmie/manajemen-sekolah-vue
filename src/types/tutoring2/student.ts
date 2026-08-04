/**
 * BimbelStudent — wire shape for `/api/tutoring-v2/students*`
 * (BE-18 admin CRUD spine). Kept in a namespaced folder so future
 * `types/tutoring2/*` modules (packages/enrollments/sessions/…) can
 * settle here as they get split out of the monolithic
 * `types/tutoring-bimbel.ts`.
 *
 * The BE endpoint returns Laravel's `StudentResource` shape (see
 * `App\Modules\Tutoring\Http\Resources\StudentResource`), which reuses
 * the shared `students` table — bimbel doesn't own its own person model.
 * Fields are `?` where the resource omits them on partial writes /
 * missing subselects, mirroring the backend faithfully.
 *
 * NOTE on `student_status`: the BE column is `aktif|trial|lulus` (an
 * Indonesian legacy enum retained across the school ↔ bimbel boundary
 * because the school code writes it too — see rule
 * feedback_english_convention_absolute.md, "wire keys / enum values"
 * clause: these are legacy VALUES that already ship in production and
 * are exempt from the English-migration until a coordinated column
 * rename lands). The FE surface still adopts the flat boolean `active`
 * (also returned by the resource) for chip logic.
 */
export interface BimbelStudent {
  id: string;
  school_id: string;
  /** User row for the wali; also the login the wali resolves as. */
  user_id?: string | null;
  student_number?: string | null;
  nisn?: string | null;
  name: string;
  gender?: 'male' | 'female' | null;
  place_of_birth?: string | null;
  /** YYYY-MM-DD. */
  date_of_birth?: string | null;
  address?: string | null;
  phone_number?: string | null;

  guardian_name?: string | null;
  guardian_email?: string | null;
  guardian_phone?: string | null;

  /** Legacy Indonesian enum retained by the shared students table. */
  student_status?: 'aktif' | 'trial' | 'lulus' | null;

  /** Convenience boolean: false only when student_status='lulus'. */
  active?: boolean;

  /** Subselects from BE-18 controller — safe to default to 0. */
  active_enrollment_count?: number;
  active_bill_count?: number;

  created_at?: string;
  updated_at?: string;
}

/** Query string for `GET /students`. Only fields the BE reads. */
export interface BimbelStudentListParams {
  page?: number;
  per_page?: number;
  /** '' | 'true' | 'false' — BE accepts booleanish. Default true. */
  active?: boolean | string;
  /** Name / student_number / guardian_name / guardian_email LIKE. */
  search?: string;
}

/** Body shape for `POST /students`. */
export interface BimbelStudentCreatePayload {
  name: string;
  student_number?: string | null;
  nisn?: string | null;
  gender: 'male' | 'female';
  place_of_birth?: string | null;
  date_of_birth?: string | null;
  address?: string | null;
  phone_number?: string | null;
  guardian_name: string;
  guardian_email: string;
  guardian_phone?: string | null;
  student_status?: 'aktif' | 'trial' | 'lulus' | null;
}

/**
 * Body shape for `PUT /students/{id}` — all fields optional; a partial
 * write is safe (`sometimes` rules on the BE). `student_number` is
 * deliberately NOT here — the tenant-stable NIS handle is only settable
 * at create time (parity with the school-side Data Siswa screen).
 */
export interface BimbelStudentUpdatePayload {
  name?: string;
  nisn?: string | null;
  gender?: 'male' | 'female';
  place_of_birth?: string | null;
  date_of_birth?: string | null;
  address?: string | null;
  phone_number?: string | null;
  guardian_name?: string;
  guardian_email?: string | null;
  guardian_phone?: string | null;
  student_status?: 'aktif' | 'trial' | 'lulus' | null;
}

/**
 * Envelope for `POST /students` — carries a one-time guardian temp
 * password when a brand-new wali user was minted. Null when Opsi B
 * account activation is on (activation link is dispatched instead) or
 * when the wali already existed and was reused. FE must show the
 * password once and drop it from memory afterwards.
 */
export interface BimbelStudentCreateResponse {
  data: BimbelStudent;
  guardian_temp_password: string | null;
}

/**
 * Structured 422 code the wali-attach path *may* raise on the
 * school-side CreateStudentAction. Kept here because the FE sheet
 * treats them the same across school/bimbel — the greenfield BE
 * (`Tutoring\Actions\CreateStudentAction`) does NOT raise these today
 * (it reuses the existing user silently), but the FE should still be
 * ready if the coexistence rules add them later.
 */
export type BimbelStudentErrorCode =
  | 'email_conflict'
  | 'already_teacher_here';
