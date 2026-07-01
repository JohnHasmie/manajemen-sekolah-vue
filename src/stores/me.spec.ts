/**
 * Vitest spec for useMeStore (Phase D).
 *
 * See services/rbac.service.spec.ts for adoption notes — this file is
 * also typecheck-only until Vitest lands (`npm i -D vitest ...`).
 *
 * Tests focus on the load-bearing contracts consumers depend on:
 *   - can() fail-closed BEFORE snapshot loads (sidebar can't flash)
 *   - super-admin short-circuit (single flag flips every check)
 *   - concurrent refresh() calls share one in-flight promise
 *   - reset() truly wipes state
 */
// @ts-nocheck — vitest types not installed yet
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { useMeStore } from './me';
import { MeService } from '@/services/me.service';

vi.mock('@/services/me.service', () => ({
  MeService: {
    fetch: vi.fn(),
  },
}));

const SNAP = (over = {}) => ({
  user: { id: 'u1', name: 'Ana', email: 'a@x', photoUrl: null },
  schoolId: 'sch_1',
  isSuperAdmin: false,
  abilities: new Set(['finance.bill.view', 'rbac.role.view']),
  fetchedAt: null,
  ...over,
});

describe('useMeStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  describe('can() fail-closed', () => {
    it('returns false for any ability before the first refresh lands', () => {
      const me = useMeStore();
      expect(me.can('anything.at.all')).toBe(false);
      expect(me.canAny(['a.b.c'])).toBe(false);
    });

    it('returns true only for abilities present in the snapshot', async () => {
      (MeService.fetch as any).mockResolvedValueOnce(SNAP());
      const me = useMeStore();
      await me.refresh();
      expect(me.can('finance.bill.view')).toBe(true);
      expect(me.can('finance.bill.create')).toBe(false);
    });
  });

  describe('super-admin short-circuit', () => {
    it('returns true for every ability when isSuperAdmin', async () => {
      (MeService.fetch as any).mockResolvedValueOnce(
        SNAP({ isSuperAdmin: true, abilities: new Set() }),
      );
      const me = useMeStore();
      await me.refresh();
      expect(me.can('rbac.role.manage')).toBe(true);
      expect(me.can('nonexistent.permission')).toBe(true);
      expect(me.canAny(['x.y.z'])).toBe(true);
    });
  });

  describe('canAny', () => {
    it('returns true when ANY of the abilities is held', async () => {
      (MeService.fetch as any).mockResolvedValueOnce(SNAP());
      const me = useMeStore();
      await me.refresh();
      expect(me.canAny(['x.y.z', 'rbac.role.view'])).toBe(true);
      expect(me.canAny(['x.y.z', 'q.r.s'])).toBe(false);
    });
  });

  describe('refresh() coalescing', () => {
    it('deduplicates overlapping refresh calls onto one network round-trip', async () => {
      let resolveFetch: (v: any) => void = () => {};
      const pending = new Promise((r) => (resolveFetch = r));
      (MeService.fetch as any).mockReturnValueOnce(pending);

      const me = useMeStore();
      const p1 = me.refresh();
      const p2 = me.refresh();
      const p3 = me.refresh();

      // All three should be the SAME promise instance (in-flight coalesce).
      expect(p1).toBe(p2);
      expect(p2).toBe(p3);
      // Exactly one HTTP call fired despite three refresh() invocations.
      expect(MeService.fetch).toHaveBeenCalledTimes(1);

      resolveFetch(SNAP());
      await p1;
    });

    it('allows a fresh call after the previous refresh settles', async () => {
      (MeService.fetch as any).mockResolvedValue(SNAP());
      const me = useMeStore();
      await me.refresh();
      await me.refresh();
      expect(MeService.fetch).toHaveBeenCalledTimes(2);
    });
  });

  describe('reset()', () => {
    it('wipes the snapshot and error state', async () => {
      (MeService.fetch as any).mockResolvedValueOnce(SNAP());
      const me = useMeStore();
      await me.refresh();
      expect(me.snapshot).not.toBeNull();

      me.reset();
      expect(me.snapshot).toBeNull();
      expect(me.error).toBeNull();
      // After reset, can() is fail-closed again.
      expect(me.can('finance.bill.view')).toBe(false);
    });
  });

  describe('error handling', () => {
    it('records the error message and leaves snapshot null', async () => {
      (MeService.fetch as any).mockRejectedValueOnce(new Error('boom'));
      const me = useMeStore();
      const result = await me.refresh();
      expect(result).toBeNull();
      expect(me.error).toBe('boom');
      expect(me.snapshot).toBeNull();
      expect(me.can('x')).toBe(false);
    });
  });
});
