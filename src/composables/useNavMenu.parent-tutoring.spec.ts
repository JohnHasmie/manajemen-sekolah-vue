/**
 * Every row in the wali (parent) bimbel sidebar must open a real screen.
 *
 * ── The defect this pins ──
 *
 * `parentTutoringNav` built v1-shaped URLs — `/parent/tutoring/<id>/classes`,
 * `/sessions`, `/bills`, `/activities`, `/progress`, `/leaderboard`,
 * `/announcements` — and the router has never defined a single
 * parameterised `parent/tutoring/:x/` route. Seven of thirteen rows
 * matched only the catch-all. Worse, with no child selected the id was
 * the literal string `':studentId'`, so the URL carried a real colon
 * character and nothing could ever match it.
 *
 * It survived review because it is invisible to the two guards that
 * already exist. `route-names-resolve.spec.ts` reads `{ name: '…' }`
 * pushes and says so explicitly: "Path-based navigation is also
 * skipped". The nav menu is entirely path-based. And a `to` that points
 * nowhere throws nothing — `<RouterLink>` renders, the click resolves to
 * the catch-all, the wali is redirected to `/`. A menu item that
 * quietly does nothing.
 *
 * ── Why this file drives the REAL objects ──
 *
 * The paths come from the REAL `useNavMenu` and are resolved against the
 * REAL `router`, so deleting a route or repointing a row fails here even
 * though this file did not change. A hand-copied table of expected
 * destinations would only ever restate itself.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import router from '@/router';

/**
 * Everything `PermissionCatalog::parentTutoringDefaults()` grants that
 * any nav gate could plausibly read. Tests that care about a MISSING
 * ability subtract from this set rather than building a bespoke one, so
 * "hidden because the gate fired" can never be confused with "hidden
 * because the fixture forgot an unrelated key".
 */
const WALI_DEFAULT_ABILITIES = [
  'dashboard.view',
  'dashboard.parent.view',
  'tutoring.dashboard.view',
  'tutoring.session.view',
  'tutoring.bill.view_own',
  'tutoring.material.view',
  'tutoring.activity.view',
  'tutoring.announcement.view',
  'tutoring.voucher.redeem',
  'tutoring.program.view',
  'tutoring.leaderboard.view',
  'tutoring.enrollment.view_own',
  'tutoring.attendance.view_own',
  'tutoring.assessment.view_own',
  'tutoring.score.view_own',
] as const;

/** A child id shaped like the uuids the enrollments payload carries. */
const CHILD_ID = '9d1f4c2a-0000-4000-8000-000000000abc';

// ── useNavMenu test doubles ───────────────────────────────────────
//
// Mutable so one mock set serves every case below. Each factory spreads
// `importOriginal()` first: this file also imports the REAL router, and
// `router/index.ts` pulls `tenantKindFromRaw` out of `@/composables/useTenant`,
// so a bare factory would strip it and break the router rather than the
// thing under test.
let abilities = new Set<string>(WALI_DEFAULT_ABILITIES);
let activeChildId = '';

vi.mock('@/stores/auth', async (importOriginal) => ({
  ...(await importOriginal<Record<string, unknown>>()),
  useAuthStore: () => ({
    isSuperAdmin: false,
    activeRole: 'parent',
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

// A bimbel tenant: the branch that serves the parent bimbel menu.
vi.mock('@/composables/useTenant', async (importOriginal) => ({
  ...(await importOriginal<Record<string, unknown>>()),
  useTenant: () => ({ isTutoringCenter: { value: true } }),
}));

vi.mock('@/composables/useChildPicker', async (importOriginal) => ({
  ...(await importOriginal<Record<string, unknown>>()),
  useChildPicker: () => ({
    activeChildId: { value: activeChildId },
    hasOverdueBills: { value: false },
  }),
}));

/** Flattened items of the wali bimbel menu, as `useNavMenu` returns them. */
async function parentNavItems() {
  // Imported inside the call so the mocks above are in place, and
  // re-imported per call so the computed re-reads the mutable fixtures.
  const { useNavMenu } = await import('@/composables/useNavMenu');
  return useNavMenu().value.flatMap((section) => section.items);
}

async function parentNavPaths(): Promise<string[]> {
  return (await parentNavItems()).map((item) => item.to);
}

/**
 * The catch-all (`/:pathMatch(.*)*`, an unnamed redirect to `/`) matches
 * anything, so "resolve() returned something" is NOT evidence a route
 * exists. A real destination resolves to a NAMED record; the catch-all
 * has no name. That distinction is the whole test — an earlier draft
 * asserted `matched.length > 0` and passed against every dead path in
 * the file it was supposed to be failing on.
 */
function resolvesToRealRoute(path: string): boolean {
  const resolved = router.resolve(path);
  if (resolved.matched.length === 0) return false;
  const leaf = resolved.matched[resolved.matched.length - 1];
  return typeof leaf.name === 'string' && !leaf.path.includes('pathMatch');
}

describe('wali bimbel sidebar', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    abilities = new Set<string>(WALI_DEFAULT_ABILITIES);
    activeChildId = '';
  });

  it('the resolver is not vacuous — it rejects a path nothing defines', () => {
    // Pins the detector against the exact shape the bug produced, so a
    // future edit cannot turn this suite into a no-op that reports
    // "every menu fine" because it stopped distinguishing the catch-all.
    expect(resolvesToRealRoute(`/parent/tutoring/${CHILD_ID}/classes`)).toBe(false);
    expect(resolvesToRealRoute('/parent/tutoring2/home')).toBe(true);
  });

  describe('with a child selected', () => {
    beforeEach(() => {
      activeChildId = CHILD_ID;
    });

    it('every destination resolves to a registered route', async () => {
      const dead = (await parentNavPaths()).filter((to) => !resolvesToRealRoute(to));

      expect(
        dead,
        'These sidebar rows point at paths the router does not define. ' +
          'The click resolves to the catch-all and redirects the wali to ' +
          '`/` — the menu item silently does nothing:\n\n' +
          `${dead.map((d) => `  ${d}`).join('\n')}`,
      ).toEqual([]);
    });

    it('renders a menu at all — the gates do not empty it', async () => {
      // Guards the opposite failure: `applyGates` now runs over this
      // menu, and a gate naming an ability no wali holds would delete
      // rows rather than fix them. A default wali sees every row.
      expect((await parentNavPaths()).length).toBeGreaterThanOrEqual(10);
    });

    it("each row's ability gate mirrors its destination route's", async () => {
      // Looser than the route → a row whose click the router guard
      // bounces. Stricter → a screen hidden from a wali who can open it.
      // Either way the wali sees a menu that lies about what it does.
      const mismatched = (await parentNavItems())
        .map((item) => {
          const leaf = router.resolve(item.to).matched.at(-1);
          return {
            to: item.to,
            nav: item.ability,
            route: leaf?.meta?.ability as string | undefined,
          };
        })
        // The child picker is a WAYPOINT, not the destination: it carries
        // no gate of its own and forwards to the screen named by
        // `?target=`. Its gate is asserted in the child-selected state,
        // where the row points straight at the real route.
        .filter((row) => !row.to.startsWith('/parent/tutoring2/children'))
        .filter((row) => row.nav !== row.route);

      expect(
        mismatched,
        `Nav gate and route gate disagree:\n${mismatched
          .map((m) => `  ${m.to}: nav=${m.nav ?? '(none)'} route=${m.route ?? '(none)'}`)
          .join('\n')}`,
      ).toEqual([]);
    });
  });

  describe('with no child selected', () => {
    it('puts no literal route parameter in any URL', async () => {
      // The original `activeChildId || ':studentId'` produced
      // `/parent/tutoring/:studentId/sessions` — a real colon in a real
      // URL, matching nothing.
      const literal = (await parentNavPaths()).filter((to) => to.includes(':'));

      expect(
        literal,
        `These URLs carry an unsubstituted route parameter:\n${literal
          .map((l) => `  ${l}`)
          .join('\n')}`,
      ).toEqual([]);
    });

    it('every destination still resolves to a registered route', async () => {
      const dead = (await parentNavPaths()).filter((to) => !resolvesToRealRoute(to));

      expect(dead).toEqual([]);
    });

    it('renders no row that needs a child id it does not have', async () => {
      // A row may not point at a `:studentId` route while no child is
      // selected — the param would be missing and the screen would load
      // for nobody. Such rows go through the child picker instead.
      const unresolvable = (await parentNavPaths()).filter((to) => {
        const leaf = router.resolve(to).matched.at(-1);
        return leaf?.path.includes(':studentId') ?? false;
      });

      expect(
        unresolvable,
        `These rows need a child id that is not selected yet:\n${unresolvable
          .map((u) => `  ${u}`)
          .join('\n')}`,
      ).toEqual([]);
    });

    it('sends every picker row to a target the picker actually honours', async () => {
      // ParentTutoring2PickChildView validates `?target=` against an
      // allow-list and falls back to `attendance` for anything it does
      // not recognise. An unlisted token is therefore NOT an error the
      // wali can see: they click "Peringkat", pick a child, and land on
      // Kehadiran. Read from the view's source rather than restated
      // here, so deleting a target fails this test.
      const source = readFileSync(
        join(process.cwd(), 'src/views/parent/tutoring2/ParentTutoring2PickChildView.vue'),
        'utf8',
      );
      const block = source.slice(
        source.indexOf('const TARGETS'),
        source.indexOf('const targetRouteName'),
      );
      const allowed = new Set([...block.matchAll(/^\s{2}(\w+):/gm)].map((m) => m[1]));
      expect(allowed.size, 'failed to parse the TARGETS allow-list').toBeGreaterThan(3);

      const unknown = (await parentNavPaths())
        .filter((to) => to.includes('?target='))
        .map((to) => to.split('?target=')[1])
        .filter((token) => !allowed.has(token));

      expect(unknown).toEqual([]);
    });
  });

  /**
   * The rows this MR added, and the two it deliberately did NOT.
   *
   * Everything above iterates whatever `parentTutoringNav` happens to
   * return, so it stays green if a row is DELETED — "every destination
   * resolves" is vacuously true of a menu that lost the item. These
   * tests name the destinations, which is the only way a removal fails.
   */
  describe('the per-child screens that earned a row', () => {
    beforeEach(() => {
      activeChildId = CHILD_ID;
    });

    it.each([
      ['Kehadiran', `/parent/tutoring2/attendance/${CHILD_ID}`],
      ['Nilai', `/parent/tutoring2/assessments/${CHILD_ID}`],
      ['Riwayat Pembayaran', '/parent/tutoring2/history'],
    ])('the wali can find %s in the sidebar', async (_label, path) => {
      expect(await parentNavPaths()).toContain(path);
    });

    /**
     * Rapor renders an amber "no rapor exists yet" notice whose only
     * control forwards to Perkembangan nilai — there is no rapor
     * endpoint. Daftar program 403s for a default wali (it needs
     * `tutoring.program.view` / `.package.view` / `.enrollment.manage`,
     * none of which `parentTutoringDefaults()` grants) and is an ACTION
     * reached from the More tiles, not a place.
     *
     * A sidebar row is a standing promise that a destination exists.
     * Neither of these can keep it, so neither gets one — and this test
     * is why re-adding one has to be a deliberate argument rather than a
     * tidy-up that looks like completeness.
     */
    it.each([
      ['Rapor', 'report-card'],
      ['Daftar program', 'enroll'],
    ])('deliberately keeps %s out of the sidebar', async (_label, segment) => {
      const found = (await parentNavPaths()).filter((to) => to.includes(`/${segment}`));
      expect(found).toEqual([]);
    });

    /**
     * Two rows reading "Nilai" is the defect that adding the assessment
     * list would otherwise ship: `tutoring.nav.progress` was itself
     * labelled "Nilai" while pointing at the TREND screen, whose own
     * header says "Perkembangan nilai".
     *
     * Asserts on labelKey rather than resolved text so it does not
     * depend on the i18n runtime being mounted.
     */
    it('gives no two rows the same label', async () => {
      const keys = (await parentNavItems()).map((i) => i.labelKey);
      const dupes = keys.filter((k, i) => keys.indexOf(k) !== i);
      expect(dupes, `duplicate sidebar labels: ${dupes.join(', ')}`).toEqual([]);
    });

    /**
     * NavIcon matches on `name === '…'` and falls through to a default
     * hollow circle for anything it does not know — which is how the
     * Prestasi surfaces shipped visible "O" placeholders to prod. A
     * typo'd icon is therefore silent: the row renders, just wrong.
     *
     * `receipt` (the obvious name for payment history) is one of the
     * names NavIcon does NOT define, and this test is what caught it.
     * Read from the component's source so deleting a glyph fails here.
     */
    it('names an icon NavIcon actually draws', async () => {
      const source = readFileSync(
        join(process.cwd(), 'src/components/feature/NavIcon.vue'),
        'utf8',
      );
      const drawn = new Set(
        [...source.matchAll(/name === '([a-z0-9-]+)'/g)].map((m) => m[1]),
      );
      expect(drawn.size, 'failed to parse NavIcon glyph names').toBeGreaterThan(50);

      const missing = (await parentNavItems())
        .map((i) => i.icon)
        .filter((icon) => !drawn.has(icon));

      expect(
        missing,
        `NavIcon has no glyph for these — they render as a hollow circle:\n${missing
          .map((m) => `  ${m}`)
          .join('\n')}`,
      ).toEqual([]);
    });
  });

  describe('ability gating', () => {
    beforeEach(() => {
      activeChildId = CHILD_ID;
    });

    it.each([
      ['tutoring.announcement.view', '/parent/tutoring2/announcements'],
      ['tutoring.session.view', `/parent/tutoring2/sessions/${CHILD_ID}`],
    ])('hides the %s row from a wali without the key', async (ability, path) => {
      // This menu used to return straight out of `useNavMenu` without
      // `applyGates`, so the one `ability` it declared was inert: the
      // row rendered for everyone, and the ROUTE guard then bounced the
      // click. The permission catalog is a seed, not a ceiling — a
      // tenant may revoke either key through the RBAC picker.
      expect(await parentNavPaths()).toContain(path);

      abilities.delete(ability);
      expect(await parentNavPaths()).not.toContain(path);
    });
  });
});
