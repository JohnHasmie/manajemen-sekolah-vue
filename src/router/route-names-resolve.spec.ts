/**
 * Every route name a view navigates to must exist.
 *
 * The Flutter side of this app grew four dead navigations exactly this
 * way — tiles pushing paths nobody had registered, opening the router's
 * "no route matched" page. They were found by a guard like this one, not
 * by review, and one of the four had a `try`/`catch` around the push that
 * could never fire because navigation to an unknown target does not
 * throw.
 *
 * Vue Router fails softer and therefore quieter: `router.push({ name })`
 * for an unknown name rejects with a warning in the console and the user
 * simply stays where they are. A button that does nothing is the exact
 * defect this surface has been shedding for a week, so it gets a guard
 * rather than a promise to be careful.
 *
 * ── What is checked ──
 *
 * Literal `{ name: '...' }` targets inside `router.push` / `router.replace`
 * / `<RouterLink :to>` object syntax across `src/views` and
 * `src/components`, against the REAL `router.getRoutes()`. Reading the
 * router rather than a list copied into the test means deleting a route
 * fails here even though this file did not change.
 *
 * ── What is not, and why ──
 *
 * Computed targets (`{ name: someVar }`, template literals) are skipped:
 * their value is not knowable from source, and a guess would make this
 * test lie in one direction or the other. Path-based navigation is also
 * skipped — this codebase navigates by name almost everywhere, and the
 * few path pushes are covered by the router's own typing.
 */
import { describe, expect, it } from 'vitest';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import router from './index';

/** Every name the router will actually match. */
function registeredNames(): Set<string> {
  return new Set(
    router
      .getRoutes()
      .map((r) => r.name)
      .filter((n): n is string => typeof n === 'string'),
  );
}

function walk(dir: string): string[] {
  return readdirSync(dir).flatMap((entry) => {
    const full = join(dir, entry);
    return statSync(full).isDirectory() ? walk(full) : [full];
  });
}

interface Offence {
  file: string;
  name: string;
}

/**
 * A route name in NAVIGATION POSITION: inside `push(...)`, `replace(...)`
 * or a `:to` binding.
 *
 * The first version of this matched any `name: '...'` whose value
 * contained a dot, on the theory that route names here are dot-segmented.
 * That quietly skipped every single-segment name — `profile`, `login`,
 * `dashboard` — which are exactly the targets the most recent MR added
 * pushes to. Matching on POSITION instead of on the shape of the value
 * covers those and drops the DTO false positives at the same time,
 * because a `{ name: 'Budi' }` payload is not inside a push.
 */
const NAV_NAME = /(?:\.(?:push|replace)\s*\(|:to\s*=\s*"\s*)\{[^{}]*?\bname:\s*'([^']+)'/g;

function findOffences(roots: string[], known: Set<string>): Offence[] {
  const out: Offence[] = [];

  for (const root of roots) {
    for (const file of walk(root)) {
      if (!file.endsWith('.vue') && !file.endsWith('.ts')) continue;
      if (file.endsWith('.spec.ts')) continue;

      const rel = file.slice(file.indexOf('/src/') + 1);
      const source = readFileSync(file, 'utf8');

      for (const match of source.matchAll(NAV_NAME)) {
        const name = match[1];
        if (known.has(name)) continue;
        out.push({ file: rel, name });
      }
    }
  }

  return out;
}

describe('route names used by the app all resolve', () => {
  it('finds no navigation to a route that does not exist', () => {
    const known = registeredNames();
    expect(known.size).toBeGreaterThan(100); // introspection sanity

    const offences = findOffences(
      [join(process.cwd(), 'src', 'views'), join(process.cwd(), 'src', 'components')],
      known,
    );

    const report = [...new Set(offences.map((o) => `  ${o.file} → ${o.name}`))].sort();

    expect(
      report,
      report.length === 0
        ? ''
        : 'These navigate to route names the router does not define. Vue ' +
            'Router rejects the push with a console warning and the user ' +
            'stays put — the control silently does nothing:\n\n' +
            `${report.join('\n')}\n\n` +
            'Register the route, fix the name, or remove the control.',
    ).toEqual([]);
  });

  it('actually detects a bad name — the guard is not vacuous', () => {
    // Pins the detector against a synthetic offender so a future edit to
    // the regex cannot quietly turn this suite into a no-op that reports
    // "all routes fine" because it stopped looking.
    const known = new Set(['student.tutoring2.profile']);
    const source = "router.push({ name: 'student.tutoring2.ghost' });";

    const found = [...source.matchAll(NAV_NAME)].map((m) => m[1]).filter((n) => !known.has(n));

    expect(found).toEqual(['student.tutoring2.ghost']);
  });

  it('ignores a `name:` key that is not a navigation target', () => {
    // `name` is a common DTO field. Matching on position rather than on
    // the value keeps those out without needing a shape heuristic.
    const source = "const payload = { name: 'Budi Santoso' };";
    expect([...source.matchAll(NAV_NAME)]).toEqual([]);
  });

  it('catches a single-segment name too', () => {
    // The regression that motivated matching on position: `profile` and
    // `login` have no dot, and the previous rule skipped them.
    const source = "router.push({ name: 'profile' });";
    const found = [...source.matchAll(NAV_NAME)].map((m) => m[1]);
    expect(found).toEqual(['profile']);
  });
});
