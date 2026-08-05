import type { Page } from '@playwright/test';
import type { E2EManifest } from './accounts';

/**
 * The router table, read from the running app.
 *
 * `src/main.ts` publishes `window.__E2E_ROUTES__` under
 * `import.meta.env.DEV` only, so production ships nothing. In exchange a
 * ~2000-line route table becomes a self-maintaining oracle instead of a
 * hand transcription that goes stale on the next route added.
 */

export interface RouteRecord {
  path: string;
  name: string;
  hasRedirect: boolean;
  meta: {
    public?: boolean;
    role?: string;
    superAdmin?: boolean;
    ability?: string;
    abilityAny?: string[];
    needs?: string;
  };
}

/** Mirrors `roleHomePath` in src/router/index.ts. */
export const ROLE_HOME: Record<string, string> = {
  admin: '/admin',
  administrator: '/admin',
  guru: '/teacher',
  teacher: '/teacher',
  wali_kelas: '/teacher',
  wali: '/parent',
  parent: '/parent',
  orang_tua: '/parent',
  staff: '/staff',
  super_admin: '/super-admin',
};

export async function readRouteTable(page: Page): Promise<RouteRecord[]> {
  const routes = await page.evaluate(
    () => (window as unknown as { __E2E_ROUTES__?: RouteRecord[] }).__E2E_ROUTES__ ?? null,
  );

  if (!routes) {
    throw new Error(
      'window.__E2E_ROUTES__ is missing. The dev-only export in src/main.ts did not run — ' +
        'is the app being served by `vite build` output instead of the dev server?',
    );
  }

  return routes;
}

/**
 * Fill `:param` segments from real seeded ids.
 *
 * Returns null when a param cannot be resolved. Callers REPORT those
 * rather than skipping silently — an unreachable route is a coverage
 * gap, and a gap nobody can see is indistinguishable from coverage.
 */
export function concretise(path: string, data: E2EManifest['data']): string | null {
  if (!path.includes(':')) return path;

  const classId = data.classes[0]?.id;
  const studentId = data.students[0]?.id;
  const subjectId = data.subjects[0];

  const substitutions: Record<string, string | undefined> = {
    classId: classId,
    kelasId: classId,
    studentId: studentId,
    siswaId: studentId,
    subjectId: subjectId,
    mapelId: subjectId,
  };

  let out = path;

  for (const match of path.matchAll(/:([A-Za-z_]+)\??/g)) {
    const [token, name] = match;
    const value = substitutions[name];

    if (!value) return null;

    out = out.replace(token, value);
  }

  return out.includes(':') ? null : out;
}

export type Verdict = 'allow' | 'denyRoleHome' | 'denyLogin';

/**
 * What the guard SHOULD decide, reimplementing only the unambiguous half
 * of `router.beforeEach`.
 *
 * `meta.needs` is deliberately excluded: those context flags are derived
 * inside `useMeStore` from the tenant's modules, and an oracle that
 * re-derives them could disagree with the app for reasons that are
 * interesting but not obviously bugs. Those routes are reported, not
 * failed — promote them once the report is empty.
 */
export function expectedVerdict(
  route: RouteRecord,
  activeRole: string,
  abilities: Set<string>,
  isSuperAdmin: boolean,
): Verdict {
  if (route.meta.public) return 'allow';

  const required = route.meta.role;

  if (required) {
    const routeHasAbilityGate =
      typeof route.meta.ability === 'string' ||
      (Array.isArray(route.meta.abilityAny) && route.meta.abilityAny.length > 0);

    const matches =
      required === activeRole ||
      (required === 'teacher' && activeRole === 'wali_kelas') ||
      (required === 'admin' && isSuperAdmin) ||
      (required === 'admin' && activeRole === 'staff' && routeHasAbilityGate);

    if (!matches) return 'denyRoleHome';
  }

  if (route.meta.superAdmin === true && !isSuperAdmin) return 'denyRoleHome';

  // Super-admin holds the whole catalogue, so the ability checks below
  // can never deny it — mirrors AbilityResolver's short-circuit.
  if (route.meta.ability && !abilities.has(route.meta.ability)) return 'denyRoleHome';

  if (route.meta.abilityAny && !route.meta.abilityAny.some((a) => abilities.has(a))) {
    return 'denyRoleHome';
  }

  return 'allow';
}

/** What actually happened, read from where the browser ended up. */
export function observedVerdict(finalPath: string, target: string, roleHome: string): Verdict {
  if (finalPath.startsWith('/login')) return 'denyLogin';
  if (finalPath === roleHome && target !== roleHome) return 'denyRoleHome';

  return 'allow';
}
