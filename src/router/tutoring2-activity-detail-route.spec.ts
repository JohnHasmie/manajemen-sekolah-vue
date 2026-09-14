/**
 * The tutor activity detail route, asserted against the REAL router.
 *
 * Three separate claims live here, and each was stated as fact in a
 * comment somewhere before it was ever checked:
 *
 *   1. `/teacher/tutoring2/activities` still resolves to the LIST after
 *      a `:id` sibling was declared next to it. A detail route that
 *      swallowed its own list is the classic ordering accident.
 *   2. `/teacher/tutoring2/activities/<id>` resolves to the DETAIL and
 *      hands the id through as `params.id` — the row click pushes
 *      `params`, so a route that parsed it as anything else would give
 *      the screen an empty id and a guaranteed 404.
 *   3. A STATIC segment outranks a param regardless of declaration
 *      order. This repo depends on that in production —
 *      `teacher/tutoring2/sessions/:id` is declared ~220 lines BEFORE
 *      `sessions/new` and `sessions/recurring` — so it is pinned here
 *      rather than trusted. If a future Vue Router really did switch to
 *      declaration order, two shipped tutor screens would go dark and
 *      this is where that shows up.
 *
 * Plus the gate: `meta.ability` must be the key
 * `ActivityController::show` authorizes on, not a plausible-sounding
 * neighbour.
 */
import { describe, expect, it } from 'vitest';
import router from './index';

const LIST_PATH = '/teacher/tutoring2/activities';
const DETAIL_ID = '01a00e34-0000-4000-8000-000000000001';

function leafOf(path: string) {
  return router.resolve(path).matched.at(-1);
}

describe('teacher.tutoring2.activity-detail — route shape', () => {
  it('leaves the list path resolving to the list', () => {
    expect(router.resolve(LIST_PATH).name).toBe('teacher.tutoring2.activities');
  });

  it('resolves an id to the detail screen and passes it as params.id', () => {
    const r = router.resolve(`${LIST_PATH}/${DETAIL_ID}`);
    expect(r.name).toBe('teacher.tutoring2.activity-detail');
    expect(r.params.id).toBe(DETAIL_ID);
  });

  it('gates on the ability ActivityController::show authorizes', () => {
    // `$this->authorize('tutoring.activity.view')` is the first line of
    // `show`. `tutoring.activity.manage` would be STRICTER than the
    // server and would hide a readable screen from a tutor whose tenant
    // granted read only.
    expect(leafOf(`${LIST_PATH}/${DETAIL_ID}`)?.meta?.ability).toBe(
      'tutoring.activity.view',
    );
  });

  it('still carries the tutoring module + teacher role gates its siblings do', () => {
    const meta = leafOf(`${LIST_PATH}/${DETAIL_ID}`)?.meta;
    expect(meta?.role).toBe('teacher');
    expect(meta?.needs).toBe('tutoring-module');
  });
});

describe('static segments outrank params in the shipped router', () => {
  // Positive control: these two literals are declared ~220 lines AFTER
  // `teacher/tutoring2/sessions/:id`. If declaration order won, both
  // would resolve to the session detail with an id of "new"/"recurring"
  // and two live tutor screens would be unreachable.
  it.each([
    ['/teacher/tutoring2/sessions/new', 'teacher.tutoring2.session-create'],
    ['/teacher/tutoring2/sessions/recurring', 'teacher.tutoring2.sessions-recurring'],
  ])('%s resolves to %s, not the :id detail', (path, name) => {
    expect(router.resolve(path).name).toBe(name);
  });

  it('and the param route still matches a real id', () => {
    expect(router.resolve(`/teacher/tutoring2/sessions/${DETAIL_ID}`).name).toBe(
      'teacher.tutoring2.session-detail',
    );
  });
});
