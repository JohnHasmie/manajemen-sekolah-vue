/**
 * Vitest contract spec for AdminTutoring2AttendanceView.
 *
 * Pins the Kelompok / Tutor filter chips, which shipped inert: the click
 * handler was `@click="groupFilter = ''"`, i.e. it only ever CLEARED to
 * the "Semua" default and no menu existed behind it, so a bimbel admin
 * on prod reported "semua button/filter tdk berfungsi". Both chips also
 * rendered `truncateId(...)` — an id fragment.
 *
 * Also pinned: the Sesi column rendered `truncateId(s.learning_group_id)`
 * while `learning_group_name` was already on the same row.
 *
 * The KPI tiles are covered separately by the existing suite; this spec
 * deliberately touches only the toolbar and the row label.
 *
 * The real <FilterFacetPickerModal> is mounted (only its <Modal> shell is
 * stubbed, because Modal teleports to body).
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
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

function makeSession(overrides = {}) {
  return {
    id: 'se-1',
    learning_group_id: 'gr-1',
    learning_group_name: 'UTBK Pagi A',
    tutor_id: 'tu-1',
    tutor_name: 'Pak Rahmat',
    starts_at: '2026-08-17T08:00:00+07:00',
    ends_at: '2026-08-17T10:00:00+07:00',
    room: 'R1',
    status: 'done',
    status_label: 'Selesai',
    attendances_count: 10,
    attendances_present_count: 9,
    ...overrides,
  };
}

const GROUPS = [
  { id: 'gr-1', program_id: 'pr-1', program_name: 'Intensif UTBK', name: 'UTBK Pagi A', kind: 'group', capacity: 12, status: 'active' },
  { id: 'gr-2', program_id: 'pr-2', program_name: 'Reguler SMP', name: 'SMP Sore B', kind: 'group', capacity: 10, status: 'active' },
];
const TUTORS = [
  { id: 'tu-1', user_id: 'us-1', name: 'Pak Rahmat', is_active: true, active_group_count: 2 },
  { id: 'tu-2', user_id: 'us-2', name: 'Bu Sinta', is_active: true, active_group_count: 1 },
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
            date: 'Tanggal',
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
  const i18n = makeI18n();
  const w = mount(AdminTutoring2AttendanceView, {
    global: {
      plugins: [i18n],
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
        Modal: { template: '<div data-testid="facet-modal"><slot /></div>' },
        Button: { template: '<button><slot /></button>' },
      },
    },
  });
  await flushPromises();
  return w;
}

/** Chips render in template order: date, group, tutor. */
const CHIP = { date: 0, group: 1, tutor: 2 };

function optionRows(w) {
  return w.findAll('[data-testid="facet-modal"] button');
}

function lastListSessionsArg() {
  const calls = (TutoringBimbelService.listSessions as any).mock.calls;
  return calls[calls.length - 1][0];
}

describe('AdminTutoring2AttendanceView filter chips', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (TutoringBimbelService.listSessions as any).mockResolvedValue({
      items: [makeSession()],
      pagination: undefined,
    });
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
  });

  it('loads both option lists on mount', async () => {
    await mountView();

    expect(TutoringBimbelService.listGroups).toHaveBeenCalledTimes(1);
    expect(TutoringTutorsService.list).toHaveBeenCalledTimes(1);
  });

  it('the id-valued chips start at "Semua" and are enabled once options arrive', async () => {
    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    for (const i of [CHIP.group, CHIP.tutor]) {
      expect(chips[i].text()).toBe('Semua');
      expect(chips[i].attributes('disabled')).toBeUndefined();
    }
  });

  it('clicking the Kelompok chip OPENS a picker listing groups by name', async () => {
    const w = await mountView();
    // Nothing is open before the click — the old handler opened nothing.
    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(false);

    await w.findAll('[data-testid="chip"]')[CHIP.group].trigger('click');

    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(true);
    const labels = optionRows(w).map((b) => b.text());
    expect(labels[0]).toContain('Semua');
    expect(labels.join(' ')).toContain('UTBK Pagi A');
    expect(labels.join(' ')).toContain('SMP Sore B');
  });

  it('picking a group re-queries with learning_group_id and shows its name', async () => {
    const w = await mountView();
    await w.findAll('[data-testid="chip"]')[CHIP.group].trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();

    expect(lastListSessionsArg().learning_group_id).toBe('gr-2');
    const chip = w.findAll('[data-testid="chip"]')[CHIP.group];
    expect(chip.text()).toBe('SMP Sore B');
    expect(chip.text()).not.toContain('gr-2');
  });

  it('picking a tutor re-queries with tutor_id and shows their name', async () => {
    const w = await mountView();
    await w.findAll('[data-testid="chip"]')[CHIP.tutor].trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();

    expect(lastListSessionsArg().tutor_id).toBe('tu-2');
    expect(w.findAll('[data-testid="chip"]')[CHIP.tutor].text()).toBe('Bu Sinta');
  });

  it('the "Semua" row clears the filter back off the query', async () => {
    const w = await mountView();

    await w.findAll('[data-testid="chip"]')[CHIP.tutor].trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();
    expect(lastListSessionsArg().tutor_id).toBe('tu-2');

    await w.findAll('[data-testid="chip"]')[CHIP.tutor].trigger('click');
    await optionRows(w)[0].trigger('click'); // "Semua"
    await flushPromises();

    expect(lastListSessionsArg().tutor_id).toBeUndefined();
    expect(w.findAll('[data-testid="chip"]')[CHIP.tutor].text()).toBe('Semua');
  });

  it('a facet whose list came back empty disables its own chip only', async () => {
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: [] });

    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips[CHIP.group].attributes('disabled')).toBeDefined();
    expect(chips[CHIP.tutor].attributes('disabled')).toBeUndefined();
  });

  it('one failing option endpoint does not blank the other chip', async () => {
    (TutoringTutorsService.list as any).mockRejectedValue(new Error('403'));

    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips[CHIP.tutor].attributes('disabled')).toBeDefined();
    expect(chips[CHIP.group].attributes('disabled')).toBeUndefined();
  });
});

describe('AdminTutoring2AttendanceView row label', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
  });

  it('names the session by its group NAME, not the id', async () => {
    (TutoringBimbelService.listSessions as any).mockResolvedValue({
      items: [makeSession({ learning_group_id: 'gr-aaaaaaaa-bbbb' })],
      pagination: undefined,
    });

    const w = await mountView();
    const row = w.find('[data-testid="async"] tbody tr').text();

    expect(row).toContain('UTBK Pagi A');
    expect(row).not.toContain('gr-aaaaa');
  });

  it('falls back to an id fragment only when the row carries no name', async () => {
    (TutoringBimbelService.listSessions as any).mockResolvedValue({
      items: [makeSession({ learning_group_name: null })],
      pagination: undefined,
    });

    const w = await mountView();

    expect(w.find('[data-testid="async"] tbody tr').text()).toContain('gr-1');
  });
});
