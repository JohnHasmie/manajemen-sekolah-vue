/**
 * Type definitions for the /me abilities snapshot.
 *
 * Mirrors Flutter's `MeSnapshot` (lib/features/me/data/me_service.dart)
 * one-to-one so the same server response speaks to both clients. The
 * server payload is defined by the Phase A backend `Me` controller
 * (app/Modules/Auth/Http/Controllers/MeController.php, MR !225).
 */

export interface MeUser {
  id: string;
  name: string;
  email: string;
  photoUrl: string | null;
}

/**
 * Immutable ability snapshot for the currently-active school + role.
 *
 * Consumed by:
 *   - useNavMenu.ts (hides sidebar items when `ability` set and not held)
 *   - views/components (v-if="me.can('rbac.role.view')")
 *   - route guards (future — currently guarded by `role:` meta)
 */
export interface MeSnapshot {
  user: MeUser;
  schoolId: string | null;
  /**
   * True when the platform `super_admin` role sits on the user.
   * Short-circuits `can()` / `canAny()` — a super-admin sees every
   * ability regardless of the abilities set.
   */
  isSuperAdmin: boolean;
  /**
   * Flat permission-key set from the resolver, e.g.
   *   { "finance.bill.view", "rbac.role.create", ... }
   *
   * A Set (not an array) so `has()` is O(1) — the nav menu iterates
   * every render.
   */
  abilities: Set<string>;
  /**
   * Sellable-module keys the tenant currently entitles, e.g.
   *   { "attendance_class", "grades", "communication" }
   *
   * Emitted by MeController alongside `abilities` (see backend
   * MeController.php `modules` field). Distinct from abilities
   * because a nav item can gate on "tenant owns any module that
   * needs siswa roster" — that's a fact about modules, not any
   * single permission key.
   *
   * Empty Set for demo tenants pre-hydration; super-admin should
   * NOT check this — they see everything regardless.
   */
  modules: Set<string>;
  /**
   * Backend timestamp of the snapshot. Used by the debug page to show
   * "last refreshed" — never load-bearing for gating.
   */
  fetchedAt: string | null;
}

/** Raw server payload shape from GET /me — kept internal to the service. */
export interface MeResponseShape {
  user?: {
    id?: string | number;
    name?: string;
    email?: string;
    photo_url?: string | null;
  };
  school_id?: string | null;
  is_super_admin?: boolean;
  abilities?: string[];
  modules?: string[];
  fetched_at?: string;
}
