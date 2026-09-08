/**
 * The staff drill-in wrapper: whose marks am I reading, and does the
 * page still work when nobody told me their name?
 *
 * The name travels in `?name=` because no endpoint would give it to a
 * tutor — `GET /tutoring-v2/students/{id}` authorizes
 * `tutoring.student.view`, which `tutorTutoringDefaults()` does not
 * grant. That makes the bookmarked-link case real rather than
 * theoretical, so the fallback is pinned here: the SCORES are still
 * correct and still authorised, and only the label is unknown.
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import Tutoring2StudentScoresView from './Tutoring2StudentScoresView.vue';
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

/** Swapped per-test to move the route the view is mounted under. */
let route = { params: {}, query: {}, meta: {} };
vi.mock('vue-router', () => ({
  useRoute: () => route,
  useRouter: () => ({ push: vi.fn() }),
}));

const PROGRESS = {
  points: [
    { assessment_id: 'as-1', title: 'Tryout 1', program_id: 'pr-1', program_name: 'UTBK', date: '2026-06-01', score: 80, max_score: 100, percent: 80, kkm_percent: 75, notes: null },
  ],
  programs: [{ id: 'pr-1', name: 'UTBK' }],
  summary: { graded_count: 1, average: 80, highest: 80, lowest: 80, latest: 80 },
  peer_average_by_program: {},
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
            kicker: 'Detail nilai siswa',
            titleFallback: 'Tanpa nama',
            kpiAverage: 'Rata-rata', kpiHighest: 'Tertinggi', kpiLowest: 'Terendah', kpiGraded: 'Dinilai',
            emptyTitle: 'Belum ada nilai', emptyDesc: 'Belum ada nilai.',
            noGradedYet: 'Belum ada penilaian dinilai.',
            chartTitle: 'Tren nilai', chartNeedsMorePoints: 'Butuh dua titik.',
            legendStudent: 'Nilai siswa',
            legendPeer: 'Rata-rata peserta program ({value})',
            passed: 'Tuntas', belowKkm: 'Di bawah KKM', noKkm: 'Tanpa KKM',
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
  const w = mount(Tutoring2StudentScoresView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: {
          props: ['role', 'kicker', 'title', 'meta'],
          template:
            '<header :data-role="role"><span data-testid="title">{{ title }}</span><span data-testid="meta">{{ meta }}</span></header>',
        },
        KpiStripCards: true,
        PageFilterToolbar: { template: '<div><slot name="chips" /></div>' },
        AppFilterChip: { template: '<button></button>' },
        AsyncView: { props: ['state'], template: '<div><slot /></div>' },
        StatusBadge: true,
      },
    },
  });
  await flushPromises();
  return w;
}

describe('staff student-scores drill-in', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (TutoringStudentsService.getProgress as any).mockResolvedValue(PROGRESS);
    route = {
      params: { studentId: 'st-7' },
      query: { name: 'Anaya Putri' },
      meta: { role: 'admin' },
    };
  });

  it('asks about the student in the path', async () => {
    await mountView();
    expect(TutoringStudentsService.getProgress).toHaveBeenCalledWith('st-7');
  });

  it('titles the page with the student’s name', async () => {
    const w = await mountView();
    expect(w.find('[data-testid="title"]').text()).toBe('Anaya Putri');
    expect(w.find('[data-testid="meta"]').text()).toBe('1 penilaian dinilai');
  });

  it('falls back to an honest placeholder on a link with no ?name=', async () => {
    route = { params: { studentId: 'st-7' }, query: {}, meta: { role: 'admin' } };
    const w = await mountView();
    expect(w.find('[data-testid="title"]').text()).toBe('Tanpa nama');
    // The marks themselves are unaffected — only the label was unknown.
    expect(w.findAll('li')).toHaveLength(1);
  });

  it('treats a blank ?name= as no name rather than an empty title', async () => {
    route = { params: { studentId: 'st-7' }, query: { name: '   ' }, meta: { role: 'admin' } };
    const w = await mountView();
    expect(w.find('[data-testid="title"]').text()).toBe('Tanpa nama');
  });

  it('tints the header to whichever staff surface we arrived from', async () => {
    const w = await mountView();
    expect(w.find('header').attributes('data-role')).toBe('admin');

    route = { params: { studentId: 'st-7' }, query: { name: 'A' }, meta: { role: 'teacher' } };
    const w2 = await mountView();
    expect(w2.find('header').attributes('data-role')).toBe('teacher');
  });

  it('uses the staff wording for the plotted series, not the wali’s', async () => {
    const w = await mountView();
    expect(w.text()).not.toContain('Nilai anak');
  });
});
