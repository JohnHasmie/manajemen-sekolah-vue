import { mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { BrowserContext, Page } from '@playwright/test';
import { request } from '@playwright/test';
import { loadManifest, type E2EFixture } from './accounts';

const HERE_DIR = dirname(fileURLToPath(import.meta.url));

/**
 * Authenticating a Playwright context against this app.
 *
 * ── Why not `storageState` ──────────────────────────────────────────
 * The usual "log in once, reuse storageState" recipe does NOT work here.
 * src/lib/storage.ts routes the Sanctum bearer to `sessionStorage`
 * (a Round-9 decision: an XSS then only gets a tab-lifetime token, not a
 * 30-day one). Playwright's storageState persists cookies + localStorage
 * and NOT sessionStorage, so a restored state would come back with every
 * key present EXCEPT the token — the app would look logged in for a
 * frame and then bounce to /login. Injecting both stores by hand on each
 * context is the honest way to reproduce a logged-in tab.
 *
 * ── Why the API, not the login form ─────────────────────────────────
 * Driving the form would make every one of ~100 nav assertions depend on
 * the login screen still working. One selector change there would turn
 * the whole suite red for a reason unrelated to what it tests. The form
 * deserves its own dedicated test instead.
 */

const STORAGE_KEYS = {
  token: 'kamiledu.token',
  user: 'kamiledu.user',
  schoolId: 'kamiledu.school_id',
  role: 'kamiledu.role',
} as const;

export interface Session {
  token: string;
  user: unknown;
  schoolId: string;
  role: string;
}

/**
 * One session per account, shared across workers AND across runs.
 *
 * `routes/api.php` throttles `/auth/login` at **5 requests per minute**.
 * A suite with seven fixtures blows through that immediately, and the
 * 429s land on whichever tests happen to run last — including the
 * CONTROL rows of the authorization matrix, which then fail as though
 * the policy were wrong when the session simply never opened.
 *
 * An in-memory cache is not enough: Playwright starts a worker process
 * per spec file, so each file re-imports this module with an empty map.
 * The cache therefore lives on disk, and a cached token is validated
 * with a cheap `GET /me` before reuse — so a stale token after a re-seed
 * costs one extra login, not a confusing 401 mid-test.
 */
const sessions = new Map<string, Promise<Session>>();

/**
 * NOT under `test-results/`. Playwright wipes its output directory at the
 * start of every run, so a cache kept there never survives — every run
 * did seven fresh logins and blew straight through the API's
 * `throttle:5,1`, which then failed whichever tests happened to run last
 * with a 429. `node_modules/.cache` persists between runs and is already
 * ignored by git.
 */
const CACHE_PATH = resolve(HERE_DIR, '../../node_modules/.cache/e2e-sessions.json');

type CacheFile = Record<string, Session>;

function readCache(): CacheFile {
  try {
    return JSON.parse(readFileSync(CACHE_PATH, 'utf8')) as CacheFile;
  } catch {
    return {};
  }
}

function writeCache(email: string, session: Session): void {
  try {
    mkdirSync(dirname(CACHE_PATH), { recursive: true });

    const next = { ...readCache(), [email]: session };
    // Write-then-rename so a worker reading mid-write never sees a
    // truncated file. Concurrent writers race, and last-writer-wins is
    // fine here — every value is an independently valid token.
    const tmp = `${CACHE_PATH}.${process.pid}.tmp`;
    writeFileSync(tmp, JSON.stringify(next, null, 2));
    renameSync(tmp, CACHE_PATH);
  } catch {
    // A cache that cannot be written just means more logins, not a
    // broken run — never fail a test over it.
  }
}

async function stillValid(session: Session): Promise<boolean> {
  const apiBase = process.env.E2E_API_URL ?? 'http://localhost:8001/api';
  const ctx = await request.newContext();

  try {
    const res = await ctx.get(`${apiBase}/me`, {
      headers: {
        Authorization: `Bearer ${session.token}`,
        Accept: 'application/json',
        'X-School-ID': session.schoolId,
        'X-Active-Role': session.role,
      },
    });

    return res.status() === 200;
  } catch {
    return false;
  } finally {
    await ctx.dispose();
  }
}

/**
 * Exchange fixture credentials for a Sanctum token via the API.
 */
export function login(account: E2EFixture): Promise<Session> {
  const cached = sessions.get(account.email);

  if (cached) return cached;

  // Evict a failed attempt so a retry can try again rather than
  // replaying the same rejection for the rest of the run.
  const pending = doLogin(account).catch((err: unknown) => {
    sessions.delete(account.email);
    throw err;
  });

  sessions.set(account.email, pending);

  return pending;
}

async function doLogin(account: E2EFixture): Promise<Session> {
  const cached = readCache()[account.email];

  if (cached && (await stillValid(cached))) return cached;

  const session = await freshLogin(account);

  writeCache(account.email, session);

  return session;
}

async function freshLogin(account: E2EFixture): Promise<Session> {
  const manifest = loadManifest();
  const apiBase = process.env.E2E_API_URL ?? 'http://localhost:8001/api';

  const ctx = await request.newContext();

  try {
    // The login route is throttled at 5/minute. Even with the session
    // cache a cold run can bunch several first-time logins together, so
    // back off and retry rather than failing a test for a limit that
    // clears on its own.
    let res = await ctx.post(`${apiBase}/auth/login`, {
      headers: { Accept: 'application/json' },
      data: { email: account.email, password: manifest.password },
    });

    for (let attempt = 0; res.status() === 429 && attempt < 4; attempt += 1) {
      await new Promise((r) => setTimeout(r, 15_000));

      res = await ctx.post(`${apiBase}/auth/login`, {
        headers: { Accept: 'application/json' },
        data: { email: account.email, password: manifest.password },
      });
    }

    if (!res.ok()) {
      throw new Error(
        `Login failed for ${account.role} <${account.email}>: ` +
          `HTTP ${res.status()} ${await res.text()}`,
      );
    }

    const body = (await res.json()) as { token?: string; user?: unknown };

    if (!body.token) {
      throw new Error(
        `Login for ${account.role} returned no token. Body: ${JSON.stringify(body)}`,
      );
    }

    return {
      token: body.token,
      user: body.user,
      schoolId: manifest.school.id,
      role: account.role,
    };
  } finally {
    await ctx.dispose();
  }
}

/**
 * Plant the session into a context so every page it opens starts logged
 * in. addInitScript runs before any app code on each navigation, which
 * matters: storage.ts reads the token at module load, so writing it
 * after the page has started would be too late.
 */
export async function applySession(
  context: BrowserContext,
  session: Session,
  fixture?: E2EFixture,
): Promise<void> {
  // The super-admin console is cross-tenant: its destructive endpoints
  // reach EVERY demo school in the database, not only the fixture one.
  // No spec has a reason to send those verbs, so block them at the
  // network layer rather than trusting every future spec author to know.
  if (fixture?.read_only) {
    await context.route('**/api/admin/demo-schools/**', (route) => {
      const method = route.request().method();

      return method === 'DELETE' || method === 'POST'
        ? route.abort('blockedbyclient')
        : route.continue();
    });
  }

  await context.addInitScript(
    ([keys, s]) => {
      // The token lives in sessionStorage; everything else in
      // localStorage. Mirrors SESSION_STORAGE_KEYS in src/lib/storage.ts.
      window.sessionStorage.setItem(keys.token, s.token);
      window.localStorage.setItem(keys.user, JSON.stringify(s.user));
      window.localStorage.setItem(keys.schoolId, s.schoolId);
      window.localStorage.setItem(keys.role, s.role);
    },
    [STORAGE_KEYS, session] as const,
  );
}

/**
 * True when the app has bounced us to the login screen — the signal that
 * the injected session was not accepted.
 */
export function isOnLogin(page: Page): boolean {
  return new URL(page.url()).pathname.startsWith('/login');
}
