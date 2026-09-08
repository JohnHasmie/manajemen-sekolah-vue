/**
 * AdminTutoring2BillingView — the "Periode" filter chip.
 *
 * ── The defect ──
 *
 * The chip's handler was
 *   `@click="monthFilter = monthFilter ? '' : toLocalYm()"`
 * — a two-value toggle. An admin could filter to THIS month, or to no
 * month, and could never reach any other one, even though
 * `GET /tutoring-v2/bills` accepts an arbitrary `month`. Chasing an
 * unpaid bill from three months ago was simply not expressible on this
 * screen. The chip also rendered the raw wire value, `2026-09`.
 *
 * ── Anti-vacuity notes ──
 *
 * 1. The REAL <AppFilterChip>, <PageFilterToolbar> and
 *    <MonthPickerModal> are mounted — only <Teleport> and leaf chrome
 *    are stubbed. There is no second implementation of the chip or the
 *    picker for these assertions to pass against.
 * 2. Nothing reaches into `w.vm`. Every interaction is a DOM
 *    `trigger('click')` on a queried element, so an unwired handler
 *    fails the test.
 * 3. The reload count is asserted as an EXACT number, never
 *    `toHaveBeenCalled()`. Both failure modes this wiring invites — the
 *    modal's `apply` and a `v-model` write each firing the watcher
 *    (two), or the picker writing a ref nothing watches (zero) — are
 *    caught. The mount load is counted first so the delta is explicit.
 * 4. The chip label assertion is `not.toContain('2026-03')`, the exact
 *    wire string, rather than a loose "has some text" check.
 */
// @ts-nocheck — vitest types optional in this workspace
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
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

const MODAL = '[data-testid="month-picker-modal"]';
const CELL = '[data-testid="month-picker-cell"]';
const ALL_ROW = '[data-testid="month-picker-all"]';

const SUMMARY = { tertagih: 0, terbayar: 0, menunggak: 0, overdue_count: 0 };

function makeI18n() {
  // The real shipped copy: a typo'd key would surface here rather than
  // being masked by a hand-written message stub.
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: { id: idMessages },
  });
}

async function mountView() {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listBills).mockResolvedValue({
    items: [
      {
        id: 'bill-1',
        student_id: 'st-1',
        student_name: 'Rina',
        source_type: 'TUTORING_MONTHLY',
        due_date: '2026-03-10',
        amount: 500_000,
        status: 'unpaid',
      },
    ],
    pagination: undefined,
  });
  vi.mocked(TutoringBimbelService.getBillsSummary).mockResolvedValue(SUMMARY);

  const w = mount(AdminTutoring2BillingView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        teleport: true,
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        NavIcon: true,
        AsyncView: {
          props: ['state'],
          template: '<div><slot /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

/** The Periode chip, found by its LABEL so a chip reorder can't fool us. */
function periodChip(w) {
  const chip = w
    .findAllComponents(AppFilterChip)
    .find((c) => c.props('label') === 'Periode');
  expect(chip, 'no chip labelled "Periode"').toBeTruthy();
  return chip;
}

const listCalls = () => vi.mocked(TutoringBimbelService.listBills).mock.calls;
const summaryCalls = () => vi.mocked(TutoringBimbelService.getBillsSummary).mock.calls;
const lastListArg = () => listCalls().at(-1)[0];

beforeEach(() => {
  vi.clearAllMocks();
  vi.useFakeTimers();
  // Fixed "now" so the picker's default ceiling (the current month) and
  // the month the grid opens on are deterministic.
  vi.setSystemTime(new Date(2026, 8, 15, 12, 0, 0)); // 15 Sep 2026, LOCAL
});

afterEach(() => {
  vi.useRealTimers();
});

describe('Keuangan bimbel · Periode chip', () => {
  it('starts at "Semua" with no month on the query', async () => {
    const w = await mountView();

    expect(periodChip(w).props('value')).toBe('Semua');
    expect(lastListArg().month).toBeUndefined();
    expect(summaryCalls().at(-1)[0].month).toBeUndefined();
  });

  it('clicking the chip OPENS a picker instead of toggling the filter', async () => {
    const w = await mountView();
    expect(w.find(MODAL).exists()).toBe(false);
    expect(listCalls()).toHaveLength(1);

    await periodChip(w).trigger('click');

    expect(w.find(MODAL).exists()).toBe(true);
    expect(w.findAll(CELL)).toHaveLength(12);
    // Opening a picker is not a filter change: the old handler wrote the
    // ref on this very click and refetched.
    expect(listCalls()).toHaveLength(1);
    expect(periodChip(w).props('value')).toBe('Semua');
  });

  it('reaches a month that is NOT the current one — the whole defect', async () => {
    const w = await mountView();

    await periodChip(w).trigger('click');
    await w.findAll(CELL)[2].trigger('click'); // March 2026
    await flushPromises();

    expect(lastListArg().month).toBe('2026-03');
    expect(lastListArg().month).not.toBe('2026-09'); // what the toggle could reach
    expect(summaryCalls().at(-1)[0].month).toBe('2026-03');
    // The picker closes behind the pick, as FilterFacetPickerModal does.
    expect(w.find(MODAL).exists()).toBe(false);
  });

  it('applying a month reloads EXACTLY ONCE', async () => {
    const w = await mountView();
    expect(listCalls()).toHaveLength(1); // the mount load
    expect(summaryCalls()).toHaveLength(1);

    await periodChip(w).trigger('click');
    await w.findAll(CELL)[2].trigger('click');
    await flushPromises();

    // Not 3 (apply + a v-model write both tripping the watcher) and not
    // 1 (a write nothing watches).
    expect(listCalls()).toHaveLength(2);
    expect(summaryCalls()).toHaveLength(2);
  });

  it('renders a human month label, never the raw YYYY-MM', async () => {
    const w = await mountView();

    await periodChip(w).trigger('click');
    await w.findAll(CELL)[2].trigger('click');
    await flushPromises();

    expect(periodChip(w).props('value')).toBe('Maret 2026');
    expect(periodChip(w).text()).not.toContain('2026-03');
  });

  it('"Semua bulan" clears back to Semua and reloads EXACTLY ONCE', async () => {
    const w = await mountView();

    await periodChip(w).trigger('click');
    await w.findAll(CELL)[2].trigger('click');
    await flushPromises();
    expect(lastListArg().month).toBe('2026-03');
    expect(listCalls()).toHaveLength(2);

    await periodChip(w).trigger('click');
    expect(w.find(ALL_ROW).exists()).toBe(true);
    await w.get(ALL_ROW).trigger('click');
    await flushPromises();

    expect(lastListArg().month).toBeUndefined();
    expect(summaryCalls().at(-1)[0].month).toBeUndefined();
    expect(periodChip(w).props('value')).toBe('Semua');
    expect(listCalls()).toHaveLength(3);
    expect(summaryCalls()).toHaveLength(3);
  });

  it('re-picking the month already selected does not refetch', async () => {
    const w = await mountView();

    await periodChip(w).trigger('click');
    await w.findAll(CELL)[2].trigger('click');
    await flushPromises();
    expect(listCalls()).toHaveLength(2);

    await periodChip(w).trigger('click');
    await w.findAll(CELL)[2].trigger('click'); // March again
    await flushPromises();

    expect(listCalls()).toHaveLength(2);
  });

  it('leaves the Sumber and Status chips exactly as they were', async () => {
    // Those two carry a DIFFERENT defect (enum filters stuck on one
    // value) and are tracked separately. This MR must not have quietly
    // rewritten them.
    const w = await mountView();
    const labels = w.findAllComponents(AppFilterChip).map((c) => c.props('label'));
    expect(labels).toEqual(['Sumber', 'Status', 'Periode']);

    const source = w.findAllComponents(AppFilterChip)[0];
    await source.trigger('click');
    await flushPromises();
    expect(lastListArg().source_type).toBe('TUTORING_MONTHLY');

    const status = w.findAllComponents(AppFilterChip)[1];
    await status.trigger('click');
    await flushPromises();
    expect(lastListArg().status).toBe('unpaid');
  });
});
