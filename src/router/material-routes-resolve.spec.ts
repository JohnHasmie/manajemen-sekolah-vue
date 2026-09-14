/**
 * The literal routes under `teacher/tutoring2/materials` must keep
 * winning over the new `:id` one.
 *
 * A detail route is a param segment sitting exactly where a literal
 * sibling already lives — `materials/new`, the upload screen a tutor
 * reaches from the floating "Unggah materi" button. Get the precedence
 * wrong and that button silently opens a material detail for a material
 * whose id is the string "new", which 404s. Nothing else in the tree
 * would notice: it type-checks, it builds, and every existing spec stays
 * green, because none of them resolve a PATH.
 *
 * That last part is worth stating plainly, because a comment in
 * `router/index.ts` claims `route-names-resolve.spec.ts` pins this. It
 * does not — that guard only checks that every `{ name }` a view pushes
 * is registered, and never calls `router.resolve()` on a path. A comment
 * is a claim, not evidence, so here is the evidence.
 *
 * Vue Router 4 ranks a static segment above a param regardless of
 * declaration order, so the assertion below should hold whatever order
 * the routes are written in. Pinning the OUTCOME rather than the order
 * means a future reshuffle — or a router upgrade that changed the
 * ranking rules — fails here instead of in production.
 */
import { describe, expect, it } from 'vitest';
import router from './index';

/** Every literal (param-free) path registered under the materials tree. */
function materialLiterals(): string[] {
  return router
    .getRoutes()
    .map((r) => r.path)
    .filter((p) => p.includes('/materials/') && !p.includes(':'));
}

describe('tutor materials routes — literal vs :id', () => {
  it('resolves the upload screen, not the detail one, for materials/new', () => {
    const match = router.resolve('/teacher/tutoring2/materials/new');
    expect(match.name).toBe('teacher.tutoring2.material-upload');
  });

  it('resolves a real id to the detail screen', () => {
    const match = router.resolve(
      '/teacher/tutoring2/materials/019f8090-4d6a-71ab-bf01-c98a6ac73293',
    );
    expect(match.name).toBe('teacher.tutoring2.material-detail');
    expect(match.params.id).toBe('019f8090-4d6a-71ab-bf01-c98a6ac73293');
  });

  it('still resolves the list itself', () => {
    expect(router.resolve('/teacher/tutoring2/materials').name).toBe(
      'teacher.tutoring2.materials',
    );
  });

  /**
   * Derived from the router, not typed out here. A literal added under
   * `materials/` later — `materials/import`, say — lands in this list on
   * its own and gets the same resolution check, instead of quietly
   * relying on someone remembering this file exists.
   */
  it('every literal under materials/ resolves to its own route, not to :id', () => {
    const literals = materialLiterals();
    // Guards the guard: an empty list would make the loop below vacuous.
    expect(literals).toContain('/teacher/tutoring2/materials/new');

    for (const path of literals) {
      expect(router.resolve(path).name).not.toBe('teacher.tutoring2.material-detail');
    }
  });

  /**
   * The detail route mirrors what the server enforces on `show`:
   * `MaterialController@show` opens with
   * `authorize('tutoring.material.view')`. The WRITE key
   * (`tutoring.material.manage`, gating update/destroy) is deliberately
   * NOT here — a tutor who may read but not edit must still reach the
   * page and see it read-only, rather than being bounced to their home.
   */
  it('gates the detail route on the ability show actually checks', () => {
    const detail = router
      .getRoutes()
      .find((r) => r.name === 'teacher.tutoring2.material-detail');
    expect(detail?.meta.ability).toBe('tutoring.material.view');
    expect(detail?.meta.needs).toBe('tutoring-module');
  });
});
