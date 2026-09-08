/**
 * `hydrateFromToken` — the Google "redirect mode" hydration path.
 *
 * Regression cover for the production report "login Google tidak ke
 * dashboard, nyantol di halaman login dengan #kg_token=...":
 *
 *   - the FAILURE path must not dead-end silently. It has to publish a
 *     user-facing `error`, drop back to the interactive login step, and
 *     clear the state that caused the failure so the retry is clean.
 *   - the stale-tenant TRIGGER: `kamiledu.school_id` lives in
 *     localStorage while the token lives in sessionStorage, so it
 *     outlives its session and `http.ts` replays it as `X-Tenant-ID`.
 *     `/me` is not on `EnsureSchoolContext`'s bypass list, so it 403s
 *     when the freshly signed-in account isn't a member of that tenant.
 *     The tenant must be validated against `/user/schools` (which the
 *     middleware DOES bypass) before `/me` is asked anything.
 *   - the SUCCESS path must still land on `step === 'done'`, which is
 *     what LoginView routes to `/` on.
 */
// @ts-nocheck — repo convention for spec files
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createPinia, setActivePinia } from 'pinia';

import { useAuthStore } from './auth';
import { AuthService } from '@/services/auth.service';
import { MeService } from '@/services/me.service';
import { StorageKeys } from '@/lib/storage';

vi.mock('@/services/me.service', () => ({
  MeService: { fetch: vi.fn() },
}));

vi.mock('@/services/auth.service', () => ({
  AuthService: {
    listSchools: vi.fn(),
    listRoles: vi.fn(),
    health: vi.fn(),
    logout: vi.fn(),
  },
}));

vi.mock('@/services/schools.service', () => ({
  SchoolService: { getActiveSchool: vi.fn().mockResolvedValue(null) },
}));

vi.mock('@/services/teachers.service', () => ({
  TeacherService: { resolveProfile: vi.fn().mockResolvedValue(null) },
}));

vi.mock('./academic-year', () => ({
  useAcademicYearStore: () => ({
    fetchAll: vi.fn().mockResolvedValue(undefined),
    reset: vi.fn(),
  }),
}));

const SCHOOL = (id: string, name = 'Sekolah ' + id) => ({ id, name });

/** Minimal /me snapshot in the shape `MeService.fetch` resolves to. */
const SNAP = (over = {}) => ({
  user: { id: 'u-1', name: 'Luay', email: 'luay@example.com', photoUrl: null },
  schoolId: null,
  isSuperAdmin: false,
  abilities: new Set<string>(),
  modules: new Set<string>(),
  subscription: null,
  fetchedAt: null,
  ...over,
});

/**
 * What the tenant headers would carry at the moment `/me` is called.
 * `http.ts` reads this exact key off localStorage on every request, so
 * reading it inside the mock is a faithful stand-in for the header.
 */
function tenantHeaderAtCallTime(): string | null {
  return window.localStorage.getItem(StorageKeys.schoolId);
}

describe('auth.hydrateFromToken — Google redirect', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    window.localStorage.clear();
    window.sessionStorage.clear();
  });

  describe('failure path (the reported dead end)', () => {
    beforeEach(() => {
      AuthService.listSchools.mockResolvedValue([SCHOOL('sch-a')]);
      MeService.fetch.mockRejectedValue(
        Object.assign(new Error('Request failed with status code 403'), {
          response: { status: 403 },
        }),
      );
    });

    it('rejects instead of silently resolving', async () => {
      const auth = useAuthStore();
      await expect(auth.hydrateFromToken('pat-123')).rejects.toThrow();
    });

    it('publishes a user-facing error so the login form can show it', async () => {
      const auth = useAuthStore();
      await auth.hydrateFromToken('pat-123').catch(() => {});

      expect(auth.error).toBeTruthy();
      expect(String(auth.error).length).toBeGreaterThan(0);
    });

    it('leaves the user on an interactive login step, not a blank wait', async () => {
      const auth = useAuthStore();
      auth.step = 'school';
      await auth.hydrateFromToken('pat-123').catch(() => {});

      // 'login' is the only step whose FormCard branch renders a form the
      // user can act on. 'done' / 'school' would spin or show an empty
      // picker forever, which is exactly the reported symptom.
      expect(auth.step).toBe('login');
    });

    it('tears the half-built session down', async () => {
      const auth = useAuthStore();
      await auth.hydrateFromToken('pat-123').catch(() => {});

      expect(auth.token).toBeNull();
      expect(auth.user).toBeNull();
      expect(auth.isAuthenticated).toBe(false);
      expect(window.sessionStorage.getItem(StorageKeys.token)).toBeNull();
    });

    it('clears the stale tenant scope so the RETRY is not poisoned again', async () => {
      window.localStorage.setItem(StorageKeys.schoolId, 'sch-from-last-user');
      window.localStorage.setItem(StorageKeys.role, 'admin');
      window.localStorage.setItem('kamiledu.academicYearId', 'ay-old');

      const auth = useAuthStore();
      await auth.hydrateFromToken('pat-123').catch(() => {});

      expect(window.localStorage.getItem(StorageKeys.schoolId)).toBeNull();
      expect(window.localStorage.getItem(StorageKeys.role)).toBeNull();
      expect(window.localStorage.getItem('kamiledu.academicYearId')).toBeNull();
      expect(auth.schoolId).toBeNull();
    });
  });

  describe('stale-tenant trigger', () => {
    it('drops a remembered tenant the new account cannot access BEFORE calling /me', async () => {
      window.localStorage.setItem(StorageKeys.schoolId, 'sch-from-last-user');
      window.localStorage.setItem(StorageKeys.role, 'admin');

      let tenantSeenByMe: string | null = 'not-called';
      AuthService.listSchools.mockResolvedValue([SCHOOL('sch-mine')]);
      MeService.fetch.mockImplementation(async () => {
        if (tenantSeenByMe === 'not-called') {
          tenantSeenByMe = tenantHeaderAtCallTime();
        }
        return SNAP({ schoolId: tenantHeaderAtCallTime() });
      });

      const auth = useAuthStore();
      await auth.hydrateFromToken('pat-123');

      // The whole point: /me must NOT have been asked with the tenant id
      // the user has no membership for — that is what returns 403.
      expect(tenantSeenByMe).toBeNull();
      expect(auth.step).toBe('done');
      expect(auth.schoolId).toBe('sch-mine');
    });

    it('keeps a remembered tenant that IS still accessible', async () => {
      window.localStorage.setItem(StorageKeys.schoolId, 'sch-mine');

      let tenantSeenByMe: string | null = 'not-called';
      AuthService.listSchools.mockResolvedValue([
        SCHOOL('sch-mine'),
        SCHOOL('sch-other'),
      ]);
      MeService.fetch.mockImplementation(async () => {
        if (tenantSeenByMe === 'not-called') {
          tenantSeenByMe = tenantHeaderAtCallTime();
        }
        return SNAP({ schoolId: tenantHeaderAtCallTime() });
      });

      const auth = useAuthStore();
      await auth.hydrateFromToken('pat-123');

      expect(tenantSeenByMe).toBe('sch-mine');
      // Remembered + still valid ⇒ straight through, no picker.
      expect(auth.step).toBe('done');
      expect(auth.schoolId).toBe('sch-mine');
    });

    it('offers the school picker instead of dead-ending when the remembered tenant is gone and several remain', async () => {
      window.localStorage.setItem(StorageKeys.schoolId, 'sch-from-last-user');

      AuthService.listSchools.mockResolvedValue([
        SCHOOL('sch-a'),
        SCHOOL('sch-b'),
      ]);
      MeService.fetch.mockImplementation(async () =>
        SNAP({ schoolId: tenantHeaderAtCallTime() }),
      );

      const auth = useAuthStore();
      await auth.hydrateFromToken('pat-123');

      expect(auth.step).toBe('school');
      expect(auth.schools.map((s) => s.id)).toEqual(['sch-a', 'sch-b']);
    });

    it('does not prune when the school list itself failed — /me still gets a say', async () => {
      window.localStorage.setItem(StorageKeys.schoolId, 'sch-mine');

      let tenantSeenByMe: string | null = 'not-called';
      AuthService.listSchools.mockRejectedValue(new Error('network down'));
      MeService.fetch.mockImplementation(async () => {
        if (tenantSeenByMe === 'not-called') {
          tenantSeenByMe = tenantHeaderAtCallTime();
        }
        return SNAP({ schoolId: tenantHeaderAtCallTime() });
      });

      const auth = useAuthStore();
      await auth.hydrateFromToken('pat-123');

      expect(tenantSeenByMe).toBe('sch-mine');
      expect(auth.step).toBe('done');
    });
  });

  describe('success path', () => {
    it('reaches step "done" — the signal LoginView routes to / on', async () => {
      AuthService.listSchools.mockResolvedValue([SCHOOL('sch-only')]);
      MeService.fetch.mockImplementation(async () =>
        SNAP({ schoolId: tenantHeaderAtCallTime() }),
      );

      const auth = useAuthStore();
      await auth.hydrateFromToken('pat-123');

      expect(auth.step).toBe('done');
      expect(auth.isAuthenticated).toBe(true);
      expect(auth.error).toBeNull();
      expect(auth.user?.email).toBe('luay@example.com');
      expect(window.sessionStorage.getItem(StorageKeys.token)).toBe('pat-123');
      expect(window.localStorage.getItem(StorageKeys.schoolId)).toBe(
        'sch-only',
      );
    });

    it('re-asks /me once the single tenant is auto-selected, so abilities are not empty', async () => {
      AuthService.listSchools.mockResolvedValue([SCHOOL('sch-only')]);
      MeService.fetch.mockImplementation(async () => {
        const tenant = tenantHeaderAtCallTime();
        return SNAP({
          schoolId: tenant,
          // The backend only knows which abilities to return once a
          // tenant is in play — exactly why the first (tenant-less)
          // answer must not be the one we keep.
          abilities: tenant ? new Set(['finance.bill.view']) : new Set(),
        });
      });

      const auth = useAuthStore();
      await auth.hydrateFromToken('pat-123');

      expect(MeService.fetch).toHaveBeenCalledTimes(2);
      expect(auth.user?.abilities).toContain('finance.bill.view');
    });
  });
});
