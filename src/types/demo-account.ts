/**
 * Types for the super-admin demo-account management + incomplete
 * (abandoned) demo-registration features (backend MR: super-admin
 * demo-account delete + incomplete-registrations list).
 *
 * Source of truth:
 *   - app/Modules/Demo/Http/Controllers/DemoAccountAdminController.php
 *       GET    /api/demo-schools/{schoolId}/accounts        (counts)
 *       DELETE /api/demo-schools/{schoolId}/accounts?mode=… (delete)
 *   - app/Modules/Demo/Http/Controllers/DemoIncompleteRegistrationController.php
 *       GET    /api/demo-incomplete-registrations           (list)
 *
 * EVERY delete is gated server-side by the `super_admin` middleware AND
 * the DeleteDemoSchoolAccountsAction re-asserts schools.is_demo=true, so
 * a real (non-demo) tenant can NEVER be touched from here.
 */

/** Delete scope: all accounts, or a single role. */
export type DemoAccountDeleteMode = 'all' | 'guru' | 'admin' | 'wali';

/**
 * Per-role account counts for a demo school.
 *
 * The backend currently dual-emits English + Indonesian keys
 * (teacher/guru, parent/wali). Phase 8 will drop the Indonesian
 * keys, so callers MUST prefer the English ones and fall back to
 * the Indonesian only for older backends still in flight.
 */
export interface DemoAccountCountsByRole {
  admin: number;
  /** English canonical (phase-8 forward). */
  teacher?: number;
  /** English canonical (phase-8 forward). */
  parent?: number;
  /** Indonesian legacy — DROPPED in phase 8 cleanup. */
  guru?: number;
  /** Indonesian legacy — DROPPED in phase 8 cleanup. */
  wali?: number;
  /** Pivots whose role isn't one of the three managed buckets. */
  other: number;
}

/** Response of GET /demo-schools/{schoolId}/accounts. */
export interface DemoAccountCounts {
  school_id: string;
  is_demo: boolean;
  total_accounts: number;
  by_role: DemoAccountCountsByRole;
}

/** Summary returned by DELETE /demo-schools/{schoolId}/accounts. */
export interface DemoAccountDeleteResult {
  school_id: string;
  mode: DemoAccountDeleteMode;
  /** Underlying `users` rows force-deleted (demo-only members). */
  deleted_users: number;
  /** `users_schools` pivot rows removed from the demo school. */
  detached_pivots: number;
  /** `users_roles` rows removed. */
  deleted_roles: number;
  /** Per-role breakdown of removed role rows, e.g. { teacher: 12 }. */
  deleted_by_role: Record<string, number>;
}

/**
 * Summary returned by DELETE /demo-schools/{schoolId} — deleting the
 * ENTIRE demo school (the school row + ALL its provisioned data).
 *
 * Source of truth:
 *   - app/Modules/Demo/Actions/DeleteDemoSchoolAction.php
 *   - app/Modules/Demo/Http/Resources/DeleteDemoSchoolResource.php
 *
 * Strictly demo-only: the backend re-asserts schools.is_demo=true, so a
 * real (non-demo) tenant can NEVER be deleted from here.
 */
export interface DeleteDemoSchoolResult {
  /** False on the idempotent no-op path (school already gone). */
  deleted: boolean;
  school_id: string;
  school_name: string | null;
  /** Demo-only `users` rows hard-deleted. */
  deleted_users: number;
  /** Users shared with another (real) school — detached, NOT deleted. */
  detached_users: number;
  /** Explicit per-table delete counts for non-cascading tables. */
  deleted_records: Record<string, number>;
  /** `demo_requests` rows reset (activated_school_id nulled + expired). */
  demo_requests_reset: number;
}

/** The user who started an abandoned registration (Google sign-in). */
export interface IncompleteRegistrationRequester {
  id: string;
  name: string | null;
  email: string | null;
}

/** One abandoned demo registration row. */
export interface IncompleteRegistration {
  id: string;
  user_id: string;
  requester: IncompleteRegistrationRequester | null;
  /** 0-indexed step the user stopped at. */
  current_step: number;
  /** 1-indexed display step ("Langkah {display_step} dari {total_steps}"). */
  display_step: number;
  total_steps: number;
  /** 0..100 rough progress. */
  progress_percent: number;
  /** School name the user had typed so far (may be null). */
  school_name_draft: string | null;
  last_active_at: string | null;
  created_at: string | null;
  updated_at: string | null;
}

export interface IncompleteRegistrationListMeta {
  current_page: number;
  last_page: number;
  per_page: number;
  total: number;
}

export interface IncompleteRegistrationListResult {
  items: IncompleteRegistration[];
  meta: IncompleteRegistrationListMeta;
}

export interface IncompleteRegistrationListParams {
  per_page?: number;
  page?: number;
}
