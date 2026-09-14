/**
 * Vitest contract spec for the "Tanggal" chip on
 * AdminTutoring2AttendanceView.
 *
 * ── What shipped ────────────────────────────────────────────────────
 *
 * A FABRICATED control. `dateFilter` existed at exactly five sites —
 * its declaration, the reload watcher, and three template bindings —
 * and was passed to no query and read by no client-side predicate. Its
 * own author labelled it `// nominal, UI-only`. Because it sat in the
 * watcher, pressing it fired an IDENTICAL refetch: the label cycled
 * Semua → Hari ini → Minggu ini → Bulan ini, the chip lit up active,
 * and the table visibly re-rendered with the same rows. That re-render
 * is what sold the lie — an inert button looks broken, a button that
 * reloads and changes nothing looks like it worked.
 *
 * ── Why this spec cannot pass vacuously ─────────────────────────────
 *
 * The `listSessions` mock is NOT a fixed fixture. It reads the `from` /
 * `to` it was handed and returns only the sessions inside that
 * half-open window, exactly as `SessionController::index` does
 * (`starts_at >= from`, `starts_at < to`). So the row-count assertions
 * below are downstream of the real request params: a chip that sends
 * nothing still renders all four rows, and no amount of re-rendering
 * can fake a narrowing. The params themselves are asserted too.
 *
 * ── The exclusive upper bound ───────────────────────────────────────
 *
 * `to` is `<`, not `<=`. Every window below asserts BOTH bounds, and
 * the fixtures deliberately include a session on the LAST day of each
 * window — the row an inclusive-looking `to` would silently drop.
 */
// @ts-nocheck — vitest types not installed yet
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2AttendanceView from './AdminTutoring2AttendanceView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';

vi.mock('@/services/tutoring-bimbel.service', () => ({
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

vi.mock('@/services/tutoring2/reports', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@/services/tutoring2/reports')>();
  return { ...actual, downloadCsv: vi.fn() };
});

/**
 * "Now" for every test here: Wednesday 9 September 2026, 10:00 LOCAL.
 *
 *   today       → [2026-09-09, 2026-09-10)
 *   minggu ini  → [2026-09-07, 2026-09-14)   Mon 7 – Sun 13
 *   bulan ini   → [2026-09-01, 2026-10-01)
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
    status: 'done',
    status_label: 'Selesai',
    attendances_count: 10,
    attendances_present_count: 9,
  };
}

/**
 * One session on each boundary the windows turn on. Every `starts_at`
 * is a WIB wall-clock literal, so the local calendar day of each row is
 * unambiguous regardless of the runner's timezone.
 */
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

/**
 * The API, honestly modelled: `starts_at >= from` and `starts_at < to`,
 * the two clauses SessionController::index actually applies. A bare
 * `YYYY-MM-DD` bound is compared as that day's midnight, which is
 * precisely why `to` has to be the day AFTER the last day wanted.
 */
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
            date: 'Tanggal',
            group: 'Kelompok',
            tutor: 'Tutor',
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
  const w = mount(AdminTutoring2AttendanceView, {
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
        // The real <FilterFacetPickerModal> is mounted — only the Modal
        // shell it renders into is stubbed, because Modal teleports to
        // body and would escape the wrapper.
        Modal: { template: '<div data-testid="facet-modal"><slot /></div>' },
        Button: { template: '<button><slot /></button>' },
      },
    },
  });
  await flushPromises();
  mounted.push(w);
  return w;
}

/** Chips render in template order: date, group, tutor. */
const CHIP = { date: 0, group: 1, tutor: 2 };

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
    .findAll('[data-testid="async"] tbody tr')
    .map((tr) => tr.findAll('td')[0].text());
}
function listSessionsCalls() {
  return (TutoringBimbelService.listSessions as any).mock.calls;
}
function lastArg() {
  const calls = listSessionsCalls();
  return calls[calls.length - 1][0];
}

/** Open the Tanggal picker and click the row with this exact label. */
async function pickDate(w, label: string) {
  await chips(w)[CHIP.date].trigger('click');
  const row = optionRows(w).find((b) => b.text() === label);
  expect(row, `no picker row labelled "${label}"`).toBeTruthy();
  await row.trigger('click');
  await flushPromises();
}

const REAL_TZ = process.env.TZ;

beforeEach(() => {
  vi.clearAllMocks();
  vi.useFakeTimers();
  vi.setSystemTime(NOW);
  (TutoringBimbelService.listSessions as any).mockImplementation(fakeListSessions);
  (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
  (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
});

afterEach(() => {
  for (const w of mounted.splice(0)) w.unmount();
  vi.useRealTimers();
  process.env.TZ = REAL_TZ;
});

describe('AdminTutoring2AttendanceView Tanggal chip — reachability', () => {
  it('reads "Semua" at rest and sends NO date bounds', async () => {
    const w = await mountView();

    expect(chips(w)[CHIP.date].text()).toBe('Semua');
    const arg = lastArg();
    expect(arg.from).toBeUndefined();
    expect(arg.to).toBeUndefined();
    // The premise the narrowing tests move away from: unfiltered, every
    // fixture is on screen.
    expect(rowNames(w)).toHaveLength(ALL_SESSIONS.length);
  });

  it('OPENS a picker — the old handler opened nothing', async () => {
    const w = await mountView();
    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(false);

    await chips(w)[CHIP.date].trigger('click');

    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(true);
  });

  it('offers EVERY window from the picker, labelled, with a "Semua" reset', async () => {
    const w = await mountView();

    await chips(w)[CHIP.date].trigger('click');

    // All four reachable in one place — the blind cycle needed up to
    // three presses to reach "Bulan ini" and gave no way to see what
    // the other options were.
    expect(optionLabels(w)).toEqual(['Semua', 'Hari ini', 'Minggu ini', 'Bulan ini']);
  });

  it('renders the window LABEL on the chip, never the wire token', async () => {
    const w = await mountView();

    await pickDate(w, 'Minggu ini');

    expect(chips(w)[CHIP.date].text()).toBe('Minggu ini');
    expect(chips(w)[CHIP.date].text()).not.toContain('week');
  });
});

describe('AdminTutoring2AttendanceView Tanggal chip — the request actually changes', () => {
  it('"Hari ini" queries the half-open [D, D+1)', async () => {
    const w = await mountView();

    await pickDate(w, 'Hari ini');

    const arg = lastArg();
    expect(arg.from).toBe('2026-09-09');
    expect(arg.to).toBe('2026-09-10');
    // And the list really narrowed — not the same rows re-rendered.
    expect(rowNames(w).join(' ')).toContain('Rabu ini');
    expect(rowNames(w)).toHaveLength(1);
  });

  it('"Minggu ini" queries Monday → the FOLLOWING Monday, keeping Sunday', async () => {
    const w = await mountView();

    await pickDate(w, 'Minggu ini');

    const arg = lastArg();
    expect(arg.from).toBe('2026-09-07');
    expect(arg.to).toBe('2026-09-14');
    // Sunday the 13th is the last day of the window. A `to` of
    // '2026-09-13' would drop it silently — the whole reason the bound
    // is exclusive.
    const names = rowNames(w).join(' ');
    expect(names).toContain('Senin');
    expect(names).toContain('Rabu ini');
    expect(names).toContain('Minggu');
    expect(names).not.toContain('Agustus');
    expect(rowNames(w)).toHaveLength(3);
  });

  it('"Bulan ini" queries the calendar month, keeping the 30th', async () => {
    const w = await mountView();

    await pickDate(w, 'Bulan ini');

    const arg = lastArg();
    expect(arg.from).toBe('2026-09-01');
    expect(arg.to).toBe('2026-10-01');
    const names = rowNames(w).join(' ');
    expect(names).toContain('Akhir bulan'); // 30 Sep survives the bound
    expect(names).not.toContain('Agustus'); // 31 Aug does not
    expect(rowNames(w)).toHaveLength(4);
  });

  it('the "Semua" row clears BOTH bounds back off the query', async () => {
    const w = await mountView();
    await pickDate(w, 'Hari ini');
    expect(lastArg().from).toBe('2026-09-09');

    await pickDate(w, 'Semua');

    const arg = lastArg();
    expect(arg.from).toBeUndefined();
    expect(arg.to).toBeUndefined();
    expect(chips(w)[CHIP.date].text()).toBe('Semua');
    expect(rowNames(w)).toHaveLength(ALL_SESSIONS.length);
  });

  it('one pick triggers exactly one refetch', async () => {
    const w = await mountView();
    // Mount itself loads once, via useDataRefresh's onMounted.
    expect(listSessionsCalls()).toHaveLength(1);

    await pickDate(w, 'Hari ini');
    expect(listSessionsCalls()).toHaveLength(2);

    await pickDate(w, 'Bulan ini');
    expect(listSessionsCalls()).toHaveLength(3);
  });

  it('composes with the Kelompok chip instead of replacing it', async () => {
    const w = await mountView();

    await chips(w)[CHIP.group].trigger('click');
    await optionRows(w)[1].trigger('click'); // row 0 is "Semua"
    await flushPromises();
    expect(lastArg().learning_group_id).toBe('gr-1');

    await pickDate(w, 'Bulan ini');

    const arg = lastArg();
    // Narrowing by date must not widen the group back to "every group".
    expect(arg.learning_group_id).toBe('gr-1');
    expect(arg.from).toBe('2026-09-01');
    expect(arg.to).toBe('2026-10-01');
    expect(chips(w)[CHIP.group].text()).toBe('UTBK Pagi A');
  });
});

/**
 * The window is anchored on the reader's LOCAL day.
 *
 * The premise and the trap are asserted inside the test, so it cannot
 * pass for the wrong reason on a UTC runner — same pattern as
 * `local-date.spec.ts`.
 */
describe('AdminTutoring2AttendanceView Tanggal chip — WIB before 07:00', () => {
  it('"Hari ini" means TODAY for a 05:30 WIB admin, not yesterday', async () => {
    process.env.TZ = 'Asia/Jakarta';
    // 2026-09-08T22:30Z === 2026-09-09 05:30 WIB — inside the 7-hour
    // window in which the UTC slice still says the 8th.
    vi.setSystemTime(new Date('2026-09-08T22:30:00Z'));
    expect(new Date().getTimezoneOffset()).toBe(-420);
    expect(new Date().toISOString().slice(0, 10)).toBe('2026-09-08'); // the trap

    const w = await mountView();
    await pickDate(w, 'Hari ini');

    const arg = lastArg();
    expect(arg.from).toBe('2026-09-09');
    expect(arg.to).toBe('2026-09-10');
    // The admin's own sessions for the day they are looking at — the
    // yesterday-shifted window would have returned nothing here.
    expect(rowNames(w).join(' ')).toContain('Rabu ini');
  });

  it('"Minggu ini" is anchored on that same local day', async () => {
    process.env.TZ = 'Asia/Jakarta';
    vi.setSystemTime(new Date('2026-09-08T22:30:00Z'));

    const w = await mountView();
    await pickDate(w, 'Minggu ini');

    const arg = lastArg();
    expect(arg.from).toBe('2026-09-07');
    expect(arg.to).toBe('2026-09-14');
  });
});
