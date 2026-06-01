/**
 * Auth-flow types — mirror the Flutter `AuthState` / `AuthStep` model in
 * `lib/features/auth/presentation/controllers/auth_controller.dart`.
 *
 * The Laravel backend returns a normalized response with one of these
 * shapes depending on what step the user is on:
 *
 *   - require_otp: true       → user must enter the email OTP
 *   - needsSchoolSelection    → user belongs to multiple schools
 *   - needsRoleSelection      → user has multiple roles in the chosen school
 *   - token + user            → fully authenticated
 */

export type Role = 'admin' | 'guru' | 'wali_kelas' | 'wali' | 'staff';

export type AuthStep =
  | 'login'
  | 'otp'
  | 'school'
  | 'role'
  // Google login with no schools → the user has not registered any
  // school yet AND is not part of any existing tenant. We route them
  // into /register-demo to seed a sandbox. The auth store drops to
  // this step so RouterGuard can redirect.
  | 'register_demo'
  | 'done';

export interface School {
  id: string;
  school_id?: string; // flutter variant
  name: string;
  school_name?: string; // flutter variant
  address?: string;
  city?: string;
  academic_year?: string;
  level?: string;
  logo_url?: string | null;
  roles?: Role[];
}

export interface User {
  id: string;
  name: string;
  nama?: string; // flutter variant
  email: string;
  avatar?: string | null;
  role: Role;
  school_id?: string;
  /**
   * Display name of the active school. The backend returns this
   * directly on the user payload on login + switchSchool (alias
   * `nama_sekolah`). The SchoolPill / Profile page / ProfileMenu
   * all read this first before falling back to a `schools[]` lookup.
   */
  school_name?: string | null;
  /** Schools the user belongs to (populated when needsSchoolSelection). */
  schools?: School[];
  /** Roles the user can act as in the chosen school. */
  roles?: Role[];
}

/**
 * Raw, normalized auth response from the backend. The exact shape varies
 * depending on the flow step.
 */
export interface AuthResponse {
  success?: boolean;
  message?: string;

  // Flow-control flags
  require_otp?: boolean;
  pilih_sekolah?: boolean;
  needsSchoolSelection?: boolean;
  sekolah_list?: School[];
  schools?: School[];
  pilih_role?: boolean;
  needsRoleSelection?: boolean;
  role_list?: Role[];
  roles?: Role[];
  otp_debug?: string;

  // Register-demo branch — set by the backend when a Google login
  // succeeds but the user has no `users_schools` rows. Vue routes
  // them to /register-demo; `wizard_resume` is non-null when a prior
  // partial wizard exists so we can drop them on the right step.
  dapat_buat_demo?: boolean;
  wizard_resume?: {
    current_step: number;
    last_active_at: string;
  } | null;

  // Final-state payload
  token?: string;
  user?: User;

  // Picker payloads
  schools?: School[];
  roles?: Role[];
  school?: School;
  sekolah?: School;
  selectedSchool?: School;
}
