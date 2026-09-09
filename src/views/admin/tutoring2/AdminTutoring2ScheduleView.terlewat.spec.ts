/**
 * "Terlewat" as the admin schedule actually renders it.
 *
 * `bimbel-session-status.spec.ts` pins the derivation as a pure
 * function. This file pins the three things that spec cannot see,
 * because they are properties of the SCREEN:
 *
 *   1. The row badge really shows Terlewat — the derived label survives
 *      the `status_label` the wire sent, all the way to the DOM. Every
 *      fixture below carries `status_label: 'Terjadwal'` precisely so
 *      that a regression to wire-first precedence fails here rather than
 *      shipping a screen where nothing visibly changed.
 *   2. The KPI counters are unmoved. They count the WIRE status, so a
 *      missed session is still counted under "Terjadwal". Splitting it
 *      out would be a different product decision, and doing it by
 *      accident would make the tiles stop summing to the row count.
 *   3. The filter still speaks the wire. The picker offers exactly the
 *      four real statuses, and choosing "Terjadwal" queries
 *      `status: 'scheduled'` — the value the API accepts.
 *
 * ── Anti-vacuity notes ──
 *
 * • TZ is pinned to Asia/Jakarta and the premise is asserted
 *   (`getTimezoneOffset() === -420`, and the fixtures' WIB wall-clock
 *   hours) before any conclusion. On a UTC runner these fail loudly
 *   instead of the file passing for the wrong reason.
 * • The clock is faked to a fixed instant, so "past" and "future" are
 *   properties of the fixtures rather than of the day CI happens to run.
 * • `StatusBadge` is stubbed as a REAL element carrying its label and
 *   tone as attributes, so the assertions read the rendered output
 *   rather than reaching into component internals.
 * • The Terjadwal and Dibatalkan rows are asserted alongside the
 *   Terlewat one: a helper that returned "Terlewat" unconditionally
 *   would satisfy a lone positive assertion.
 */
import {
  afterAll,
  afterEach,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
  vi,
} from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2ScheduleView from './AdminTutoring2ScheduleView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';

vi.mock('@/services/tutoring-bimbel.service', async (importOriginal) => ({
  ...(await importOriginal<
    typeof import('@/services/tutoring-bimbel.service')
  >()),
  TutoringBimbelService: {
    listSessions: vi.fn(),
    listGroups: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/tutors', () => ({
  TutoringTutorsService: { list: vi.fn() },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({
    can: () => true,
    canAny: () => true,
  }),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn(), back: vi.fn() }),
  useRoute: () => ({ params: {}, query: {} }),
}));

/**
 * 09:00 WIB on 9 Sep 2026 — the instant every "now" in this file means.
 * Chosen so one fixture ends before it and one after it ON THE SAME
 * LOCAL DAY, which is the case a UTC day comparison gets wrong.
 */
const NOW_ISO = '2026-09-09T09:00:00+07:00';

/** Ended 08:00 WIB, an hour before NOW. Nobody marked it. */
const PAST = {
  id: 'se-past',
  learning_group_id: 'gr-1',
  learning_group_name: 'UTBK Pagi A',
  tutor_id: 'tu-1',
  tutor_name: 'Pak Rahmat',
  starts_at: '2026-09-09T06:00:00+07:00',
  ends_at: '2026-09-09T08:00:00+07:00',
  room: 'R1',
  status: 'scheduled',
  status_label: 'Terjadwal',
};

/** Ends 21:00 WIB — the same local day, still ahead of NOW. */
const FUTURE = {
  ...PAST,
  id: 'se-future',
  learning_group_name: 'UTBK Sore B',
  starts_at: '2026-09-09T19:00:00+07:00',
  ends_at: '2026-09-09T21:00:00+07:00',
  status: 'scheduled',
  status_label: 'Terjadwal',
};

/** Past AND cancelled — the reason it did not happen is on the record. */
const PAST_CANCELLED = {
  ...PAST,
  id: 'se-cancelled',
  learning_group_name: 'UTBK Batal',
  status: 'cancelled',
  status_label: 'Dibatalkan',
};

const ROWS = [PAST, FUTURE, PAST_CANCELLED];

const GROUPS = [
  {
    id: 'gr-1',
    program_id: 'pr-1',
    program_name: 'Intensif UTBK',
    name: 'UTBK Pagi A',
    kind: 'group',
    capacity: 12,
    status: 'active',
  },
];

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
            group: 'Kelompok',
            tutor: 'Tutor',
            status: 'Status',
            period: 'Periode',
            loading: 'Memuat…',
            metaSessionsWeek: '{count} sesi',
          },
          // The real id.json values, `missed` included.
          status: {
            scheduled: 'Terjadwal',
            missed: 'Terlewat',
            inProgress: 'Berlangsung',
            done: 'Selesai',
            cancelled: 'Dibatalkan',
          },
          admin: {
            schedule: {
              kpiScheduled: 'Terjadwal',
              kpiInProgress: 'Berlangsung',
              kpiDone: 'Selesai',
              kpiCancelled: 'Dibatalkan',
            },
          },
        },
      },
    },
    missingWarn: false,
    fallbackWarn: false,
  });
}

async function mountView() {
  setActivePinia(createPinia());
  const w = mount(AdminTutoring2ScheduleView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: true,
        // Renders each tile as `label=value`, so the counters are
        // observable in the DOM rather than through component internals.
        KpiStripCards: {
          props: ['cards', 'loading'],
          template:
            '<div data-testid="kpis"><span v-for="c in cards" :key="c.label" data-testid="kpi">{{ c.label }}={{ c.value }}</span></div>',
        },
        // A real element carrying label + tone as attributes.
        StatusBadge: {
          props: ['label', 'tone', 'uppercase', 'dot'],
          template:
            '<span data-testid="status-badge" :data-tone="tone">{{ label }}</span>',
        },
        PageFilterToolbar: {
          template: '<div data-testid="toolbar"><slot name="chips" /></div>',
        },
        AppFilterChip: {
          props: ['label', 'value', 'iconName', 'active', 'disabled'],
          emits: ['click'],
          template:
            '<button data-testid="chip" @click="$emit(\'click\')">{{ value }}</button>',
        },
        AsyncView: {
          props: ['state'],
          template:
            '<div data-testid="async"><slot :data="state?.data ?? []" /></div>',
        },
        Modal: { template: '<div data-testid="facet-modal"><slot /></div>' },
        Button: { template: '<button><slot /></button>' },
      },
    },
  });
  await flushPromises();
  return w;
}

const REAL_TZ = process.env.TZ;

beforeAll(() => {
  process.env.TZ = 'Asia/Jakarta';
});
afterAll(() => {
  process.env.TZ = REAL_TZ;
});

beforeEach(() => {
  vi.clearAllMocks();
  vi.useFakeTimers();
  vi.setSystemTime(new Date(NOW_ISO));
  (TutoringBimbelService.listSessions as any).mockResolvedValue({
    items: ROWS,
    meta: { current_page: 1, last_page: 1, per_page: 25, total: ROWS.length },
  });
  (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
  // Resolved, not left undefined: the view reads `.items` off both facet
  // responses, and an unresolved mock surfaces as an unhandled rejection
  // that the runner counts as an error even while the tests pass.
  (TutoringTutorsService.list as any).mockResolvedValue({ items: [] });
});

afterEach(() => {
  vi.useRealTimers();
});

describe('AdminTutoring2ScheduleView — Terlewat', () => {
  it('pins the WIB premise the fixtures rest on', () => {
    // Fails on a UTC runner (which would read 08 / 01 / 14) rather than
    // letting every assertion below pass for the wrong reason.
    expect(new Date().getTimezoneOffset()).toBe(-420);
    expect(new Date(NOW_ISO).getHours()).toBe(9);
    expect(new Date(PAST.ends_at).getHours()).toBe(8);
    expect(new Date(FUTURE.ends_at).getHours()).toBe(21);
    // Both fixtures sit on the SAME local day as `now` — so nothing here
    // could be decided by comparing calendar days.
    expect(new Date(PAST.ends_at).getDate()).toBe(9);
    expect(new Date(FUTURE.ends_at).getDate()).toBe(9);
  });

  it('renders Terlewat, Terjadwal and Dibatalkan on the right rows', async () => {
    const w = await mountView();
    const badges = w.findAll('[data-testid="status-badge"]');
    expect(badges).toHaveLength(3);

    // Row order follows the fixture order the service returned.
    expect(badges[0].text()).toBe('Terlewat'); // past + scheduled
    expect(badges[1].text()).toBe('Terjadwal'); // future + scheduled
    expect(badges[2].text()).toBe('Dibatalkan'); // past + cancelled

    // The wire said "Terjadwal" for the first row. The derived label
    // overriding it is the whole point.
    expect(PAST.status_label).toBe('Terjadwal');
  });

  it('gives the Terlewat row the warning tone and leaves the others alone', async () => {
    const w = await mountView();
    const tones = w
      .findAll('[data-testid="status-badge"]')
      .map((b) => b.attributes('data-tone'));
    expect(tones).toEqual(['warning', 'neutral', 'danger']);
  });

  it('leaves the KPI counters counting the WIRE status', async () => {
    const w = await mountView();
    const kpis = w.findAll('[data-testid="kpi"]').map((k) => k.text());

    // Two `scheduled` rows — the missed one is still one of them.
    expect(kpis).toContain('Terjadwal=2');
    expect(kpis).toContain('Dibatalkan=1');
    expect(kpis).toContain('Berlangsung=0');
    expect(kpis).toContain('Selesai=0');

    // No tile was added, and none of them counts "Terlewat".
    expect(kpis).toHaveLength(4);
    expect(kpis.some((k) => k.startsWith('Terlewat'))).toBe(false);
  });

  it('offers only the four wire statuses in the filter picker', async () => {
    const w = await mountView();
    await w.findAll('[data-testid="chip"]')[0].trigger('click');
    await flushPromises();

    const options = w
      .findAll('[data-testid="facet-modal"] button')
      .map((b) => b.text());

    expect(options).toContain('Terjadwal');
    expect(options).toContain('Berlangsung');
    expect(options).toContain('Selesai');
    expect(options).toContain('Dibatalkan');
    // A display-only state must never become a filterable one: the API
    // would reject `status=missed`, so the row would silently return
    // nothing.
    expect(options).not.toContain('Terlewat');
    expect(options.join(' ')).not.toContain('missed');
  });

  it('still queries the wire value when Terjadwal is picked', async () => {
    const w = await mountView();
    await w.findAll('[data-testid="chip"]')[0].trigger('click');
    await flushPromises();

    const terjadwal = w
      .findAll('[data-testid="facet-modal"] button')
      .find((b) => b.text() === 'Terjadwal');
    expect(terjadwal).toBeTruthy();
    await terjadwal!.trigger('click');
    await flushPromises();

    const calls = (TutoringBimbelService.listSessions as any).mock.calls;
    expect(calls[calls.length - 1][0]).toMatchObject({ status: 'scheduled' });
  });
});
