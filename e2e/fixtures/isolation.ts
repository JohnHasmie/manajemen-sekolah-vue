import type { TestInfo } from '@playwright/test';
import { apiFor } from './api';
import type { Session } from './auth';

/**
 * Data isolation for tests that mutate the shared fixture tenant.
 *
 * There is ONE seeded tenant and several workers, so isolation cannot
 * come from the database. It comes from a rule instead:
 *
 *   **A test may only touch records it created itself.**
 *
 * Everything here exists to make that rule practical.
 *
 * ── Why not the alternatives ────────────────────────────────────────
 * Transactional rollback is impossible: the browser talks HTTP to a
 * separate PHP-FPM process, so there is no shared connection to wrap.
 * Re-seeding per spec file costs ~40s each and forces `workers: 1`,
 * because the purge deletes the tenant other workers are mid-test on.
 * Snapshot/restore means dropping the database the dev stack is using —
 * the same operation that has already destroyed this dev data once.
 */

/**
 * A namespace unique to one test in one run.
 *
 * Every record a test creates carries this prefix, and every list
 * assertion is scoped by searching for it. Parallel workers become
 * invisible to each other without any coordination.
 */
export function namespaceFor(testInfo: TestInfo): string {
  // Built from the test's GROUP as well as its own title.
  //
  // `testInfo.title` alone was not unique, and the rule this function
  // exists to enforce — name it, own it — quietly did not hold.
  // rosters.spec.ts is table-driven: all five rosters run tests with
  // IDENTICAL titles, so `admin · teachers → edit · …` and
  // `admin · subjects → edit · …` both produced
  // `E2E-local-p0-editthecha` and were free to match each other's rows.
  //
  // Both halves are needed. The group alone would collide every test
  // WITHIN a roster; the title alone collides the same test ACROSS
  // rosters. Ten characters each keeps the names short enough to read in
  // a failure message while staying distinct for the current specs
  // (adminteach / adminstaff / adminclass / adminsubje / adminstude).
  const compact = (value: string, max: number) => value.replace(/\W+/g, '').slice(0, max);

  // titlePath is [file, ...describes, title]; taking the last two from
  // the end rather than by index keeps this working for specs with no
  // describe block, where the parent is simply the file name.
  const path = testInfo.titlePath;
  const leaf = compact(path[path.length - 1] ?? '', 10);
  const group = compact(path[path.length - 2] ?? '', 10);

  return `E2E-${process.env.E2E_RUN_ID ?? 'local'}-p${testInfo.parallelIndex}-${group}-${leaf}`;
}

/**
 * Records created during a test, so they can be removed afterwards.
 *
 * Teardown goes through the API rather than the UI on purpose: UI
 * teardown is slow, and it fails exactly when the UI is the broken
 * thing — leaving orphans behind on every real failure, which is when
 * you can least afford extra noise.
 */
export class Tracker {
  private readonly created: { endpoint: string; id: string }[] = [];

  track(endpoint: string, id: string): void {
    this.created.push({ endpoint, id });
  }

  /** Delete newest-first, so children go before their parents. */
  async cleanup(session: Session): Promise<string[]> {
    if (this.created.length === 0) return [];

    const client = await apiFor(session);
    const failures: string[] = [];

    try {
      for (const { endpoint, id } of [...this.created].reverse()) {
        const res = await client.ctx.fetch(`${client.base}${endpoint}/${id}`, { method: 'DELETE' });

        // 404 is fine — the test may have deleted it as the thing under
        // test. Anything else is a leak worth reporting rather than
        // swallowing: a silent leak becomes another test's mystery
        // failure three specs later.
        if (!res.ok() && res.status() !== 404) {
          failures.push(`${res.status()} DELETE ${endpoint}/${id}`);
        }
      }
    } finally {
      await client.dispose();
      this.created.length = 0;
    }

    return failures;
  }
}
