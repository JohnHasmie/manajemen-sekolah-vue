/**
 * AdminTutoring2ProgramsView — the "Status" filter chip.
 *
 * ── The defect ──
 *
 * The chip's handler was
 *   `@click="statusFilter = statusFilter ? '' : 'active'"`
 * — a two-value toggle, because <AppFilterChip> is a plain button with
 * no menu of its own. An admin could ask for `active` or for nothing,
 * and could never reach `draft` (belum terbit — the state this page's
 * own KPI tile counts) or `archived` (dikunci, produced by the
 * `POST /programs/{id}/archive` endpoint), even though
 * `ProgramStatus.php` declares all three and `GET /tutoring-v2/programs`
 * matches any one of them.
 *
 * It was also worse than its Keuangan sibling in one respect: the chip
 * bound `statusFilter` itself, so with the filter applied an Indonesian
 * admin read the raw English wire word `active` rather than "Aktif".
 *
 * ── Anti-vacuity notes ──
 *
 * 1. The REAL <AppFilterChip>, <PageFilterToolbar>, <StatusBadge> and
 *    <FilterFacetPickerModal> are mounted. Only <Modal> — the
 *    teleporting shell the picker renders into, which would escape the
 *    wrapper — and leaf chrome are stubbed. The rows clicked below are
 *    the rows an admin clicks.
 * 2. Nothing reaches into `w.vm`. Every interaction is a DOM
 *    `trigger('click')` on a queried element, so an unwired handler
 *    fails the test.
 * 3. Assertions are on what the SERVER IS ASKED FOR (`listPrograms`'
 *    last argument) and on what the USER SEES (the chip's rendered
 *    value, the row pill's text) — never on a ref.
 * 4. `listPrograms` is a small fake server: it honours `params.status`
 *    the way `ProgramController::index` does (exact match), so picking
 *    a status visibly narrows the table and the pill text can be
 *    compared against the chip text. A fixed fixture would make every
 *    narrowing assertion vacuous.
 * 5. There is a fixture row for EVERY status. Without the `draft` and
 *    `archived` rows no assertion could distinguish "Arsip filters to
 *    archived" from "Arsip filters to draft" — the rendered label list
 *    is byte-identical either way, and those two were the values the
 *    toggle could never reach in the first place.
 * 6. Reload counts are EXACT numbers. Both failure modes this wiring
 *    invites — `apply` plus a second write each tripping the watcher
 *    (two reloads), or a picker writing a ref nothing watches (zero) —
 *    are caught.
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2ProgramsView from './AdminTutoring2ProgramsView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import idMessages from '@/locales/id.json';

vi.mock('@/services/tutoring-bimbel.service', async () => {
  // The runtime status vocabulary lives in this module beside the type,
  // and the view builds its option list from it. Importing the real
  // module keeps that constant REAL — a hand-stubbed array here would
  // let the view and the test agree on a vocabulary the app does not
  // actually ship.
  const actual = await vi.importActual<
    typeof import('@/services/tutoring-bimbel.service')
  >('@/services/tutoring-bimbel.service');
  return {
    ...actual,
    TutoringBimbelService: {
      listPrograms: vi.fn(),
      createProgram: vi.fn(),
    },
  };
});

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({
    can: () => true,
    canAny: () => true,
  }),
}));

vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }),
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));

vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: () => {},
}));

/** The stubbed <Modal> shell; the picker's own rows live inside it. */
const MODAL = '[data-testid="facet-modal"]';

/**
 * One program per status.
 *
 * `status_label` is deliberately ABSENT so the rows render through
 * `statusLabel()` — the same `tutoring2.status.*` lookup the chip and
 * the picker options use. If the row ever disagreed with the control
 * that produced it, these assertions would catch it.
 */
const PROGRAMS = [
  {
    id: 'pr-1',
    name: 'Intensif UTBK',
    grade_level: 'SMA',
    status: 'active',
    packages_count: 3,
  },
  {
    id: 'pr-2',
    name: 'Kelas Persiapan OSN',
    grade_level: 'SMP',
    status: 'draft',
    packages_count: 1,
  },
  {
    id: 'pr-3',
    name: 'Bimbel Reguler 2024',
    grade_level: 'SMA',
    status: 'archived',
    packages_count: 2,
  },
];

function makeI18n() {
  // The real shipped copy: a typo'd key would surface here rather than
  // being masked by a hand-written message stub. `tutoring2.status.*`
  // is the block the row pills read too.
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: { id: idMessages },
  });
}

async function mountView() {
  setActivePinia(createPinia());
  // A fake server: it applies `status` the way ProgramController::index
  // does (exact match), so a pick visibly narrows the table.
  vi.mocked(TutoringBimbelService.listPrograms).mockImplementation(
    async (params = {}) => ({
      items: params.status
        ? PROGRAMS.filter((p) => p.status === params.status)
        : PROGRAMS,
      pagination: undefined,
    }),
  );

  const w = mount(AdminTutoring2ProgramsView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        teleport: true,
        BrandPageHeader: true,
        KpiStripCards: true,
        NavIcon: true,
        AsyncView: {
          props: ['state'],
          template: '<div><slot :data="state?.data ?? []" /></div>',
        },
        // NOT stubbed: AppFilterChip, PageFilterToolbar, StatusBadge,
        // FilterFacetPickerModal. Only the teleporting shell is.
        Modal: { template: `<div data-testid="facet-modal"><slot /></div>` },
      },
    },
  });
  await flushPromises();
  return w;
}

/** The Status chip, found by its LABEL so a chip reorder can't fool us. */
function statusChip(w) {
  const chip = w
    .findAllComponents(AppFilterChip)
    .find((c) => c.props('label') === 'Status');
  expect(chip, 'no chip labelled "Status"').toBeTruthy();
  return chip;
}

/** Picker rows, in render order. Row 0 is the "Semua" reset. */
const optionRows = (w) => w.findAll(`${MODAL} button`);
const optionLabels = (w) => optionRows(w).map((b) => b.text().trim());

/** The Status column's pills, as an admin reads them. */
const pillTexts = (w) =>
  w.findAllComponents(StatusBadge).map((c) => c.props('label'));

const listCalls = () => vi.mocked(TutoringBimbelService.listPrograms).mock.calls;
const lastListArg = () => listCalls().at(-1)[0];

beforeEach(() => {
  vi.clearAllMocks();
});

describe('Program bimbel · Status chip', () => {
  it('starts at "Semua" with no status on the query', async () => {
    const w = await mountView();

    expect(statusChip(w).props('value')).toBe('Semua');
    expect(lastListArg().status).toBeUndefined();
  });

  it('clicking the chip OPENS a picker instead of toggling the filter', async () => {
    const w = await mountView();
    expect(w.find(MODAL).exists()).toBe(false);
    expect(listCalls()).toHaveLength(1);

    await statusChip(w).trigger('click');

    expect(w.find(MODAL).exists()).toBe(true);
    // Opening a picker is not a filter change: the old handler wrote
    // `active` on this very click and refetched.
    expect(listCalls()).toHaveLength(1);
    expect(lastListArg().status).toBeUndefined();
    expect(statusChip(w).props('value')).toBe('Semua');
  });

  it('lists every status the server can filter on, in Indonesian', async () => {
    const w = await mountView();

    await statusChip(w).trigger('click');

    // "Semua" + the three values ProgramStatus.php declares, labelled
    // from tutoring2.status.* — not one English wire word among them.
    expect(optionLabels(w)).toEqual(['Semua', 'Draft', 'Aktif', 'Arsip']);
  });

  it('does NOT offer a "nonactive" option — the server stores no such status', async () => {
    const w = await mountView();

    await statusChip(w).trigger('click');

    // Length first, so this cannot pass vacuously against a picker that
    // never opened. The reporter asked for "active dan nonactive";
    // `nonactive` is not a ProgramStatus case, and because
    // ProgramController::index does not validate `status`, asking for it
    // would return 200 + an empty page that reads as "belum ada
    // program". The two real non-active states are offered instead.
    expect(optionRows(w)).toHaveLength(4);
    expect(optionLabels(w)).not.toContain('nonactive');
    expect(optionLabels(w)).not.toContain('Nonaktif');
  });

  /**
   * Every option pinned LABEL-to-WIRE, one row at a time.
   *
   * The label-list assertion above proves the three words RENDER. It
   * cannot prove each word SENDS the status it names: swap two keys
   * while building `statusOptions` and the rendered list stays
   * byte-identical, so "Arsip" quietly asks the server for `draft`. A
   * control that reads one thing and filters another is worse than a
   * dead one, because the reader believes the list it shows them.
   *
   * Only clicking each row and reading the outgoing query catches that,
   * and only the per-status fixture rows make the narrowing observable.
   */
  it.each([
    ['Draft', 'draft'],
    ['Aktif', 'active'],
    ['Arsip', 'archived'],
  ])('option "%s" asks the server for status=%s', async (label, wire) => {
    const w = await mountView();
    await statusChip(w).trigger('click');

    const row = optionRows(w).find((b) => b.text().trim() === label);
    expect(row, `no picker row labelled "${label}"`).toBeTruthy();
    await row!.trigger('click');
    await flushPromises();

    expect(lastListArg().status).toBe(wire);
    // …the chip reports the state it just applied…
    expect(statusChip(w).props('value')).toBe(label);
    // …and the table narrows to exactly that status.
    expect(pillTexts(w)).toEqual([label]);
  });

  it.each([
    ['Draft', 'draft'],
    ['Arsip', 'archived'],
  ])('reaches "%s" — a status the toggle could never produce', async (label, wire) => {
    const w = await mountView();

    await statusChip(w).trigger('click');
    const row = optionRows(w).find((b) => b.text().trim() === label);
    await row!.trigger('click');
    await flushPromises();

    expect(lastListArg().status).toBe(wire);
    expect(lastListArg().status).not.toBe('active'); // all the toggle could reach
    // The picker closes behind the pick, as FilterFacetPickerModal does.
    expect(w.find(MODAL).exists()).toBe(false);
  });

  it('renders a translated chip value, never the raw wire word', async () => {
    const w = await mountView();

    await statusChip(w).trigger('click');
    const row = optionRows(w).find((b) => b.text().trim() === 'Aktif');
    await row!.trigger('click');
    await flushPromises();

    // The old chip bound `statusFilter` directly and read "active".
    expect(statusChip(w).props('value')).toBe('Aktif');
    expect(statusChip(w).text()).not.toContain('active');
  });

  it('applying a status reloads EXACTLY ONCE', async () => {
    const w = await mountView();
    expect(listCalls()).toHaveLength(1); // the mount load

    await statusChip(w).trigger('click');
    const row = optionRows(w).find((b) => b.text().trim() === 'Draft');
    await row!.trigger('click');
    await flushPromises();

    // Not 3 (apply + a second write both tripping the watcher) and not
    // 1 (a write nothing watches).
    expect(listCalls()).toHaveLength(2);
  });

  it('"Semua" clears the status off the query and reloads EXACTLY ONCE', async () => {
    const w = await mountView();

    await statusChip(w).trigger('click');
    const row = optionRows(w).find((b) => b.text().trim() === 'Arsip');
    await row!.trigger('click');
    await flushPromises();
    expect(lastListArg().status).toBe('archived');
    expect(listCalls()).toHaveLength(2);

    await statusChip(w).trigger('click');
    await optionRows(w)[0].trigger('click'); // "Semua"
    await flushPromises();

    // Absent, not ''. An empty string would be forwarded as
    // `where('status', '')` and match nothing.
    expect(lastListArg().status).toBeUndefined();
    expect(lastListArg().status).not.toBe(''); // axios omits undefined; it forwards ''
    expect(statusChip(w).props('value')).toBe('Semua');
    expect(pillTexts(w)).toEqual(['Aktif', 'Draft', 'Arsip']);
    expect(listCalls()).toHaveLength(3);
  });

  it('re-picking the status already selected does not refetch', async () => {
    const w = await mountView();

    await statusChip(w).trigger('click');
    await optionRows(w).find((b) => b.text().trim() === 'Draft')!.trigger('click');
    await flushPromises();
    expect(listCalls()).toHaveLength(2);

    await statusChip(w).trigger('click');
    await optionRows(w).find((b) => b.text().trim() === 'Draft')!.trigger('click');
    await flushPromises();

    expect(listCalls()).toHaveLength(2);
  });

  it('leaves the Jenjang chip exactly as it was', async () => {
    // `grade_level` is free text server-side with no enum, and the app
    // canonicalises a DIFFERENT field (`education_level`) elsewhere.
    // Converting this chip would mean inventing a vocabulary, so it is
    // tracked separately and this MR must not have quietly rewritten it.
    const w = await mountView();
    const labels = w.findAllComponents(AppFilterChip).map((c) => c.props('label'));
    expect(labels).toEqual(['Status', 'Jenjang']);

    const grade = w.findAllComponents(AppFilterChip)[1];
    await grade.trigger('click');
    await flushPromises();
    expect(lastListArg().grade_level).toBe('SMA');
  });
});
