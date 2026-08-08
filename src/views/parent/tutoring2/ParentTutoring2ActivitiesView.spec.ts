/**
 * Behavioural spec for ParentTutoring2ActivitiesView.
 *
 * Written after two bugs on this screen that every other gate missed —
 * both of them the same kind of failure, where a payload change was
 * type-correct but silently altered what a parent SEES.
 *
 *   1. The fan-out this view used to do capped its submission lookups at
 *      the first 30 activities. Past the cap every row arrived with
 *      `submission: null`, which this screen renders as the pseudo-status
 *      "belum dikumpulkan" — a child who handed work in was displayed to
 *      their parent as delinquent.
 *   2. Replacing that fan-out grew the payload from an array into an
 *      object so it could carry meta.summary. `useDataRefresh.isEmpty()`
 *      only recognises null/undefined/empty-array, so a child with NO
 *      activities stopped resolving to `status: 'empty'` and rendered a
 *      blank content branch instead of the empty state.
 *
 * Neither was visible to vue-tsc, to the service contract specs, or to
 * the backend feature tests. They are visible here, because this file
 * mounts the component and looks at the result.
 *
 * Sibling specs under views/**\/tutoring2 are mostly smoke-level
 * ("exports a component"). This one deliberately is not.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import ParentTutoring2ActivitiesView from './ParentTutoring2ActivitiesView.vue';
import { SubmissionsService } from '@/services/tutoring2/submissions';
import type {
  StudentActivityRow,
  StudentSubmissionsSummary,
} from '@/types/tutoring2/activity';

vi.mock('@/services/tutoring2/submissions', () => ({
  SubmissionsService: {
    listByStudent: vi.fn(),
    listByActivity: vi.fn(),
    grade: vi.fn(),
  },
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { studentId: 'st-1' } }),
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: () => {},
}));

function makeRow(i: number, submitted: boolean): StudentActivityRow {
  return {
    activity: {
      id: `act-${i}`,
      learning_group_id: 'g-1',
      kind: 'tugas',
      title: `Tugas ${i}`,
      due_at: '2026-03-01T12:00:00+07:00',
      max_points: 100,
    },
    submission: submitted
      ? {
          id: `sub-${i}`,
          activity_id: `act-${i}`,
          enrollment_id: 'en-1',
          status: 'graded',
          score: 90,
        }
      : null,
  };
}

function makeSummary(o: Partial<StudentSubmissionsSummary> = {}): StudentSubmissionsSummary {
  return { total: 0, missing: 0, submitted: 0, graded: 0, pending: 0, ...o };
}

/**
 * KpiStripCards is stubbed to expose the VALUES it was handed, because
 * the assertions below are about what the numbers say, not how the tile
 * chrome looks — that belongs to the component that owns it.
 */
async function mountView() {
  setActivePinia(createPinia());
  const i18n = createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: { id: {} },
    missingWarn: false,
    fallbackWarn: false,
  });

  const w = mount(ParentTutoring2ActivitiesView, {
    global: {
      plugins: [i18n],
      stubs: {
        BrandPageHeader: true,
        // Exposes the TONE so a row's rendered status can be asserted:
        // 'success' = graded, 'danger'/'neutral' = the null pseudo-status
        // "belum dikumpulkan". That distinction is the whole bug.
        StatusBadge: {
          props: ['label', 'tone'],
          template: '<span data-testid="row-status" :data-tone="tone" />',
        },
        KpiStripCards: {
          props: ['cards'],
          template:
            '<div data-testid="kpis">{{ cards.map((c) => c.value).join("|") }}</div>',
        },
        PageFilterToolbar: {
          template: '<div><slot name="chips" /></div>',
        },
        AppFilterChip: {
          props: ['label', 'value'],
          template: '<button data-testid="chip" />',
        },
        // Mirrors AsyncView's real contract: it renders the default slot
        // ONLY for 'content'. Recording the status is what lets the empty
        // -state assertion below be about behaviour rather than markup.
        AsyncView: {
          props: ['state'],
          template:
            '<div data-testid="async" :data-status="state?.status"><slot v-if="state?.status === \'content\'" /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

describe('ParentTutoring2ActivitiesView', () => {
  beforeEach(() => vi.clearAllMocks());

  it('asks the server for one child, not a per-activity fan-out', async () => {
    vi.mocked(SubmissionsService.listByStudent).mockResolvedValue({
      items: [makeRow(1, true)],
      summary: makeSummary({ total: 1, graded: 1 }),
      total: 1,
      lastPage: 1,
    });

    await mountView();

    expect(SubmissionsService.listByStudent).toHaveBeenCalledTimes(1);
    expect(SubmissionsService.listByStudent).toHaveBeenCalledWith('st-1', {
      per_page: 200,
    });
    // The per-activity call is what the old fan-out used. It must not fire.
    expect(SubmissionsService.listByActivity).not.toHaveBeenCalled();
  });

  it('renders the EMPTY state when the child has no activities', async () => {
    // Regression #2. The loader must hand back null, not an object with an
    // empty rows array — useDataRefresh only recognises null/undefined/[]
    // as empty, so an object here silently becomes a blank content branch.
    vi.mocked(SubmissionsService.listByStudent).mockResolvedValue({
      items: [],
      summary: makeSummary(),
      total: 0,
      lastPage: 1,
    });

    const w = await mountView();

    expect(w.get('[data-testid="async"]').attributes('data-status')).toBe('empty');
  });

  it('keeps KPI counts on the whole set, not on the rows it loaded', async () => {
    // Regression #1's sibling: the tiles used to be counted from loaded
    // rows, so they inherited the fan-out's cap and under-reported. They
    // now read meta.summary. One row loaded, thirty-five in the set.
    vi.mocked(SubmissionsService.listByStudent).mockResolvedValue({
      items: [makeRow(1, true)],
      summary: makeSummary({ total: 35, missing: 30, submitted: 4, graded: 1, pending: 34 }),
      total: 35,
      lastPage: 1,
    });

    const w = await mountView();

    const kpis = w.get('[data-testid="kpis"]').text();
    // total | pending | graded | overdue
    expect(kpis.startsWith('35|34|1|')).toBe(true);
  });

  it('shows a handed-in row as handed in, at any depth in the list', async () => {
    // Regression #1 proper. Row 35 carrying a submission must not be
    // rendered as "belum dikumpulkan".
    const rows = [
      ...Array.from({ length: 34 }, (_, i) => makeRow(i + 1, false)),
      makeRow(35, true),
    ];
    vi.mocked(SubmissionsService.listByStudent).mockResolvedValue({
      items: rows,
      summary: makeSummary({ total: 35, missing: 34, graded: 1, pending: 34 }),
      total: 35,
      lastPage: 1,
    });

    const w = await mountView();

    const tones = w.findAll('[data-testid="row-status"]').map((n) => n.attributes('data-tone'));
    expect(tones).toHaveLength(35);
    // Exactly one row is graded — the 35th. Under the old 30-lookup cap
    // this came back null and rendered as the "belum dikumpulkan"
    // pseudo-status alongside the 34 genuine non-submissions.
    expect(tones.filter((x) => x === 'success')).toHaveLength(1);
    expect(tones.filter((x) => x === 'success' || x === 'danger' || x === 'neutral')).toHaveLength(35);
  });

  it('walks further pages when the server reports more than one', async () => {
    vi.mocked(SubmissionsService.listByStudent)
      .mockResolvedValueOnce({
        items: [makeRow(1, false)],
        summary: makeSummary({ total: 2, missing: 2, pending: 2 }),
        total: 2,
        lastPage: 2,
      })
      .mockResolvedValueOnce({
        items: [makeRow(2, false)],
        summary: makeSummary({ total: 2, missing: 2, pending: 2 }),
        total: 2,
        lastPage: 2,
      });

    await mountView();

    expect(SubmissionsService.listByStudent).toHaveBeenCalledTimes(2);
    expect(SubmissionsService.listByStudent).toHaveBeenLastCalledWith('st-1', {
      per_page: 200,
      page: 2,
    });
  });
});
