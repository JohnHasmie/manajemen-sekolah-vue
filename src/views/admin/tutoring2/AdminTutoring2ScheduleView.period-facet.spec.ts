/**
 * Vitest contract spec for the "Periode" chip on
 * AdminTutoring2ScheduleView, and for the precedence rule that lets it
 * coexist with the `?date=` drill-in.
 *
 * ── What shipped ────────────────────────────────────────────────────
 *
 * A FABRICATED control. `periodFilter` existed at exactly five sites —
 * its declaration, the reload watcher, and three template bindings —
 * and reached no query. Its own author labelled it `// nominal,
 * UI-only`. Because it sat in the watcher, pressing it fired a
 * BYTE-IDENTICAL refetch: the chip lit up, the list visibly
 * re-rendered, nothing was filtered.
 *
 * ── Why wiring it needed a rule, not just a param ───────────────────
 *
 * `listSessions` has exactly ONE pair of date keys and
 * `SessionController::index` honours no others — there is no `period`
 * param. So the period must write `from`/`to`, the same two keys the
 * neighbouring `dateFilter` (a single DAY, seeded from `?date=` by the
 * Laporan Aktivitas drill-in) already owns. Two controls, two meanings,
 * one pair of keys. The rule under test:
 *
 *   • a specific DAY wins while it is set;
 *   • choosing a period CLEARS the day and strips `?date=` off the URL,
 *     through the same `clearDateFilter()` the context bar calls;
 *   • a day arriving from the URL resets the period chip to "Semua".
 *
 * So exactly one date scope is in force, and the chip and the context
 * bar always agree about which one.
 *
 * ── Why this spec cannot pass vacuously ─────────────────────────────
 *
 * The `listSessions` mock reads the `from`/`to` it was handed and
 * returns only the sessions inside that half-open window, exactly as
 * the controller does. Row counts below are therefore downstream of the
 * real request params. The params are asserted directly as well.
 *
 * The eight `?date=` tests in AdminTutoring2ScheduleView.spec.ts are
 * the deep link's own contract and are deliberately NOT duplicated
 * here; they must stay green untouched.
 */
// @ts-nocheck — vitest types not installed yet
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { reactive } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2ScheduleView from './AdminTutoring2ScheduleView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';

vi.mock('@/services/tutoring-bimbel.service', async (importOriginal) => ({
  ...(await importOriginal()),
  TutoringBimbelService: {
    listSessions: vi.fn(),
    listGroups: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/tutors', () => ({
  TutoringTutorsService: { list: vi.fn() },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: (_fn: () => void) => {
    /* noop in tests */
  },
}));

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({
    can: () => true,
    canAny: () => true,
  }),
}));

const push = vi.fn();

/**
 * A FAITHFUL `router.replace`: it writes the new query back into the
 * reactive route, exactly as the real router does.
 *
 * This matters more than it looks. `clearDateFilter()` strips `?date=`
 * via `router.replace`, and the view watches `() => route.query.date`.
 * With an inert `vi.fn()` the second half of that loop never runs, so
 * every assertion about what happens AFTER the URL changes is silently
 * unreachable — including the guard that decides whether the period chip
 * survives a day being cleared. An inert mock does not make such a test
 * fail; it makes it untestable, which is worse, because it reads as
 * covered.
 */
const replace = vi.fn((to?: { query?: Record<string, unknown> }) => {
  const next = to?.query ?? {};
  for (const k of Object.keys(routeQuery)) delete routeQuery[k];
  Object.assign(routeQuery, next);
  return Promise.resolve();
});

// REACTIVE, because the view watches `() => route.query.date`. A plain
// object would never notify, and the deep-link tests below would be
// asserting nothing.
const route = reactive({ params: {}, query: {} as Record<string, unknown> });
const routeQuery = route.query;

function setDateQuery(value?: string) {
  for (const k of Object.keys(routeQuery)) delete routeQuery[k];
  if (value !== undefined) routeQuery.date = value;
}

vi.mock('vue-router', () => ({
  useRouter: () => ({ push, replace, back: vi.fn() }),
  useRoute: () => route,
}));

/**
 * "Now" for every test here: Wednesday 9 September 2026, 10:00 LOCAL.
 *
 *   minggu ini → [2026-09-07, 2026-09-14)   Mon 7 – Sun 13
 *   bulan ini  → [2026-09-01, 2026-10-01)
 */
const NOW = new Date(2026, 8, 9, 10, 0, 0);

function session(id: string, startsAt: string, name: string) {
  return {
    id,
    learning_group_id: 'gr-1',
    learning_group_name: name,
    tutor_id: 'tu-1',
    tutor_name: 'Pak Rahmat',
    starts_at: startsAt,
    ends_at: startsAt,
    room: 'R1',
    status: 'scheduled',
    status_label: 'Terjadwal',
  };
}

const LAST_MONTH = session('se-aug', '2026-08-31T08:00:00+07:00', 'Agustus');
const MONDAY = session('se-mon', '2026-09-07T08:00:00+07:00', 'Senin');
const TODAY = session('se-today', '2026-09-09T08:00:00+07:00', 'Rabu ini');
/** Sunday — the LAST day of the week window, dropped by an inclusive `to`. */
const SUNDAY = session('se-sun', '2026-09-13T20:00:00+07:00', 'Minggu');
/** 30 Sep — the LAST day of the month window, same trap one size up. */
const MONTH_END = session('se-eom', '2026-09-30T20:00:00+07:00', 'Akhir bulan');

const ALL_SESSIONS = [LAST_MONTH, MONDAY, TODAY, SUNDAY, MONTH_END];

const GROUPS = [
  { id: 'gr-1', program_id: 'pr-1', program_name: 'Intensif UTBK', name: 'UTBK Pagi A', kind: 'group', capacity: 12, status: 'active' },
  { id: 'gr-2', program_id: 'pr-2', program_name: 'Reguler SMP', name: 'SMP Sore B', kind: 'group', capacity: 10, status: 'active' },
];
const TUTORS = [
  { id: 'tu-1', user_id: 'us-1', name: 'Pak Rahmat', is_active: true, active_group_count: 2 },
  { id: 'tu-2', user_id: 'us-2', name: 'Bu Sinta', is_active: true, active_group_count: 1 },
];

/** `starts_at >= from` and `starts_at < to` — the controller's clauses. */
function fakeListSessions(params: Record<string, unknown> = {}) {
  const rows = ALL_SESSIONS.filter((s) => {
    const day = s.starts_at.slice(0, 10);
    if (params.from && day < String(params.from)) return false;
    if (params.to && day >= String(params.to)) return false;
    if (params.learning_group_id && s.learning_group_id !== params.learning_group_id) return false;
    return true;
  });
  return Promise.resolve({ items: rows, pagination: undefined });
}

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: {
      id: {
        tutoring2: {
          common: {
            all: 'Semua',
            today: 'Hari ini',
            thisWeek: 'Minggu ini',
            thisMonth: 'Bulan ini',
            group: 'Kelompok',
            tutor: 'Tutor',
            status: 'Status',
            period: 'Periode',
          },
          admin: {
            schedule: {
              dateFilterActive: 'Menampilkan sesi pada {date}',
              dateFilterClear: 'Tampilkan semua tanggal',
            },
          },
          status: {
            scheduled: 'Terjadwal',
            inProgress: 'Berlangsung',
            done: 'Selesai',
            cancelled: 'Dibatalkan',
          },
        },
      },
    },
    missingWarn: false,
    fallbackWarn: false,
  });
}

const mounted: ReturnType<typeof mount>[] = [];

async function mountView() {
  setActivePinia(createPinia());
  const w = mount(AdminTutoring2ScheduleView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        PageFilterToolbar: {
          template: '<div data-testid="toolbar"><slot name="chips" /></div>',
        },
        AppFilterChip: {
          props: ['label', 'value', 'iconName', 'active', 'disabled'],
          emits: ['click'],
          template:
            '<button data-testid="chip" :disabled="disabled" @click="$emit(\'click\')">{{ value }}</button>',
        },
        AsyncView: {
          props: ['state'],
          template: '<div data-testid="async"><slot :data="state?.data ?? []" /></div>',
        },
        // The real <FilterFacetPickerModal> is mounted; only the Modal
        // shell is stubbed, because Modal teleports to body.
        Modal: { template: '<div data-testid="facet-modal"><slot /></div>' },
        Button: { template: '<button><slot /></button>' },
      },
    },
  });
  await flushPromises();
  mounted.push(w);
  return w;
}

/** Chips render in template order: status, group, tutor, period. */
const CHIP = { status: 0, group: 1, tutor: 2, period: 3 };
const BAR = '[data-testid="schedule-date-filter"]';

function chips(w) {
  return w.findAll('[data-testid="chip"]');
}
function optionRows(w) {
  return w.findAll('[data-testid="facet-modal"] button');
}
function optionLabels(w) {
  return optionRows(w).map((b) => b.text());
}
function rowNames(w) {
  return w
    .findAll('[data-testid="schedule-row"]')
    .map((tr) => tr.findAll('td')[1].text());
}
function listSessionsCalls() {
  return (TutoringBimbelService.listSessions as any).mock.calls;
}
function lastArg() {
  const calls = listSessionsCalls();
  return calls[calls.length - 1][0];
}

/** Open the Periode picker and click the row with this exact label. */
async function pickPeriod(w, label: string) {
  await chips(w)[CHIP.period].trigger('click');
  const row = optionRows(w).find((b) => b.text() === label);
  expect(row, `no picker row labelled "${label}"`).toBeTruthy();
  await row.trigger('click');
  await flushPromises();
}

const REAL_TZ = process.env.TZ;

beforeEach(() => {
  vi.clearAllMocks();
  setDateQuery();
  vi.useFakeTimers();
  vi.setSystemTime(NOW);
  (TutoringBimbelService.listSessions as any).mockImplementation(fakeListSessions);
  (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
  (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
});

afterEach(() => {
  // Mandatory: `route` is shared and reactive, so a view left mounted
  // keeps its `watch(() => route.query.date, …)` alive and reloads on
  // the NEXT test's setDateQuery().
  for (const w of mounted.splice(0)) w.unmount();
  vi.useRealTimers();
  process.env.TZ = REAL_TZ;
});

describe('AdminTutoring2ScheduleView Periode chip — reachability', () => {
  it('reads "Semua" at rest and sends NO date bounds', async () => {
    const w = await mountView();

    expect(chips(w)[CHIP.period].text()).toBe('Semua');
    const arg = lastArg();
    expect(arg.from).toBeUndefined();
    expect(arg.to).toBeUndefined();
    expect(rowNames(w)).toHaveLength(ALL_SESSIONS.length);
  });

  it('OPENS a picker — the old handler opened nothing', async () => {
    const w = await mountView();
    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(false);

    await chips(w)[CHIP.period].trigger('click');

    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(true);
  });

  it('offers EVERY window from the picker, plus a "Semua" reset', async () => {
    const w = await mountView();

    await chips(w)[CHIP.period].trigger('click');

    // No "Hari ini": a single day is what `dateFilter` and the context
    // bar already express, and a second way to say it would re-open the
    // ambiguity the precedence rule closes.
    expect(optionLabels(w)).toEqual(['Semua', 'Minggu ini', 'Bulan ini']);
  });

  it('renders the window LABEL on the chip, never the wire token', async () => {
    const w = await mountView();

    await pickPeriod(w, 'Bulan ini');

    expect(chips(w)[CHIP.period].text()).toBe('Bulan ini');
    expect(chips(w)[CHIP.period].text()).not.toContain('month');
  });
});

describe('AdminTutoring2ScheduleView Periode chip — the request actually changes', () => {
  it('"Minggu ini" queries Monday → the FOLLOWING Monday, keeping Sunday', async () => {
    const w = await mountView();

    await pickPeriod(w, 'Minggu ini');

    const arg = lastArg();
    expect(arg.from).toBe('2026-09-07');
    expect(arg.to).toBe('2026-09-14');
    const names = rowNames(w).join(' ');
    expect(names).toContain('Senin');
    expect(names).toContain('Minggu'); // 13 Sep survives the exclusive bound
    expect(names).not.toContain('Agustus');
    expect(rowNames(w)).toHaveLength(3);
  });

  it('"Bulan ini" queries the calendar month, keeping the 30th', async () => {
    const w = await mountView();

    await pickPeriod(w, 'Bulan ini');

    const arg = lastArg();
    expect(arg.from).toBe('2026-09-01');
    expect(arg.to).toBe('2026-10-01');
    const names = rowNames(w).join(' ');
    expect(names).toContain('Akhir bulan');
    expect(names).not.toContain('Agustus');
    expect(rowNames(w)).toHaveLength(4);
  });

  it('the "Semua" row clears BOTH bounds back off the query', async () => {
    const w = await mountView();
    await pickPeriod(w, 'Minggu ini');
    expect(lastArg().from).toBe('2026-09-07');

    await pickPeriod(w, 'Semua');

    const arg = lastArg();
    expect(arg.from).toBeUndefined();
    expect(arg.to).toBeUndefined();
    expect(chips(w)[CHIP.period].text()).toBe('Semua');
    expect(rowNames(w)).toHaveLength(ALL_SESSIONS.length);
  });

  it('one pick triggers exactly one refetch', async () => {
    const w = await mountView();
    expect(listSessionsCalls()).toHaveLength(1);

    await pickPeriod(w, 'Minggu ini');
    expect(listSessionsCalls()).toHaveLength(2);

    await pickPeriod(w, 'Bulan ini');
    expect(listSessionsCalls()).toHaveLength(3);
  });

  it('composes with the Kelompok chip instead of replacing it', async () => {
    const w = await mountView();

    await chips(w)[CHIP.group].trigger('click');
    await optionRows(w)[1].trigger('click'); // row 0 is "Semua"
    await flushPromises();
    expect(lastArg().learning_group_id).toBe('gr-1');

    await pickPeriod(w, 'Bulan ini');

    const arg = lastArg();
    expect(arg.learning_group_id).toBe('gr-1');
    expect(arg.from).toBe('2026-09-01');
    expect(arg.to).toBe('2026-10-01');
  });

  it('leaves the sibling chips reading "Semua"', async () => {
    const w = await mountView();

    await pickPeriod(w, 'Minggu ini');

    expect(chips(w)[CHIP.status].text()).toBe('Semua');
    expect(chips(w)[CHIP.group].text()).toBe('Semua');
    expect(chips(w)[CHIP.tutor].text()).toBe('Semua');
    const arg = lastArg();
    expect(arg.status).toBeUndefined();
    expect(arg.tutor_id).toBeUndefined();
  });
});

/**
 * One effective date scope at a time, and it is always the one on
 * screen. Every test here is about the two controls NOT both writing
 * `from`/`to`.
 */
describe('AdminTutoring2ScheduleView Periode vs the ?date= drill-in', () => {
  it('a specific day WINS over a period that was set first', async () => {
    const w = await mountView();
    await pickPeriod(w, 'Bulan ini');
    expect(lastArg().from).toBe('2026-09-01');

    // A second drill-in from Laporan Aktivitas into the mounted view.
    routeQuery.date = '2026-09-09';
    await flushPromises();

    const arg = lastArg();
    expect(arg.from).toBe('2026-09-09');
    expect(arg.to).toBe('2026-09-10');
    expect(rowNames(w)).toHaveLength(1);
  });

  it('and that arriving day RESETS the period chip, so it cannot claim a window it is not applying', async () => {
    const w = await mountView();
    await pickPeriod(w, 'Bulan ini');
    expect(chips(w)[CHIP.period].text()).toBe('Bulan ini');

    routeQuery.date = '2026-09-09';
    await flushPromises();

    // Otherwise the chip reads "Bulan ini" over a list showing one day.
    expect(chips(w)[CHIP.period].text()).toBe('Semua');
    expect(w.find(BAR).exists()).toBe(true);
  });

  it('the day still wins when the drill-in was the ENTRY point', async () => {
    setDateQuery('2026-09-09');

    const w = await mountView();

    // Byte-for-byte what the deep link has always sent.
    const arg = lastArg();
    expect(arg.from).toBe('2026-09-09');
    expect(arg.to).toBe('2026-09-10');
    expect(chips(w)[CHIP.period].text()).toBe('Semua');
  });

  it('choosing a period CLEARS the day and widens the query to the window', async () => {
    setDateQuery('2026-09-09');
    const w = await mountView();
    expect(lastArg().from).toBe('2026-09-09');
    expect(w.find(BAR).exists()).toBe(true);

    await pickPeriod(w, 'Minggu ini');

    const arg = lastArg();
    expect(arg.from).toBe('2026-09-07');
    expect(arg.to).toBe('2026-09-14');
    // The context bar must go with the day it announces.
    expect(w.find(BAR).exists()).toBe(false);
    expect(chips(w)[CHIP.period].text()).toBe('Minggu ini');
    expect(rowNames(w)).toHaveLength(3);
  });

  it('and strips ?date= off the URL, through the SAME clearDateFilter the bar uses', async () => {
    setDateQuery('2026-09-09');
    const w = await mountView();

    await pickPeriod(w, 'Minggu ini');

    // Otherwise a refresh silently re-applies the day the reader just
    // replaced with a week. `replace`, not `push` — swapping one filter
    // for another is not a place in history worth returning to.
    expect(replace).toHaveBeenCalledTimes(1);
    expect(push).not.toHaveBeenCalled();
    const arg = replace.mock.calls[0][0];
    expect(arg.name).toBe('admin.tutoring2.schedule');
    expect(arg.query.date).toBeUndefined();
  });

  it('keeps the sibling query params it did not own while doing so', async () => {
    setDateQuery('2026-09-09');
    routeQuery.tab = 'sesi';
    const w = await mountView();

    await pickPeriod(w, 'Bulan ini');

    expect(replace.mock.calls[0][0].query).toEqual({ tab: 'sesi' });
  });

  it('clears the day in ONE refetch, not two', async () => {
    setDateQuery('2026-09-09');
    const w = await mountView();
    expect(listSessionsCalls()).toHaveLength(1);

    await pickPeriod(w, 'Minggu ini');

    // Both refs change inside one tick, so the single watcher fires
    // once. Not 3 (day-clear + period-set each tripping it) and not 1
    // (a write nothing watches).
    expect(listSessionsCalls()).toHaveLength(2);
  });

  it('picking "Semua" on the period does NOT clear a day the reader drilled into', async () => {
    setDateQuery('2026-09-09');
    const w = await mountView();

    await pickPeriod(w, 'Semua');

    // Resetting an unset period is a no-op; it must not throw away the
    // drill-in, and it must not touch the URL.
    expect(replace).not.toHaveBeenCalled();
    const arg = lastArg();
    expect(arg.from).toBe('2026-09-09');
    expect(arg.to).toBe('2026-09-10');
    expect(w.find(BAR).exists()).toBe(true);
  });
});

/**
 * The window is anchored on the reader's LOCAL day. Premise and trap
 * asserted inside the test, so it cannot pass for the wrong reason on a
 * UTC runner.
 */
describe('AdminTutoring2ScheduleView Periode chip — WIB before 07:00', () => {
  it('"Minggu ini" is the week of the LOCAL day, not of the UTC one', async () => {
    process.env.TZ = 'Asia/Jakarta';
    // 2026-09-13T22:30Z === 2026-09-14 05:30 WIB — a Monday in WIB
    // while UTC still says Sunday the 13th, so the two disagree about
    // which WEEK it is, not merely which day.
    vi.setSystemTime(new Date('2026-09-13T22:30:00Z'));
    expect(new Date().getTimezoneOffset()).toBe(-420);
    expect(new Date().toISOString().slice(0, 10)).toBe('2026-09-13'); // the trap

    const w = await mountView();
    await pickPeriod(w, 'Minggu ini');

    // The WIB reader's week starts on the 14th. The UTC slice would
    // have handed them 7–13 Sep — an entire week in the past.
    const arg = lastArg();
    expect(arg.from).toBe('2026-09-14');
    expect(arg.to).toBe('2026-09-21');
  });

  it('"Bulan ini" is the month of the LOCAL day too', async () => {
    process.env.TZ = 'Asia/Jakarta';
    // 2026-08-31T18:30Z === 2026-09-01 01:30 WIB.
    vi.setSystemTime(new Date('2026-08-31T18:30:00Z'));
    expect(new Date().toISOString().slice(0, 7)).toBe('2026-08'); // the trap

    const w = await mountView();
    await pickPeriod(w, 'Bulan ini');

    const arg = lastArg();
    expect(arg.from).toBe('2026-09-01');
    expect(arg.to).toBe('2026-10-01');
  });
});
