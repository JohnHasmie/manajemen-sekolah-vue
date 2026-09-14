/**
 * AdminTutoring2BillingView — the "Status" filter chip.
 *
 * ── The defect ──
 *
 * The chip's handler was
 *   `@click="statusFilter = statusFilter ? '' : 'unpaid'"`
 * — a two-value toggle, because <AppFilterChip> is a plain button with
 * no menu of its own. An admin could ask for `unpaid` or for nothing,
 * and could never reach `pending` (bukti transfer sudah diunggah,
 * menunggu verifikasi), `partial` or `paid`, even though all four exist
 * in `BillStatus.php` and `GET /tutoring-v2/bills` matches any one of
 * them. The chip also printed the raw English wire word, `unpaid`, to an
 * Indonesian admin.
 *
 * ── Anti-vacuity notes ──
 *
 * 1. The REAL <AppFilterChip>, <PageFilterToolbar>, <StatusBadge> and
 *    <FilterFacetPickerModal> are mounted. Only <Modal> — the teleporting
 *    shell the picker renders into, which would escape the wrapper — and
 *    leaf chrome are stubbed. The option rows clicked below are the rows
 *    an admin clicks.
 * 2. Nothing reaches into `w.vm`. Every interaction is a DOM
 *    `trigger('click')` on a queried element, so an unwired handler
 *    fails the test.
 * 3. Assertions are on what the SERVER IS ASKED FOR (`listBills`' last
 *    argument) and on what the USER SEES (the chip's rendered value, the
 *    row pill's text) — never on a ref.
 * 4. `listBills` is a small fake server: it honours `params.status`, so
 *    picking a status changes the rows on screen and the pill text can
 *    be compared against the chip text.
 * 5. Reload counts are EXACT numbers. Both failure modes this wiring
 *    invites — `apply` plus a second write each tripping the watcher
 *    (two reloads), or a picker writing a ref nothing watches (zero) —
 *    are caught.
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2BillingView from './AdminTutoring2BillingView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import idMessages from '@/locales/id.json';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listBills: vi.fn(),
    getBillsSummary: vi.fn(),
  },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));

/** The stubbed <Modal> shell; the picker's own rows live inside it. */
const MODAL = '[data-testid="facet-modal"]';

const SUMMARY = { tertagih: 0, terbayar: 0, menunggak: 0, overdue_count: 0 };

/**
 * Two rows with DIFFERENT statuses, both already past 15 Sep 2026 —
 * see the "never relabels a past-due row" test.
 */
const BILLS = [
  {
    id: 'bill-1',
    student_id: 'st-1',
    student_name: 'Rina',
    source_type: 'TUTORING_MONTHLY',
    due_date: '2026-03-10',
    amount: 500_000,
    status: 'unpaid',
  },
  {
    id: 'bill-2',
    student_id: 'st-2',
    student_name: 'Budi',
    source_type: 'TUTORING_MONTHLY',
    due_date: '2026-03-12',
    amount: 300_000,
    status: 'pending',
  },
];

function makeI18n() {
  // The real shipped copy: a typo'd key would surface here rather than
  // being masked by a hand-written message stub. `tutoring2.status.*` is
  // the block the row pills read too.
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: { id: idMessages },
  });
}

async function mountView() {
  setActivePinia(createPinia());
  // A fake server: it applies `status` the way BillController::index
  // does (exact match), so a pick visibly narrows the table.
  vi.mocked(TutoringBimbelService.listBills).mockImplementation(
    async (params = {}) => ({
      items: params.status
        ? BILLS.filter((b) => b.status === params.status)
        : BILLS,
      pagination: undefined,
    }),
  );
  vi.mocked(TutoringBimbelService.getBillsSummary).mockResolvedValue(SUMMARY);

  const w = mount(AdminTutoring2BillingView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        teleport: true,
        BrandPageHeader: true,
        KpiStripCards: true,
        NavIcon: true,
        AsyncView: {
          props: ['state'],
          template: '<div><slot /></div>',
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
  w.findAll('tbody tr td:last-child span').map((s) => s.text().trim()).filter(Boolean);

const listCalls = () => vi.mocked(TutoringBimbelService.listBills).mock.calls;
const summaryCalls = () => vi.mocked(TutoringBimbelService.getBillsSummary).mock.calls;
const lastListArg = () => listCalls().at(-1)[0];

beforeEach(() => {
  vi.clearAllMocks();
});

describe('Keuangan bimbel · Status chip', () => {
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
    // `unpaid` on this very click and refetched.
    expect(listCalls()).toHaveLength(1);
    expect(lastListArg().status).toBeUndefined();
    expect(statusChip(w).props('value')).toBe('Semua');
  });

  it('lists every status the server can filter on, in Indonesian', async () => {
    const w = await mountView();

    await statusChip(w).trigger('click');

    // "Semua" + the four values BillStatus.php declares, labelled from
    // tutoring2.status.* — not one English wire word among them.
    expect(optionLabels(w)).toEqual([
      'Semua',
      'Belum lunas',
      'Menunggu verifikasi',
      'Bayar sebagian',
      'Lunas',
    ]);
  });

  it('does NOT offer "Menunggak" — the server stores no such status', async () => {
    const w = await mountView();

    await statusChip(w).trigger('click');

    // Length first, so this cannot pass vacuously against a picker that
    // never opened. `overdue` is derived from due_date; asking the API
    // for it returns 200 + an empty page, which reads as "no bills".
    expect(optionRows(w)).toHaveLength(5);
    expect(optionLabels(w)).not.toContain('Menunggak');
  });

  it('reaches "pending" — the status the toggle could never produce', async () => {
    const w = await mountView();

    await statusChip(w).trigger('click');
    await optionRows(w)[2].trigger('click'); // Menunggu verifikasi
    await flushPromises();

    expect(lastListArg().status).toBe('pending');
    expect(lastListArg().status).not.toBe('unpaid'); // all the toggle could reach
    // The picker closes behind the pick, as FilterFacetPickerModal does.
    expect(w.find(MODAL).exists()).toBe(false);
  });

  it('applying a status reloads EXACTLY ONCE', async () => {
    const w = await mountView();
    expect(listCalls()).toHaveLength(1); // the mount load
    expect(summaryCalls()).toHaveLength(1);

    await statusChip(w).trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();

    // Not 3 (apply + a second write both tripping the watcher) and not
    // 1 (a write nothing watches).
    expect(listCalls()).toHaveLength(2);
    expect(summaryCalls()).toHaveLength(2);
    // The KPI strip is refetched but NOT narrowed: /bills/summary takes
    // only source_type and month. Its docblock claims status narrows it;
    // the code never applies it. Pinned so the claim cannot be believed.
    expect(summaryCalls().at(-1)[0].status).toBeUndefined();
  });

  it('renders a translated chip label, never the raw wire word', async () => {
    const w = await mountView();

    await statusChip(w).trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();

    expect(statusChip(w).props('value')).toBe('Menunggu verifikasi');
    expect(statusChip(w).text()).not.toContain('pending');
  });

  it('narrows the table, and the row pills read the same words as the chip', async () => {
    const w = await mountView();
    expect(pillTexts(w)).toEqual(['Belum lunas', 'Menunggu verifikasi']);

    await statusChip(w).trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();

    expect(pillTexts(w)).toEqual(['Menunggu verifikasi']);
    expect(pillTexts(w)[0]).toBe(statusChip(w).props('value'));
  });

  it('never relabels a past-due row as "Menunggak" behind the filter', async () => {
    // Both fixtures are months overdue. The Status column shows the WIRE
    // status the chip filters on, so a row cannot contradict the control
    // that produced it; menunggak is the KPI tile's job.
    const w = await mountView();

    await statusChip(w).trigger('click');
    await optionRows(w)[1].trigger('click'); // Belum lunas
    await flushPromises();

    expect(lastListArg().status).toBe('unpaid');
    expect(pillTexts(w)).toEqual(['Belum lunas']);
  });

  it('"Semua" clears the status off the query and reloads EXACTLY ONCE', async () => {
    const w = await mountView();

    await statusChip(w).trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();
    expect(lastListArg().status).toBe('pending');
    expect(listCalls()).toHaveLength(2);

    await statusChip(w).trigger('click');
    await optionRows(w)[0].trigger('click'); // "Semua"
    await flushPromises();

    // Absent, not ''. An empty string would be forwarded as
    // `where('status', '')` and match nothing.
    expect(lastListArg().status).toBeUndefined();
    expect(statusChip(w).props('value')).toBe('Semua');
    expect(pillTexts(w)).toEqual(['Belum lunas', 'Menunggu verifikasi']);
    expect(listCalls()).toHaveLength(3);
  });

  it('re-picking the status already selected does not refetch', async () => {
    const w = await mountView();

    await statusChip(w).trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();
    expect(listCalls()).toHaveLength(2);

    await statusChip(w).trigger('click');
    await optionRows(w)[2].trigger('click'); // pending again
    await flushPromises();

    expect(listCalls()).toHaveLength(2);
  });

  it('leaves the Sumber chip exactly as it was', async () => {
    // The Sumber chip carries the IDENTICAL defect (an enum filter stuck
    // on one hardcoded value) and is tracked separately. This MR must
    // not have quietly rewritten it.
    const w = await mountView();
    const labels = w.findAllComponents(AppFilterChip).map((c) => c.props('label'));
    expect(labels).toEqual(['Sumber', 'Status', 'Periode']);

    const source = w.findAllComponents(AppFilterChip)[0];
    await source.trigger('click');
    await flushPromises();
    expect(lastListArg().source_type).toBe('TUTORING_MONTHLY');
  });
});
