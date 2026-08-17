/**
 * Vitest contract spec for AdminTutoring2GroupsView.
 *
 * Pins the Program / Term / Tutor filter chips, which shipped inert: the
 * click handler was `@click="programFilter = ''"`, i.e. it only ever
 * CLEARED to the "Semua" default and no menu existed behind it, so a
 * bimbel admin on prod reported "semua button/filter tdk berfungsi".
 * The chip also rendered `shortId(programFilter)` — an id fragment — so
 * even a working filter would have read as gibberish.
 *
 * Each test below fails against that old template:
 *
 *   1. opens a picker      — clicking a chip must OPEN an option list.
 *                            Old code opened nothing.
 *   2. program / term /    — picking an option must re-call listGroups
 *      tutor apply           with the matching id param, proving the
 *                            list actually narrows.
 *   3. names, not UUIDs    — the chip must read the option's NAME.
 *   4. "Semua" clears      — the reset row must drop the param again.
 *
 * The real <FilterFacetPickerModal> is mounted (only its <Modal> shell is
 * stubbed, because Modal teleports to body and would escape the wrapper);
 * the option rows clicked here are the ones an admin clicks.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2GroupsView from './AdminTutoring2GroupsView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringTermsService } from '@/services/tutoring2/terms';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listGroups: vi.fn(),
    listPrograms: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/terms', () => ({
  TutoringTermsService: { list: vi.fn() },
}));

vi.mock('@/services/tutoring2/tutors', () => ({
  TutoringTutorsService: { list: vi.fn() },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: (_fn: () => void) => {
    /* noop in tests */
  },
}));

vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: (_fn: () => void) => {
    /* noop in tests */
  },
}));

function makeGroup(overrides = {}) {
  return {
    id: 'gr-1',
    program_id: 'pr-1',
    program_name: 'Intensif UTBK',
    term_id: 'tm-1',
    term_name: 'Gelombang 1',
    tutor_id: 'tu-1',
    tutor_name: 'Pak Rahmat',
    name: 'UTBK Pagi A',
    kind: 'group',
    kind_label: 'Grup',
    capacity: 12,
    room: null,
    status: 'active',
    status_label: 'Aktif',
    seated_count: 8,
    ...overrides,
  };
}

const PROGRAMS = [
  { id: 'pr-1', name: 'Intensif UTBK', grade_level: '12', status: 'active' },
  { id: 'pr-2', name: 'Reguler SMP', grade_level: '8', status: 'active' },
];
const TERMS = [
  { id: 'tm-1', name: 'Gelombang 1', start_date: null, end_date: null, is_current: true, status: 'active', status_label: 'Aktif' },
  { id: 'tm-2', name: 'Gelombang 2', start_date: null, end_date: null, is_current: false, status: 'draft', status_label: 'Draf' },
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
            program: 'Program',
            term: 'Term',
            tutor: 'Tutor',
            gradeLevel: 'Jenjang',
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
  const w = mount(AdminTutoring2GroupsView, {
    global: {
      plugins: [i18n],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        PageFilterToolbar: {
          template: '<div data-testid="toolbar"><slot name="chips" /></div>',
        },
        // Mirrors the real chip's contract: renders `value`, honours
        // `disabled`, emits `click`. Keeping `value` in the DOM is what
        // lets the "names, not UUIDs" assertions read the chip.
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
        // FilterFacetPickerModal is NOT stubbed — only the Modal shell it
        // renders into, because Modal teleports to body.
        Modal: { template: '<div data-testid="facet-modal"><slot /></div>' },
        Button: { template: '<button><slot /></button>' },
      },
    },
  });
  await flushPromises();
  return w;
}

/** Chips render in template order: program, term, tutor. */
const CHIP = { program: 0, term: 1, tutor: 2 };

function optionRows(w) {
  return w.findAll('[data-testid="facet-modal"] button');
}

function lastListGroupsArg() {
  const calls = (TutoringBimbelService.listGroups as any).mock.calls;
  return calls[calls.length - 1][0];
}

describe('AdminTutoring2GroupsView filter chips', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (TutoringBimbelService.listGroups as any).mockResolvedValue({
      items: [makeGroup()],
      pagination: undefined,
    });
    (TutoringBimbelService.listPrograms as any).mockResolvedValue({ items: PROGRAMS });
    (TutoringTermsService.list as any).mockResolvedValue({ items: TERMS });
    (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
  });

  it('loads all three option lists on mount', async () => {
    await mountView();

    expect(TutoringBimbelService.listPrograms).toHaveBeenCalledTimes(1);
    expect(TutoringTermsService.list).toHaveBeenCalledTimes(1);
    expect(TutoringTutorsService.list).toHaveBeenCalledTimes(1);
  });

  it('chips start at "Semua" and are enabled once options arrive', async () => {
    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips).toHaveLength(3);
    for (const chip of chips) {
      expect(chip.text()).toBe('Semua');
      expect(chip.attributes('disabled')).toBeUndefined();
    }
  });

  it('clicking a chip OPENS a picker listing the options by name', async () => {
    const w = await mountView();
    // Nothing is open before the click — this is the regression: the old
    // handler set the filter to '' and opened nothing at all.
    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(false);

    await w.findAll('[data-testid="chip"]')[CHIP.program].trigger('click');

    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(true);
    const labels = optionRows(w).map((b) => b.text());
    // "Semua" reset row + one row per program, by NAME.
    expect(labels[0]).toContain('Semua');
    expect(labels.join(' ')).toContain('Intensif UTBK');
    expect(labels.join(' ')).toContain('Reguler SMP');
  });

  it('picking a program re-queries with program_id and shows its name', async () => {
    const w = await mountView();
    await w.findAll('[data-testid="chip"]')[CHIP.program].trigger('click');

    // Row 0 is the "Semua" reset; row 2 is the second program.
    await optionRows(w)[2].trigger('click');
    await flushPromises();

    expect(lastListGroupsArg().program_id).toBe('pr-2');
    // The chip must read the NAME, never a UUID fragment.
    const chip = w.findAll('[data-testid="chip"]')[CHIP.program];
    expect(chip.text()).toBe('Reguler SMP');
    expect(chip.text()).not.toContain('pr-2');
  });

  it('picking a term re-queries with term_id and shows its name', async () => {
    const w = await mountView();
    await w.findAll('[data-testid="chip"]')[CHIP.term].trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();

    expect(lastListGroupsArg().term_id).toBe('tm-2');
    expect(w.findAll('[data-testid="chip"]')[CHIP.term].text()).toBe('Gelombang 2');
  });

  it('picking a tutor re-queries with tutor_id and shows their name', async () => {
    const w = await mountView();
    await w.findAll('[data-testid="chip"]')[CHIP.tutor].trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();

    expect(lastListGroupsArg().tutor_id).toBe('tu-2');
    expect(w.findAll('[data-testid="chip"]')[CHIP.tutor].text()).toBe('Bu Sinta');
  });

  it('the "Semua" row clears the filter back off the query', async () => {
    const w = await mountView();

    await w.findAll('[data-testid="chip"]')[CHIP.program].trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();
    expect(lastListGroupsArg().program_id).toBe('pr-2');

    await w.findAll('[data-testid="chip"]')[CHIP.program].trigger('click');
    await optionRows(w)[0].trigger('click'); // "Semua"
    await flushPromises();

    expect(lastListGroupsArg().program_id).toBeUndefined();
    expect(w.findAll('[data-testid="chip"]')[CHIP.program].text()).toBe('Semua');
  });

  it('a facet whose list came back empty disables its own chip only', async () => {
    (TutoringTutorsService.list as any).mockResolvedValue({ items: [] });

    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips[CHIP.tutor].attributes('disabled')).toBeDefined();
    // The other two must stay usable — one dead endpoint must not take
    // the whole toolbar down with it.
    expect(chips[CHIP.program].attributes('disabled')).toBeUndefined();
    expect(chips[CHIP.term].attributes('disabled')).toBeUndefined();
  });

  it('one failing option endpoint does not blank the other two chips', async () => {
    (TutoringTermsService.list as any).mockRejectedValue(new Error('403'));

    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips[CHIP.term].attributes('disabled')).toBeDefined();
    expect(chips[CHIP.program].attributes('disabled')).toBeUndefined();
    expect(chips[CHIP.tutor].attributes('disabled')).toBeUndefined();
  });
});
