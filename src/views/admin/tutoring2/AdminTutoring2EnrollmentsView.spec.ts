/**
 * Vitest contract spec for AdminTutoring2EnrollmentsView.
 *
 * Pins the Program filter chip, which shipped inert: the click handler
 * was `@click="programFilter = ''"`, i.e. it only ever CLEARED to the
 * "Semua" default and no menu existed behind it, so a bimbel admin on
 * prod reported "semua button/filter tdk berfungsi". The chip also
 * rendered `truncateId(programFilter)` — an id fragment — so even a
 * working filter would have read as gibberish.
 *
 * The Status and Billing-mode chips are two-value toggles
 * (`x = x ? '' : 'active'`); they DO change state and are deliberately
 * left as they are. The tests below therefore only touch Program.
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
import AdminTutoring2EnrollmentsView from './AdminTutoring2EnrollmentsView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listEnrollments: vi.fn(),
    listPrograms: vi.fn(),
  },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: (_fn: () => void) => {
    /* noop in tests */
  },
}));

function makeEnrollment(overrides = {}) {
  return {
    id: 'en-1',
    student_id: 'st-1',
    student_name: 'Aulia Rahma',
    student_number: '2026001',
    program_id: 'pr-1',
    program_name: 'Intensif UTBK',
    billing_mode: 'prepaid',
    billing_mode_label: 'Prabayar',
    status: 'active',
    status_label: 'Aktif',
    total_sessions_snapshot: 24,
    remaining_sessions: 18,
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
            billingMode: 'Skema bayar',
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
  const w = mount(AdminTutoring2EnrollmentsView, {
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
        // `disabled`, emits `click`.
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

/** Chips render in template order: status, program, billing mode. */
const CHIP = { status: 0, program: 1, billingMode: 2 };

function optionRows(w) {
  return w.findAll('[data-testid="facet-modal"] button');
}

function lastListEnrollmentsArg() {
  const calls = (TutoringBimbelService.listEnrollments as any).mock.calls;
  return calls[calls.length - 1][0];
}

describe('AdminTutoring2EnrollmentsView Program chip', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (TutoringBimbelService.listEnrollments as any).mockResolvedValue({
      items: [makeEnrollment()],
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

    expect(lastListEnrollmentsArg().program_id).toBe('pr-2');
    // The chip must read the NAME, never a UUID fragment.
    const chip = w.findAll('[data-testid="chip"]')[CHIP.program];
    expect(chip.text()).toBe('Reguler SMP');
    expect(chip.text()).not.toContain('pr-2');
  });

  it('the "Semua" row clears the filter back off the query', async () => {
    const w = await mountView();

    await w.findAll('[data-testid="chip"]')[CHIP.program].trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();
    expect(lastListEnrollmentsArg().program_id).toBe('pr-2');

    await w.findAll('[data-testid="chip"]')[CHIP.program].trigger('click');
    await optionRows(w)[0].trigger('click'); // "Semua"
    await flushPromises();

    expect(lastListEnrollmentsArg().program_id).toBeUndefined();
    expect(w.findAll('[data-testid="chip"]')[CHIP.program].text()).toBe('Semua');
  });

  it('an empty program list disables the chip but leaves the toggles alone', async () => {
    (TutoringBimbelService.listPrograms as any).mockResolvedValue({ items: [] });

    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips[CHIP.program].attributes('disabled')).toBeDefined();
    // Status / Billing mode do not depend on a fetch and must stay live.
    expect(chips[CHIP.status].attributes('disabled')).toBeUndefined();
    expect(chips[CHIP.billingMode].attributes('disabled')).toBeUndefined();
  });

  it('a failing program endpoint does not blank the other chips', async () => {
    (TutoringBimbelService.listPrograms as any).mockRejectedValue(new Error('403'));

    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips[CHIP.program].attributes('disabled')).toBeDefined();
    expect(chips[CHIP.status].attributes('disabled')).toBeUndefined();
    expect(chips[CHIP.billingMode].attributes('disabled')).toBeUndefined();
    // The list itself must still have loaded — an options failure is not
    // a data failure.
    expect(TutoringBimbelService.listEnrollments).toHaveBeenCalled();
  });
});
