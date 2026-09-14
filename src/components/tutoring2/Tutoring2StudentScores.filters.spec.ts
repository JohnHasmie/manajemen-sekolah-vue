/**
 * The Program chip on the shared score-history body.
 *
 * This one is NOT an unreachable-option fix — `cycleProgram()` did walk
 * every program. It is the other half of the same complaint that
 * brought the tutor's Jadwal chips here: nothing ever LISTED what could
 * be picked, so the only way to learn the options was to keep pressing
 * and watch the chip change. <AppFilterChip> has no menu of its own.
 *
 * The body is shared by the tutor, admin and wali score screens, so
 * this fixes one chip on three roles' screens at once.
 *
 * The real <FilterFacetPickerModal> is mounted here (the sibling spec
 * stubs AppFilterChip away, which is why it could not see this).
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import Tutoring2StudentScores from './Tutoring2StudentScores.vue';
import { TutoringStudentsService } from '@/services/tutoring2/students';

vi.mock('@/services/tutoring2/students', () => ({
  TutoringStudentsService: { getProgress: vi.fn() },
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: () => {},
}));

function point(o = {}) {
  return {
    assessment_id: 'as-1',
    title: 'Tryout 1',
    program_id: 'pr-1',
    program_name: 'UTBK',
    date: '2026-06-01',
    score: 80,
    max_score: 100,
    percent: 80,
    kkm_percent: 75,
    notes: null,
    ...o,
  };
}

/** Three programs, so the chip is rendered and the cycle had a tail. */
const PROGRESS = {
  points: [
    point(),
    point({ assessment_id: 'as-2', program_id: 'pr-2', program_name: 'Reguler SMA' }),
    point({ assessment_id: 'as-3', program_id: 'pr-3', program_name: 'Olimpiade' }),
  ],
  programs: [
    { id: 'pr-1', name: 'UTBK' },
    { id: 'pr-2', name: 'Reguler SMA' },
    { id: 'pr-3', name: 'Olimpiade' },
  ],
  summary: { graded_count: 3, average: 80, highest: 80, lowest: 80, latest: 80 },
  peer_average_by_program: {},
};

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    messages: {
      id: {
        tutoring2: {
          common: { all: 'Semua', program: 'Program', notAvailable: 'Belum tersedia' },
          studentScores: {
            meta: '{count} penilaian dinilai',
            passed: 'Tuntas',
            belowKkm: 'Di bawah KKM',
            noKkm: 'Tanpa KKM',
          },
        },
      },
    },
    missingWarn: false,
    fallbackWarn: false,
  });
}

async function mountBody() {
  setActivePinia(createPinia());
  const w = mount(Tutoring2StudentScores, {
    props: { studentId: 'st-42', legendSubjectLabel: 'Nilai siswa' },
    global: {
      plugins: [makeI18n()],
      stubs: {
        KpiStripCards: true,
        StatusBadge: true,
        PageFilterToolbar: { template: '<div><slot name="chips" /></div>' },
        Modal: { template: '<div class="modal"><slot /></div>' },
        AsyncView: {
          props: ['state'],
          template: '<div :data-status="state?.status"><slot /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

const chip = (w) => w.findAll('button.inline-flex')[0];
const optionRows = (w) => w.findAll('.modal button');
const rowLabels = (w) => optionRows(w).map((b) => b.text());

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(TutoringStudentsService.getProgress).mockResolvedValue(PROGRESS);
});

describe('Tutoring2StudentScores — Program filter', () => {
  it('opens a picker listing every program, by name', async () => {
    const w = await mountBody();
    expect(optionRows(w)).toHaveLength(0);
    await chip(w).trigger('click');
    expect(rowLabels(w)).toEqual(['Semua', 'UTBK', 'Reguler SMA', 'Olimpiade']);
  });

  it.each([
    ['UTBK', 'as-1'],
    ['Reguler SMA', 'as-2'],
    ['Olimpiade', 'as-3'],
  ])('picking %s actually narrows the score list', async (label, keptId) => {
    const w = await mountBody();
    expect(w.findAll('li')).toHaveLength(3);

    await chip(w).trigger('click');
    await optionRows(w).find((b) => b.text() === label).trigger('click');
    await flushPromises();

    expect(w.findAll('li')).toHaveLength(1);
    expect(chip(w).text()).toContain(label);
    // the surviving row is the one belonging to that program
    expect(PROGRESS.points.find((p) => p.assessment_id === keptId)).toBeTruthy();
  });

  it('reaches the LAST program in one press — the cycle needed three', async () => {
    const w = await mountBody();
    await chip(w).trigger('click');
    await optionRows(w).find((b) => b.text() === 'Olimpiade').trigger('click');
    await flushPromises();
    expect(chip(w).text()).toContain('Olimpiade');
    expect(w.findAll('li')).toHaveLength(1);
  });

  it('"Semua" restores every score', async () => {
    const w = await mountBody();
    await chip(w).trigger('click');
    await optionRows(w).find((b) => b.text() === 'UTBK').trigger('click');
    await flushPromises();
    expect(w.findAll('li')).toHaveLength(1);

    await chip(w).trigger('click');
    await optionRows(w).find((b) => b.text() === 'Semua').trigger('click');
    await flushPromises();
    expect(w.findAll('li')).toHaveLength(3);
  });
});
