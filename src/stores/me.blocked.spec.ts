import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it } from 'vitest';

import { useMeStore } from '@/stores/me';
import type { MeSnapshot, MeSubscription } from '@/types/me';

/**
 * `isSubscriptionBlocked` decides whether the whole app is replaced by
 * the block page, so both directions of a mistake are expensive: a false
 * positive blacks out a paying school, a false negative lets a lapsed one
 * keep working.
 *
 * The case worth writing down is the third one. An ACTIVE school that has
 * bought no optional module has an empty `modules` set — indistinguishable
 * from an expired tenant from here — which is exactly why this flag comes
 * from the server instead of being inferred locally.
 */
function snapshot(over: Partial<MeSnapshot> = {}): MeSnapshot {
  return {
    user: { id: 'u1', name: 'Agus', email: 'a@b.c', photoUrl: null },
    schoolId: 's1',
    isSuperAdmin: false,
    abilities: new Set<string>(),
    modules: new Set<string>(),
    subscription: null,
    fetchedAt: null,
    ...over,
  } as MeSnapshot;
}

function sub(over: Partial<MeSubscription> = {}): MeSubscription {
  return {
    isBlocked: false,
    status: 'active',
    expiredAt: null,
    daysExpired: null,
    plan: 'monthly',
    amount: 250000,
    blockedContext: null,
    ...over,
  };
}

describe('me store — subscription block', () => {
  beforeEach(() => setActivePinia(createPinia()));

  it('blocks when the server says the tenant is blocked', () => {
    const me = useMeStore();
    me.snapshot = snapshot({
      subscription: sub({ isBlocked: true, status: 'expired', daysExpired: 3 }),
    });

    expect(me.isSubscriptionBlocked).toBe(true);
  });

  it('does not block an active tenant that owns zero modules', () => {
    // The reason the flag is not derived from `modules.size`. This school
    // is healthy; inferring would take it offline.
    const me = useMeStore();
    me.snapshot = snapshot({
      modules: new Set<string>(),
      subscription: sub({ isBlocked: false, status: 'active' }),
    });

    expect(me.hasStudentContext).toBe(false);
    expect(me.isSubscriptionBlocked).toBe(false);
  });

  it('never blocks a super admin', () => {
    // They are who goes in and fixes the tenant. Server says the same,
    // but a client that forgot this check would strand them.
    const me = useMeStore();
    me.snapshot = snapshot({
      isSuperAdmin: true,
      subscription: sub({ isBlocked: true, status: 'expired' }),
    });

    expect(me.isSubscriptionBlocked).toBe(false);
  });

  it('fails open when the backend predates the field', () => {
    // An older API omits `subscription` entirely. Defaulting the other
    // way would black out every client the moment it met one.
    const me = useMeStore();
    me.snapshot = snapshot({ subscription: null });

    expect(me.isSubscriptionBlocked).toBe(false);
  });

  it('fails open before the first snapshot lands', () => {
    const me = useMeStore();
    expect(me.snapshot).toBeNull();
    expect(me.isSubscriptionBlocked).toBe(false);
  });
});
