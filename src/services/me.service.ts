/**
 * MeService — thin wrapper over `GET /me`.
 *
 * Server: app/Modules/Auth/Http/Controllers/MeController.php (backend
 * MR !225). Returns the currently-active school's abilities for the
 * active role, plus a super-admin flag.
 *
 * Mirrors the Flutter service so the two clients evolve together:
 *   lib/features/me/data/me_service.dart
 */

import { api } from '@/lib/http';
import type { MeResponseShape, MeSnapshot, MeSubscription } from '@/types/me';

/** Unwrap the standard Laravel `{ success, data }` envelope. */
function unwrap<T>(payload: unknown): T {
  if (payload && typeof payload === 'object' && 'data' in (payload as any)) {
    return ((payload as any).data ?? payload) as T;
  }
  return payload as T;
}

function normalizeSnapshot(raw: MeResponseShape): MeSnapshot {
  const abilitiesRaw = raw.abilities;
  const abilities = new Set<string>(
    Array.isArray(abilitiesRaw)
      ? abilitiesRaw.filter((a): a is string => typeof a === 'string')
      : [],
  );

  const modulesRaw = raw.modules;
  const modules = new Set<string>(
    Array.isArray(modulesRaw)
      ? modulesRaw.filter((m): m is string => typeof m === 'string')
      : [],
  );

  return {
    user: {
      id: String(raw.user?.id ?? ''),
      name: String(raw.user?.name ?? ''),
      email: String(raw.user?.email ?? ''),
      photoUrl: raw.user?.photo_url ?? null,
    },
    schoolId: raw.school_id ?? null,
    isSuperAdmin: raw.is_super_admin === true,
    abilities,
    modules,
    subscription: normalizeSubscription(raw.subscription),
    fetchedAt: raw.fetched_at ?? null,
  };
}

/**
 * Maps the `subscription` block, tolerating its absence.
 *
 * A backend that predates the field, or a session with no active
 * school, yields null — and null must mean "not blocked". Defaulting
 * the other way would black out every client the moment they met an
 * older API.
 */
function normalizeSubscription(raw: any): MeSubscription | null {
  if (!raw || typeof raw !== 'object') return null;

  const ctx = raw.blocked_context;

  return {
    isBlocked: raw.is_blocked === true,
    status: String(raw.status ?? 'none'),
    expiredAt: raw.expired_at ?? null,
    daysExpired: typeof raw.days_expired === 'number' ? raw.days_expired : null,
    plan: raw.plan ?? null,
    amount: typeof raw.amount === 'number' ? raw.amount : null,
    blockedContext:
      ctx && typeof ctx === 'object'
        ? {
            accounts: Number(ctx.accounts ?? 0),
            teachers: Number(ctx.teachers ?? 0),
            staff: Number(ctx.staff ?? 0),
            students: Number(ctx.students ?? 0),
            admin: ctx.admin
              ? {
                  name: String(ctx.admin.name ?? ''),
                  email: String(ctx.admin.email ?? ''),
                  phone: ctx.admin.phone ?? null,
                }
              : null,
          }
        : null,
  };
}

export const MeService = {
  /**
   * Fetches the /me snapshot for the currently-authenticated user.
   *
   * Throws on network / 401. The caller (me store) turns that into
   * a `null` snapshot + `error` state so views can render a
   * degraded-but-safe UI ("Menyembunyikan menu — tidak ada koneksi").
   */
  async fetch(): Promise<MeSnapshot> {
    const res = await api.get('/me');
    const raw = unwrap<MeResponseShape>(res.data);
    return normalizeSnapshot(raw ?? {});
  },
};

export type MeServiceType = typeof MeService;
