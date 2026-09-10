/**
 * Every screen the tutor (guru bimbel) sidebar promises must exist — and
 * every screen that exists and works must be reachable from it.
 *
 * ── The defect this pins ──
 *
 * `teacher.tutoring2.assessments` and `teacher.tutoring2.students` have
 * been registered routes, with working views behind them, for as long as
 * the greenfield tutor surface has existed. Nothing linked to either one:
 * no nav row, and no `router.push` / `<RouterLink>` anywhere in `src/`.
 * The only way to open them was to type the URL.
 *
 * The blast radius was larger than two screens, because each is the sole
 * door to its own drill-ins:
 *
 *   assessments ──┬─ assessment-create   ("+" button on the list)
 *                 ├─ scores              (row tap)
 *                 └─ assessment-result   (row tap)
 *   students ─────── student-detail      (row tap)
 *
 * Six working screens, zero entry points. Meanwhile the Flutter app has
 * shipped both for months — "Siswa saya" is a tutor shell tab (MOB-2) and
 * "Penilaian" is a quick action on the tutor home screen. That web/app
 * divergence is what Luay reported.
 *
 * ── Why the existing guards could not see it ──
 *
 * This is the INVERSE of the wali defect that
 * `useNavMenu.parent-tutoring.spec.ts` pins. There, rows pointed at
 * routes that did not exist. Here, routes exist and no row points at
 * them. A "every row resolves to a real route" sweep is vacuously true of
 * a menu that never mentions the screen — which is exactly why the tests
 * below NAME their destinations. A generic sweep also stays green if
 * someone deletes one of these rows again.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import router from '@/router';

/**
 * Everything `PermissionCatalog::tutorTutoringDefaults()` grants. Tests
 * that care about a MISSING ability subtract from this set rather than
 * building a bespoke one, so "hidden because the gate fired" can never be
 * confused with "hidden because the fixture forgot an unrelated key".
 *
 * `tutoring.session.manage` is deliberately absent — the catalog does not
 * grant it to a tutor (session lifecycle is admin-only by design), which
 * is why the Sesi Berulang row is invisible to a default tutor.
 */
const TUTOR_DEFAULT_ABILITIES = [
  'dashboard.view',
  'dashboard.teacher.view',
  'communication.notification.receive',
  'communication.inbox.view',
  'tutoring.dashboard.view',
  'tutoring.report.view',
  'tutoring.session.view',
  'tutoring.session.mark_attendance',
  'tutoring.material.view',
  'tutoring.material.manage',
  'tutoring.activity.view',
  'tutoring.activity.manage',
  'tutoring.assessment.view',
  'tutoring.assessment.manage',
  'tutoring.assessment.rate',
  'tutoring.announcement.view',
  'tutoring.announcement.create',
  'tutoring.payout.view_own',
  'tutoring.payout.request',
  'tutoring.leaderboard.view',
  'tutoring.group.view',
  'tutoring.enrollment.view',
  'tutoring.attendance.view',
  'tutoring.score.view',
  'tutoring.score.manage',
  'tutoring.term.view',
] as const;

/** The two rows this MR adds. */
const ASSESSMENTS = '/teacher/tutoring2/assessments';
const STUDENTS = '/teacher/tutoring2/students';

// ── useNavMenu test doubles ───────────────────────────────────────
//
// Mutable so one mock set serves every case below. Each factory spreads
// `importOriginal()` first: this file also imports the REAL router, and
// `router/index.ts` pulls `tenantKindFromRaw` out of `@/composables/useTenant`,
// so a bare factory would strip it and break the router rather than the
// thing under test.
let abilities = new Set<string>(TUTOR_DEFAULT_ABILITIES);

vi.mock('@/stores/auth', async (importOriginal) => ({
  ...(await importOriginal<Record<string, unknown>>()),
  useAuthStore: () => ({
    isSuperAdmin: false,
    activeRole: 'teacher',
    // A bimbel tenant has no homeroom concept, so a tutor never carries
    // homeroomClasses — and TUTORING_MENUS.teacher is what serves them.
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

// A bimbel tenant: the branch that serves the tutor bimbel menu.
vi.mock('@/composables/useTenant', async (importOriginal) => ({
  ...(await importOriginal<Record<string, unknown>>()),
  useTenant: () => ({ isTutoringCenter: { value: true } }),
}));

vi.mock('@/composables/useChildPicker', async (importOriginal) => ({
  ...(await importOriginal<Record<string, unknown>>()),
  useChildPicker: () => ({
    activeChildId: { value: '' },
    hasOverdueBills: { value: false },
  }),
}));

/** Flattened items of the tutor bimbel menu, as `useNavMenu` returns them. */
async function tutorNavItems() {
  // Imported inside the call so the mocks above are in place, and
  // re-imported per call so the computed re-reads the mutable fixtures.
  const { useNavMenu } = await import('@/composables/useNavMenu');
  return useNavMenu().value.flatMap((section) => section.items);
}

async function tutorNavPaths(): Promise<string[]> {
  return (await tutorNavItems()).map((item) => item.to);
}

/**
 * The catch-all (`/:pathMatch(.*)*`, an unnamed redirect to `/`) matches
 * anything, so "resolve() returned something" is NOT evidence a route
 * exists. A real destination resolves to a NAMED record; the catch-all
 * has no name.
 */
function resolvesToRealRoute(path: string): boolean {
  const resolved = router.resolve(path);
  if (resolved.matched.length === 0) return false;
  const leaf = resolved.matched[resolved.matched.length - 1];
  return typeof leaf.name === 'string' && !leaf.path.includes('pathMatch');
}

describe('tutor (guru bimbel) sidebar', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    abilities = new Set<string>(TUTOR_DEFAULT_ABILITIES);
  });

  it('the resolver is not vacuous — it rejects a path nothing defines', () => {
    // Pins the detector, so a future edit cannot turn this suite into a
    // no-op that reports "every menu fine" because it stopped
    // distinguishing the catch-all.
    expect(resolvesToRealRoute('/teacher/tutoring2/nothing-here')).toBe(false);
    expect(resolvesToRealRoute(ASSESSMENTS)).toBe(true);
    expect(resolvesToRealRoute(STUDENTS)).toBe(true);
  });

  it('every destination resolves to a registered route', async () => {
    const dead = (await tutorNavPaths()).filter((to) => !resolvesToRealRoute(to));

    expect(
      dead,
      'These sidebar rows point at paths the router does not define. ' +
        'The click resolves to the catch-all and redirects the tutor to ' +
        '`/` — the menu item silently does nothing:\n\n' +
        `${dead.map((d) => `  ${d}`).join('\n')}`,
    ).toEqual([]);
  });

  /**
   * The rows this MR added.
   *
   * The sweep above iterates whatever `TEACHER_TUTORING_NAV` happens to
   * contain, so it stays green if a row is DELETED — "every destination
   * resolves" is vacuously true of a menu that lost the item. These tests
   * name the destinations, which is the only way a removal fails.
   */
  describe('the screens that were unreachable', () => {
    it.each([
      ['Penilaian', ASSESSMENTS],
      ['Siswa saya', STUDENTS],
    ])('the tutor can find %s in the sidebar', async (_label, path) => {
      expect(
        await tutorNavPaths(),
        `No sidebar row opens ${path}. The route and its view exist and ` +
          'work; without a row the only way in is typing the URL.',
      ).toContain(path);
    });

    /**
     * Both rows must survive a tutor who holds NO tutoring abilities at
     * all. Neither route declares a `meta.ability`, so neither nav row
     * may declare one — a gate stricter than the route hides a screen the
     * router would happily open, which is the same class of bug as the
     * dead row this MR fixes.
     *
     * This is the test that fails if someone "tightens" these rows with a
     * plausible-looking key such as `tutoring.assessment.view`.
     */
    it.each([
      ['Penilaian', ASSESSMENTS],
      ['Siswa saya', STUDENTS],
    ])('shows %s even to a tutor with no tutoring abilities', async (_label, path) => {
      abilities = new Set<string>(['dashboard.view']);
      expect(await tutorNavPaths()).toContain(path);
    });

    /**
     * The drill-ins deliberately get no row of their own.
     *
     * `assessment-create` is the "+" on the assessments list,
     * `scores` / `assessment-result` are its row taps, and
     * `student-detail` is the students list's row tap. Each is an ACTION
     * reached from its list, not a place — and each is now reachable,
     * because the list that opens it is. A sidebar row for a `:id` route
     * could not be built anyway: there is no id to put in the URL.
     */
    it.each([
      ['Buat penilaian', '/assessments/new'],
      ['Hasil penilaian', '/result'],
      ['Input nilai', '/scores'],
    ])('deliberately keeps %s out of the sidebar', async (_label, segment) => {
      const found = (await tutorNavPaths()).filter((to) => to.includes(segment));
      expect(found).toEqual([]);
    });

    /**
     * Guards the reason the drill-ins need no row: the lists open them.
     * If a future edit removes the "+" button or the row tap, these
     * screens go dark again and this test says so, rather than the
     * sidebar quietly being blamed.
     */
    it('the assessments list is the door to its three drill-ins', () => {
      const source = readFileSync(
        join(process.cwd(), 'src/views/teacher/tutoring2/TutorTutoring2AssessmentsView.vue'),
        'utf8',
      );
      for (const name of [
        'teacher.tutoring2.assessment-create',
        'teacher.tutoring2.assessment-result',
        'teacher.tutoring2.scores',
      ]) {
        expect(source, `${name} is no longer opened from the assessments list`).toContain(
          name,
        );
      }
    });

    it('the students list is the door to student detail', () => {
      const source = readFileSync(
        join(process.cwd(), 'src/views/teacher/tutoring2/TutorTutoring2StudentsView.vue'),
        'utf8',
      );
      expect(source).toContain('teacher.tutoring2.student-detail');
    });
  });

  describe('gates', () => {
    it("each row's ability gate mirrors its destination route's", async () => {
      // Looser than the route → a row whose click the router guard
      // bounces. Stricter → a screen hidden from a tutor who can open it.
      // Either way the tutor sees a menu that lies about what it does.
      //
      // Grant the one key the catalog withholds so the gated rows are
      // present to be checked, rather than filtered out before the
      // comparison runs.
      abilities.add('tutoring.session.manage');

      const mismatched = (await tutorNavItems())
        .map((item) => {
          const leaf = router.resolve(item.to).matched.at(-1);
          return {
            to: item.to,
            nav: item.ability,
            route: leaf?.meta?.ability as string | undefined,
          };
        })
        .filter((row) => row.nav !== row.route);

      expect(
        mismatched,
        `Nav gate and route gate disagree:\n${mismatched
          .map((m) => `  ${m.to}: nav=${m.nav ?? '(none)'} route=${m.route ?? '(none)'}`)
          .join('\n')}`,
      ).toEqual([]);
    });

    it('the mirror check can actually see a gated row', async () => {
      // Positive control for the test above: if the menu ever stopped
      // declaring any ability at all, the mirror would pass vacuously.
      // The announcements row's route DOES declare one, so at least one
      // row must carry a gate for the comparison to mean anything.
      const gated = (await tutorNavItems()).filter((i) => i.ability);
      expect(gated.map((i) => i.to)).toContain('/teacher/tutoring2/announcements');
    });

    it('renders a menu at all — the gates do not empty it', async () => {
      // Guards the opposite failure: a gate naming an ability no tutor
      // holds would delete rows rather than fix them.
      expect((await tutorNavPaths()).length).toBeGreaterThanOrEqual(10);
    });
  });

  describe('labels and icons', () => {
    it('gives no two rows the same label', async () => {
      // The menu already carries `tutoring.nav.assessments` ("Nilai", the
      // WALI row) and `tutoring.nav.students` ("Siswa Bimbel", the ADMIN
      // row). Reusing either key here would have been the tidy-looking
      // move; it would also have put two differently-scoped rows under
      // one word. Asserts on labelKey so it does not need the i18n
      // runtime mounted.
      const keys = (await tutorNavItems()).map((i) => i.labelKey);
      const dupes = keys.filter((k, i) => keys.indexOf(k) !== i);
      expect(dupes, `duplicate sidebar labels: ${dupes.join(', ')}`).toEqual([]);
    });

    it.each([
      [ASSESSMENTS, 'Penilaian'],
      [STUDENTS, 'Siswa saya'],
    ])('%s reads "%s" in Indonesian', async (path, label) => {
      // A labelKey with no entry in id.json renders the raw key in the
      // sidebar. Read the locale file rather than restating the mapping.
      const id = JSON.parse(
        readFileSync(join(process.cwd(), 'src/locales/id.json'), 'utf8'),
      ) as Record<string, never>;
      const item = (await tutorNavItems()).find((i) => i.to === path);
      expect(item, `no sidebar row for ${path}`).toBeDefined();

      const resolved = item!.labelKey
        .split('.')
        .reduce<unknown>((node, key) => (node as Record<string, unknown>)?.[key], id);

      expect(
        resolved,
        `${item!.labelKey} is missing from id.json — the sidebar would ` +
          'render the raw key',
      ).toBe(label);
    });

    it('every row names an icon NavIcon actually draws', async () => {
      // NavIcon matches on `name === '…'` and falls through to a default
      // hollow circle for anything it does not know — which is how the
      // Prestasi surfaces shipped visible "O" placeholders to prod. A
      // typo'd icon is therefore silent: the row renders, just wrong.
      // Read from the component's source so deleting a glyph fails here.
      const source = readFileSync(
        join(process.cwd(), 'src/components/feature/NavIcon.vue'),
        'utf8',
      );
      const drawn = new Set([...source.matchAll(/name === '([a-z0-9-]+)'/g)].map((m) => m[1]));
      expect(drawn.size, 'failed to parse NavIcon glyph names').toBeGreaterThan(50);

      const missing = (await tutorNavItems())
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
});
