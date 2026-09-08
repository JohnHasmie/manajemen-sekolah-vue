/**
 * The SHARED score-history body — the thing that makes the wali screen
 * and the staff drill-in one rendering instead of two.
 *
 * `ParentTutoring2ProgressView.spec.ts` already pins this payload's
 * rendering rules THROUGH the wali wrapper, and deliberately so: it was
 * written against the pre-extraction component and is unchanged by the
 * extraction, which is what proves the wali screen did not regress.
 *
 * This file pins the other half — that the body is genuinely reusable by
 * a caller who is not the wali:
 *
 *   • it reads whichever student the PROP names, not a route param;
 *   • it hands the header slot the two facts a caller needs to write its
 *     own meta line, so no caller has to reach into this state;
 *   • the series legend comes from the caller, because "Nilai anak" is
 *     wrong on a staff screen looking at someone else's child;
 *   • an absent studentId makes NO request at all.
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

const PROGRESS = {
  points: [
    { assessment_id: 'as-1', title: 'Tryout 1', program_id: 'pr-1', program_name: 'UTBK', date: '2026-06-01', score: 80, max_score: 100, percent: 80, kkm_percent: 75, notes: null },
    { assessment_id: 'as-2', title: 'Tryout 2', program_id: 'pr-1', program_name: 'UTBK', date: '2026-07-01', score: 120, max_score: 200, percent: 60, kkm_percent: 75, notes: null },
  ],
  programs: [{ id: 'pr-1', name: 'UTBK' }],
  summary: { graded_count: 2, average: 70, highest: 80, lowest: 60, latest: 60 },
  peer_average_by_program: { 'pr-1': 65 },
};

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: {
      id: {
        tutoring2: {
          common: { all: 'Semua', program: 'Program', loading: 'Memuat…', notAvailable: 'Belum tersedia' },
          studentScores: {
            meta: '{count} penilaian dinilai',
            kpiAverage: 'Rata-rata',
            kpiHighest: 'Tertinggi',
            kpiLowest: 'Terendah',
            kpiGraded: 'Dinilai',
            emptyTitle: 'Belum ada nilai',
            emptyDesc: 'Belum ada nilai.',
            noGradedYet: 'Belum ada penilaian dinilai.',
            chartTitle: 'Tren nilai',
            chartNeedsMorePoints: 'Butuh dua titik.',
            legendStudent: 'Nilai siswa',
            legendPeer: 'Rata-rata peserta program ({value})',
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

async function mountBody(props = {}, headerSlot?: string) {
  setActivePinia(createPinia());
  const w = mount(Tutoring2StudentScores, {
    props: {
      studentId: 'st-42',
      legendSubjectLabel: 'Nilai siswa',
      ...props,
    },
    slots: headerSlot
      ? { header: headerSlot }
      : {},
    global: {
      plugins: [makeI18n()],
      stubs: {
        KpiStripCards: true,
        PageFilterToolbar: { template: '<div><slot name="chips" /></div>' },
        AppFilterChip: { template: '<button></button>' },
        AsyncView: {
          props: ['state'],
          template: '<div :data-status="state?.status"><slot /></div>',
        },
        StatusBadge: {
          props: ['label', 'tone'],
          template: '<span data-testid="badge" :data-tone="tone">{{ label }}</span>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

describe('Tutoring2StudentScores — the shared body', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (TutoringStudentsService.getProgress as any).mockResolvedValue(PROGRESS);
  });

  it('reads the student the PROP names, not a route param', async () => {
    await mountBody({ studentId: 'st-99' });
    expect(TutoringStudentsService.getProgress).toHaveBeenCalledWith('st-99');
  });

  it('renders the payload the endpoint returned', async () => {
    const w = await mountBody();
    expect(w.findAll('li')).toHaveLength(2);
    // Newest first, and pass/fail read off the pre-rescaled kkm_percent.
    expect(w.findAll('[data-testid="badge"]').map((b) => b.text())).toEqual([
      'Di bawah KKM',
      'Tuntas',
    ]);
    expect(w.text()).toContain('Rata-rata peserta program (65.0)');
  });

  it('hands the header slot the count and the loading flag', async () => {
    const w = await mountBody(
      {},
      '<template #header="{ count, loading }"><h1 data-testid="h">{{ loading ? "…" : count }}</h1></template>',
    );
    expect(w.find('[data-testid="h"]').text()).toBe('2');
  });

  it('takes the series legend from the caller, so staff wording can differ', async () => {
    const w = await mountBody({ legendSubjectLabel: 'Nilai anak' });
    expect(w.text()).toContain('Nilai anak');
    expect(w.text()).not.toContain('Nilai siswa');
  });

  it('makes no request at all when it has no student to ask about', async () => {
    const w = await mountBody({ studentId: '' });
    expect(TutoringStudentsService.getProgress).not.toHaveBeenCalled();
    expect(w.find('[data-status]').attributes('data-status')).toBe('empty');
  });
});
