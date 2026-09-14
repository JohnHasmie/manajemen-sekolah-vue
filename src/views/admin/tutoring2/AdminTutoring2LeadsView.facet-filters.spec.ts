/**
 * AdminTutoring2LeadsView — the "Status" and "Sumber" filter chips.
 *
 * ── The defect ──
 *
 * Both chips were two-value toggles, because <AppFilterChip> is a plain
 * button with no menu of its own:
 *
 *   @click="statusFilter = statusFilter ? '' : 'new'"
 *   @click="sourceFilter = sourceFilter ? '' : 'whatsapp'"
 *
 * So of the five statuses `LeadStatus` declares, an admin could reach
 * exactly one — `new` — and never `contacted`, `trial`, `converted` or
 * `dropped`, even though this screen's own KPI cards count the last two
 * and its table renders all five. Sumber was the same shape: `whatsapp`
 * reachable, `website` / `walkin` / `referral` / `other` not. The
 * chevron each chip paints promised a picker that did not exist.
 *
 * Both are now <FilterFacetPickerModal> facets, the shape
 * AdminTutoring2BillingView's Status chip uses.
 *
 * ── Anti-vacuity notes ──
 *
 * 1. The REAL <AppFilterChip>, <PageFilterToolbar>, <StatusBadge> and
 *    <FilterFacetPickerModal> are mounted. Only <Modal> — the
 *    teleporting shell the picker renders into, which would escape the
 *    wrapper — and leaf chrome are stubbed. The rows clicked below are
 *    the rows an admin clicks. (The sibling
 *    AdminTutoring2LeadsView.spec.ts stubs <AppFilterChip> as an EMPTY
 *    button, so no test there could ever observe what a chip displays —
 *    which is why this file exists separately.)
 * 2. Nothing reaches into `w.vm`. Every interaction is a DOM
 *    `trigger('click')` on a queried element, so an unwired handler
 *    fails the test.
 * 3. Assertions are on what the SERVER IS ASKED FOR
 *    (`TutoringLeadsService.list`' last argument) and on what the USER
 *    SEES (the chip's rendered value, the row's cells) — never on a ref.
 * 4. `list` is a small fake server: it honours `params.status` and
 *    `params.source` the way LeadController::index does, so a pick
 *    visibly narrows the table. A fixed fixture would make every
 *    narrowing assertion vacuous.
 * 5. There is a fixture lead for EVERY status and EVERY source, each
 *    carrying a unique name. Without them no assertion could
 *    distinguish "Terdaftar filters to converted" from "Terdaftar
 *    filters to dropped" — the rendered label list is byte-identical
 *    either way, and those are exactly the values the toggle could
 *    never reach.
 * 6. Fixtures deliberately omit `status_label` / `source_label`, so the
 *    rows render through `statusLabel()` / `sourceLabel()`'s fallback to
 *    LEAD_STATUS_LABEL / LEAD_SOURCE_LABEL — the same maps the picker
 *    options are built from. A row cannot disagree with the control
 *    that produced it.
 * 7. Reload counts are EXACT numbers. Both failure modes this wiring
 *    invites — `apply` plus a second write each tripping the watcher
 *    (two reloads), or a picker writing a ref nothing watches (zero) —
 *    are caught.
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2LeadsView from './AdminTutoring2LeadsView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { TutoringLeadsService } from '@/services/tutoring2/leads';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import idMessages from '@/locales/id.json';

vi.mock('@/services/tutoring2/leads', () => ({
  TutoringLeadsService: {
    list: vi.fn(),
    get: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    convert: vi.fn(),
    drop: vi.fn(),
    destroy: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/students', () => ({
  TutoringStudentsService: {
    list: vi.fn().mockResolvedValue({ items: [], pagination: undefined }),
    get: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    deactivate: vi.fn(),
  },
}));

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listPrograms: vi.fn(),
    listPackages: vi.fn(),
    listGroups: vi.fn(),
  },
}));

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
 * Five leads: one per status AND one per source, so a single fixture
 * set makes both facets observable. Every name is unique, so a narrowed
 * table can be identified by name alone.
 */
const LEADS = [
  {
    id: 'ld-1',
    name: 'Ayu',
    phone: '0811',
    email: null,
    status: 'new',
    source: 'website',
    created_at: '2026-09-01T03:00:00+07:00',
    updated_at: '2026-09-01T03:00:00+07:00',
  },
  {
    id: 'ld-2',
    name: 'Bayu',
    phone: '0812',
    email: null,
    status: 'contacted',
    source: 'walkin',
    created_at: '2026-09-02T03:00:00+07:00',
    updated_at: '2026-09-02T03:00:00+07:00',
  },
  {
    id: 'ld-3',
    name: 'Citra',
    phone: '0813',
    email: null,
    status: 'trial',
    source: 'referral',
    created_at: '2026-09-03T03:00:00+07:00',
    updated_at: '2026-09-03T03:00:00+07:00',
  },
  {
    id: 'ld-4',
    name: 'Dewi',
    phone: '0814',
    email: null,
    status: 'converted',
    source: 'whatsapp',
    created_at: '2026-09-04T03:00:00+07:00',
    updated_at: '2026-09-04T03:00:00+07:00',
  },
  {
    id: 'ld-5',
    name: 'Eka',
    phone: '0815',
    email: null,
    status: 'dropped',
    source: 'other',
    created_at: '2026-09-05T03:00:00+07:00',
    updated_at: '2026-09-05T03:00:00+07:00',
  },
];

function makeI18n() {
  // The real shipped copy. Note the whole `tutoring2.admin.leads.*` node
  // is absent from it today, so the screen's `tOr(key, fallback)` helper
  // serves the Indonesian fallback — including the Sumber chip's label.
  // Using the real bundle keeps that true here instead of masking it
  // with a hand-written message stub.
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: { id: idMessages },
  });
}

async function mountView() {
  setActivePinia(createPinia());
  // A fake server: it applies `status` and `source` the way
  // LeadController::index does (exact match), so a pick visibly narrows
  // the table.
  vi.mocked(TutoringLeadsService.list).mockImplementation(
    async (params = {}) => ({
      items: LEADS.filter(
        (l) =>
          (!params.status || l.status === params.status) &&
          (!params.source || l.source === params.source),
      ),
      pagination: undefined,
    }),
  );
  vi.mocked(TutoringBimbelService.listPrograms).mockResolvedValue({
    items: [],
    pagination: undefined,
  });

  const w = mount(AdminTutoring2LeadsView, {
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

/** A chip found by its LABEL, so a chip reorder can't fool us. */
function chipByLabel(w, label: string) {
  const chip = w
    .findAllComponents(AppFilterChip)
    .find((c) => c.props('label') === label);
  expect(chip, `no chip labelled "${label}"`).toBeTruthy();
  return chip;
}

const statusChip = (w) => chipByLabel(w, 'Status');
const sourceChip = (w) => chipByLabel(w, 'Sumber');

/** Picker rows, in render order. Row 0 is the "Semua" reset. */
const optionRows = (w) => w.findAll(`${MODAL} button`);
const optionLabels = (w) => optionRows(w).map((b) => b.text().trim());

/** Click the picker row an admin would click, by its visible label. */
async function pickOption(w, label: string) {
  const row = optionRows(w).find((b) => b.text().trim() === label);
  expect(row, `no picker row labelled "${label}"`).toBeTruthy();
  await row!.trigger('click');
  await flushPromises();
}

const rows = (w) => w.findAll('[data-testid="lead-row"]');
/** Lead names, as an admin reads them. */
const rowNames = (w) => rows(w).map((r) => r.find('td button').text().trim());
/** The Sumber column (3rd cell). */
const rowSources = (w) =>
  rows(w).map((r) => r.findAll('td')[2].text().trim());
/** The Status column's pills. */
const pillTexts = (w) =>
  w.findAllComponents(StatusBadge).map((c) => c.props('label'));

const listCalls = () => vi.mocked(TutoringLeadsService.list).mock.calls;
const lastListArg = () => listCalls().at(-1)[0];

beforeEach(() => {
  vi.clearAllMocks();
});

describe('Leads bimbel · Status chip', () => {
  it('starts at "Semua" with no status on the query', async () => {
    const w = await mountView();

    expect(statusChip(w).props('value')).toBe('Semua');
    expect(lastListArg().status).toBeUndefined();
    expect(rowNames(w)).toEqual(['Ayu', 'Bayu', 'Citra', 'Dewi', 'Eka']);
  });

  it('clicking the chip OPENS a picker instead of toggling the filter', async () => {
    const w = await mountView();
    expect(w.find(MODAL).exists()).toBe(false);
    expect(listCalls()).toHaveLength(1);

    await statusChip(w).trigger('click');

    expect(w.find(MODAL).exists()).toBe(true);
    // Opening a picker is not a filter change: the old handler wrote
    // `new` on this very click and refetched.
    expect(listCalls()).toHaveLength(1);
    expect(lastListArg().status).toBeUndefined();
    expect(statusChip(w).props('value')).toBe('Semua');
  });

  it('lists every status LeadStatus declares, in Indonesian', async () => {
    const w = await mountView();

    await statusChip(w).trigger('click');

    // "Semua" + all five values, in LEAD_STATUS_VALUES order, labelled
    // from LEAD_STATUS_LABEL — not one English wire word among them.
    expect(optionLabels(w)).toEqual([
      'Semua',
      'Baru',
      'Dihubungi',
      'Trial',
      'Terdaftar',
      'Batal',
    ]);
  });

  it('offers "Batal" too, though the report did not ask for it', async () => {
    // The reporter listed semua / terdaftar / trial / dihubungi / baru.
    // `dropped` ("Batal") is a real status this screen already counts in
    // a KPI card and renders in the table — omitting it from the picker
    // would leave cancelled leads unfilterable while the page keeps
    // showing them. It is built from LEAD_STATUS_VALUES, so it is here
    // by construction rather than by a hand-kept list.
    const w = await mountView();

    await statusChip(w).trigger('click');
    await pickOption(w, 'Batal');

    expect(lastListArg().status).toBe('dropped');
    expect(rowNames(w)).toEqual(['Eka']);
  });

  /**
   * Every option pinned LABEL-to-WIRE, one row at a time.
   *
   * The label-list assertion above proves the five words RENDER. It
   * cannot prove each word SENDS the status it names: swap two keys
   * while building `statusFacetOptions` and the rendered list stays
   * byte-identical, so "Terdaftar" quietly asks the server for
   * `dropped`. A control that reads one thing and filters another is
   * worse than a dead one, because the reader believes the list it
   * shows them.
   */
  it.each([
    ['Baru', 'new', 'Ayu'],
    ['Dihubungi', 'contacted', 'Bayu'],
    ['Trial', 'trial', 'Citra'],
    ['Terdaftar', 'converted', 'Dewi'],
    ['Batal', 'dropped', 'Eka'],
  ])('option "%s" asks the server for status=%s', async (label, wire, who) => {
    const w = await mountView();
    await statusChip(w).trigger('click');
    await pickOption(w, label);

    expect(lastListArg().status).toBe(wire);
    // …the chip reports the state it just applied…
    expect(statusChip(w).props('value')).toBe(label);
    // …and the table narrows to exactly that status.
    expect(rowNames(w)).toEqual([who]);
    expect(pillTexts(w)).toEqual([label]);
  });

  it('applying a status reloads EXACTLY ONCE and closes the picker', async () => {
    const w = await mountView();
    expect(listCalls()).toHaveLength(1); // the mount load

    await statusChip(w).trigger('click');
    await pickOption(w, 'Terdaftar');

    // Not 3 (apply + a second write both tripping the watcher) and not
    // 1 (a write nothing watches).
    expect(listCalls()).toHaveLength(2);
    expect(w.find(MODAL).exists()).toBe(false);
  });

  it('"Semua" clears the status off the query and reloads EXACTLY ONCE', async () => {
    const w = await mountView();

    await statusChip(w).trigger('click');
    await pickOption(w, 'Trial');
    expect(lastListArg().status).toBe('trial');
    expect(listCalls()).toHaveLength(2);

    await statusChip(w).trigger('click');
    await optionRows(w)[0].trigger('click'); // "Semua"
    await flushPromises();

    // Absent, not ''. An empty string would be forwarded as
    // `where('status', '')` and match nothing — `pruneParams` in
    // services/tutoring2/leads.ts drops undefined, never the key itself.
    expect(lastListArg().status).toBeUndefined();
    expect(lastListArg().status).not.toBe('');
    expect(statusChip(w).props('value')).toBe('Semua');
    expect(rowNames(w)).toEqual(['Ayu', 'Bayu', 'Citra', 'Dewi', 'Eka']);
    expect(listCalls()).toHaveLength(3);
  });

  it('re-picking the status already selected does not refetch', async () => {
    const w = await mountView();

    await statusChip(w).trigger('click');
    await pickOption(w, 'Dihubungi');
    expect(listCalls()).toHaveLength(2);

    await statusChip(w).trigger('click');
    await pickOption(w, 'Dihubungi');

    expect(listCalls()).toHaveLength(2);
  });
});

describe('Leads bimbel · Sumber chip', () => {
  it('starts at "Semua" with no source on the query', async () => {
    const w = await mountView();

    expect(sourceChip(w).props('value')).toBe('Semua');
    expect(lastListArg().source).toBeUndefined();
  });

  it('clicking the chip OPENS a picker instead of toggling the filter', async () => {
    const w = await mountView();
    expect(listCalls()).toHaveLength(1);

    await sourceChip(w).trigger('click');

    expect(w.find(MODAL).exists()).toBe(true);
    // The old handler wrote `whatsapp` on this very click and refetched.
    expect(listCalls()).toHaveLength(1);
    expect(lastListArg().source).toBeUndefined();
    expect(sourceChip(w).props('value')).toBe('Semua');
  });

  it('lists every source LeadSource declares, in Indonesian', async () => {
    const w = await mountView();

    await sourceChip(w).trigger('click');

    // "Semua" + all five values, in LEAD_SOURCE_VALUES order, labelled
    // from LEAD_SOURCE_LABEL. "WhatsApp" is the shipped label the table
    // cell already uses; the reporter's colloquial "WA" is the same
    // option, not a rename.
    expect(optionLabels(w)).toEqual([
      'Semua',
      'Website',
      'Datang langsung',
      'Rekomendasi',
      'WhatsApp',
      'Lainnya',
    ]);
  });

  it.each([
    ['Website', 'website', 'Ayu'],
    ['Datang langsung', 'walkin', 'Bayu'],
    ['Rekomendasi', 'referral', 'Citra'],
    ['WhatsApp', 'whatsapp', 'Dewi'],
    ['Lainnya', 'other', 'Eka'],
  ])('option "%s" asks the server for source=%s', async (label, wire, who) => {
    const w = await mountView();
    await sourceChip(w).trigger('click');
    await pickOption(w, label);

    expect(lastListArg().source).toBe(wire);
    // …the chip reports the state it just applied…
    expect(sourceChip(w).props('value')).toBe(label);
    // …and the table narrows to exactly that source, the cell reading
    // the same word as the chip.
    expect(rowNames(w)).toEqual([who]);
    expect(rowSources(w)).toEqual([label]);
  });

  it('renders a translated chip value, never the raw wire word', async () => {
    const w = await mountView();

    await sourceChip(w).trigger('click');
    await pickOption(w, 'WhatsApp');

    expect(sourceChip(w).props('value')).toBe('WhatsApp');
    expect(sourceChip(w).text()).not.toContain('whatsapp');
  });

  it('applying a source reloads EXACTLY ONCE', async () => {
    const w = await mountView();
    expect(listCalls()).toHaveLength(1);

    await sourceChip(w).trigger('click');
    await pickOption(w, 'Rekomendasi');

    expect(listCalls()).toHaveLength(2);
  });

  it('"Semua" clears the source off the query and reloads EXACTLY ONCE', async () => {
    const w = await mountView();

    await sourceChip(w).trigger('click');
    await pickOption(w, 'Website');
    expect(lastListArg().source).toBe('website');
    expect(listCalls()).toHaveLength(2);

    await sourceChip(w).trigger('click');
    await optionRows(w)[0].trigger('click'); // "Semua"
    await flushPromises();

    expect(lastListArg().source).toBeUndefined();
    expect(lastListArg().source).not.toBe('');
    expect(sourceChip(w).props('value')).toBe('Semua');
    expect(rowNames(w)).toEqual(['Ayu', 'Bayu', 'Citra', 'Dewi', 'Eka']);
    expect(listCalls()).toHaveLength(3);
  });

  it('the two chips filter independently and compose on the wire', async () => {
    // Each picker writes only its OWN ref — a handler that reset the
    // sibling, or one that reloaded by hand, would show up here.
    const w = await mountView();

    await statusChip(w).trigger('click');
    await pickOption(w, 'Terdaftar');
    await sourceChip(w).trigger('click');
    await pickOption(w, 'WhatsApp');

    expect(lastListArg()).toMatchObject({ status: 'converted', source: 'whatsapp' });
    expect(statusChip(w).props('value')).toBe('Terdaftar');
    expect(sourceChip(w).props('value')).toBe('WhatsApp');
    expect(rowNames(w)).toEqual(['Dewi']);
    expect(listCalls()).toHaveLength(3); // mount + one per pick
  });

  it('keeps both chips in the toolbar, in order', async () => {
    const w = await mountView();
    const labels = w.findAllComponents(AppFilterChip).map((c) => c.props('label'));
    expect(labels).toEqual(['Status', 'Sumber']);
  });
});
