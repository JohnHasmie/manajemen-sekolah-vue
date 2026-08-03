import type { FixtureKey } from './accounts';

/**
 * The curated deny matrix.
 *
 * Every row here was probed against the running stack before being
 * written down — none is an assumption about what the policy "should"
 * be. Where the observed behaviour looked wrong it was investigated
 * before being encoded, not encoded and explained later.
 *
 * ── Why every deny is paired with an allow ──────────────────────────
 * A matrix of pure 403-expectations passes just as happily when the
 * token is broken, the tenant header is missing, or the account was
 * never seeded. The control row proves the client is genuinely
 * authenticated as that role, so the 403 next to it means "denied",
 * not "never got in".
 */

export interface MatrixRow {
  fixture: FixtureKey;
  method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  path: string;
  expect: number;
  /** Why this row exists — printed on failure. */
  because: string;
  body?: unknown;
}

export const DENY_MATRIX: MatrixRow[] = [
  // ── parent ────────────────────────────────────────────────────────
  {
    fixture: 'parent',
    method: 'GET',
    path: '/bills',
    expect: 403,
    because: "parent holds finance.bill.view_own, NOT finance.bill.view — the school-wide bill list is not theirs",
  },
  {
    fixture: 'parent',
    method: 'GET',
    path: '/bill/parent',
    expect: 200,
    because: 'CONTROL: the parent can read their own children\'s bills, so the 403 above is a denial and not a broken session',
  },

  // ── teacher ───────────────────────────────────────────────────────
  {
    fixture: 'teacher',
    method: 'POST',
    path: '/report-cards/publish',
    expect: 403,
    because: 'teacher holds academic.report_card.manage but NOT .publish — publishing is the admin/homeroom act',
    body: {},
  },
  // NOTE: `GET /report-cards` is deliberately NOT used as the control
  // here. It answers 400 (class_id + academic_year required) for every
  // role, because validation runs BEFORE authorization — so it can never
  // distinguish allowed from denied. An authorization probe has to pick
  // an endpoint that actually reaches the authorization layer.
  {
    fixture: 'parent',
    method: 'GET',
    path: '/rpp',
    expect: 403,
    because:
      'REGRESSION GUARD: LessonPlanController guarded its writes but not its reads, and '
      + "Route::apiResource('rpp') carries no can: middleware — so a parent could list every "
      + "teacher's lesson plans. Verified with real rows on 2026-08-03, then fixed.",
  },
  {
    fixture: 'teacher',
    method: 'GET',
    path: '/admin/readiness',
    expect: 403,
    because: 'route carries can:readiness.view middleware; teacher defaults do not include it',
  },
  {
    fixture: 'teacher',
    method: 'GET',
    path: '/rpp',
    expect: 200,
    because: 'CONTROL: the teacher reaches their own lesson plans',
  },
  {
    fixture: 'teacher',
    method: 'GET',
    path: '/bills',
    expect: 403,
    because: 'the school-wide bill list is finance staff territory, not teaching staff',
  },

  // ── staff ─────────────────────────────────────────────────────────
  {
    fixture: 'staff',
    method: 'GET',
    path: '/bills',
    expect: 403,
    because: 'baseline staff defaults carry no finance ability at all',
  },
  {
    fixture: 'staff',
    method: 'POST',
    path: '/report-cards/publish',
    expect: 403,
    because: 'staff has no academic ability whatsoever',
    body: {},
  },
  {
    fixture: 'staff',
    method: 'GET',
    path: '/me',
    expect: 200,
    because: 'CONTROL: the staff session is genuinely authenticated',
  },
];

/**
 * Admin-ish read endpoints, probed as low-privilege roles.
 *
 * Report-only. 61 of 108 controllers carry an explicit authorize() call,
 * so the remaining 47 are where an unguarded read is most likely to
 * live. This is a net, not an assertion: a 2xx here is a lead to
 * investigate and then promote into DENY_MATRIX by hand — never a
 * release blocker on its own, because some of these legitimately return
 * an empty, correctly-scoped result.
 */
export const ADMIN_READ_PROBES: string[] = [
  '/bills',
  '/classes',
  '/students',
  '/teacher',
  '/staff',
  '/admin-stats',
  '/admin/readiness',
  '/grade-recaps',
  '/assessments',
  '/activities',
  '/payment-types',
  '/payments',
  '/announcement',
  '/trash',
  '/permissions',
  '/teaching-schedule/all',
  '/lesson-plans/admin-queue',
  '/report-cards/admin-pipeline',
  '/alert-settings',
  '/billing-settings',
];
