/**
 * Me store — Pinia equivalent of Flutter's `meProvider` NotifierProvider.
 *
 * Holds the active-school-+-role ability snapshot. Refreshed whenever
 * auth transitions land on step=='done' or the user switches school /
 * role — see `stores/auth.ts` for the wiring.
 *
 * Consumer contract:
 *   const me = useMeStore();
 *   me.can('finance.bill.view')     // guarded action / render
 *   me.canAny(['a.b.c','d.e.f'])    // "any of these"
 *   me.snapshot                     // reactive; null before first load
 *
 * Design decisions:
 *   - `snapshot` is a shallowRef of an object — cheap to swap wholesale
 *     when a fresh /me lands, and never mutated in place. Views read
 *     `.value` and Vue re-renders only when the reference changes.
 *   - `can()` / `canAny()` are exposed as store methods (not computeds)
 *     because they take runtime string args. They safely short-circuit
 *     when the snapshot is still null (returns false).
 *   - `refresh()` is idempotent per in-flight promise: overlapping
 *     calls (e.g. selectSchool → selectRole in rapid succession) share
 *     a single network round-trip.
 */
import { defineStore } from 'pinia';
import { computed, ref, shallowRef } from 'vue';

import { MeService } from '@/services/me.service';
import type { MeSnapshot } from '@/types/me';

export const useMeStore = defineStore('me', () => {
  const snapshot = shallowRef<MeSnapshot | null>(null);
  const loading = ref(false);
  const error = ref<string | null>(null);
  let inFlight: Promise<MeSnapshot | null> | null = null;

  /** True when we've successfully hydrated at least once. */
  const hasSnapshot = computed(() => snapshot.value !== null);

  /** True while the very first fetch is in flight (used by app splash). */
  const isInitialLoading = computed(
    () => loading.value && snapshot.value === null,
  );

  /**
   * Fetch a fresh /me snapshot. Coalesces concurrent callers onto a
   * single request so `selectSchool()` → `selectRole()` (which both
   * fire refresh in the auth store) doesn't double-hit the backend.
   */
  async function refresh(): Promise<MeSnapshot | null> {
    if (inFlight) return inFlight;
    loading.value = true;
    error.value = null;
    inFlight = (async () => {
      try {
        const next = await MeService.fetch();
        snapshot.value = next;
        return next;
      } catch (e) {
        error.value = (e as Error).message ?? String(e);
        return null;
      } finally {
        loading.value = false;
        inFlight = null;
      }
    })();
    return inFlight;
  }

  /**
   * Permission check. Returns false when the snapshot hasn't loaded
   * — deliberately fail-closed so a race between mount and hydration
   * never flashes a menu item the user can't actually use.
   */
  function can(ability: string): boolean {
    const snap = snapshot.value;
    if (!snap) return false;
    if (snap.isSuperAdmin) return true;
    return snap.abilities.has(ability);
  }

  function canAny(abilities: Iterable<string>): boolean {
    const snap = snapshot.value;
    if (!snap) return false;
    if (snap.isSuperAdmin) return true;
    for (const a of abilities) {
      if (snap.abilities.has(a)) return true;
    }
    return false;
  }

  /**
   * Wipe. Called by the auth store on logout so the next login can't
   * transiently see the previous user's abilities.
   */
  function reset() {
    snapshot.value = null;
    error.value = null;
    loading.value = false;
    inFlight = null;
  }

  return {
    // state
    snapshot,
    loading,
    error,
    // derived
    hasSnapshot,
    isInitialLoading,
    // actions
    refresh,
    can,
    canAny,
    reset,
  };
});
