/**
 * The picker's `?target=` allow-list, now read in BOTH directions.
 *
 * Forward (`resolveParentTutoring2Target`) is what the picker has always
 * done: a child was tapped, send them to the screen `?target=` names —
 * through an allow-list, because `target` comes off the URL and an
 * unchecked value would let a crafted link bounce a wali into any named
 * route in the app.
 *
 * Reverse (`parentTutoring2TargetKey`) is what the "Ganti anak" link
 * needs: the wali is ON a per-child screen and wants a different child,
 * so which `?target=` brings them back HERE? The two halves have to
 * agree or the wali loses their place — which is exactly what the picker
 * did before it had a key for every screen.
 */
import { describe, expect, it } from 'vitest';
import {
  PARENT_TUTORING2_DEFAULT_TARGET,
  PARENT_TUTORING2_TARGETS,
  parentTutoring2TargetKey,
  resolveParentTutoring2Target,
} from './parent-tutoring2-targets';
import router from './index';

describe('parent tutoring2 target allow-list', () => {
  it('every key round-trips, so a switcher returns the wali where they were', () => {
    for (const key of Object.keys(PARENT_TUTORING2_TARGETS)) {
      const routeName = resolveParentTutoring2Target(key);
      expect(parentTutoring2TargetKey(routeName)).toBe(key);
    }
  });

  it('every destination is a route the router will actually match', () => {
    // Reading the real router rather than a list copied in here means
    // renaming a route fails this test even though it did not change.
    const registered = new Set(
      router
        .getRoutes()
        .map((r) => r.name)
        .filter((n): n is string => typeof n === 'string'),
    );

    for (const name of Object.values(PARENT_TUTORING2_TARGETS)) {
      expect(registered).toContain(name);
    }
  });

  it('every destination is addressed by :studentId — a target that is not per-child is a bug', () => {
    // The picker hands the chosen child over as a route PARAM. A target
    // whose path has no `:studentId` would silently drop it and land the
    // wali on a screen that is not about the child they just picked.
    const byName = new Map(router.getRoutes().map((r) => [r.name, r.path]));

    for (const name of Object.values(PARENT_TUTORING2_TARGETS)) {
      expect(byName.get(name)).toContain(':studentId');
    }
  });

  it('refuses an unrecognised target instead of routing to it', () => {
    expect(resolveParentTutoring2Target('admin.tutoring2.payouts.summary')).toBe(
      PARENT_TUTORING2_TARGETS[PARENT_TUTORING2_DEFAULT_TARGET],
    );
    expect(resolveParentTutoring2Target(undefined)).toBe(
      PARENT_TUTORING2_TARGETS[PARENT_TUTORING2_DEFAULT_TARGET],
    );
  });

  it('returns null — not the default — for a route that is not a destination', () => {
    // `null` has to stay distinguishable from "attendance". A caller
    // that turned an unknown route into the default key would send a
    // wali switching child on an unlisted screen to Kehadiran instead
    // of leaving them to be routed by the picker's own fallback.
    expect(parentTutoring2TargetKey('parent.tutoring2.history')).toBeNull();
    expect(parentTutoring2TargetKey('parent.tutoring2.enroll')).toBeNull();
    expect(parentTutoring2TargetKey('')).toBeNull();
  });
});
