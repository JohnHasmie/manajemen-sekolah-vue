/**
 * Every bimbel session-WRITE surface must be gated on
 * `tutoring.session.manage`.
 *
 * ── Why this guard exists ──
 *
 * Two tutor screens post to endpoints that authorize on
 * `tutoring.session.manage`:
 *
 *   Tutoring2CreateSessionView          → POST /tutoring-v2/sessions
 *   TutorTutoring2RecurringSessionsView → POST /tutoring-v2/sessions/recurring
 *
 * (`SessionController::store` / `::storeRecurring`, both
 * `$this->authorize('tutoring.session.manage')`.)
 *
 * `PermissionCatalog::tutorTutoringDefaults()` does NOT grant that key
 * — a tutor gets `tutoring.session.view` + `tutoring.session.mark_attendance`,
 * and the lifecycle keys sit in `adminTutoringDefaults()`. Bimbel session
 * scheduling is an admin act by design. `Gate::before` answers from the
 * role-scoped ability list with no fallback, so a default tutor who
 * reaches either form is refused at submit.
 *
 * Both surfaces used to be reachable anyway. `session-create` had no
 * entry point at all (URL-only), and the recurring view was WORSE: it sat
 * in `useNavMenu`'s tutor menu with no gate whatsoever, so every tutor on
 * every bimbel tenant could fill in a series form whose submit always
 * 403s. That is the "tombol diklik tidak terjadi apa-apa" defect
 * !1211/!1215 spent two MRs removing, one layer up.
 *
 * The gate is deliberately not a deletion: the permission catalog is a
 * SEED, not a ceiling. A tenant that grants `tutoring.session.manage` to
 * its tutor role through the RBAC picker gets both screens back with no
 * code change — which is also exactly how the product decision "bimbel
 * tutors may schedule their own sessions" would land if it is ever made.
 *
 * ── Why a guard rather than a careful reviewer ──
 *
 * The `meta.ability` assertions below read `router.getRoutes()`, the REAL
 * router, so dropping the gate fails here even though this file did not
 * change. The nav assertions drive the REAL `useNavMenu`, so a row added
 * to the tutor menu pointing at a session-write path is caught the same
 * way — a hand-copied list of expected items would only ever restate
 * itself.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import router from './index';

/**
 * The one key every session-write surface must sit behind. Named once so
 * the router half and the nav half cannot drift apart.
 */
const SESSION_WRITE_ABILITY = 'tutoring.session.manage';

/** Tutor menu path whose view POSTs a session-write endpoint. */
const RECURRING_PATH = '/teacher/tutoring2/sessions/recurring';

/**
 * Route names rendering a session-write form. The admin twin is listed
 * beside its tutor counterpart on purpose: it is the route that
 * established this gate ("bounce rather than show a form the server will
 * refuse"), and a regression there is the same bug.
 */
const SESSION_WRITE_ROUTES = [
  'teacher.tutoring2.session-create',
  'teacher.tutoring2.sessions-recurring',
  'admin.tutoring2.session-create',
] as const;

// ── useNavMenu test doubles ───────────────────────────────────────
//
// Mutable so one mock set serves both the granted and the withheld
// case; `abilities` is the only thing any test below varies.
//
// Every mock spreads `importOriginal()` first. This file also imports
// the REAL router, and `router/index.ts` pulls `tenantKindFromRaw` out
// of `@/composables/useTenant` — a bare factory returning only
// `useTenant` would quietly strip it and break the module under test
// rather than the thing being tested.
let abilities = new Set<string>();

vi.mock('@/stores/auth', async (importOriginal) => ({
  ...(await importOriginal<Record<string, unknown>>()),
  useAuthStore: () => ({
    isSuperAdmin: false,
    activeRole: 'teacher',
    homeroomClasses: [],
    hasAbility: (perm: string) => abilities.has(perm),
  }),
}));

vi.mock('@/stores/me', async (importOriginal) => ({
  ...(await importOriginal<Record<string, unknown>>()),
  useMeStore: () => ({
    hasStudentContext: true,
    hasAcademicContext: true,
    hasTutoringContext: true,
  }),
}));

// A bimbel tenant: this is the branch that serves TEACHER_TUTORING_NAV.
vi.mock('@/composables/useTenant', async (importOriginal) => ({
  ...(await importOriginal<Record<string, unknown>>()),
  useTenant: () => ({ isTutoringCenter: { value: true } }),
}));

vi.mock('@/composables/useChildPicker', async (importOriginal) => ({
  ...(await importOriginal<Record<string, unknown>>()),
  useChildPicker: () => ({
    activeChildId: { value: null },
    hasOverdueBills: { value: false },
  }),
}));

describe('bimbel session-write surfaces are ability-gated', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    abilities = new Set<string>();
  });

  describe('router', () => {
    it.each(SESSION_WRITE_ROUTES)(
      '%s requires tutoring.session.manage',
      (name) => {
        const route = router.getRoutes().find((r) => r.name === name);

        // Not `?.meta` — a route that vanished should fail loudly here
        // rather than pass because `undefined` never had a gate.
        expect(route, `route ${name} is not registered`).toBeDefined();
        expect(route!.meta.ability).toBe(SESSION_WRITE_ABILITY);
      },
    );
  });

  describe('tutor nav', () => {
    /** Flattened `to` paths of the tutor bimbel menu. */
    async function tutorNavPaths(): Promise<string[]> {
      // Imported inside the test so the mocks above are in place, and
      // re-imported per call so the computed re-reads `abilities`.
      const { useNavMenu } = await import('@/composables/useNavMenu');
      return useNavMenu().value.flatMap((section) =>
        section.items.map((item) => item.to),
      );
    }

    it('hides the recurring-sessions row from a default tutor', async () => {
      // Exactly what tutorTutoringDefaults() grants on the session side.
      abilities = new Set([
        'tutoring.session.view',
        'tutoring.session.mark_attendance',
      ]);

      expect(await tutorNavPaths()).not.toContain(RECURRING_PATH);
    });

    it('shows it to a tutor whose tenant granted the key', async () => {
      abilities = new Set([
        'tutoring.session.view',
        'tutoring.session.mark_attendance',
        SESSION_WRITE_ABILITY,
      ]);

      expect(await tutorNavPaths()).toContain(RECURRING_PATH);
    });

    /**
     * The decision this MR records: no tutor "create session" CTA. A
     * future one is not forbidden — it just may not be UNGATED, because
     * an ungated entry point is the 403 the gates above exist to stop.
     * Copying TutorTutoring2AssessmentsView's ungated <router-link>
     * verbatim is the specific mistake this catches: that one is ungated
     * only because tutors really do hold `tutoring.assessment.manage`.
     */
    it('exposes no ungated tutor route into a session-write form', async () => {
      abilities = new Set([
        'tutoring.session.view',
        'tutoring.session.mark_attendance',
      ]);

      // `getRoutes()` hands back the RESOLVED path, leading slash and
      // all (`/teacher/tutoring2/sessions/recurring`), not the nested
      // `path:` literal the route was declared with. Normalising the
      // nav side to match instead of stripping the slash off the route
      // side: an earlier draft did the latter and compared
      // `teacher/…` against `/teacher/…`, so the filter matched nothing
      // and the assertion passed no matter what the nav contained.
      const writePaths = new Set(
        SESSION_WRITE_ROUTES.map(
          (name) => router.getRoutes().find((r) => r.name === name)?.path,
        ).filter((p): p is string => typeof p === 'string'),
      );
      expect(writePaths.size).toBe(SESSION_WRITE_ROUTES.length);

      const leaked = (await tutorNavPaths()).filter((to) =>
        writePaths.has(to.startsWith('/') ? to : `/${to}`),
      );

      expect(leaked).toEqual([]);
    });
  });
});
