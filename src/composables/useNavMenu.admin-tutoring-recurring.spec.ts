/**
 * The admin (bimbel) "Sesi Berulang" sidebar row.
 *
 * ── The defect this pins ──
 *
 * Recurring bimbel scheduling shipped on the TUTOR menu only. The
 * endpoint behind it, `POST /tutoring-v2/sessions/recurring`, authorizes
 * on `tutoring.session.manage` — a key
 * `PermissionCatalog::adminTutoringDefaults()` grants and
 * `tutorTutoringDefaults()` does NOT. So on a default bimbel tenant the
 * series form existed exactly where its submit 403s, and nowhere the
 * person entitled to use it could reach it. An admin's only option was
 * to create every session in a weekly series one at a time.
 *
 * This suite pins the row that closes that, on both sides of its gate:
 * present for an admin holding the key, absent without it. The "absent"
 * half matters as much as the present half — an ungated row would be the
 * same "tombol diklik tidak terjadi apa-apa" defect one layer up, shown
 * to a staff tier whose submit the server refuses.
 *
 * The tutor row is asserted UNCHANGED here too. This change deliberately
 * adds the admin entry point without removing the tutor one, so that no
 * window exists in which nobody can create a recurring schedule; a
 * regression that "tidied up" the tutor row while adding this one would
 * otherwise pass unnoticed.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import router from '@/router';

/** The row this change adds. */
const ADMIN_RECURRING = '/admin/tutoring2/sessions/recurring';
/** The pre-existing tutor row, which must survive. */
const TUTOR_RECURRING = '/teacher/tutoring2/sessions/recurring';

const SESSION_MANAGE = 'tutoring.session.manage';

/**
 * The tutoring slice of `PermissionCatalog::adminTutoringDefaults()`.
 * Tests that care about a MISSING ability subtract from this set rather
 * than building a bespoke one, so "hidden because the gate fired" cannot
 * be confused with "hidden because the fixture forgot an unrelated key".
 */
const ADMIN_DEFAULT_ABILITIES = [
  'dashboard.view',
  'dashboard.admin.view',
  'tutoring.dashboard.view',
  'tutoring.report.view',
  'tutoring.program.view',
  'tutoring.program.manage',
  'tutoring.student.view',
  'tutoring.student.manage',
  'tutoring.tutor.view',
  'tutoring.tutor.manage',
  'tutoring.group.view',
  'tutoring.group.manage',
  'tutoring.session.view',
  SESSION_MANAGE,
  'tutoring.session.cancel',
  'tutoring.session.mark_attendance',
  'tutoring.session_reminder.manage',
  'tutoring.lead.view',
  'tutoring.announcement.view',
] as const;

// ── useNavMenu test doubles ───────────────────────────────────────
//
// Mutable so one mock set serves every case. Each factory spreads
// `importOriginal()` first: this file also imports the REAL router, and
// `router/index.ts` pulls `tenantKindFromRaw` out of
// `@/composables/useTenant` — a bare factory would strip it and break
// the router rather than the thing under test.
let abilities = new Set<string>(ADMIN_DEFAULT_ABILITIES);
let activeRole = 'admin';

vi.mock('@/stores/auth', async (importOriginal) => ({
  ...(await importOriginal<Record<string, unknown>>()),
  useAuthStore: () => ({
    isSuperAdmin: false,
    get activeRole() {
      return activeRole;
    },
    homeroomClasses: [],
    // The gate reads the role-scoped `abilities` list from GET /me —
    // in the real store `hasAbility` resolves through
    // `useMeStore().snapshot.abilities`, NOT `roles[].permission_keys`.
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

// A bimbel tenant: the branch that serves ADMIN_TUTORING_NAV.
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

/** Flattened `to` paths of the bimbel menu for the current mock role. */
async function navPaths(): Promise<string[]> {
  // Imported inside the call so the mocks above are in place, and
  // re-imported per call so the computed re-reads the mutable fixtures.
  const { useNavMenu } = await import('@/composables/useNavMenu');
  return useNavMenu().value.flatMap((section) =>
    section.items.map((item) => item.to),
  );
}

/**
 * The catch-all (`/:pathMatch(.*)*`, an unnamed redirect to `/`) matches
 * anything, so "resolve() returned something" is NOT evidence a route
 * exists. A real destination resolves to a NAMED record.
 */
function resolvesToRealRoute(path: string): boolean {
  const resolved = router.resolve(path);
  if (resolved.matched.length === 0) return false;
  const leaf = resolved.matched[resolved.matched.length - 1];
  return typeof leaf.name === 'string' && !leaf.path.includes('pathMatch');
}

describe('admin (bimbel) sidebar — Sesi Berulang', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    abilities = new Set<string>(ADMIN_DEFAULT_ABILITIES);
    activeRole = 'admin';
  });

  it('the resolver is not vacuous — it rejects a path nothing defines', () => {
    // Pins the detector, so a future edit cannot turn this suite into a
    // no-op reporting "menu fine" because it stopped distinguishing the
    // catch-all.
    expect(resolvesToRealRoute('/admin/tutoring2/nothing-here')).toBe(false);
    expect(resolvesToRealRoute(ADMIN_RECURRING)).toBe(true);
  });

  it('shows the row to an admin holding tutoring.session.manage', async () => {
    expect(await navPaths()).toContain(ADMIN_RECURRING);
  });

  it('hides the row from an admin tier without the key', async () => {
    abilities.delete(SESSION_MANAGE);

    expect(await navPaths()).not.toContain(ADMIN_RECURRING);
  });

  it('points the row at a registered route, not the catch-all', async () => {
    const dead = (await navPaths()).filter((to) => !resolvesToRealRoute(to));

    expect(
      dead,
      'These sidebar rows point at paths the router does not define. ' +
        'The click resolves to the catch-all and redirects to `/` — the ' +
        `menu item silently does nothing:\n${dead.join('\n')}`,
    ).toEqual([]);
  });

  it('leaves the tutor row in place (removal is a separate decision)', async () => {
    activeRole = 'teacher';

    // A tutor whose tenant granted the key keeps the screen — the
    // permission catalog is a seed, not a ceiling.
    expect(await navPaths()).toContain(TUTOR_RECURRING);
  });
});
