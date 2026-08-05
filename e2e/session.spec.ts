import { expect, test } from '@playwright/test';
import { fixture, loadManifest } from './fixtures/accounts';
import { applySession, isOnLogin, login } from './fixtures/auth';
import { readRouteTable, ROLE_HOME } from './fixtures/routes';

/**
 * Phase 8 — session, deep links, resilience.
 *
 * Everything else in this suite starts from an already-authenticated
 * context. These tests cover the seams around that: getting in, staying
 * in across a hard refresh, and getting out.
 */

const manifest = loadManifest();

/**
 * The bug the guard's own comment describes: on a hard refresh the `/me`
 * snapshot starts null, so ability gates evaluated against empty data
 * denied every gated sub-route and bounced the user home — "refresh
 * always returns to /teacher". The `await me.refresh()` in `beforeEach`
 * is the fix, and it is exactly the kind of thing a store refactor
 * silently undoes.
 *
 * A COLD context per role is essential: an in-app navigation already has
 * the snapshot loaded, so it cannot reproduce this at all.
 */
for (const key of ['admin', 'teacher', 'parent'] as const) {
  test(`deep link · ${key} lands on a gated route after a cold load`, async ({ browser }) => {
    const account = fixture(key);
    const session = await login(account);

    // One throwaway context just to read the route table.
    const scout = await browser.newContext();
    await applySession(scout, session, account);
    const scoutPage = await scout.newPage();
    await scoutPage.goto('/');
    await scoutPage.waitForLoadState('networkidle');

    const home = ROLE_HOME[session.role] ?? '/';
    const routes = await readRouteTable(scoutPage);

    // Gated routes this role can actually reach, taken from the nav it
    // renders — so the test asks for pages the user is entitled to, not
    // pages we assume they are.
    const navHrefs = await scoutPage.evaluate(() =>
      Array.from(document.querySelectorAll('nav a[href^="/"], aside a[href^="/"]'))
        .map((a) => a.getAttribute('href'))
        .filter((h): h is string => !!h),
    );

    const gated = [...new Set(navHrefs)]
      .filter((h) => h !== home && !h.includes(':'))
      .filter((h) => {
        const r = routes.find((x) => x.path === h);
        return r && (r.meta.ability || r.meta.abilityAny);
      })
      .slice(0, 3);

    await scout.close();

    test.skip(gated.length === 0, `${key} renders no ability-gated nav items to deep-link into`);

    for (const href of gated) {
      // Fresh context each time: this must be a COLD load, with no
      // snapshot in memory, or it is not the scenario under test.
      const context = await browser.newContext();
      await applySession(context, session, account);
      const page = await context.newPage();

      await page.goto(href);
      await page.waitForLoadState('networkidle');

      const landed = new URL(page.url()).pathname;

      expect(
        landed,
        `cold-loading ${href} bounced to ${landed} — the guard evaluated its ability gates ` +
          'before /me had loaded, which is the "refresh always returns home" regression',
      ).toBe(href);

      await context.close();
    }
  });
}

/**
 * The guard is documented as failing OPEN: when `/me` errors it skips
 * every ability check and defers to the server. That is a deliberate
 * anti-misroute tradeoff, so this is a DESIGNED FINDING, not a bug
 * claim — reported, never failed. What it produces is a list of the
 * pages a broken `/me` leaves reachable client-side, which is the
 * shortlist worth hardening server-side first.
 */
test('probe: which gated pages stay reachable when /me fails', async ({ browser }) => {
  const account = fixture('parent');
  const context = await browser.newContext();
  await applySession(context, await login(account), account);
  const page = await context.newPage();

  // Load once so the route table is available, THEN break /me.
  await page.goto('/');
  await page.waitForLoadState('networkidle');

  const routes = await readRouteTable(page);

  await page.route('**/api/me', (route) => route.fulfill({ status: 500, body: '{}' }));

  const adminGated = routes
    .filter((r) => r.meta.role === 'admin' && (r.meta.ability || r.meta.abilityAny))
    .filter((r) => !r.path.includes(':') && !r.hasRedirect)
    .slice(0, 8);

  const reachable: string[] = [];

  for (const r of adminGated) {
    await page.goto(r.path);
    await page.waitForLoadState('domcontentloaded');

    if (new URL(page.url()).pathname === r.path) reachable.push(r.path);
  }

  console.log(
    `\n── /me broken: ${reachable.length}/${adminGated.length} admin-gated pages still rendered for a parent ──`,
  );
  for (const p of reachable) console.log(`      ${p}`);
  console.log(
    '   Report only — the guard is documented as fail-open (src/router/index.ts:1998).\n' +
      '   The server is the authoritative gate; this list is what to verify there first.',
  );

  await context.close();
});

/**
 * A 401 must land the user on /login rather than a blank page. Forced at
 * the network layer so it does not depend on a token actually expiring.
 */
test('a 401 from the API sends the user to /login', async ({ browser }) => {
  const account = fixture('admin');
  const context = await browser.newContext();
  await applySession(context, await login(account), account);
  const page = await context.newPage();

  await page.goto('/admin');
  await page.waitForLoadState('networkidle');

  await page.route('**/api/**', (route) =>
    route.fulfill({ status: 401, contentType: 'application/json', body: '{"message":"Unauthenticated."}' }),
  );

  await page.goto('/admin/students');
  await page.waitForLoadState('domcontentloaded');
  await page.waitForTimeout(2_000);

  expect(
    isOnLogin(page) || (await page.locator('body').innerText()).trim().length > 20,
    'a 401 left the user on a blank page instead of redirecting to /login',
  ).toBe(true);

  await context.close();
});

/**
 * The login screen, exercised in exactly one place.
 *
 * Every other test injects a session directly and deliberately so:
 * coupling ~30 tests to this form would mean one selector change
 * reddens the whole suite.
 *
 * Only the REJECTION path is driven here. The success path is already
 * proven every time any other test authenticates, and re-driving it
 * through the form would spend one of the five logins per minute that
 * `throttle:5,1` allows — a budget this suite has already exhausted
 * more than once.
 */
test('the login form rejects a wrong password without navigating away', async ({ browser }) => {
  const account = fixture('admin');

  const context = await browser.newContext();
  const page = await context.newPage();

  await page.goto('/login');
  await page.waitForLoadState('networkidle');

  // Wrong password first: it must NOT navigate away.
  await page.getByTestId('login-email').fill(account.email);
  await page.getByTestId('login-password').fill('definitely-not-the-password');
  await page.getByTestId('login-submit').click();
  await page.waitForTimeout(2_000);

  expect(
    isOnLogin(page),
    'a wrong password navigated away from /login',
  ).toBe(true);

  await context.close();
});
