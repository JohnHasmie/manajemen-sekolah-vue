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
import type { MeResponseShape, MeSnapshot } from '@/types/me';

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
    fetchedAt: raw.fetched_at ?? null,
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
