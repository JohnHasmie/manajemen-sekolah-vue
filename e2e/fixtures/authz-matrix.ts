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
  // ── found by the broad probe, then confirmed with real rows ───────
  {
    fixture: 'parent',
    method: 'GET',
    path: '/lesson-plans/admin-queue',
    expect: 403,
    because:
      "REGRESSION GUARD: the admin REVIEW queue was ungated, so a parent received the whole "
      + "tier-grouped list — lesson-plan titles, subjects, classes and teacher names. Same "
      + 'controller family as /rpp (fixed in !627); this route was missed.',
  },
  {
    fixture: 'parent',
    method: 'GET',
    path: '/teacher',
    expect: 403,
    because:
      'REGRESSION GUARD: the staff roster was ungated and carries PII — every teacher\'s '
      + 'employee_number, phone_number, gender and employment_status went to any parent.',
  },
  {
    fixture: 'staff',
    method: 'GET',
    path: '/teacher',
    expect: 403,
    because: 'baseline staff defaults carry no school.teacher.view',
  },

  // ── schedule editing helpers (backend !636) ───────────────────────
  //
  // Gated on `academic.schedule.manage`, NOT row-scoped, and the
  // distinction is the whole point: these answer "is this slot taken",
  // "who is free", "what can merge". A caller shown a partial timetable
  // would be told a slot is free while someone else teaches in it, and
  // that wrong answer then gets written to the database. Refusing beats
  // answering wrongly.
  {
    fixture: 'parent',
    method: 'GET',
    path: '/teaching-schedule/conflicts',
    expect: 403,
    because: 'conflict detection is an editing affordance; a parent holds .view, never .manage',
  },
  {
    fixture: 'teacher',
    method: 'GET',
    path: '/teaching-schedules/block-candidates',
    expect: 403,
    because: 'block merge candidates are proposed to whoever edits the grid — teachers do not',
  },
  {
    fixture: 'parent',
    method: 'GET',
    path: '/teaching-schedules/available-teachers',
    expect: 403,
    because: 'who-is-free leaks every teacher\'s occupancy across the school',
  },
  {
    fixture: 'admin',
    method: 'GET',
    path: '/teaching-schedules/block-candidates',
    expect: 200,
    because: 'CONTROL: the admin who actually edits the grid still reaches it, so the three 403s above are denials and not a controller refusing everyone',
  },

  // ── bill-type catalogue + the announcement control (backend !640) ──
  {
    fixture: 'parent',
    method: 'GET',
    path: '/payment-types',
    expect: 403,
    because:
      'the fee catalogue is an admin finance surface; a parent reads their own bills through ' +
      '/bill/parent, which already embeds the type it needs',
  },
  {
    fixture: 'teacher',
    method: 'GET',
    path: '/payment-types',
    expect: 403,
    because: 'teachers hold no finance ability at all',
  },
  {
    fixture: 'admin',
    method: 'GET',
    path: '/payment-types',
    expect: 200,
    because: 'CONTROL: AdminFinanceJenisView and AdminFinanceBillsView live on this endpoint',
  },
  {
    fixture: 'parent',
    method: 'GET',
    path: '/announcement',
    expect: 200,
    because:
      'CONTROL, and the point of the row: /announcement sat on the same reachable list as the two ' +
      'above and was NOT a leak — the repository already filters by role_target. Locking the 200 ' +
      'stops a future sweep from "fixing" it into a 403 and taking the parent inbox with it',
  },

  // ── class import template (backend !645) ──────────────────────────
  //
  // Not a blank form despite the name: it ships every class in the
  // school plus each one's homeroom teacher, i.e. the roster as a
  // spreadsheet. `import` on the same controller already required
  // school.class.manage; the template feeding it did not.
  {
    fixture: 'parent',
    method: 'GET',
    path: '/class/template',
    expect: 403,
    because: 'the class template is a pre-filled roster export, not a blank form',
  },
  {
    fixture: 'teacher',
    method: 'GET',
    path: '/class/template',
    expect: 403,
    because: 'school.class.manage is admin-only, and importing classes is an admin flow',
  },
  {
    fixture: 'admin',
    method: 'GET',
    path: '/class/template',
    expect: 200,
    because: 'CONTROL: AdminImportExcelModal downloads this before an import',
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

/**
 * Reads that stay 200 for everyone but must return DIFFERENT rows per
 * caller.
 *
 * DENY_MATRIX cannot express this. Its rows assert a status code, and a
 * status code is exactly what these endpoints do not distinguish: the
 * low-privilege caller is *allowed* to read, they must simply not receive
 * the whole tenant. `/teaching-schedule/all` shipped for months returning
 * every row in the school to any holder of `academic.schedule.view` — an
 * ability parents and students hold too — and answered 200 the entire
 * time.
 *
 * That is the same lesson the probe group above learned the hard way: a
 * 200 is a lead, not a verdict. `/bill/parent` looked identical to an
 * IDOR until its body turned out to be `[]`. Only reading the payload
 * tells a leak apart from a correctly-scoped result.
 *
 * The assertion is a STRICT SUBSET, not a smaller count. Counting alone
 * passes an implementation that scopes to the wrong thing entirely — some
 * other class, some other teacher — as long as it returns fewer rows.
 */
export interface ScopedReadRow {
  path: string;
  /** The fixture whose view is the whole tenant — and the control. */
  full: FixtureKey;
  /** Fixtures whose view must be a strict, non-equal subset of `full`. */
  narrowed: FixtureKey[];
  /** Why this row exists — printed on failure. */
  because: string;
}

export const SCOPED_READS: ScopedReadRow[] = [
  // `teacher` is deliberately NOT in `narrowed` here. The seeded tenant
  // has two classes and the fixture teacher teaches both, so "sees fewer
  // than the admin" is simply false for them — asserting it would fail
  // against a CORRECT backend, which is exactly how the matrix case in
  // !1092 first went red. The teacher branch of ClassVisibilityScope is
  // covered by ClassAndPaymentTypeReadAuthzTest, where the fixture is
  // built rather than borrowed.
  {
    path: '/classes?per_page=200',
    full: 'admin',
    narrowed: ['parent'],
    because:
      'school.class.view is admin-only, yet thirteen teacher screens fill their class pickers ' +
      'here — so !640 narrowed the rows instead of gating, and a parent now sees only the classes ' +
      'their children sit in',
  },
  {
    path: '/teaching-schedule',
    full: 'admin',
    narrowed: ['teacher', 'parent'],
    because:
      'the unfiltered index went through TeachingScheduleRepository::getAll(), which bypassed ' +
      'the filtered Action entirely — it was the one read left school-wide after !635',
  },
  {
    path: '/teaching-schedule/filtered?limit=200',
    full: 'admin',
    narrowed: ['teacher', 'parent'],
    because: 'the paginated list behind every schedule filter UI',
  },
  {
    path: '/teaching-schedule/all',
    full: 'admin',
    narrowed: ['teacher', 'parent'],
    because:
      'the timetable grid is an admin surface; a teacher may see the lessons they teach and ' +
      'a parent the classes their children sit in, but neither may pull the whole school — ' +
      'which teacher is with which class at which hour, all week',
  },
];
