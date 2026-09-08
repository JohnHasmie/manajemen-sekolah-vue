/**
 * AdminTutoring2PayoutRequestsView — the "Periode" filter chip.
 *
 * ── The defect ──
 *
 * Same shape as the Tutor chip this screen already fixed, and the same
 * prod report ("semua button/filter tdk berfungsi"). The handler was
 *   `@click="monthFilter = monthFilter ? '' : toLocalYm()"`
 * — a toggle between THIS month and no month, with no path to any other
 * one, though the requests endpoint takes an arbitrary `month`. An
 * admin reconciling last month's payouts on the 2nd could not select
 * last month. The chip also displayed the raw `2026-09`.
 *
 * ── Deliberately NOT changed ──
 *
 * The Status chip IS a two-value toggle (Semua ⇄ pending) and that is
 * by design: the `<select v-model="statusFilter">` revealed beneath it
 * is how an admin reaches the other four states. A test below pins that
 * so a later sweep does not "fix" it into a picker and delete the
 * select.
 *
 * ── Anti-vacuity notes ──
 *
 * 1. Real <AppFilterChip>, <PageFilterToolbar> and <MonthPickerModal>;
 *    only <Teleport> and leaf chrome are stubbed.
 * 2. Interactions are DOM clicks on queried elements — never `w.vm`.
 * 3. Reload counts are EXACT, so a double-fire (apply + a v-model write
 *    both tripping the watcher) and a zero-fire both fail.
 */
// @ts-nocheck — vitest types optional in this workspace
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2PayoutRequestsView from './AdminTutoring2PayoutRequestsView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import { PayoutsService } from '@/services/tutoring2/payouts';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';
import idMessages from '@/locales/id.json';

vi.mock('@/services/tutoring2/payouts', () => ({
  PayoutsService: {
    listRequests: vi.fn(),
    approveRequest: vi.fn(),
    rejectRequest: vi.fn(),
    markRequestPaid: vi.fn(),
    rollbackRequest: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/tutors', () => ({
  TutoringTutorsService: { list: vi.fn() },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));

vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn() }),
}));

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({ can: () => true }),
}));

const MONTH_MODAL = '[data-testid="month-picker-modal"]';
const CELL = '[data-testid="month-picker-cell"]';
const ALL_ROW = '[data-testid="month-picker-all"]';

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: { id: idMessages },
  });
}

async function mountView() {
  setActivePinia(createPinia());
  vi.mocked(PayoutsService.listRequests).mockResolvedValue({
    items: [
      {
        id: 'pq-1',
        tutor_id: 'tu-1',
        tutor_name: 'Pak Rahmat',
        period_month: '2026-03',
        amount: 1_500_000,
        status: 'pending',
        requested_at: '2026-03-15T09:00:00+07:00',
      },
    ],
    pagination: undefined,
  });
  vi.mocked(TutoringTutorsService.list).mockResolvedValue({
    items: [{ id: 'tu-1', user_id: 'us-1', name: 'Pak Rahmat', is_active: true, active_group_count: 2 }],
  });

  const w = mount(AdminTutoring2PayoutRequestsView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        teleport: true,
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        FormField: true,
        FormSheet: true,
        NavIcon: true,
        Button: { template: '<button><slot /></button>' },
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

function chipByLabel(w, label) {
  const chip = w.findAllComponents(AppFilterChip).find((c) => c.props('label') === label);
  expect(chip, `no chip labelled "${label}"`).toBeTruthy();
  return chip;
}

const periodChip = (w) => chipByLabel(w, 'Periode');
const listCalls = () => vi.mocked(PayoutsService.listRequests).mock.calls;
const lastArg = () => listCalls().at(-1)[0];

beforeEach(() => {
  vi.clearAllMocks();
  vi.useFakeTimers();
  vi.setSystemTime(new Date(2026, 8, 15, 12, 0, 0)); // 15 Sep 2026, LOCAL
});

afterEach(() => {
  vi.useRealTimers();
});

describe('Permintaan payout · Periode chip', () => {
  it('starts at "Semua" with no month on the query', async () => {
    const w = await mountView();

    expect(periodChip(w).props('value')).toBe('Semua');
    expect(lastArg().month).toBeUndefined();
  });

  it('clicking the chip OPENS a picker instead of toggling the filter', async () => {
    const w = await mountView();
    expect(w.find(MONTH_MODAL).exists()).toBe(false);
    expect(listCalls()).toHaveLength(1);

    await periodChip(w).trigger('click');

    expect(w.find(MONTH_MODAL).exists()).toBe(true);
    expect(w.findAll(CELL)).toHaveLength(12);
    expect(listCalls()).toHaveLength(1);
    expect(periodChip(w).props('value')).toBe('Semua');
  });

  it('reaches a month that is NOT the current one — the whole defect', async () => {
    const w = await mountView();

    await periodChip(w).trigger('click');
    await w.findAll(CELL)[2].trigger('click'); // March 2026
    await flushPromises();

    expect(lastArg().month).toBe('2026-03');
    expect(lastArg().month).not.toBe('2026-09'); // all the toggle could reach
    expect(w.find(MONTH_MODAL).exists()).toBe(false);
  });

  it('applying a month reloads EXACTLY ONCE', async () => {
    const w = await mountView();
    expect(listCalls()).toHaveLength(1); // the mount load

    await periodChip(w).trigger('click');
    await w.findAll(CELL)[2].trigger('click');
    await flushPromises();

    expect(listCalls()).toHaveLength(2);
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
    expect(lastArg().month).toBe('2026-03');
    expect(listCalls()).toHaveLength(2);

    await periodChip(w).trigger('click');
    expect(w.find(ALL_ROW).exists()).toBe(true);
    await w.get(ALL_ROW).trigger('click');
    await flushPromises();

    expect(lastArg().month).toBeUndefined();
    expect(periodChip(w).props('value')).toBe('Semua');
    expect(listCalls()).toHaveLength(3);
  });

  it('re-picking the month already selected does not refetch', async () => {
    const w = await mountView();

    await periodChip(w).trigger('click');
    await w.findAll(CELL)[2].trigger('click');
    await flushPromises();
    expect(listCalls()).toHaveLength(2);

    await periodChip(w).trigger('click');
    await w.findAll(CELL)[2].trigger('click');
    await flushPromises();

    expect(listCalls()).toHaveLength(2);
  });

  it('the Period filter does not disturb Status or Tutor', async () => {
    const w = await mountView();

    await periodChip(w).trigger('click');
    await w.findAll(CELL)[2].trigger('click');
    await flushPromises();

    expect(lastArg().status).toBeUndefined();
    expect(lastArg().tutor_id).toBeUndefined();
    expect(chipByLabel(w, 'Status').props('value')).toBe('Semua');
    expect(chipByLabel(w, 'Tutor').props('value')).toBe('Semua');
  });

  it('leaves the Status chip a toggle backed by its select — by design', async () => {
    // Three of four sweep angles mis-read this chip as broken. It is
    // not: the toggle reveals a <select> carrying the other four
    // states. If a later change turns the chip into a picker, that
    // select must not vanish with it.
    const w = await mountView();
    const status = chipByLabel(w, 'Status');

    expect(w.find('select').exists()).toBe(false);

    await status.trigger('click');
    await flushPromises();

    expect(lastArg().status).toBe('pending');
    const select = w.get('select');
    const values = select.findAll('option').map((o) => o.attributes('value'));
    expect(values).toEqual(['', 'pending', 'approved', 'rejected', 'paid', 'rolled_back']);
  });
});
