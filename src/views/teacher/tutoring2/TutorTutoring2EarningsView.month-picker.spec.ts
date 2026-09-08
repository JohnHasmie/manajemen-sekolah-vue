/**
 * "role guru/tutor pada halaman honor, di input periode jadikan ketika
 * input di klik maka menampilkan kalender yang dapat dipilih, bukan
 * input yang hanya dapat diketik."
 *
 * ── The defect, and why the obvious fix was wrong ──
 *
 * The Periode field was ALREADY `<input type="month">` — the correct
 * input type for a `YYYY-MM` value — so "set the input type" would have
 * changed nothing. The cause is browser support: desktop Safari ships no
 * picker UI for `type="month"` and degrades it to a plain text box (MDN:
 * only Chrome/Opera and Edge on desktop have usable implementations).
 * The reporter was on macOS Safari, which is why the same screen looked
 * fine to everyone on Chrome.
 *
 * ── What this file locks ──
 *
 * 1. The control is a BUTTON that opens a picker, and there is no text
 *    input left on the toolbar to type a raw `YYYY-MM` into.
 * 2. Picking a month refetches EXACTLY ONCE with the new month. The view
 *    has a `watch(month, reload)`; a field that emitted twice (or
 *    re-emitted the same value) would double-fetch, and the count is
 *    asserted rather than "was called".
 * 3. The default period is the current LOCAL month. There is a deliberate
 *    comment in the view about this: a UTC-derived default shows the
 *    PREVIOUS month for the first 7 hours of every 1st in WIB. The test
 *    pins TZ to Asia/Jakarta and sets the clock inside that window, so a
 *    regression to `toISOString().slice(0, 7)` reddens it.
 *
 * Anti-vacuity: the real <MonthPickerField> / <MonthPickerModal> /
 * <FormField> are mounted; only `<Teleport>` and the page chrome are
 * stubbed. Every assertion drives the DOM rather than calling a handler
 * on `w.vm`.
 */
// @ts-nocheck — vitest types optional in this workspace
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import Earnings from './TutorTutoring2EarningsView.vue';
import { PayoutsService } from '@/services/tutoring2/payouts';
import idMessages from '@/locales/id.json';

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({ can: () => true, canAny: () => true }),
}));

vi.mock('@/services/tutoring2/payouts', () => ({
  PayoutsService: {
    getSelfSummary: vi.fn(),
    listMyRequests: vi.fn(),
    getRequest: vi.fn(),
  },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: () => {},
}));

const TRIGGER = '[data-testid="field-earnings-month"]';
const MODAL = '[data-testid="month-picker-modal"]';
const CELL = '[data-testid="month-picker-cell"]';

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
  vi.mocked(PayoutsService.getSelfSummary).mockResolvedValue({
    tutor_id: 'tut-1',
    tutor_name: 'Bu Sinta',
    period_month: '2026-09',
    sessions_taught: 12,
    base_amount: 1_200_000,
    adjustments: 50_000,
    net_amount: 1_250_000,
  });
  vi.mocked(PayoutsService.listMyRequests).mockResolvedValue({
    items: [],
    pagination: undefined,
  });

  const w = mount(Earnings, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: true,
        teleport: true,
        AsyncView: {
          props: ['state'],
          template: `<div><slot v-if="state?.status === 'content'" /></div>`,
        },
      },
    },
  });
  await flushPromises();
  return w;
}

/** Every `month` the view has asked the server for, oldest first. */
function requestedMonths() {
  return vi.mocked(PayoutsService.getSelfSummary).mock.calls.map((c) => c[0]?.month);
}

const REAL_TZ = process.env.TZ;

beforeAll(() => {
  // WIB — every tenant on this platform, and the reporter's timezone.
  process.env.TZ = 'Asia/Jakarta';
});
afterAll(() => {
  process.env.TZ = REAL_TZ;
});

beforeEach(() => {
  vi.clearAllMocks();
  vi.useFakeTimers();
  // 2026-08-31T18:30Z === 1 Sep 2026, 01:30 WIB. Inside the window where
  // a UTC-derived default would wrongly say August.
  vi.setSystemTime(new Date('2026-08-31T18:30:00Z'));
});

afterEach(() => {
  vi.useRealTimers();
});

describe('Honor Saya · period picker', () => {
  it('renders a button, not a typeable month input', async () => {
    const w = await mountView();
    const trigger = w.get(TRIGGER);
    expect(trigger.element.tagName).toBe('BUTTON');
    // The reported symptom was a bare text box. Nothing on this toolbar
    // should be typeable any more.
    expect(w.find('input[type="month"]').exists()).toBe(false);
    expect(w.find('input[type="text"]').exists()).toBe(false);
  });

  it('defaults to the current LOCAL month, not the UTC one', async () => {
    // Premise guard — a spec that silently ran in UTC would be vacuous.
    expect(new Date().getTimezoneOffset()).toBe(-420);
    expect(new Date().toISOString().slice(0, 7)).toBe('2026-08'); // the buggy form

    const w = await mountView();
    expect(w.get(TRIGGER).text()).toBe('September 2026');
    expect(requestedMonths()).toEqual(['2026-09']);
  });

  it('opens the picker when the field is clicked', async () => {
    const w = await mountView();
    expect(w.find(MODAL).exists()).toBe(false);
    await w.get(TRIGGER).trigger('click');
    expect(w.find(MODAL).exists()).toBe(true);
    expect(w.findAll(CELL)).toHaveLength(12);
  });

  it('refetches EXACTLY ONCE with the picked month', async () => {
    const w = await mountView();
    expect(requestedMonths()).toEqual(['2026-09']);

    await w.get(TRIGGER).trigger('click');
    await w.findAll(CELL)[2].trigger('click'); // March 2026
    await flushPromises();

    // One initial load + one for the pick. Not three.
    expect(requestedMonths()).toEqual(['2026-09', '2026-03']);
    expect(vi.mocked(PayoutsService.getSelfSummary)).toHaveBeenCalledTimes(2);
  });

  it('updates the visible label to the month it fetched', async () => {
    const w = await mountView();
    await w.get(TRIGGER).trigger('click');
    await w.findAll(CELL)[2].trigger('click');
    await flushPromises();

    expect(w.get(TRIGGER).text()).toBe('Maret 2026');
    expect(requestedMonths().at(-1)).toBe('2026-03');
  });

  it('does not refetch when the already-selected month is re-picked', async () => {
    const w = await mountView();
    await w.get(TRIGGER).trigger('click');
    await w.findAll(CELL)[8].trigger('click'); // September — already current
    await flushPromises();

    expect(vi.mocked(PayoutsService.getSelfSummary)).toHaveBeenCalledTimes(1);
  });

  it('will not offer a future month, which would render as an empty honor', async () => {
    const w = await mountView();
    await w.get(TRIGGER).trigger('click');
    const cells = w.findAll(CELL);
    expect(cells[8].attributes('disabled')).toBeUndefined(); // Sep 2026 = now
    expect(cells[9].attributes('disabled')).toBeDefined(); // Oct 2026 = future
    expect(cells[11].attributes('disabled')).toBeDefined(); // Dec 2026
  });
});
