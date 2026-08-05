import { defineConfig, devices } from '@playwright/test';

/**
 * E2E config for the web app.
 *
 * Points at the local dev stack only. The suite logs in as seeded
 * fixture accounts and walks authenticated pages, so it must never be
 * aimed at a real tenant — `E2E_BASE_URL` exists for a different local
 * port, not for staging or production.
 *
 * Prerequisites (see e2e/README.md):
 *   1. the core API answering on :8001
 *   2. `php artisan db:seed --class=Database\Seeders\E2ESeeder`
 */
const BASE_URL = process.env.E2E_BASE_URL ?? 'http://localhost:5173';
const BASE_PORT = new URL(BASE_URL).port || '5173';

export default defineConfig({
  testDir: './e2e',
  // One test == one role's ENTIRE nav walk (~25 pages, each waiting for
  // networkidle and possibly a first-time lazy-chunk compile), and the
  // workers share ONE Vite dev server, so they queue behind each other's
  // cold compiles. 300s still killed healthy walks mid-way, and a
  // timeout reads exactly like a product failure while being nothing of
  // the sort. Raise it rather than lower the parallelism: an aborted run
  // costs far more than a slow one.
  timeout: 600_000,
  expect: { timeout: 10_000 },
  // Fail the run if a `test.only` was committed by accident.
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  // Roles are independent; run them in parallel. Within a role the walk
  // is sequential so console errors stay attributable to one page.
  fullyParallel: false,
  // ONE worker, deliberately.
  //
  // Everything here shares a single Vite dev server and a single API. The
  // authz matrix alone fires ~150 in-SPA navigations per role, and with
  // several workers doing that at once the data-heavy admin pages stop
  // finishing their loads: the class dropdown comes back empty and the
  // roster renders without its rows. Those specs then fail on a product
  // that is merely saturated, and — worse — they PASS when run alone, so
  // the failure reads as flakiness instead of contention.
  //
  // A slower, deterministic suite beats a faster one nobody trusts. Raise
  // this only alongside a per-worker tenant and a dedicated server.
  workers: 1,
  reporter: [['list'], ['html', { open: 'never', outputFolder: 'e2e-report' }]],
  use: {
    baseURL: BASE_URL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'off',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
  webServer: {
    // The port comes from BASE_URL. It used to be hard-coded to 5173
    // while `url` followed E2E_BASE_URL, so pointing the suite at another
    // port booted a server on 5173 and then waited for a URL nothing was
    // serving. Worse, with 5173 free it silently started a server from
    // THIS checkout and served it as if it were the one you had aimed at
    // — a before/after comparison against another build then ran twice
    // against the same code and passed both times.
    command: `npm run dev -- --port ${BASE_PORT} --strictPort`,
    url: BASE_URL,
    reuseExistingServer: true,
    timeout: 120_000,
  },
});
