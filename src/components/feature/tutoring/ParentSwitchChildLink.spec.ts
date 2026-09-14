/**
 * The wali "Ganti anak" link.
 *
 * ── What went wrong, and why these four properties ──
 *
 * A wali with two children reported that some bimbel screens showed one
 * child and others showed two, and concluded the data was wrong. It was
 * not: every `parent/tutoring2/*` screen carrying `:studentId` is scoped
 * to one child by design. The defect was that from those screens there
 * was no way to reach the other child, so "one child" never read as a
 * choice the wali had made.
 *
 * A switcher fixes that only if it is honest about all four cases:
 *
 *   1. It APPEARS on a per-child screen for a wali with two children —
 *      otherwise the gap is still there.
 *   2. It is ABSENT for a wali with one child. A control whose
 *      destination is a one-item list is clutter, and this surface has
 *      spent weeks shedding controls that lead nowhere.
 *   3. It is ABSENT from screens that are not per-child. Payment history
 *      has no child to switch; a link there would change nothing, which
 *      is the same class of defect as a dead filter chip.
 *   4. It RETURNS THE WALI TO THE SAME SCREEN. Switching child on Nilai
 *      and landing on Kehadiran is how the original picker behaved for
 *      every route it had no `?target=` key for, and it reads as the app
 *      losing your place.
 *
 * The last case in this file is structural rather than behavioural: it
 * pins WHICH views carry the link, so neither adding a per-child screen
 * without a switcher nor bolting one onto a tenant-wide screen can land
 * quietly.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia } from 'pinia';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import idMessages from '@/locales/id.json';
import ParentSwitchChildLink from './ParentSwitchChildLink.vue';
import { useBimbelChildren } from '@/composables/useBimbelChildren';
import { parentTutoring2TargetKey } from '@/router/parent-tutoring2-targets';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

interface RouteStub {
  name: string;
  params: Record<string, string>;
}

let currentRoute: RouteStub = { name: '', params: {} };

vi.mock('vue-router', () => ({
  useRoute: () => currentRoute,
}));

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { listEnrollments: vi.fn() },
}));

/**
 * Renders a real anchor and parks the resolved target on an attribute,
 * so the round-trip assertion reads the object the component built
 * rather than a stringified href.
 */
const RouterLinkStub = {
  props: ['to'],
  template: '<a :data-to="JSON.stringify(to)"><slot /></a>',
};

const SWITCH = '[data-testid="parent-switch-child"]';

/** One active enrollment per named child — the shape the picker reads. */
function enrollments(...names: string[]) {
  return {
    items: names.map((student_name, i) => ({
      id: `en-${i + 1}`,
      student_id: `st-${i + 1}`,
      student_name,
      status: 'active',
    })),
  };
}

function mountLink() {
  return mount(ParentSwitchChildLink, {
    global: {
      components: { RouterLink: RouterLinkStub },
      plugins: [
        createI18n({
          // Real Indonesian messages, not an empty bag: a missing
          // `tutoring2.parent.switchChild.action` would then render the
          // key path and the label assertion below would catch it.
          legacy: false,
          locale: 'id',
          messages: { id: idMessages },
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
    },
  });
}

async function mountOn(
  route: RouteStub,
  children: string[],
  { preload = true } = {},
) {
  currentRoute = route;
  const { invalidate, refresh } = useBimbelChildren();

  vi.mocked(TutoringBimbelService.listEnrollments).mockResolvedValue(
    enrollments(...children) as never,
  );

  // Module-level cache — put it back to its pre-load state, then either
  // seed it (so the mount measures rendering) or leave it cold (so the
  // mount measures whether the component fetches at all).
  invalidate();
  if (preload) await refresh();
  vi.mocked(TutoringBimbelService.listEnrollments).mockClear();

  const w = mountLink();
  await flushPromises();
  return w;
}

const TWO_CHILDREN = ['Egi Cahyani Hidayat', 'Raka Pratama'];

describe('ParentSwitchChildLink', () => {
  beforeEach(() => {
    vi.mocked(TutoringBimbelService.listEnrollments).mockReset();
  });

  it('offers the switch, next to the child it is showing, when the wali has two children', async () => {
    const w = await mountOn(
      { name: 'parent.tutoring2.attendance', params: { studentId: 'st-1' } },
      TWO_CHILDREN,
    );

    const el = w.find(SWITCH);
    expect(el.exists()).toBe(true);
    // The pairing is the point: a bare "Ganti anak" in the corner would
    // not tell the wali WHICH child they are currently reading about.
    expect(el.text()).toContain('Egi Cahyani Hidayat');
    expect(el.text()).toContain('Ganti anak');
  });

  it('stays away when the wali has exactly one child', async () => {
    const w = await mountOn(
      { name: 'parent.tutoring2.attendance', params: { studentId: 'st-1' } },
      ['Egi Cahyani Hidayat'],
    );

    // Not "renders disabled" — absent. The destination would be a list
    // with one row on it.
    expect(w.find(SWITCH).exists()).toBe(false);
  });

  it('stays away from a screen that is not scoped to a child, even for a wali with two', async () => {
    const w = await mountOn(
      // Riwayat pembayaran: no `:studentId`, nothing to switch.
      { name: 'parent.tutoring2.history', params: {} },
      // PRELOADED on purpose. An earlier version of this case left the
      // cache cold, so "no children loaded" and "no child in the route"
      // were indistinguishable and deleting the `:studentId` guard
      // altogether kept the suite green.
      TWO_CHILDREN,
    );

    expect(w.find(SWITCH).exists()).toBe(false);
  });

  it('does not even go looking for children on a screen that has no child', async () => {
    await mountOn(
      { name: 'parent.tutoring2.history', params: {} },
      TWO_CHILDREN,
      { preload: false },
    );

    // The same guard keeps the siswa half of the shared leaderboard view
    // from firing a wali-scoped enrollment index and swallowing a 403.
    expect(TutoringBimbelService.listEnrollments).not.toHaveBeenCalled();
  });

  it('comes back to the SAME screen for the newly chosen child', async () => {
    const w = await mountOn(
      { name: 'parent.tutoring2.assessments', params: { studentId: 'st-2' } },
      TWO_CHILDREN,
    );

    expect(JSON.parse(w.find(SWITCH).find('a').attributes('data-to') ?? '{}')).toEqual({
      name: 'parent.tutoring2.pick-child',
      query: { target: 'assessments' },
    });
  });

  it('omits the target rather than guessing one for a screen the picker cannot route to', async () => {
    const w = await mountOn(
      // Per-child, but deliberately not an allow-listed destination.
      { name: 'parent.tutoring2.enroll', params: { studentId: 'st-1' } },
      TWO_CHILDREN,
    );

    // A fabricated key would resolve to the allow-list default and move
    // the wali to Kehadiran — quieter than a dead link, and worse.
    expect(JSON.parse(w.find('a').attributes('data-to') ?? '{}')).toEqual({
      name: 'parent.tutoring2.pick-child',
    });
  });
});

/**
 * WHERE in the header it lands.
 *
 * The brief for this was explicit that the switcher must read as part of
 * the "which child am I looking at" line — "Egi Cahyani Hidayat · Ganti
 * anak" — rather than as a stray button bolted into the corner. In
 * `BrandPageHeader` those are two different slots: the title column
 * (`meta-extra`) and the right-hand action cluster (the default slot).
 * Swapping them is a one-word edit that changes nothing testable about
 * behaviour, so the placement gets its own assertion.
 */
describe('where the switch sits in the header', () => {
  it('renders in the title column, under the meta line — not in the action cluster', async () => {
    const BrandPageHeader = (await import('@/components/layout/BrandPageHeader.vue'))
      .default;

    const w = mount(BrandPageHeader, {
      props: { role: 'parent' as const, title: 'Kehadiran', meta: '214 tercatat' },
      slots: { 'meta-extra': '<p data-testid="parent-switch-child">x</p>' },
      global: { plugins: [createPinia()] },
    });

    const column = w.find('div.min-w-0');
    expect(column.exists()).toBe(true);
    expect(column.find(SWITCH).exists()).toBe(true);
    // The meta line comes first; the switcher reads as its continuation.
    expect(column.text().indexOf('214 tercatat')).toBeLessThan(
      column.text().indexOf('x'),
    );
  });

  it('still renders on a screen that has no meta line at all', async () => {
    // Rapor passes no `meta`. A slot nested inside the meta paragraph
    // would have vanished there — the one screen whose header is just a
    // title, and so the one that needed the switcher most.
    const BrandPageHeader = (await import('@/components/layout/BrandPageHeader.vue'))
      .default;

    const w = mount(BrandPageHeader, {
      props: { role: 'parent' as const, title: 'Rapor' },
      slots: { 'meta-extra': '<p data-testid="parent-switch-child">x</p>' },
      global: { plugins: [createPinia()] },
    });

    expect(w.find(SWITCH).exists()).toBe(true);
  });
});

/**
 * Which screens carry the link, pinned at the file level.
 *
 * The runtime cases above prove the component behaves; this proves it is
 * WIRED to the right set. Both directions matter: a new per-child screen
 * that forgets the switcher reopens the original complaint, and a
 * switcher on a tenant-wide screen is a control that changes nothing.
 */
describe('which wali screens carry the switch', () => {
  const VIEWS = join(process.cwd(), 'src/views');

  /** Every view whose route carries `:studentId`, and which the wali browses. */
  const EXPECTED = [
    'parent/tutoring2/ParentTutoring2ActivitiesView.vue',
    'parent/tutoring2/ParentTutoring2AssessmentsView.vue',
    'parent/tutoring2/ParentTutoring2AttendanceView.vue',
    'parent/tutoring2/ParentTutoring2ProgressView.vue',
    'parent/tutoring2/ParentTutoring2ReportCardView.vue',
    'parent/tutoring2/ParentTutoring2SessionsView.vue',
    'parent/tutoring2/ParentTutoring2VouchersView.vue',
    // Shared with `/student/tutoring2/leaderboard`; the component's own
    // `:studentId` guard is what keeps it off the siswa route.
    'tutoring2/Tutoring2LeaderboardView.vue',
  ];

  /**
   * Per-child by route, deliberately WITHOUT the link: a three-step
   * enrollment form. Switching child halfway through would discard the
   * programme and package the wali had already chosen, with no warning.
   * Deliberate, so it is written down rather than left looking forgotten.
   */
  const EXCLUDED_ON_PURPOSE = [
    'parent/tutoring2/ParentTutoring2EnrollWizardView.vue',
  ];

  /** Wali screens with no `:studentId` — there is no child to switch. */
  const NOT_PER_CHILD = [
    'parent/tutoring2/ParentTutoring2HistoryView.vue',
    'parent/tutoring2/ParentTutoring2PayView.vue',
    'parent/tutoring2/ParentTutoring2HomeView.vue',
    'parent/tutoring2/ParentTutoring2ProfileView.vue',
    'parent/tutoring2/ParentTutoring2NotificationsView.vue',
    'parent/tutoring2/ParentTutoring2GroupAnnouncementsView.vue',
    'parent/tutoring2/ParentTutoring2RegisterLeadView.vue',
    'parent/tutoring2/ParentTutoring2PickChildView.vue',
  ];

  /**
   * The TAG, not the identifier.
   *
   * This matched the bare name at first, which the `import` line
   * satisfies on its own — so deleting the `<template #meta-extra>`
   * block from a view left the switcher gone from the page and the suite
   * green. A rendered component is the claim being made here.
   */
  function renders(rel: string): boolean {
    return readFileSync(join(VIEWS, rel), 'utf8').includes('<ParentSwitchChildLink');
  }

  it.each(EXPECTED)('%s offers it', (rel) => {
    expect(renders(rel)).toBe(true);
  });

  it.each([...NOT_PER_CHILD, ...EXCLUDED_ON_PURPOSE])('%s does not', (rel) => {
    expect(readFileSync(join(VIEWS, rel), 'utf8')).not.toContain('ParentSwitchChildLink');
  });

  /**
   * The half the runtime cases cannot see.
   *
   * A screen can carry the link and still lose the wali's place: the
   * round trip needs an entry in the picker's allow-list, and a per-child
   * screen added without one falls through to the default and lands them
   * on Kehadiran. Rapor was in exactly that position before this MR —
   * routed with `:studentId`, absent from the allow-list.
   *
   * Read out of the router rather than restated here, so adding a screen
   * is the only edit needed for this to start checking it.
   */
  it.each(EXPECTED)('%s has a picker allow-list key to come back through', (rel) => {
    const router = readFileSync(join(process.cwd(), 'src/router/index.ts'), 'utf8');
    const pairs = [
      ...router.matchAll(
        /name:\s*'([^']+)',\s*component:\s*\(\)\s*=>\s*import\('@\/views\/([^']+)'\)/g,
      ),
    ];

    const names = pairs.filter(([, , view]) => view === rel).map(([, name]) => name);
    expect(names.length).toBeGreaterThan(0);

    // At least one of this view's routes must be an allow-listed
    // destination. `Tutoring2LeaderboardView` has two (wali + siswa) and
    // only the wali one is — which is the point of "at least one".
    expect(names.some((n) => parentTutoring2TargetKey(n) !== null)).toBe(true);
  });
});
