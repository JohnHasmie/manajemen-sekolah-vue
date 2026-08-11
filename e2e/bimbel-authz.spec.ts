import { expect, test } from '@playwright/test';
import { bimbel, bimbelFixture } from './fixtures/accounts';
import { apiFor, statusOf } from './fixtures/api';
import { login } from './fixtures/auth';

/**
 * The bimbel surface — unreachable until the tenant existed.
 *
 * A bimbel is a separate `tenant_type` whose roles hold `tutoring.*`
 * abilities a school's roles hold none of. Every request from a school
 * fixture therefore answered 403, 404 or an empty list, and 35
 * parameter-free `GET /api/tutoring-v2` routes had never been exercised
 * once. This is what exercises them.
 *
 * Two things are asserted here that the backend suite cannot:
 *
 *  · the answers arrive over the REAL stack — nginx, middleware, the
 *    header set the app's axios interceptor actually sends;
 *  · the tenant is the SEEDED one, so "scoped" is measured against data
 *    provisioning produced rather than rows a test invented.
 */

const block = bimbel();

test.skip(
  !block,
  'no bimbel block in the manifest — re-seed. This is a COVERAGE GAP, not a pass.',
);

/**
 * Reads reserved for the bimbel admin, each with the reason.
 *
 * Every deny is paired with the admin allow below: a matrix of 403s
 * passes just as happily when the tokens are broken.
 */
const ADMIN_ONLY = [
  { path: '/tutoring-v2/tutors', why: 'the tutor roster — names and contact of every colleague' },
  { path: '/tutoring-v2/students', why: 'the student roster' },
  { path: '/tutoring-v2/leads', why: 'prospective customers' },
  { path: '/tutoring-v2/vouchers', why: 'every promo code in the tenant' },
  { path: '/tutoring-v2/billing-settings', why: 'how the tenant bills' },
  { path: '/tutoring-v2/bills/summary', why: 'tenant-wide revenue' },
  { path: '/tutoring-v2/payouts/rates', why: 'what every tutor is paid' },
  { path: '/tutoring-v2/payouts/closes', why: 'payroll periods' },
  { path: '/tutoring-v2/payouts/admin-summary', why: 'payroll totals' },
  { path: '/tutoring-v2/settings/bill-reminders', why: 'tenant billing configuration' },
  { path: '/tutoring-v2/settings/session-reminders', why: 'tenant reminder configuration' },
];

for (const row of ADMIN_ONLY) {
  for (const key of ['teacher', 'parent'] as const) {
    test(`bimbel ${key} may NOT GET ${row.path}`, async () => {
      const client = await apiFor(await login(bimbelFixture(key)));

      try {
        expect(await statusOf(client, 'GET', row.path), row.why).toBe(403);
      } finally {
        await client.dispose();
      }
    });
  }

  test(`CONTROL: bimbel admin may GET ${row.path}`, async () => {
    const client = await apiFor(await login(bimbelFixture('admin')));

    try {
      expect(
        await statusOf(client, 'GET', row.path),
        'the admin must be able to read it, or the denials above prove nothing',
      ).toBe(200);
    } finally {
      await client.dispose();
    }
  });
}

/**
 * The admin calendar is scoped to the caller, not gated.
 *
 * `authorize('tutoring.session.view')` is held by every role in a bimbel
 * — everyone reads sessions — so the ability answers "may you read
 * sessions", never "whose". Before !738 a tutor and a wali each received
 * the tenant's entire timetable: who is with which group, at which hour,
 * in which room.
 *
 * The assertion that cannot pass by accident is the LAST one. "Fewer rows
 * than the admin" is satisfied by a wali who sees a fixed subset for the
 * wrong reason; two wali whose children sit in different groups must see
 * DISJOINT rows. That is also why the seeder mints a second wali — with
 * one, their slice IS the tenant and every scoped read looks unscoped.
 */
test('the bimbel calendar shows each caller only their own sessions', async () => {
  const range = '?from=2020-01-01&to=2030-12-31';

  const sessionsFor = async (key: 'admin' | 'teacher' | 'parent' | 'parent_other') => {
    const client = await apiFor(await login(bimbelFixture(key)));

    try {
      const res = await client.ctx.fetch(`${client.base}/tutoring-v2/admin/schedule${range}`);
      expect(res.status(), `${key} could not read the calendar at all`).toBe(200);

      const body = (await res.json()) as { data?: { sessions?: { id: string; tutor_id: string }[] }[] };

      return (body.data ?? []).flatMap((day) => day.sessions ?? []);
    } finally {
      await client.dispose();
    }
  };

  const admin = await sessionsFor('admin');
  const tutor = await sessionsFor('teacher');
  const waliA = await sessionsFor('parent');
  const waliB = await sessionsFor('parent_other');

  // CONTROL: the tenant has sessions from more than one tutor, or
  // "the tutor sees no foreign sessions" is trivially true.
  const tutorsInTenant = new Set(admin.map((s) => s.tutor_id));
  expect(
    tutorsInTenant.size,
    'the seeded tenant has sessions from a single tutor, so nothing below can fail',
  ).toBeGreaterThan(1);

  const ownTutorId = bimbelFixture('teacher').teacher_id;
  expect(ownTutorId, 'the tutor fixture carries no teacher_id').toBeTruthy();

  expect(
    tutor.filter((s) => s.tutor_id !== ownTutorId).map((s) => s.id),
    "the tutor received another tutor's sessions — that is the tenant's timetable, not theirs",
  ).toEqual([]);

  expect(tutor.length, 'the tutor sees none of their own sessions').toBeGreaterThan(0);
  expect(tutor.length).toBeLessThan(admin.length);

  const idsA = waliA.map((s) => s.id);
  const idsB = waliB.map((s) => s.id);

  expect(idsA.length, 'wali A sees nothing, so the comparison below is vacuous').toBeGreaterThan(0);
  expect(idsB.length, 'wali B sees nothing, so the comparison below is vacuous').toBeGreaterThan(0);

  expect(
    idsA.filter((id) => idsB.includes(id)),
    'two wali whose children sit in different groups saw overlapping sessions — the calendar ' +
      'is not scoped by ownership, it is merely returning fewer rows',
  ).toEqual([]);
});
