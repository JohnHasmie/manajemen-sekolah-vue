import { expect, test, type Page } from '@playwright/test';
import { fixture, loadManifest } from './fixtures/accounts';
import { apiFor, statusOf } from './fixtures/api';
import { applySession, login } from './fixtures/auth';

/**
 * Phase 7 — role behaviour on real data.
 *
 * Only possible because Phase 2 repaired the fixtures. With the old
 * hollow accounts the teacher had no `teachers` row and the parent no
 * child, so every one of these screens rendered an empty state and
 * passed a "did it load" check while proving nothing.
 *
 * Assertions here avoid coupling to copy wherever possible. The nav
 * divergence, for instance, is asserted on the SET OF HREFS rather than
 * on section headings — `locales/id.json` is switchable at runtime, so
 * heading text would redden the suite on a copy edit with nothing
 * broken, while the hrefs are the actual routing contract.
 */

const manifest = loadManifest();

async function navHrefs(page: Page): Promise<string[]> {
  const hrefs = await page.evaluate(() =>
    Array.from(document.querySelectorAll('nav a[href^="/"], aside a[href^="/"]'))
      .map((a) => a.getAttribute('href'))
      .filter((h): h is string => !!h),
  );

  return [...new Set(hrefs)];
}

/**
 * The homeroom branch is the one piece of role behaviour with no role
 * string behind it: `normalizeRole()` collapses `wali_kelas` to
 * `teacher`, and the app picks WALI_KELAS_NAV purely on
 * `homeroomClasses.length > 0`. Both halves have to be asserted or a
 * regression that shows everyone the same nav passes twice.
 */
test('a homeroom teacher and a plain teacher get different navs', async ({ browser }) => {
  const walikelas = fixture('wali_kelas');
  const teacher = fixture('teacher');

  const ctxA = await browser.newContext();
  await applySession(ctxA, await login(walikelas), walikelas);
  const pageA = await ctxA.newPage();
  await pageA.goto('/teacher');
  await pageA.waitForLoadState('networkidle');
  const waliNav = await navHrefs(pageA);

  const ctxB = await browser.newContext();
  await applySession(ctxB, await login(teacher), teacher);
  const pageB = await ctxB.newPage();
  await pageB.goto('/teacher');
  await pageB.waitForLoadState('networkidle');
  const plainNav = await navHrefs(pageB);

  expect(waliNav.length, 'homeroom nav rendered nothing').toBeGreaterThan(0);
  expect(plainNav.length, 'teacher nav rendered nothing').toBeGreaterThan(0);

  expect(
    waliNav,
    'the two teacher surfaces rendered identical navs — the homeroom branch is not firing, ' +
      'which usually means the fixture teacher owns a homeroom too, or homeroomClasses never loaded',
  ).not.toEqual(plainNav);

  // WALI_KELAS_NAV is TEACHER_NAV re-grouped, minus these two.
  expect(plainNav, 'plain teacher should have the class hub').toContain('/teacher/classes');
  expect(waliNav, 'homeroom nav drops the class hub in favour of Kelas Saya').not.toContain('/teacher/classes');

  await ctxA.close();
  await ctxB.close();
});

/**
 * The most common authorization bug shape in this codebase: the button
 * is hidden but the endpoint stays open. 47 of 108 controllers carry no
 * `authorize()` call at all, so asserting only the UI would miss it
 * entirely. Both halves belong in ONE test — split across two, a future
 * edit can delete the API half and the UI half still looks like
 * coverage.
 */
test('a homeroom teacher may open report cards but may not publish them', async ({ browser }) => {
  const walikelas = fixture('wali_kelas');
  const session = await login(walikelas);

  const context = await browser.newContext();
  await applySession(context, session, walikelas);
  const page = await context.newPage();

  await page.goto('/teacher/report-cards');
  await page.waitForLoadState('networkidle');

  expect(new URL(page.url()).pathname, 'the homeroom teacher was bounced off report cards').toContain(
    '/teacher/report-cards',
  );

  const client = await apiFor(session);

  try {
    expect(
      await statusOf(client, 'POST', '/report-cards/publish', {}),
      'the teacher role holds academic.report_card.manage but NOT .publish — if this ever ' +
        'returns 2xx, hiding the button in the UI is the only thing standing in the way',
    ).toBe(403);
  } finally {
    await client.dispose();
    await context.close();
  }
});

/**
 * The parent must actually have a child. Before the fixture repair this
 * screen rendered an empty picker and a green test.
 */
test('a parent sees their own seeded child', async ({ browser }) => {
  const parent = fixture('parent');

  test.skip(!parent.child_student_id, 'parent fixture has no linked child');

  const child = manifest.data.students.find((s) => s.id === parent.child_student_id);

  test.skip(!child, "the parent's child is not in the manifest data sample");

  const context = await browser.newContext();
  await applySession(context, await login(parent), parent);
  const page = await context.newPage();

  await page.goto('/parent');
  await page.waitForLoadState('networkidle');

  await expect(
    page.locator('body'),
    'the parent dashboard never named their child — the guardian_email link is not resolving',
  ).toContainText(child!.name);

  await context.close();
});

/**
 * Read-only by construction: this account reaches every demo school in
 * the database, so the fixture installs a network block on the
 * destructive verbs. Assert the block is actually armed rather than
 * trusting that no spec will ever try.
 */
test('the super-admin fixture cannot fire destructive platform calls', async ({ browser }) => {
  const superAdmin = fixture('super_admin');

  expect(superAdmin.read_only, 'super_admin must be marked read_only in the manifest').toBe(true);

  const context = await browser.newContext();
  await applySession(context, await login(superAdmin), superAdmin);
  const page = await context.newPage();

  await page.goto('/super-admin/schools');
  await page.waitForLoadState('networkidle');

  const blocked = await page.evaluate(async () => {
    try {
      await fetch('/api/admin/demo-schools/whatever', { method: 'DELETE' });
      return false;
    } catch {
      return true;
    }
  });

  expect(blocked, 'the destructive-verb route block is not armed for the read_only fixture').toBe(true);

  await context.close();
});
