/**
 * Characterization spec for the wali "Nilai / Progress" screen.
 *
 * ── Why this file was written BEFORE the refactor it guards ──
 *
 * The rendering below was about to be extracted into
 * <Tutoring2StudentScores> so that the staff Peringkat drill-in and the
 * wali screen cannot drift (Luay, 2026-09 — "Pada website belum
 * menampilkan detail nilai siswa"). The wali screen is LIVE, and the
 * extraction is the whole regression risk, so its behaviour had to be
 * pinned first. It had no spec at all.
 *
 * Every assertion here was written against the PRE-refactor component
 * and passed against it unchanged. That is the point: the file is not
 * edited by the refactor, so it can only stay green by the wrapper
 * rendering what the original did.
 *
 * What is pinned, and why each one is a real trap:
 *
 *   1. The endpoint is asked about the ROUTE's student — a wrapper that
 *      forgot to forward `:studentId` would silently render the empty
 *      state rather than error.
 *   2. Points arrive OLDEST-first and the list renders NEWEST-first. A
 *      re-sort "for tidiness" inverts a child's history.
 *   3. `kkm_percent` is ALREADY rescaled onto 0..100 server-side. The
 *      badge must compare it against `percent` directly. Re-deriving it
 *      from the raw score renders pass/fail BACKWARDS — the one defect
 *      the file header warns about at length.
 *   4. A point with a null `percent` (max_score 0) is dropped, not
 *      plotted as a zero.
 *   5. `peer_average_by_program` with no filter is the mean ACROSS the
 *      child's programmes' means, and is simply not drawn when absent —
 *      never faked into a curve.
 *   6. The chart needs >= 2 datable points; undated scores stay in the
 *      list but off the time axis.
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import ParentTutoring2ProgressView from './ParentTutoring2ProgressView.vue';
import { TutoringStudentsService } from '@/services/tutoring2/students';

vi.mock('@/services/tutoring2/students', () => ({
  TutoringStudentsService: { getProgress: vi.fn() },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {
    /* noop in tests */
  },
}));
vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: () => {
    /* noop in tests */
  },
}));

const STUDENT_ID = '019f8090-4d6a-71ab-bf01-c98a6ac73294';

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { studentId: STUDENT_ID }, query: {} }),
  useRouter: () => ({ push: vi.fn() }),
}));

/**
 * Oldest-first, exactly as the server sends it.
 *
 * `as-2` is the trap for the KKM rule: 120/200 is 60%, which is BELOW
 * its 75% passing mark — but ABOVE the raw `kkm` of 150 read against the
 * raw score of 120 only if you compare the wrong pair. A client that
 * re-derived the threshold would badge this row "Lulus".
 */
const POINTS = [
  {
    assessment_id: 'as-1',
    title: 'Tryout Nasional 1',
    program_id: 'pr-1',
    program_name: 'Intensif UTBK',
    date: '2026-06-01',
    score: 80,
    max_score: 100,
    percent: 80,
    kkm_percent: 75,
    notes: null,
  },
  {
    assessment_id: 'as-2',
    title: 'Tryout Nasional 2',
    program_id: 'pr-1',
    program_name: 'Intensif UTBK',
    date: '2026-07-01',
    score: 120,
    max_score: 200,
    percent: 60,
    kkm_percent: 75,
    notes: null,
  },
  {
    assessment_id: 'as-3',
    title: 'Latihan Reguler',
    program_id: 'pr-2',
    program_name: 'Reguler SMP',
    date: '2026-08-01',
    score: 90,
    max_score: 100,
    percent: 90,
    kkm_percent: null,
    notes: null,
  },
  // max_score 0 → the server sends percent null rather than guessing.
  {
    assessment_id: 'as-4',
    title: 'Belum dinilai penuh',
    program_id: 'pr-2',
    program_name: 'Reguler SMP',
    date: '2026-08-10',
    score: 0,
    max_score: 0,
    percent: null,
    kkm_percent: null,
    notes: null,
  },
];

const PROGRESS = {
  points: POINTS,
  programs: [
    { id: 'pr-1', name: 'Intensif UTBK' },
    { id: 'pr-2', name: 'Reguler SMP' },
  ],
  summary: {
    graded_count: 3,
    average: 76.7,
    highest: 90,
    lowest: 60,
    latest: 90,
  },
  peer_average_by_program: { 'pr-1': 70, 'pr-2': 80 },
};

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
            loading: 'Memuat…',
            notAvailable: 'Belum tersedia',
          },
          // The BODY strings live under the shared `studentScores`
          // namespace, because the same rendering serves staff. The two
          // blocks below carry identical VALUES for every string this
          // spec asserts, so which namespace the component reads is
          // invisible here — which is the point: the assertions are on
          // rendered output, not on key names.
          studentScores: {
            kpiAverage: 'Rata-rata',
            kpiHighest: 'Tertinggi',
            kpiLowest: 'Terendah',
            kpiGraded: 'Dinilai',
            emptyTitle: 'Belum ada nilai',
            emptyDesc: 'Nilai akan muncul setelah penilaian dipublikasikan.',
            noGradedYet: 'Belum ada penilaian yang dinilai.',
            chartTitle: 'Tren nilai',
            chartNeedsMorePoints: 'Butuh minimal dua penilaian bertanggal.',
            legendStudent: 'Nilai siswa',
            legendPeer: 'Rata-rata peserta program ({value})',
            passed: 'Lulus',
            belowKkm: 'Di bawah KKM',
            noKkm: 'Tanpa KKM',
          },
          parent: {
            home: { subtitle: 'Perkembangan anak' },
            progress: {
              title: 'Nilai',
              meta: '{count} penilaian',
              kpiAverage: 'Rata-rata',
              kpiHighest: 'Tertinggi',
              kpiLowest: 'Terendah',
              kpiGraded: 'Dinilai',
              emptyTitle: 'Belum ada nilai',
              emptyDesc: 'Nilai akan muncul setelah penilaian dipublikasikan.',
              noGradedYet: 'Belum ada penilaian yang dinilai.',
              chartTitle: 'Tren nilai',
              chartNeedsMorePoints: 'Butuh minimal dua penilaian bertanggal.',
              legendChild: 'Nilai anak',
              legendPeer: 'Rata-rata peserta program ({value})',
              passed: 'Lulus',
              belowKkm: 'Di bawah KKM',
              noKkm: 'Tanpa KKM',
            },
          },
        },
      },
    },
    missingWarn: false,
    fallbackWarn: false,
  });
}

/**
 * Stubs mirror each component's real contract closely enough to assert
 * through: the KPI strip exposes its values, the badge its label, and
 * the chip emits click so the program filter can be cycled.
 */
async function mountView() {
  setActivePinia(createPinia());
  const w = mount(ParentTutoring2ProgressView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: {
          props: ['role', 'kicker', 'title', 'meta'],
          template:
            '<header data-testid="header" :data-role="role"><span data-testid="header-title">{{ title }}</span><span data-testid="header-kicker">{{ kicker }}</span><span data-testid="header-meta">{{ meta }}</span></header>',
        },
        KpiStripCards: {
          props: ['cards', 'loading'],
          template:
            '<div data-testid="kpis"><span v-for="c in cards" :key="c.label" data-testid="kpi" :data-label="c.label">{{ c.value }}</span></div>',
        },
        PageFilterToolbar: {
          template: '<div data-testid="toolbar"><slot name="chips" /></div>',
        },
        AppFilterChip: {
          props: ['label', 'value', 'iconName', 'active'],
          emits: ['click'],
          template:
            '<button data-testid="chip" @click="$emit(\'click\')">{{ value }}</button>',
        },
        AsyncView: {
          props: ['state'],
          template:
            '<div data-testid="async" :data-status="state?.status"><slot /></div>',
        },
        StatusBadge: {
          props: ['label', 'tone', 'uppercase'],
          template:
            '<span data-testid="badge" :data-tone="tone">{{ label }}</span>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

function rows(w) {
  return w.findAll('li');
}
function kpi(w, label) {
  return w.find(`[data-testid="kpi"][data-label="${label}"]`)?.text();
}

describe('wali progress screen — payload rendering', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (TutoringStudentsService.getProgress as any).mockResolvedValue(PROGRESS);
  });

  it('asks the endpoint about the student named in the route', async () => {
    await mountView();
    expect(TutoringStudentsService.getProgress).toHaveBeenCalledWith(STUDENT_ID);
  });

  it('drops a point whose percent is null instead of plotting it as zero', async () => {
    const w = await mountView();
    // Four points in, three rendered: `as-4` had max_score 0.
    expect(rows(w)).toHaveLength(3);
    expect(w.text()).not.toContain('Belum dinilai penuh');
  });

  it('renders newest-first, the inverse of the oldest-first payload', async () => {
    const w = await mountView();
    const titles = rows(w).map((r) => r.find('p').text());
    expect(titles).toEqual([
      'Latihan Reguler',
      'Tryout Nasional 2',
      'Tryout Nasional 1',
    ]);
  });

  it('badges pass/fail off the ALREADY-rescaled kkm_percent', async () => {
    const w = await mountView();
    const badges = w.findAll('[data-testid="badge"]');
    // Same order as the rows: newest first.
    expect(badges.map((b) => b.text())).toEqual([
      'Tanpa KKM', // as-3: kkm_percent null → neutral, never guessed
      'Di bawah KKM', // as-2: 60% < 75% — backwards if re-derived from raw
      'Lulus', // as-1: 80% >= 75%
    ]);
    expect(badges.map((b) => b.attributes('data-tone'))).toEqual([
      'neutral',
      'danger',
      'success',
    ]);
  });

  it('derives every KPI from the visible points only', async () => {
    const w = await mountView();
    // (80 + 60 + 90) / 3 = 76.666… → 1 dp
    expect(kpi(w, 'Rata-rata')).toBe('76.7');
    expect(kpi(w, 'Tertinggi')).toBe('90.0');
    expect(kpi(w, 'Terendah')).toBe('60.0');
    expect(kpi(w, 'Dinilai')).toBe('3');
  });

  it('draws the peer baseline as the mean across programme means', async () => {
    const w = await mountView();
    // (70 + 80) / 2 = 75 with no programme filter applied.
    expect(w.text()).toContain('Rata-rata peserta program (75.0)');
    expect(w.find('line').exists()).toBe(true);
  });

  it('calls the plotted series the WALI’s wording, not a staff one', async () => {
    // The series legend is the one string that cannot be shared: a wali
    // reads "Nilai anak", staff read "Nilai siswa" about someone else's
    // child. A shared body must take it from the caller.
    const w = await mountView();
    expect(w.text()).toContain('Nilai anak');
    expect(w.text()).not.toContain('Nilai siswa');
  });

  it('omits the baseline entirely when the server sent no peer data', async () => {
    (TutoringStudentsService.getProgress as any).mockResolvedValue({
      ...PROGRESS,
      peer_average_by_program: {},
    });
    const w = await mountView();
    // Not drawn, and not invented as a flat zero line either.
    expect(w.find('line').exists()).toBe(false);
    expect(w.text()).not.toContain('Rata-rata peserta program');
  });

  it('needs two datable points before it will draw a chart', async () => {
    (TutoringStudentsService.getProgress as any).mockResolvedValue({
      ...PROGRESS,
      points: [POINTS[0]],
    });
    const w = await mountView();
    expect(w.find('polyline').exists()).toBe(false);
    expect(w.text()).toContain('Butuh minimal dua penilaian bertanggal.');
    // The score itself is still listed — only the time axis is withheld.
    expect(rows(w)).toHaveLength(1);
  });

  it('keeps an undated score in the list but off the time axis', async () => {
    (TutoringStudentsService.getProgress as any).mockResolvedValue({
      ...PROGRESS,
      points: [POINTS[0], POINTS[1], { ...POINTS[2], date: null }],
    });
    const w = await mountView();
    expect(rows(w)).toHaveLength(3);
    // Two datable points → two vertices, not three.
    expect(w.find('polyline').attributes('points').split(' ')).toHaveLength(2);
  });

  it('filters to one programme when the chip is cycled', async () => {
    const w = await mountView();
    // '' → pr-1 on the first click.
    await w.find('[data-testid="chip"]').trigger('click');
    await flushPromises();

    const titles = rows(w).map((r) => r.find('p').text());
    expect(titles).toEqual(['Tryout Nasional 2', 'Tryout Nasional 1']);
    // Baseline is now that programme's own mean, not the cross-programme one.
    expect(w.text()).toContain('Rata-rata peserta program (70.0)');
  });

  it('shows the honest empty state rather than a fabricated series', async () => {
    (TutoringStudentsService.getProgress as any).mockResolvedValue({
      ...PROGRESS,
      points: [],
    });
    const w = await mountView();
    expect(w.find('[data-testid="async"]').attributes('data-status')).toBe(
      'empty',
    );
    expect(w.find('polyline').exists()).toBe(false);
  });
});

describe('wali progress screen — header identity', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (TutoringStudentsService.getProgress as any).mockResolvedValue(PROGRESS);
  });

  it('keeps the wali role, kicker and title', async () => {
    const w = await mountView();
    const header = w.find('[data-testid="header"]');
    expect(header.attributes('data-role')).toBe('parent');
    expect(w.find('[data-testid="header-title"]').text()).toBe('Nilai');
    expect(w.find('[data-testid="header-kicker"]').text()).toBe(
      'Perkembangan anak',
    );
    expect(w.find('[data-testid="header-meta"]').text()).toBe('3 penilaian');
  });
});
