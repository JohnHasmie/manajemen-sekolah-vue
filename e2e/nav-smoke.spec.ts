import { expect, test, type Page } from '@playwright/test';
import { uiFixtures } from './fixtures/accounts';
import { applySession, isOnLogin, login } from './fixtures/auth';

/**
 * Phase 1 — navigation smoke across every role.
 *
 * For each seeded role this walks every item the sidebar actually
 * renders and asserts the page came up. It deliberately does NOT assert
 * page contents: the point is coverage of the failure mode that keeps
 * biting this app — a route that renders nothing at all.
 *
 * Real regressions this shape catches:
 *   · a lazy chunk that fails to import, leaving a blank page
 *   · a role losing nav items to an ability/RBAC change
 *   · a route guard bouncing an authenticated user back to /login
 *   · a view that throws on mount
 *
 * Nav items are read from the DOM rather than from a hardcoded list, so
 * the walk follows what each role is really offered. A hardcoded list
 * would keep passing after a menu was removed — testing history instead
 * of the product.
 *
 * Hard failures vs findings
 * ─────────────────────────
 * Fails the test: bounced to /login, blank main content, any 5xx, an
 * uncaught exception. These mean the page is broken.
 *
 * Reported but not failed: console errors and 4xx responses. They are
 * worth seeing, but a page that renders correctly while logging a 404
 * for an optional avatar is not a broken page, and failing on it would
 * teach everyone to ignore this suite.
 */

interface PageReport {
  href: string;
  consoleErrors: string[];
  clientErrors: string[];
}


/** Text length below which a page counts as "rendered nothing". */
const MIN_CONTENT_CHARS = 20;

/**
 * The AI service is a SEPARATE deployment from the core API, and a local
 * stack routinely runs without it wired up — when `EDU_CORE_URL` is unset
 * in the AI container its entitlement lookup fails and EVERY AI endpoint
 * answers 503, regardless of what the page under test does.
 *
 * Failing the suite for that would make the run red for a reason that has
 * nothing to do with the web app, and a suite that is red by default is a
 * suite everyone learns to ignore. So 5xx from the AI origin is reported
 * loudly and separately, while 5xx from the core API still fails hard.
 */
const AI_ORIGIN = new URL(process.env.E2E_AI_URL ?? 'http://localhost:8000/api').origin;

function isAiOrigin(url: string): boolean {
  try {
    return new URL(url).origin === AI_ORIGIN;
  } catch {
    return false;
  }
}

async function collectNavHrefs(page: Page): Promise<string[]> {
  const hrefs = await page.evaluate(() =>
    Array.from(document.querySelectorAll('nav a[href^="/"], aside a[href^="/"]'))
      .map((a) => a.getAttribute('href'))
      .filter((h): h is string => !!h),
  );

  return [...new Set(hrefs)];
}

// Walks the UI, so it takes `uiFixtures()` rather than every fixture in
// the manifest: `multi_role` holds two roles and no profile rows, and
// driving it through teacher pages produced 404s and 403s that read as
// product bugs. See the `api_only` note on E2EFixture.
for (const account of uiFixtures()) {
  // Titled by SURFACE, not role: `teacher` and `wali_kelas` are both the
  // `teacher` role, and a report showing "teacher" twice would hide which
  // of the two navs was actually walked.
  test(`nav smoke — ${account.key}`, async ({ browser }) => {
    const context = await browser.newContext();
    await applySession(context, await login(account), account);
    const page = await context.newPage();

    // Failures that must abort, collected per navigation.
    let consoleErrors: string[] = [];
    let clientErrors: string[] = [];
    let serverErrors: string[] = [];
    let pageExceptions: string[] = [];
    const aiErrorsAll = new Set<string>();
    let aiErrors: string[] = [];

    page.on('console', (m) => {
      if (m.type() === 'error') consoleErrors.push(m.text());
    });
    page.on('pageerror', (e) => pageExceptions.push(e.message));
    page.on('response', (r) => {
      const s = r.status();
      const url = r.url();
      if (s >= 500) {
        if (isAiOrigin(url)) aiErrors.push(`${s} ${url}`);
        else serverErrors.push(`${s} ${url}`);
      } else if (s >= 400) {
        clientErrors.push(`${s} ${url}`);
      }
    });

    await page.goto('/');
    await page.waitForLoadState('networkidle');

    expect(isOnLogin(page), `${account.key} could not reach an authenticated page`).toBe(false);

    const hrefs = await collectNavHrefs(page);

    expect(
      hrefs.length,
      `${account.key} rendered no nav items — the role has no menu, or abilities resolved empty`,
    ).toBeGreaterThan(0);

    const reports: PageReport[] = [];
    const blank: string[] = [];
    const bounced: string[] = [];

    for (const href of hrefs) {
      consoleErrors = [];
      clientErrors = [];
      serverErrors = [];
      pageExceptions = [];
      aiErrors = [];

      await page.goto(href);
      await page.waitForLoadState('networkidle');

      if (isOnLogin(page)) {
        bounced.push(href);
        // Re-establish position; the session is still valid, the route
        // guard just refused this one.
        continue;
      }

      const text = (await page.locator('body').innerText()).trim();
      if (text.length < MIN_CONTENT_CHARS) blank.push(href);

      aiErrors.forEach((e) => aiErrorsAll.add(e));

      expect(pageExceptions, `uncaught exception on ${account.key} ${href}`).toEqual([]);
      expect(serverErrors, `core API server error on ${account.key} ${href}`).toEqual([]);

      if (consoleErrors.length || clientErrors.length) {
        reports.push({ href, consoleErrors, clientErrors: clientErrors });
      }
    }

    // Findings, printed so a green run still surfaces them.
    if (reports.length) {
      console.log(`\n── ${account.key}: ${reports.length}/${hrefs.length} pages logged something ──`);
      for (const r of reports) {
        console.log(`  ${r.href}`);
        for (const e of new Set(r.consoleErrors)) console.log(`      console: ${e.slice(0, 160)}`);
        for (const e of new Set(r.clientErrors)) console.log(`      http   : ${e.slice(0, 160)}`);
      }
    }

    if (aiErrorsAll.size) {
      console.log(
        `\n⚠ ${account.key}: ${aiErrorsAll.size} AI-service 5xx (${AI_ORIGIN}) — NOT failed.\n` +
          '  A local stack with EDU_CORE_URL unset in the AI container 503s every\n' +
          '  AI endpoint. Verify that before reading these as product bugs:\n' +
          '    docker exec kamiledu-ai-api-app printenv EDU_CORE_URL',
      );
      for (const e of aiErrorsAll) console.log(`      ${e.slice(0, 140)}`);
    }

    expect(blank, `${account.key}: pages that rendered nothing`).toEqual([]);
    expect(bounced, `${account.key}: nav items that bounced to /login`).toEqual([]);

    console.log(`${account.key}: ${hrefs.length} nav items walked`);

    await context.close();
  });
}
