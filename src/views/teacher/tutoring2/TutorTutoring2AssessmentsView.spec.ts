/**
 * TutorTutoring2AssessmentsView — "N peserta" must not be invented.
 *
 * Twin of StudentTutoring2AssessmentsView.spec.ts. Both screens read
 * `scores_count` off `TutoringBimbelService.listAssessments`, and
 * `AssessmentController::index` runs no `withCount('scores')` — only
 * `show()` does — so `AssessmentResource`'s `when(isset(...))` omits the
 * key from every row. `?? 0` rendered "0 peserta" for every assessment
 * on every tenant, including ones a tutor had already scored.
 *
 * Kept as a separate file rather than a shared table-driven one: the two
 * views have different filter toolbars and different row actions, and a
 * shared harness would have to stub enough of both to stop resembling
 * either.
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import TutorTutoring2AssessmentsView from './TutorTutoring2AssessmentsView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { listAssessments: vi.fn() },
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

const push = vi.fn();
vi.mock('vue-router', () => ({
  useRouter: () => ({ push }),
  useRoute: () => ({ params: {}, query: {} }),
}));

function makeAssessment(overrides = {}) {
  return {
    id: 'as-1',
    program_id: 'pr-1',
    title: 'Tryout 1',
    kind: 'tryout',
    kind_label: 'Tryout',
    assessment_date: '2026-09-01',
    max_score: 100,
    published_at: '2026-08-30T00:00:00+07:00',
    // No `scores_count` — this is the real wire shape of the LIST.
    ...overrides,
  };
}

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    missingWarn: false,
    fallbackWarn: false,
    messages: {
      id: {
        tutoring2: {
          common: { metaParticipants: '{count} peserta' },
        },
      },
    },
  });
}

async function mountView(items) {
  setActivePinia(createPinia());
  (TutoringBimbelService.listAssessments as any).mockResolvedValue({ items });

  const w = mount(TutorTutoring2AssessmentsView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: true,
        StatusBadge: true,
        NavIcon: true,
        KpiStripCards: true,
        Button: true,
        AppFilterChip: true,
        RouterLink: true,
        PageFilterToolbar: { template: '<div><slot name="chips" /></div>' },
        AsyncView: {
          props: ['state'],
          template: '<div data-testid="async"><slot /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

function rowsText(w) {
  return w.find('[data-testid="async"]').text().replace(/\s+/g, ' ');
}

describe('TutorTutoring2AssessmentsView — participants absent vs zero', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('does not claim "0 peserta" when the server sent no count', async () => {
    const w = await mountView([makeAssessment()]);

    expect(rowsText(w)).not.toContain('0 peserta');
    expect(rowsText(w)).not.toContain('peserta');
  });

  it('THE INVARIANT: a reported zero still reads "0 peserta"', async () => {
    const w = await mountView([makeAssessment({ scores_count: 0 })]);

    expect(rowsText(w)).toContain('0 peserta');
  });

  it('renders a reported positive count verbatim', async () => {
    const w = await mountView([makeAssessment({ scores_count: 32 })]);

    expect(rowsText(w)).toContain('32 peserta');
  });

  it('decides per row, not per page', async () => {
    const w = await mountView([
      makeAssessment({ id: 'as-1', scores_count: 9 }),
      makeAssessment({ id: 'as-2' }), // silent
      makeAssessment({ id: 'as-3', scores_count: 0 }),
    ]);

    const text = rowsText(w);
    expect(text).toContain('9 peserta');
    expect(text).toContain('0 peserta');
    expect(text.match(/peserta/g)).toHaveLength(2);
  });
});
