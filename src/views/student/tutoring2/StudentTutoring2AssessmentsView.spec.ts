/**
 * StudentTutoring2AssessmentsView — "N peserta" must not be invented.
 *
 * The sweep that produced `@/lib/absent-vs-zero` fixed the three ADMIN
 * screens and stopped there. This row meta read
 * `{{ t('…metaParticipants', { count: a.scores_count ?? 0 }) }}` and the
 * view fetches through `TutoringBimbelService.listAssessments` — i.e.
 * `AssessmentController::index`, which runs no `withCount('scores')`
 * (only `show()` does). `AssessmentResource` emits the field via
 * `when(isset(...))`, which OMITS the key rather than sending null, so
 * every row on every tenant arrived without it and every assessment
 * read "0 peserta" no matter how many students had sat it.
 *
 * Identical defect, identical fix, and the invariant is the same one:
 * a REPORTED zero is a real answer and must still render as 0.
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import StudentTutoring2AssessmentsView from './StudentTutoring2AssessmentsView.vue';
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

  const w = mount(StudentTutoring2AssessmentsView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: true,
        StatusBadge: true,
        NavIcon: true,
        KpiStripCards: true,
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

describe('StudentTutoring2AssessmentsView — participants absent vs zero', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('does not claim "0 peserta" when the server sent no count', async () => {
    const w = await mountView([makeAssessment()]);

    expect(rowsText(w)).not.toContain('0 peserta');
    // The whole segment drops rather than printing "—" mid-sentence,
    // which also removes the dangling separator.
    expect(rowsText(w)).not.toContain('peserta');
  });

  it('THE INVARIANT: a reported zero still reads "0 peserta"', async () => {
    const w = await mountView([makeAssessment({ scores_count: 0 })]);

    expect(rowsText(w)).toContain('0 peserta');
  });

  it('renders a reported positive count verbatim', async () => {
    const w = await mountView([makeAssessment({ scores_count: 21 })]);

    expect(rowsText(w)).toContain('21 peserta');
  });

  it('decides per row, not per page', async () => {
    const w = await mountView([
      makeAssessment({ id: 'as-1', scores_count: 7 }),
      makeAssessment({ id: 'as-2' }), // silent
      makeAssessment({ id: 'as-3', scores_count: 0 }),
    ]);

    const text = rowsText(w);
    expect(text).toContain('7 peserta');
    expect(text).toContain('0 peserta');
    // Exactly two rows carry the segment; the silent one has none.
    expect(text.match(/peserta/g)).toHaveLength(2);
  });
});
