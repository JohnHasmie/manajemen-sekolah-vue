/**
 * Staff ("Data Staf") — non-teaching personnel (TU, bendahara, musyrifah,
 * satpam, dst.). Mirrors the backend StaffController resource. `roles` are
 * the active RBAC roles the person holds in this school (the access badge);
 * empty = "belum ada akses".
 */
export interface StaffRole {
  id: number;
  key: string;
  label: string;
  role_type: string;
}

/**
 * One entry in the RBAC-forward staff card's access panel. Corresponds to a
 * top-level module (rbac, finance, academic, communication, …) the staff
 * has at least one granted ability under. Backend derives `label` from the
 * module registry so we can render it verbatim.
 */
export interface StaffRbacModule {
  key: string;
  label: string;
}

/**
 * Summary attached to each staff record by the backend so the admin
 * "Data Staf" card can render access at-a-glance without loading the
 * detail sheet. `modules` is the list the staff currently has access to;
 * `missing_expected` is any module that this person's `position` suggests
 * they SHOULD have but that no granted ability covers yet — the card
 * turns those into the "mungkin perlu tambah?" nudge.
 */
export interface StaffRbacSummary {
  modules_count: number;
  modules: StaffRbacModule[];
  missing_expected: StaffRbacModule[];
}

export interface StaffMember {
  id: string;
  user_id: string;
  school_id: string;
  name: string;
  position: string;
  employee_number: string | null;
  phone: string | null;
  email: string | null;
  gender: string | null;
  employment_status: string | null;
  address: string | null;
  joined_at: string | null;
  roles: StaffRole[];
  /**
   * Access panel data for the RBAC-forward card. Optional so pre-deploy
   * responses (and legacy fixtures) still parse; the card falls back to
   * an "0 modul" empty state when it's absent.
   */
  rbac_summary?: StaffRbacSummary | null;
  created_at?: string | null;
  updated_at?: string | null;
}

/** Body for POST /staff — create a staff (and their user account) from scratch. */
export interface StaffCreatePayload {
  name: string;
  email: string;
  position: string;
  phone?: string | null;
  employee_number?: string | null;
  gender?: string | null;
  employment_status?: string | null;
  address?: string | null;
  joined_at?: string | null;
  /** RBAC role to grant in the same step (optional). */
  role_id?: number | null;
  /** Initial password for a NEW account; omit to let the server mint one. */
  password?: string | null;
}

/** PUT /staff/{id} — only the mutable data-record fields. */
export type StaffUpdatePayload = Partial<
  Pick<
    StaffCreatePayload,
    'name' | 'position' | 'phone' | 'employee_number' | 'gender' | 'employment_status' | 'joined_at'
  >
>;

/**
 * POST /staff response. `initial_password` is present ONLY when a new
 * account was minted (`user_created: true`); when an existing user was
 * linked by email it is null and no password was touched.
 */
export interface StaffCreateResult {
  data: StaffMember;
  user_created: boolean;
  initial_password: string | null;
}
