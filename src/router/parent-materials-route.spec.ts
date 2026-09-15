/**
 * The wali "Bahan Ajar" route must actually be registered.
 *
 * ── Why a resolution test and not a "route exists" one ──
 *
 * The catch-all (`/:pathMatch(.*)*`, an unnamed redirect to `/`) matches
 * ANY path, so `router.resolve()` returning something is not evidence
 * that a route exists — it is evidence that the catch-all did its job.
 * Every assertion here reads the resolved leaf's NAME, which the
 * catch-all does not have. An earlier guard elsewhere in this tree
 * asserted `matched.length > 0` and passed against every dead path it
 * was written to catch; this file does not repeat that.
 *
 * ── Why the gate is asserted here too ──
 *
 * `MaterialController@index` opens with
 * `authorize('tutoring.material.view')`, and the router's own
 * `beforeEach` bounces a route whose `meta.ability` the caller does not
 * hold. Pinning the meta here is what makes the nav gate in
 * `useNavMenu.parent-tutoring.spec.ts` meaningful: that spec asserts the
 * MENU hides the row, and this one asserts the ROUTE would have refused
 * the click anyway. A gate on one side only is the defect both are for.
 *
 * The write key (`tutoring.material.manage`) is deliberately NOT here. A
 * wali never holds it — `PermissionCatalog::parentTutoringDefaults()`
 * grants the read key alone — and gating the screen on it would hide the
 * screen from every wali who exists.
 */
import { describe, expect, it } from 'vitest';
import router from './index';

const PARENT_MATERIALS_PATH = '/parent/tutoring2/materials';

/**
 * Resolves to a REAL route, not to the unnamed catch-all. Mirrors the
 * helper `useNavMenu.parent-tutoring.spec.ts` uses, for the same reason.
 */
function resolvesToRealRoute(path: string): boolean {
  const resolved = router.resolve(path);
  if (resolved.matched.length === 0) return false;
  const leaf = resolved.matched[resolved.matched.length - 1];
  return typeof leaf.name === 'string' && !leaf.path.includes('pathMatch');
}

describe('wali Bahan Ajar route', () => {
  it('is registered rather than falling through to the catch-all', () => {
    expect(resolvesToRealRoute(PARENT_MATERIALS_PATH)).toBe(true);
  });

  it('resolves to the parent materials screen', () => {
    expect(router.resolve(PARENT_MATERIALS_PATH).name).toBe(
      'parent.tutoring2.materials',
    );
  });

  /**
   * Flat, not `/:studentId`. The endpoint has no student dimension —
   * `MaterialListParams` is group/programme/kind only — and the wali read
   * scope is a UNION of the children's groups OR their programmes, so a
   * programme-pinned material (`learning_group_id = null`) belongs to no
   * single child's group. Narrowing the screen by one child would hide
   * that entire category. Same call the Tagihan and Riwayat rows made.
   *
   * Asserted so a later "make it child-scoped like the siblings" change
   * has to read the reasoning before it lands.
   */
  it('takes no :studentId param', () => {
    const route = router
      .getRoutes()
      .find((r) => r.name === 'parent.tutoring2.materials');
    // `getRoutes()` reports the RESOLVED path (leading slash, parent
    // prefix applied), not the nested `path:` string as written in the
    // route record. Asserting the latter fails against a correct route.
    expect(route?.path).toBe(PARENT_MATERIALS_PATH);
    expect(route?.path).not.toContain(':');
    expect(router.resolve(PARENT_MATERIALS_PATH).params).toEqual({});
  });

  it('gates on the ability the index actually authorizes', () => {
    const route = router
      .getRoutes()
      .find((r) => r.name === 'parent.tutoring2.materials');
    expect(route?.meta.ability).toBe('tutoring.material.view');
    expect(route?.meta.role).toBe('parent');
    expect(route?.meta.needs).toBe('tutoring-module');
  });
});
