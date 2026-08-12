import { expect, test } from '@playwright/test';
import { bimbel, bimbelFixture, loadManifest, uiFixtures } from './fixtures/accounts';
import { applySession, login } from './fixtures/auth';
import {
  concretise,
  expectedVerdict,
  observedVerdict,
  readRouteTable,
  ROLE_HOME,
  type RouteRecord,
} from './fixtures/routes';

/**
 * Phase 4 — router authorization, generated rather than hand-written.
 *
 * For every (surface × route) pair, assert the guard's decision matches
 * what the user's real `/me` abilities say it should be. The route table
 * comes from the running app, so a route added tomorrow is covered
 * tomorrow — a hand-maintained matrix would only ever test history.
 *
 * ── Why in-SPA navigation ───────────────────────────────────────────
 * Roughly 200 routes × 6 surfaces is 1,200 decisions. At a full
 * `page.goto()` each that is half an hour; via `router.push()` inside the
 * already-loaded app it is about a minute, and it exercises the SAME
 * `beforeEach` guard. The cost is that it does not prove the page then
 * renders — but that is exactly what nav-smoke already covers.
 *
 * ── False-positive controls ─────────────────────────────────────────
 * These are the design, not an afterthought:
 *
 *  · `meta.needs` routes are REPORTED, never failed. Those context flags
 *    are derived inside useMeStore from the tenant's modules; an oracle
 *    that re-derives them can disagree for reasons that are interesting
 *    but not obviously bugs.
 *  · Routes with a `redirect` are skipped — they legitimately end
 *    somewhere else.
 *  · A route whose path IS the role home is only checked in the allow
 *    direction: "/admin" cannot be told apart from "bounced to /admin".
 *  · If `GET /me` did not return 200 the test ABORTS. The guard fails
 *    open when the snapshot is null, so a flaky /me turns every deny
 *    into a false pass — the most dangerous way this suite could lie.
 */

const manifest = loadManifest();

interface Decision {
  path: string;
  expected: string;
  observed: string;
}

// Walks the UI, so it takes `uiFixtures()` rather than every fixture in
// the manifest: `multi_role` holds two roles and no profile rows, and
// driving it through teacher pages produced 404s and 403s that read as
// product bugs. See the `api_only` note on E2EFixture.
for (const account of uiFixtures()) {
  test(`router authz — ${account.key}`, async ({ browser }) => {
    const context = await browser.newContext();
    await applySession(context, await login(account), account);
    const page = await context.newPage();

    let meStatus = 0;
    page.on('response', (r) => {
      if (new URL(r.url()).pathname.endsWith('/me')) meStatus = r.status();
    });

    await page.goto('/');
    await page.waitForLoadState('networkidle');

    expect(
      meStatus,
      'GET /me did not return 200. The guard fails open without a snapshot, so every ' +
        'deny below would pass for the wrong reason — refusing to report a green run.',
    ).toBe(200);

    const snapshot = await page.evaluate(() => {
      const w = window as unknown as { __E2E_ME__?: { abilities: string[]; activeRole: string; isSuperAdmin: boolean } };
      return w.__E2E_ME__ ?? null;
    });

    expect(snapshot, 'window.__E2E_ME__ missing — the dev-only export in main.ts did not run').not.toBeNull();

    const abilities = new Set(snapshot!.abilities);
    const activeRole = snapshot!.activeRole;
    const isSuperAdmin = snapshot!.isSuperAdmin;
    const roleHome = ROLE_HOME[activeRole] ?? '/login';

    const routes = await readRouteTable(page);

    // `getRoutes()` flattens the tree, so a layout parent and its
    // redirecting index child can BOTH surface as the same path — `/` is
    // the AppShell parent (no redirect) plus the `hub` child that
    // dispatches to the role home. Skipping only records that carry the
    // redirect leaves the parent behind, and landing on the role home
    // then reads as a denial when it is the app working correctly.
    const redirectingPaths = new Set(routes.filter((r) => r.hasRedirect).map((r) => r.path));

    const mismatches: Decision[] = [];
    const needsFindings: Decision[] = [];
    const unresolvable: string[] = [];
    let checked = 0;

    for (const route of routes) {
      if (route.hasRedirect || route.meta.public) continue;
      if (redirectingPaths.has(route.path)) continue;

      const target = concretise(route.path, manifest.data);

      if (target === null) {
        unresolvable.push(route.path);
        continue;
      }

      const expectedResult = expectedVerdict(route as RouteRecord, activeRole, abilities, isSuperAdmin);

      // Role home is indistinguishable from a bounce to it.
      if (target === roleHome && expectedResult !== 'allow') continue;

      const finalPath = await page.evaluate(
        async (p) => {
          const w = window as unknown as { __E2E_GOTO__?: (path: string) => Promise<string> };
          return w.__E2E_GOTO__ ? w.__E2E_GOTO__(p) : '';
        },
        target,
      );

      checked += 1;

      const observed = observedVerdict(new URL(finalPath, 'http://x').pathname, target, roleHome);
      const record: Decision = { path: target, expected: expectedResult, observed };

      if (observed === expectedResult) continue;

      if (route.meta.needs) needsFindings.push(record);
      else mismatches.push(record);
    }

    if (needsFindings.length) {
      console.log(
        `\n── ${account.key}: ${needsFindings.length} module-context (meta.needs) disagreements — reported, not failed ──`,
      );
      for (const d of needsFindings.slice(0, 15)) {
        console.log(`  ${d.path}  expected ${d.expected}, got ${d.observed}`);
      }
    }

    if (unresolvable.length) {
      // Silent truncation reads as "covered everything" when it did not.
      console.log(
        `\n── ${account.key}: ${unresolvable.length} routes skipped, params unresolvable from seeded data ──`,
      );
      console.log(`  e.g. ${unresolvable.slice(0, 5).join(', ')}`);
    }

    console.log(`${account.key}: ${checked} route decisions checked`);

    expect(
      mismatches,
      `${account.key}: the guard disagreed with the user's real abilities`,
    ).toEqual([]);

    await context.close();
  });
}

/**
 * Every `meta.ability` string must exist in the backend catalogue.
 *
 * A typo here is not a small bug: the ability can never be granted, so
 * the route is permanently unreachable for everyone, and it fails
 * silently by bouncing to the role home. One request covers the whole
 * class.
 */
test('every route ability exists in the permission catalogue', async ({ browser }) => {
  const admin = manifest.fixtures.find((f) => f.key === 'admin')!;
  const context = await browser.newContext();
  const session = await login(admin);
  await applySession(context, session, admin);
  const page = await context.newPage();

  await page.goto('/');
  await page.waitForLoadState('networkidle');

  const routes = await readRouteTable(page);

  const used = new Set<string>();
  for (const r of routes) {
    if (r.meta.ability) used.add(r.meta.ability);
    for (const a of r.meta.abilityAny ?? []) used.add(a);
  }

  const apiBase = process.env.E2E_API_URL ?? 'http://localhost:8001/api';
  const res = await page.request.get(`${apiBase}/permissions`, {
    headers: {
      Authorization: `Bearer ${session.token}`,
      Accept: 'application/json',
      'X-School-ID': session.schoolId,
      'X-Active-Role': session.role,
    },
  });

  expect(res.ok(), `GET /permissions failed: ${res.status()}`).toBe(true);

  const body = (await res.json()) as { data?: { key: string }[] } | { key: string }[];
  const rows = Array.isArray(body) ? body : (body.data ?? []);
  const known = new Set(rows.map((p) => p.key));

  expect(known.size, 'the permission catalogue came back empty').toBeGreaterThan(0);

  const unknown = [...used].filter((a) => !known.has(a)).sort();

  expect(
    unknown,
    'route abilities that no permission grants — these routes can never be reached by anyone',
  ).toEqual([]);

  await context.close();
});

/**
 * Which admin routes carry NO ability gate at all.
 *
 * Report only, and the last promised piece of Phase 4. A route with
 * `meta.role: 'admin'` and no `meta.ability` is protected in the client by
 * a role string and nothing else — and the router guard is cosmetic: it
 * has no 403 view, it fails open when `/me` errors, and curl skips it
 * entirely. Whether such a route is actually protected is decided by
 * `$this->authorize()` in the controller behind it, and only 61 of 108
 * carry one.
 *
 * So this list is not a bug list. It is the SHORTLIST to point the Phase 5
 * API probes at: for each entry, the question worth asking is whether a
 * staff or parent token can reach the endpoints that page calls.
 */
test('inventory: admin routes with no ability gate', async ({ browser }) => {
  const admin = manifest.fixtures.find((f) => f.key === 'admin')!;
  const context = await browser.newContext();
  await applySession(context, await login(admin), admin);
  const page = await context.newPage();

  await page.goto('/');
  await page.waitForLoadState('networkidle');

  const routes = await readRouteTable(page);

  // A report that says "0 found" because it read nothing is worse than no
  // report: it reads as a clean bill of health. Prove the table loaded
  // before believing anything derived from it.
  expect(
    routes.length,
    'the route table came back empty, so "no ungated routes" would mean nothing',
  ).toBeGreaterThan(50);

  const ungated = routes.filter(
    (r) =>
      !r.hasRedirect &&
      !r.meta.public &&
      r.meta.role === 'admin' &&
      !r.meta.superAdmin &&
      !r.meta.ability &&
      !(r.meta.abilityAny && r.meta.abilityAny.length > 0),
  );

  const gated = routes.filter(
    (r) => r.meta.role === 'admin' && (r.meta.ability || r.meta.abilityAny?.length),
  ).length;

  // Split by whether anything ELSE narrows the route. `meta.needs` gates on
  // the tenant having the module at all, which is a real constraint but not
  // an authorization one — every admin of a tenant that HAS the module
  // reaches the page. Reporting both in one flat list buries the seven
  // routes that rest on the role string alone under twenty-six bimbel ones.
  const moduleGated = ungated.filter((r) => r.meta.needs);
  const roleStringOnly = ungated.filter((r) => !r.meta.needs);

  console.log(
    `\n── ${ungated.length} of ${ungated.length + gated} admin routes carry no ability gate ──\n`,
  );

  console.log(`  ${roleStringOnly.length} rest on the role string and nothing else:\n`);
  for (const r of roleStringOnly) {
    console.log(`    ${r.path}${r.name ? `  [${r.name}]` : ''}`);
  }

  console.log(
    `\n  ${moduleGated.length} also require a module (meta.needs) — a tenant constraint,\n` +
      '  not an authorization one:\n',
  );
  for (const r of moduleGated) {
    console.log(`    ${r.path}  (needs: ${r.meta.needs})`);
  }

  console.log(
    '\n   Report only. The router gate is cosmetic — it has no 403 view, fails open\n' +
      '   when /me errors, and curl skips it. These are the pages whose protection\n' +
      '   rests entirely on the controller behind them, and only 61 of 108 carry an\n' +
      '   authorize(). Feed them to the Phase 5 probes; a 2xx for staff or parent\n' +
      '   THERE is the finding, not membership of this list.\n',
  );

  await context.close();
});

/**
 * Every route name a redirect points at must still exist.
 *
 * `beforeEnter: () => ({ name: 'admin.tutoring.dashboard' })` outlived the
 * route it named by one refactor. Vue Router cannot resolve a missing
 * name, and it does not fall back to a 404 — it throws while STARTING, so
 * the router never mounts. Every bimbel admin got a completely blank
 * page: no shell, no nav, no visible error, and a clean network tab.
 *
 * Nothing caught it. The name is a string in a lambda, so `vue-tsc` sees
 * a valid string; the ability-typo check reads `meta.ability`, not
 * redirect targets; and nav-smoke only walked the school tenant.
 *
 * WHICH TENANT MATTERS, and the first version of this test got it wrong.
 * Written against the school admin it passed with the dead redirect still
 * in place, because `isTutoringTenant()` is false there and the broken
 * branch is never taken. A guard that cannot fail is worse than none. It
 * now walks the role homes as BOTH tenants' admins, which is the only way
 * a tenant-branched redirect gets exercised at all.
 */
test('every route name referenced by a redirect still exists', async ({ browser }) => {
  const admins = [
    manifest.fixtures.find((f) => f.key === 'admin')!,
    ...(bimbel() ? [bimbelFixture('admin')] : []),
  ];

  expect(
    admins.length,
    'no bimbel admin in the manifest — the tenant-branched redirects go unexercised. Re-seed.',
  ).toBe(2);

  const warnings: string[] = [];

  for (const account of admins) {
    const context = await browser.newContext();
    await applySession(context, await login(account), account);
    const page = await context.newPage();

    page.on('console', (m) => {
      if (m.text().includes('No match')) warnings.push(`${account.email}: ${m.text()}`);
    });

    // The role homes are where the tenant-branched redirects live.
    for (const path of ['/', '/admin', '/teacher', '/parent', '/staff']) {
      await page.goto(path);
      await page.waitForLoadState('networkidle');
    }

    await context.close();
  }

  expect(
    warnings,
    'Vue Router could not resolve a route name — a redirect outlived its target. That does ' +
      'not render a 404, it aborts the router and leaves a blank page.',
  ).toEqual([]);
});
