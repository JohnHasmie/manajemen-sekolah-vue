/**
 * The ADMIN bimbel session routes, asserted against the REAL router.
 *
 * `admin/tutoring2/sessions/recurring` is a literal segment declared
 * alongside an existing `admin/tutoring2/sessions/:id` param route. Vue
 * Router 4 ranks a static segment ABOVE a param regardless of
 * declaration order, so the literal wins — but that is a property of
 * the router, not of this repo, and the sibling tutor tree already
 * depends on it in production. It is pinned here rather than trusted:
 * if it ever stopped holding, `/admin/tutoring2/sessions/recurring`
 * would resolve to a session detail for a session whose id is the
 * literal string "recurring", and the screen would go dark with a 404
 * instead of an error anyone could read.
 *
 * (Do NOT carry the go_router rule over from the Flutter half of this
 * repo. There, declaration order really does win and a literal after a
 * `:id` is dead. Here it is not — which is exactly why both directions
 * are asserted below rather than argued about.)
 *
 * The param route is asserted in the SAME file on purpose: a change
 * that fixed one by breaking the other would otherwise pass.
 */
import { describe, expect, it } from 'vitest';
import router from './index';

const BASE = '/admin/tutoring2/sessions';
const DETAIL_ID = '01a00e34-0000-4000-8000-000000000042';

function leafOf(path: string) {
  return router.resolve(path).matched.at(-1);
}

describe('admin.tutoring2 session routes — resolution', () => {
  it('resolves the recurring literal to the recurring screen', () => {
    expect(router.resolve(`${BASE}/recurring`).name).toBe(
      'admin.tutoring2.sessions-recurring',
    );
  });

  it('still resolves a real id to the session detail, with params.id', () => {
    const r = router.resolve(`${BASE}/${DETAIL_ID}`);
    expect(r.name).toBe('admin.tutoring2.session.detail');
    expect(r.params.id).toBe(DETAIL_ID);
  });

  it('leaves the pre-existing create literal alone', () => {
    expect(router.resolve(`${BASE}/new`).name).toBe(
      'admin.tutoring2.session-create',
    );
  });
});

describe('admin.tutoring2.sessions-recurring — gate', () => {
  it('gates on the ability SessionController::storeRecurring authorizes', () => {
    // `$this->authorize('tutoring.session.manage')` is the first line of
    // `storeRecurring`. This route is a write form end to end — there is
    // nothing to read on it — so bouncing beats rendering a form whose
    // submit the server will refuse.
    expect(leafOf(`${BASE}/recurring`)?.meta?.ability).toBe(
      'tutoring.session.manage',
    );
  });

  it('carries the admin role + tutoring module gates its siblings do', () => {
    const meta = leafOf(`${BASE}/recurring`)?.meta;
    expect(meta?.role).toBe('admin');
    expect(meta?.needs).toBe('tutoring-module');
  });
});
