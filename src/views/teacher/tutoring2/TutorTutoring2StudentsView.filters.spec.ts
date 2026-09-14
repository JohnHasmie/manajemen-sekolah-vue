/**
 * Contract spec for the Status + Program chips on the tutor's "Siswa
 * saya" screen.
 *
 * Status shipped as a blind six-step cycle — nothing ever listed the
 * options, the same defect a tutor reported on the Jadwal screen.
 *
 * Program shipped NOMINAL, which is worse: `programFilter` reached no
 * query and no predicate, so a press refetched identical rows, lit the
 * chip as "Tersambung" and toasted "MVP: nominal". The tests below
 * prove it now sends `program_id` — a real id, built from
 * `BimbelEnrollment.program_id`/`program_name`, which the rows have
 * carried all along.
 *
 * The real <FilterFacetPickerModal> is mounted; only <Modal>'s
 * teleporting shell is stubbed.
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import StudentsView from './TutorTutoring2StudentsView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', async (importOriginal) => ({
  ...(await importOriginal()),
  TutoringBimbelService: { listEnrollments: vi.fn() },
}));
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
  useRoute: () => ({ params: {}, query: {} }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));

function makeEnrollment(o = {}) {
  return {
    id: 'en-1',
    student_id: 'st-1',
    student_name: 'Budi',
    program_id: 'pr-1',
    program_name: 'Intensif UTBK',
    billing_mode: 'monthly',
    status: 'active',
    ...o,
  };
}

const ROWS = [
  makeEnrollment(),
  makeEnrollment({ id: 'en-2', student_id: 'st-2', student_name: 'Siti', program_id: 'pr-2', program_name: 'Reguler SMA', status: 'trial' }),
];

const messages = {
  id: {
    tutoring2: {
      common: { all: 'Semua', status: 'Status', program: 'Program', filterNoOptions: 'Belum ada pilihan' },
      status: {
        trial: 'Trial',
        active: 'Aktif',
        paused: 'Dijeda',
        graduated: 'Lulus',
        withdrawn: 'Keluar',
      },
    },
  },
};

const ToolbarStub = {
  props: ['search', 'searchPlaceholder'],
  emits: ['update:search'],
  template: '<div><slot name="chips" /></div>',
};

async function mountView(rows = ROWS) {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listEnrollments).mockResolvedValue({ items: rows });
  const w = mount(StudentsView, {
    global: {
      plugins: [createI18n({ legacy: false, locale: 'id', messages, missingWarn: false, fallbackWarn: false })],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        PageFilterToolbar: ToolbarStub,
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

const chips = (w) => w.findAll('button.inline-flex');
const optionRows = (w) => w.findAll('.modal button');
const rowLabels = (w) => optionRows(w).map((b) => b.text());
const lastParams = () => {
  const calls = vi.mocked(TutoringBimbelService.listEnrollments).mock.calls;
  return calls[calls.length - 1]?.[0] ?? {};
};

beforeEach(() => vi.clearAllMocks());

describe('TutorTutoring2StudentsView — Status filter', () => {
  it('opens a picker listing every enrollment status', async () => {
    const w = await mountView();
    expect(optionRows(w)).toHaveLength(0);
    await chips(w)[0].trigger('click');
    expect(rowLabels(w)).toEqual(['Semua', 'Trial', 'Aktif', 'Dijeda', 'Lulus', 'Keluar']);
  });

  it.each([
    ['Trial', 'trial'],
    ['Aktif', 'active'],
    ['Dijeda', 'paused'],
    ['Lulus', 'graduated'],
    ['Keluar', 'withdrawn'],
  ])('selecting %s asks the server for %s', async (label, wire) => {
    const w = await mountView();
    await chips(w)[0].trigger('click');
    await optionRows(w).find((b) => b.text() === label).trigger('click');
    await flushPromises();
    expect(lastParams().status).toBe(wire);
    expect(chips(w)[0].text()).toContain(label);
  });

  it('"Semua" drops the status parameter', async () => {
    const w = await mountView();
    await chips(w)[0].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Dijeda').trigger('click');
    await flushPromises();
    expect(lastParams().status).toBe('paused');

    await chips(w)[0].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Semua').trigger('click');
    await flushPromises();
    expect(lastParams().status).toBeUndefined();
  });
});

describe('TutorTutoring2StudentsView — Program filter', () => {
  it('lists every program on the tutor’s enrollments, by NAME', async () => {
    const w = await mountView();
    await chips(w)[1].trigger('click');
    expect(rowLabels(w)).toEqual(['Semua', 'Intensif UTBK', 'Reguler SMA']);
  });

  it('sends program_id — the old chip sent nothing at all', async () => {
    const w = await mountView();
    await chips(w)[1].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Reguler SMA').trigger('click');
    await flushPromises();
    expect(lastParams().program_id).toBe('pr-2');
    // the chip reads the NAME, never the id
    expect(chips(w)[1].text()).toContain('Reguler SMA');
    expect(chips(w)[1].text()).not.toContain('pr-2');
  });

  it('"Semua" drops the program_id parameter', async () => {
    const w = await mountView();
    await chips(w)[1].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Intensif UTBK').trigger('click');
    await flushPromises();
    expect(lastParams().program_id).toBe('pr-1');

    await chips(w)[1].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Semua').trigger('click');
    await flushPromises();
    expect(lastParams().program_id).toBeUndefined();
  });

  it('the option list survives picking one — it is not derived from the filtered rows', async () => {
    const w = await mountView();
    await chips(w)[1].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Reguler SMA').trigger('click');
    await flushPromises();
    // server now returns only that program's rows…
    vi.mocked(TutoringBimbelService.listEnrollments).mockResolvedValue({ items: [ROWS[1]] });
    await chips(w)[1].trigger('click');
    // …and both programs are still offered, so the tutor can switch back.
    expect(rowLabels(w)).toEqual(['Semua', 'Intensif UTBK', 'Reguler SMA']);
  });

  it('disables the chip when the tutor has no programs at all', async () => {
    const w = await mountView([]);
    expect(chips(w)[1].attributes('disabled')).toBeDefined();
  });
});
