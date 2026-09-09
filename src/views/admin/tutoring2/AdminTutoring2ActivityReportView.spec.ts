/**
 * Vitest spec — Laporan Aktivitas admin view.
 *
 * ── What was wrong ──────────────────────────────────────────────────
 *
 * Every `<tr>` in this table carried `hover:bg-slate-50` and the file
 * contained exactly two `@click`s, both on the export buttons. So the
 * whole table lit up under the cursor and not one row did anything —
 * which is what "kenapa barisnya tidak bisa diklik" was actually
 * reporting.
 *
 * ── What a row can open ─────────────────────────────────────────────
 *
 * Not "that activity's detail": `ActivityReportRow` is
 * `{date, sessions_*, attendance_marked_count}` with no id of any kind,
 * because the backend rollup groups by `starts_at::date`. The only
 * thing a row identifies is the DAY, so the drill-in is that day's
 * sessions — `admin.tutoring2.schedule?date=YYYY-MM-DD` — from which
 * the existing session detail is one more click.
 *
 * ── Which of these fail against the shipped template ────────────────
 *
 * RED before, all of them in the "drill-in" and "affordance is honest"
 * blocks: the old rows had no handler at all, so every navigation
 * assertion was 0 calls, and they had an unconditional `hover:` class,
 * so every "no affordance" assertion saw the hover on rows that could
 * not be opened.
 *
 * PASS EITHER WAY, deliberately: the whole "figures are unchanged"
 * block, and the wire-shape contract test carried over from the
 * original spec. Those are the baseline this change must NOT move —
 * they are here to fail if a later edit starts reshaping the report
 * while wiring navigation into it.
 */
// @ts-nocheck — vitest types not installed in this workspace
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import View from './AdminTutoring2ActivityReportView.vue';
import { TutoringReportsService } from '@/services/tutoring2/reports';
import type { ActivityReportRow } from '@/types/tutoring2/report';

vi.mock('@/services/tutoring2/reports', async (importOriginal) => ({
  ...(await importOriginal()),
  TutoringReportsService: {
    getActivityReport: vi.fn(),
    buildActivityReportPdfUrl: vi.fn(() => 'https://example.test/pdf'),
  },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {
    /* noop in tests */
  },
}));

/**
 * The DESTINATION's ability, not this page's.
 *
 * The report authorizes on `dashboard.admin.view`
 * (`AdminReportController::activity`); the sessions list authorizes on
 * `tutoring.session.view` (`SessionController::index`). They do not
 * nest — `tutoring.session.view` is also held by tutor / wali / siswa,
 * and a staff tier can hold either without the other — so reaching this
 * page proves nothing about the next one.
 */
let grantedAbilities: string[] = ['dashboard.admin.view', 'tutoring.session.view'];

const canSpy = vi.fn((ability: string) => grantedAbilities.includes(ability));

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({
    can: canSpy,
    canAny: (abilities: Iterable<string>) =>
      [...abilities].some((a) => grantedAbilities.includes(a)),
  }),
}));

const push = vi.fn();
vi.mock('vue-router', () => ({
  useRouter: () => ({ push, replace: vi.fn(), back: vi.fn() }),
  useRoute: () => ({ params: {}, query: {} }),
}));

/** A day WITH sessions — the drillable case. */
function busyDay(overrides = {}): ActivityReportRow {
  return {
    date: '2026-09-09',
    sessions_scheduled: 4,
    sessions_completed: 3,
    sessions_cancelled: 1,
    attendance_marked_count: 22,
    ...overrides,
  };
}

/**
 * A day with NOTHING on it.
 *
 * `sessions_scheduled` counts ANY session in the day's bucket
 * regardless of lifecycle state (completed and cancelled are subsets of
 * it), so zero there genuinely means the destination list would be
 * empty. The rollup emits a zero row for every day in the window, so
 * this is the COMMON case, not an edge one — a 30-day report over a
 * centre that runs weekdays has eight or nine of them.
 */
function emptyDay(overrides = {}): ActivityReportRow {
  return {
    date: '2026-09-13',
    sessions_scheduled: 0,
    sessions_completed: 0,
    sessions_cancelled: 0,
    attendance_marked_count: 0,
    ...overrides,
  };
}

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: {
      id: {
        tutoring2: {
          common: { date: 'Tanggal', loading: 'Memuat…', roleAdmin: 'Admin' },
          admin: {
            reports: {
              meta: '{count} baris',
              from: 'Dari',
              to: 'Sampai',
              downloadCsv: 'Unduh CSV',
              downloadPdf: 'Unduh PDF',
              activity: {
                title: 'Laporan Aktivitas',
                kpiScheduled: 'Sesi terjadwal',
                kpiCompleted: 'Sesi selesai',
                kpiCancelled: 'Sesi dibatalkan',
                kpiAttendance: 'Presensi tercatat',
                colScheduled: 'Terjadwal',
                colCompleted: 'Selesai',
                colCancelled: 'Dibatalkan',
                colAttendance: 'Presensi',
                emptyTitle: 'Belum ada aktivitas',
                emptyDesc: 'Tidak ada sesi atau presensi pada rentang tanggal ini.',
                // The real id.json values for the three keys this change adds.
                openDay: 'Lihat sesi pada tanggal ini',
                noSessionsThatDay: 'Tidak ada sesi pada tanggal ini',
                openDayForbidden: 'Anda tidak punya akses ke daftar sesi',
              },
            },
          },
        },
      },
    },
    missingWarn: false,
    fallbackWarn: false,
  });
}

/** Captures the `cards` prop so the KPI figures can be asserted. */
const KpiStub = {
  props: ['cards', 'loading'],
  template:
    '<div data-testid="kpi"><span v-for="c in (cards ?? [])" :key="c.label" data-testid="kpi-card">{{ c.label }}={{ c.value }}</span></div>',
};

async function mountView() {
  setActivePinia(createPinia());
  const w = mount(View, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: KpiStub,
        Button: { template: '<button><slot /></button>' },
        AsyncView: { props: ['state'], template: '<div data-testid="async"><slot /></div>' },
      },
    },
  });
  await flushPromises();
  return w;
}

function rows(w) {
  return w.findAll('[data-testid="activity-row"]');
}

/** The classes that ADVERTISE clickability. None may appear on an inert row. */
function looksClickable(row): boolean {
  const cls = row.attributes('class') ?? '';
  return cls.includes('cursor-pointer') || cls.includes('hover:bg-slate-50');
}

beforeEach(() => {
  vi.clearAllMocks();
  grantedAbilities = ['dashboard.admin.view', 'tutoring.session.view'];
  (TutoringReportsService.getActivityReport as any).mockResolvedValue({
    rows: [busyDay(), emptyDay()],
    meta: { from: '2026-09-01', to: '2026-09-30' },
  });
});

describe('AdminTutoring2ActivityReportView wire contract', () => {
  it('reads ActivityReportRow with per-day session totals', () => {
    const r: ActivityReportRow = busyDay();
    expect(r.date).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(r.sessions_scheduled).toBeGreaterThanOrEqual(r.sessions_completed);
  });
});

describe('AdminTutoring2ActivityReportView day row → that day’s sessions', () => {
  it('renders one row per day in the rollup', async () => {
    const w = await mountView();
    expect(rows(w)).toHaveLength(2);
  });

  it('clicking a day WITH sessions navigates somewhere — the click is not swallowed', async () => {
    const w = await mountView();

    await rows(w)[0].trigger('click');

    // The whole bug: the shipped rows had no @click, so this was 0.
    expect(push).toHaveBeenCalledTimes(1);
  });

  it('navigates to the sessions list narrowed to THAT day', async () => {
    const w = await mountView();

    await rows(w)[0].trigger('click');

    expect(push).toHaveBeenCalledWith({
      name: 'admin.tutoring2.schedule',
      query: { date: '2026-09-09' },
    });
  });

  it('opens from the keyboard too', async () => {
    const w = await mountView();

    // A <tr> is not focusable on its own and the row is the only control
    // here, so without tabindex + Enter the feature is mouse-only.
    expect(rows(w)[0].attributes('tabindex')).toBe('0');
    expect(rows(w)[0].attributes('role')).toBe('link');

    await rows(w)[0].trigger('keydown.enter');

    expect(push).toHaveBeenCalledTimes(1);
  });

  it('sends each row its OWN date, not the first row’s', async () => {
    (TutoringReportsService.getActivityReport as any).mockResolvedValue({
      rows: [busyDay(), busyDay({ date: '2026-09-10' }), busyDay({ date: '2026-09-11' })],
      meta: { from: '2026-09-01', to: '2026-09-30' },
    });
    const w = await mountView();

    await rows(w)[2].trigger('click');

    expect(push).toHaveBeenCalledWith({
      name: 'admin.tutoring2.schedule',
      query: { date: '2026-09-11' },
    });
  });
});

/**
 * The date must survive the hop as the SAME calendar day.
 *
 * This is the trap `local-date.ts` exists for: the row's `date` is
 * already the `YYYY-MM-DD` the backend bucketed on, and the moment
 * anything turns it into a `Date` and back through
 * `toISOString().slice(0, 10)` a WIB reader gets the previous day.
 * `new Date('2026-09-09')` is UTC midnight by spec — 07:00 WIB on the
 * 9th — and local midnight on the 9th in WIB is 17:00Z on the 8th.
 *
 * The premise (`getTimezoneOffset() === -420`) is asserted inside the
 * test so it cannot pass vacuously on a UTC CI runner, matching the
 * pattern already in `local-date.spec.ts`.
 */
describe('AdminTutoring2ActivityReportView date round-trip in WIB', () => {
  const REAL_TZ = process.env.TZ;
  afterEach(() => {
    process.env.TZ = REAL_TZ;
  });

  it('hands 2026-09-09 to the query as 2026-09-09 for a WIB admin', async () => {
    process.env.TZ = 'Asia/Jakarta';
    // Premise first — a UTC runner would make the conclusion meaningless.
    expect(new Date('2026-09-09T00:00:00Z').getTimezoneOffset()).toBe(-420);
    // And the trap itself, so the test documents what it is guarding:
    // local midnight on the 9th serialises through UTC as the 8th.
    expect(new Date(2026, 8, 9).toISOString().slice(0, 10)).toBe('2026-09-08');

    const w = await mountView();
    await rows(w)[0].trigger('click');

    expect(push.mock.calls[0][0].query.date).toBe('2026-09-09');
  });

  it('is correct in a NEGATIVE offset too, where the naive parse loses a day', async () => {
    process.env.TZ = 'America/New_York'; // UTC-4 in September
    const utcParsed = new Date('2026-09-09');
    expect(utcParsed.getTimezoneOffset()).toBe(240);
    expect(utcParsed.getDate()).toBe(8); // the trap: 8 Sep, not 9 Sep

    const w = await mountView();
    await rows(w)[0].trigger('click');

    expect(push.mock.calls[0][0].query.date).toBe('2026-09-09');
  });
});

/**
 * A row that cannot be opened must not LOOK like it can.
 *
 * This is the half that made the original complaint: the affordance was
 * unconditional. Fixing only the handler would leave the zero-session
 * rows — eight or nine out of thirty on a weekday-only centre — still
 * lighting up and still doing nothing.
 */
describe('AdminTutoring2ActivityReportView zero-session row is inert', () => {
  it('does not navigate when clicked', async () => {
    const w = await mountView();

    await rows(w)[1].trigger('click');
    await rows(w)[1].trigger('keydown.enter');

    expect(push).not.toHaveBeenCalled();
  });

  it('carries no hover, no pointer cursor, no tabindex and no link role', async () => {
    const w = await mountView();
    const inert = rows(w)[1];

    expect(looksClickable(inert)).toBe(false);
    expect(inert.attributes('tabindex')).toBeUndefined();
    expect(inert.attributes('role')).toBeUndefined();
    expect(inert.attributes('aria-label')).toBeUndefined();
  });

  it('says WHY, rather than being silently dead', async () => {
    const w = await mountView();

    expect(rows(w)[1].attributes('title')).toBe('Tidak ada sesi pada tanggal ini');
  });

  it('leaves the drillable sibling row fully clickable', async () => {
    const w = await mountView();

    expect(looksClickable(rows(w)[0])).toBe(true);
    expect(rows(w)[0].attributes('title')).toBe('Lihat sesi pada tanggal ini');
  });

  it('treats a day whose only sessions were cancelled as drillable', async () => {
    // `sessions_scheduled` counts every session in the bucket, so a day
    // of nothing-but-cancellations still HAS sessions to show. Keying
    // the gate off `sessions_completed` would wrongly kill it.
    (TutoringReportsService.getActivityReport as any).mockResolvedValue({
      rows: [busyDay({ sessions_scheduled: 2, sessions_completed: 0, sessions_cancelled: 2 })],
      meta: { from: '2026-09-01', to: '2026-09-30' },
    });
    const w = await mountView();

    await rows(w)[0].trigger('click');

    expect(push).toHaveBeenCalledTimes(1);
  });
});

/**
 * The gate is the DESTINATION's key.
 *
 * `dashboard.admin.view` got the reader onto this page; it says nothing
 * about `SessionController::index`, which authorizes on
 * `tutoring.session.view`. Without that key the drill-in must be
 * absent — inert AND unadvertised — rather than navigating into a 403.
 */
describe('AdminTutoring2ActivityReportView drill-in ability gate', () => {
  it('reads the grant off the /me snapshot via useMe().can', async () => {
    await mountView();

    expect(canSpy).toHaveBeenCalledWith('tutoring.session.view');
  });

  it('gates on the destination’s key, not the report’s own', async () => {
    // Holds the report's key and NOT the sessions key — the exact tier
    // that a `dashboard.admin.view` check would wrongly wave through.
    grantedAbilities = ['dashboard.admin.view'];
    const w = await mountView();

    await rows(w)[0].trigger('click');

    expect(push).not.toHaveBeenCalled();
  });

  it('shows no affordance on ANY row without tutoring.session.view', async () => {
    grantedAbilities = ['dashboard.admin.view'];
    const w = await mountView();

    // Asserted first: an empty list would make the loop below vacuous.
    expect(rows(w)).toHaveLength(2);
    for (const row of rows(w)) {
      expect(looksClickable(row)).toBe(false);
      expect(row.attributes('tabindex')).toBeUndefined();
      expect(row.attributes('role')).toBeUndefined();
    }
  });

  it('explains the refusal on a row that would otherwise be drillable', async () => {
    grantedAbilities = ['dashboard.admin.view'];
    const w = await mountView();

    expect(rows(w)[0].attributes('title')).toBe('Anda tidak punya akses ke daftar sesi');
  });
});

/**
 * The figures must not move.
 *
 * This block selects rows by MARKUP (`tbody tr`) rather than by the
 * `data-testid` this change introduces, precisely so it runs unchanged
 * against the shipped template — every test here is green before and
 * after, which is what makes it a baseline rather than a defect pin.
 * The change adds a way OUT of the table; if it ever starts changing
 * what the table SAYS, this block is what notices.
 */
function figureRows(w) {
  return w.findAll('[data-testid="async"] tbody tr');
}

describe('AdminTutoring2ActivityReportView figures are unchanged', () => {
  it('renders every per-day count the row carries, verbatim', async () => {
    const w = await mountView();
    const cells = figureRows(w)[0].findAll('td').map((c) => c.text());

    expect(cells).toEqual(['2026-09-09', '4', '3', '1', '22']);
  });

  it('renders the zero row as zeroes rather than dashes or blanks', async () => {
    const w = await mountView();
    const cells = figureRows(w)[1].findAll('td').map((c) => c.text());

    expect(cells).toEqual(['2026-09-13', '0', '0', '0', '0']);
  });

  it('totals the KPI strip across the whole range', async () => {
    (TutoringReportsService.getActivityReport as any).mockResolvedValue({
      rows: [busyDay(), busyDay({ date: '2026-09-10' }), emptyDay()],
      meta: { from: '2026-09-01', to: '2026-09-30' },
    });
    const w = await mountView();
    const kpis = w.findAll('[data-testid="kpi-card"]').map((c) => c.text());

    expect(kpis).toEqual([
      'Sesi terjadwal=8',
      'Sesi selesai=6',
      'Sesi dibatalkan=2',
      'Presensi tercatat=44',
    ]);
  });

  it('still asks the API for the range the pickers hold', async () => {
    await mountView();

    expect(TutoringReportsService.getActivityReport).toHaveBeenCalledTimes(1);
    const arg = (TutoringReportsService.getActivityReport as any).mock.calls[0][0];
    expect(arg.from).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(arg.to).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(arg.from <= arg.to).toBe(true);
  });

  it('keeps the KPI strip unmoved for a reader with no drill-in ability', async () => {
    // The gate hides a way OUT of the report; it must not redact the
    // report itself.
    grantedAbilities = ['dashboard.admin.view'];
    const w = await mountView();

    expect(w.findAll('[data-testid="kpi-card"]').map((c) => c.text())).toEqual([
      'Sesi terjadwal=4',
      'Sesi selesai=3',
      'Sesi dibatalkan=1',
      'Presensi tercatat=22',
    ]);
    expect(figureRows(w)[0].findAll('td').map((c) => c.text())).toEqual([
      '2026-09-09', '4', '3', '1', '22',
    ]);
  });
});
