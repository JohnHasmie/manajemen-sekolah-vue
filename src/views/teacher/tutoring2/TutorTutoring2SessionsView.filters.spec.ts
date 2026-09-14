/**
 * Contract spec for the Status + Periode filters on the tutor's Jadwal
 * screen — the two controls a tutor reported as "tidak memunculkan
 * dropdown list pilihan filter yang dapat dipilih".
 *
 * Both chips used to be wired straight to a `cycle*()` handler, so:
 *
 *   • nothing ever LISTED the options — one press just advanced to the
 *     next value in a hardcoded order, and the only way to learn what
 *     the filter could be was to keep pressing;
 *   • `in_progress` was absent from that order entirely, even though it
 *     is one of the four `BimbelSession['status']` values the API
 *     returns and the `status` parameter accepts. It was unreachable at
 *     any number of presses.
 *
 * Every test below fails against that old template. The picker is
 * mounted FOR REAL (only <Modal>'s shell is stubbed, because it
 * teleports to body and would escape the wrapper), so the rows clicked
 * here are the rows a tutor clicks.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import SessionsView from './TutorTutoring2SessionsView.vue';
import {
  BIMBEL_SESSION_STATUSES,
  TutoringBimbelService,
} from '@/services/tutoring-bimbel.service';

/**
 * `importOriginal` keeps the module's real value exports — notably
 * BIMBEL_SESSION_STATUSES, which is both what the view builds its
 * picker from and what this spec asserts completeness against. A
 * hand-written copy here would let the picker and the wire union drift
 * apart and still go green, which is the exact failure being fixed.
 */
vi.mock('@/services/tutoring-bimbel.service', async (importOriginal) => ({
  ...(await importOriginal<object>()),
  TutoringBimbelService: { listSessions: vi.fn() },
}));
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
  useRoute: () => ({ params: {}, query: {} }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));

/** Fixed clock so the "next 7 days" window is deterministic. */
const NOW = new Date('2026-09-14T09:00:00+07:00');

function isoInDays(days: number): string {
  return new Date(NOW.getTime() + days * 24 * 3600 * 1000).toISOString();
}

function makeSession(overrides: Record<string, unknown> = {}) {
  return {
    id: 'ses-1',
    learning_group_id: '01a00e34-dead-beef',
    learning_group_name: 'UTBK Pagi A',
    starts_at: isoInDays(1),
    ends_at: isoInDays(1),
    room: 'R1',
    status: 'scheduled',
    ...overrides,
  };
}

const messages = {
  id: {
    tutoring2: {
      common: {
        all: 'Semua',
        status: 'Status',
        period: 'Periode',
        group: 'Kelompok',
        next7Days: '7 hari ke depan',
        next30Days: '30 hari ke depan',
      },
      status: {
        scheduled: 'Terjadwal',
        inProgress: 'Berlangsung',
        done: 'Selesai',
        cancelled: 'Dibatalkan',
        missed: 'Terlewat',
      },
    },
  },
};

const ToolbarStub = {
  props: ['search', 'searchPlaceholder'],
  emits: ['update:search'],
  template: '<div><slot name="chips" /></div>',
};

async function mountView(items: unknown[] = [makeSession()]) {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listSessions).mockResolvedValue({
    items,
  } as never);

  const w = mount(SessionsView, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          messages,
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        PageFilterToolbar: ToolbarStub,
        Button: { template: '<button v-bind="$attrs"><slot /></button>' },
        // Real <FilterFacetPickerModal>; only the teleporting shell goes.
        Modal: { template: '<div class="modal"><slot /></div>' },
        AsyncView: {
          props: ['state'],
          template:
            '<div data-testid="async">' +
            "<slot v-if=\"state?.status === 'content' || state?.status === 'empty'\" />" +
            '</div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

/** The two toolbar chips, in template order: [Status, Periode]. */
function chips(w: any) {
  return w.findAll('button.inline-flex');
}

/** Option rows inside the open picker — "Semua" first, then the facets. */
function optionRows(w: any) {
  return w.findAll('.modal button');
}

function rowLabels(w: any): string[] {
  return optionRows(w).map((b: any) => b.text());
}

function lastStatusParam(): unknown {
  const calls = vi.mocked(TutoringBimbelService.listSessions).mock.calls;
  return (calls[calls.length - 1]?.[0] as { status?: unknown })?.status;
}

beforeEach(() => {
  vi.clearAllMocks();
  vi.useFakeTimers();
  vi.setSystemTime(NOW);
});

describe('TutorTutoring2SessionsView — Status filter', () => {
  it('opens a picker listing EVERY status the wire accepts', async () => {
    const w = await mountView();
    // Nothing is open until the chip is pressed.
    expect(optionRows(w)).toHaveLength(0);

    await chips(w)[0].trigger('click');

    const labels = rowLabels(w);
    expect(labels[0]).toBe('Semua');
    expect(labels).toEqual([
      'Semua',
      'Terjadwal',
      'Berlangsung',
      'Selesai',
      'Dibatalkan',
    ]);
    // One row per wire status, so the picker cannot silently lose one.
    expect(labels).toHaveLength(BIMBEL_SESSION_STATUSES.length + 1);
  });

  it.each(BIMBEL_SESSION_STATUSES)(
    'selecting %s actually asks the server for it',
    async (status) => {
      const w = await mountView();
      await chips(w)[0].trigger('click');

      const row = optionRows(w).find(
        (b: any) =>
          b.text() ===
          {
            scheduled: 'Terjadwal',
            in_progress: 'Berlangsung',
            done: 'Selesai',
            cancelled: 'Dibatalkan',
          }[status],
      );
      expect(row).toBeTruthy();
      await row!.trigger('click');
      await flushPromises();

      expect(lastStatusParam()).toBe(status);
    },
  );

  it('reaches in_progress, which the old cycle order omitted', async () => {
    const w = await mountView();
    await chips(w)[0].trigger('click');
    const row = optionRows(w).find((b: any) => b.text() === 'Berlangsung');
    await row!.trigger('click');
    await flushPromises();

    expect(lastStatusParam()).toBe('in_progress');
    // and the chip reads the LABEL, never the wire token
    expect(chips(w)[0].text()).toContain('Berlangsung');
    expect(chips(w)[0].text()).not.toContain('in_progress');
  });

  it('"Semua" drops the status parameter again', async () => {
    const w = await mountView();
    await chips(w)[0].trigger('click');
    await optionRows(w)
      .find((b: any) => b.text() === 'Selesai')!
      .trigger('click');
    await flushPromises();
    expect(lastStatusParam()).toBe('done');

    await chips(w)[0].trigger('click');
    await optionRows(w)
      .find((b: any) => b.text() === 'Semua')!
      .trigger('click');
    await flushPromises();
    expect(lastStatusParam()).toBeUndefined();
  });

  it('does not offer Terlewat — the wire has no such value to ask for', async () => {
    const w = await mountView();
    await chips(w)[0].trigger('click');
    // Guard against a vacuous pass: the picker must actually be open.
    expect(rowLabels(w).length).toBeGreaterThan(1);
    expect(rowLabels(w)).not.toContain('Terlewat');
  });
});

describe('TutorTutoring2SessionsView — Periode filter', () => {
  const near = makeSession({ id: 'near', starts_at: isoInDays(2), ends_at: isoInDays(2) });
  const far = makeSession({ id: 'far', starts_at: isoInDays(20), ends_at: isoInDays(20) });

  it('opens a picker listing both windows', async () => {
    const w = await mountView([near, far]);
    await chips(w)[1].trigger('click');
    expect(rowLabels(w)).toEqual([
      'Semua',
      '7 hari ke depan',
      '30 hari ke depan',
    ]);
  });

  it('picking "7 hari ke depan" actually narrows the list', async () => {
    const w = await mountView([near, far]);
    expect(w.findAll('[data-testid="async"] li')).toHaveLength(2);

    await chips(w)[1].trigger('click');
    await optionRows(w)
      .find((b: any) => b.text() === '7 hari ke depan')!
      .trigger('click');
    await flushPromises();

    const rows = w.findAll('[data-testid="async"] li');
    expect(rows).toHaveLength(1);
    expect(rows[0].text()).toContain('UTBK Pagi A');
    expect(chips(w)[1].text()).toContain('7 hari ke depan');
  });

  it('picking "30 hari ke depan" keeps the far session', async () => {
    const w = await mountView([near, far]);
    await chips(w)[1].trigger('click');
    await optionRows(w)
      .find((b: any) => b.text() === '30 hari ke depan')!
      .trigger('click');
    await flushPromises();
    expect(w.findAll('[data-testid="async"] li')).toHaveLength(2);
  });

  it('"Semua" restores the unfiltered list', async () => {
    const w = await mountView([near, far]);
    await chips(w)[1].trigger('click');
    await optionRows(w)
      .find((b: any) => b.text() === '7 hari ke depan')!
      .trigger('click');
    await flushPromises();
    expect(w.findAll('[data-testid="async"] li')).toHaveLength(1);

    await chips(w)[1].trigger('click');
    await optionRows(w)
      .find((b: any) => b.text() === 'Semua')!
      .trigger('click');
    await flushPromises();
    expect(w.findAll('[data-testid="async"] li')).toHaveLength(2);
  });
});
