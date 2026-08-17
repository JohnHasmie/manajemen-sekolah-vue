/**
 * Vitest contract spec for AdminTutoring2AssessmentsView.
 *
 * Pins the Program filter chip, which shipped inert: the click handler
 * was `@click="programFilter = ''"`, i.e. it only ever CLEARED to the
 * "Semua" default and no menu existed behind it, so a bimbel admin on
 * prod reported "semua button/filter tdk berfungsi". The chip also
 * rendered `truncateId(programFilter)` — an id fragment.
 *
 * Also pinned: the table's Program column rendered
 * `truncateId(a.program_id)` in a font-mono cell, while AssessmentResource
 * already exposes `program_name` (index eager-loads `program:id,name`).
 * The name must win.
 *
 * The Jenis and Status chips are two-value toggles; they DO change state
 * and are deliberately left as they are.
 *
 * The real <FilterFacetPickerModal> is mounted (only its <Modal> shell is
 * stubbed, because Modal teleports to body).
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2AssessmentsView from './AdminTutoring2AssessmentsView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listAssessments: vi.fn(),
    listPrograms: vi.fn(),
  },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: (_fn: () => void) => {
    /* noop in tests */
  },
}));

function makeAssessment(overrides = {}) {
  return {
    id: 'as-1',
    program_id: 'pr-1',
    program_name: 'Intensif UTBK',
    title: 'Tryout 3',
    kind: 'tryout',
    kind_label: 'Tryout',
    assessment_date: '2026-08-10',
    max_score: 100,
    published_at: '2026-08-11T09:00:00+07:00',
    scores_count: 21,
    ...overrides,
  };
}

const PROGRAMS = [
  { id: 'pr-1', name: 'Intensif UTBK', grade_level: '12', status: 'active' },
  { id: 'pr-2', name: 'Reguler SMP', grade_level: '8', status: 'active' },
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
            status: 'Status',
            kind: 'Jenis',
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
  const w = mount(AdminTutoring2AssessmentsView, {
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

/** Chips render in template order: kind, program, status. */
const CHIP = { kind: 0, program: 1, status: 2 };

function optionRows(w) {
  return w.findAll('[data-testid="facet-modal"] button');
}

function lastListAssessmentsArg() {
  const calls = (TutoringBimbelService.listAssessments as any).mock.calls;
  return calls[calls.length - 1][0];
}

describe('AdminTutoring2AssessmentsView Program chip', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (TutoringBimbelService.listAssessments as any).mockResolvedValue({
      items: [makeAssessment()],
      pagination: undefined,
    });
    (TutoringBimbelService.listPrograms as any).mockResolvedValue({ items: PROGRAMS });
  });

  it('loads the program option list on mount', async () => {
    await mountView();

    expect(TutoringBimbelService.listPrograms).toHaveBeenCalledTimes(1);
  });

  it('starts at "Semua" and is enabled once options arrive', async () => {
    const w = await mountView();
    const chip = w.findAll('[data-testid="chip"]')[CHIP.program];

    expect(chip.text()).toBe('Semua');
    expect(chip.attributes('disabled')).toBeUndefined();
  });

  it('clicking the chip OPENS a picker listing programs by name', async () => {
    const w = await mountView();
    // Nothing is open before the click — the old handler opened nothing.
    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(false);

    await w.findAll('[data-testid="chip"]')[CHIP.program].trigger('click');

    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(true);
    const labels = optionRows(w).map((b) => b.text());
    expect(labels[0]).toContain('Semua');
    expect(labels.join(' ')).toContain('Intensif UTBK');
    expect(labels.join(' ')).toContain('Reguler SMP');
  });

  it('picking a program re-queries with program_id and shows its name', async () => {
    const w = await mountView();
    await w.findAll('[data-testid="chip"]')[CHIP.program].trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();

    expect(lastListAssessmentsArg().program_id).toBe('pr-2');
    const chip = w.findAll('[data-testid="chip"]')[CHIP.program];
    expect(chip.text()).toBe('Reguler SMP');
    expect(chip.text()).not.toContain('pr-2');
  });

  it('the "Semua" row clears the filter back off the query', async () => {
    const w = await mountView();

    await w.findAll('[data-testid="chip"]')[CHIP.program].trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();
    expect(lastListAssessmentsArg().program_id).toBe('pr-2');

    await w.findAll('[data-testid="chip"]')[CHIP.program].trigger('click');
    await optionRows(w)[0].trigger('click'); // "Semua"
    await flushPromises();

    expect(lastListAssessmentsArg().program_id).toBeUndefined();
    expect(w.findAll('[data-testid="chip"]')[CHIP.program].text()).toBe('Semua');
  });

  it('an empty program list disables the chip but leaves the toggles alone', async () => {
    (TutoringBimbelService.listPrograms as any).mockResolvedValue({ items: [] });

    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips[CHIP.program].attributes('disabled')).toBeDefined();
    expect(chips[CHIP.kind].attributes('disabled')).toBeUndefined();
    expect(chips[CHIP.status].attributes('disabled')).toBeUndefined();
  });

  it('a failing program endpoint does not blank the other chips', async () => {
    (TutoringBimbelService.listPrograms as any).mockRejectedValue(new Error('403'));

    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips[CHIP.program].attributes('disabled')).toBeDefined();
    expect(chips[CHIP.kind].attributes('disabled')).toBeUndefined();
    expect(TutoringBimbelService.listAssessments).toHaveBeenCalled();
  });
});

describe('AdminTutoring2AssessmentsView Program column', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (TutoringBimbelService.listPrograms as any).mockResolvedValue({ items: PROGRAMS });
  });

  it('renders the program NAME the row already carries', async () => {
    (TutoringBimbelService.listAssessments as any).mockResolvedValue({
      items: [makeAssessment({ program_id: 'pr-aaaaaaaa-bbbb' })],
      pagination: undefined,
    });

    const w = await mountView();
    const row = w.find('[data-testid="async"] tbody tr').text();

    expect(row).toContain('Intensif UTBK');
    expect(row).not.toContain('pr-aaaaa');
  });

  it('resolves the name off the loaded option list when the row omits it', async () => {
    (TutoringBimbelService.listAssessments as any).mockResolvedValue({
      items: [makeAssessment({ program_name: null, program_id: 'pr-2' })],
      pagination: undefined,
    });

    const w = await mountView();

    expect(w.find('[data-testid="async"] tbody tr').text()).toContain('Reguler SMP');
  });

  it('falls back to an id fragment only when the program is in neither', async () => {
    (TutoringBimbelService.listAssessments as any).mockResolvedValue({
      items: [makeAssessment({ program_name: null, program_id: 'pr-gone-x' })],
      pagination: undefined,
    });

    const w = await mountView();

    expect(w.find('[data-testid="async"] tbody tr').text()).toContain('pr-gone');
  });
});
