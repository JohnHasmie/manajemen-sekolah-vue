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
/** Who else is shut out, and who can end it. Present only when blocked. */
export interface MeBlockedContext {
  accounts: number;
  teachers: number;
  staff: number;
  students: number;
  admin: { name: string; email: string; phone: string | null } | null;
}

export interface MeSubscription {
  /** The single authoritative signal. Never infer this client-side. */
  isBlocked: boolean;
  status: string;
  expiredAt: string | null;
  daysExpired: number | null;
  plan: string | null;
  /** Rupiah, as an integer. Null when the tenant never subscribed. */
  amount: number | null;
  blockedContext: MeBlockedContext | null;
}

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
   * Whether this tenant is shut out, and what the block page needs to
   * say. Emitted by MeController via GetSubscriptionStateAction.
   *
   * Deliberately NOT derivable from `modules`: an active school that
   * has bought no optional module also has an empty module set, so a
   * client inferring the block from that would shut down a paying
   * tenant. Always ask this field.
   *
   * Null when the session has no active school, or when talking to a
   * backend that predates the field — both mean "do not block".
   */
  subscription: MeSubscription | null;

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
  /** snake_case wire shape of MeSubscription; absent on older backends. */
  subscription?: unknown;
  fetched_at?: string;
}
